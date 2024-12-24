source ./configs.sh

f=$1

date=$(echo $f | cut -d_ -f4 | sed 's/12$//')
hr=$(echo $f | cut -d_ -f5 | sed 's/t0*//')
export saveDateTime=$(date -d "${date} 12 +${hr} hours" +%Y%m%d_%H)

function archive {
    field=$1
    rsync -aurq --remove-source-files -e "ssh -p ${SERVER_PORT_OG}" --rsync-path="mkdir -p ${SERVER_DIR_OG}/${field}; rsync" ${MAIN}/extracted/${field}/${MODEL}_${field}_${saveDateTime}.nc ${SERVER_IP_OG}:${SERVER_DIR_OG}/${field}
}
export -f archive

###################################################################################
##  Extract
cd ${MAIN}/nc
ncwa -4 -L1 -O -a time,depth ${MAIN}/nc/$f ${MODEL}_ICE_${saveDateTime}.nc.1
cdo -O -z zip_1 -chname,sic,seaiceFraction -chname,sih,seaiceThickness -chname,lat,latitude -chname,lon,longitude ${MODEL}_ICE_${saveDateTime}.nc.1 ${MODEL}_ICE_${saveDateTime}.nc

function extract {
    var=$1
    extractDir=${MAIN}/extracted/${var}
    mkdir -p ${extractDir} 2>/dev/null
    file=${extractDir}/${MODEL}_${var}_${saveDateTime}.nc
    ncks -O -v ${var} ${MODEL}_ICE_${saveDateTime}.nc ${file}
    python3 /home/taimaz/scripts/ncZip.py ${file}
}
export -f extract
parallel "extract {}" ::: seaiceFraction seaiceThickness

(
    cd ${MAIN}
    parallel "archive {}" ::: seaiceFraction seaiceThickness

    rm ${MAIN}/.active_$f
    echo -e "$(date +%F_%T)\t${f}" >>${MAIN}/.processed
    ./finalize.sh
) &

rm ${MAIN}/nc/${f} ${MAIN}/nc/${MODEL}_ICE_${saveDateTime}.nc*
