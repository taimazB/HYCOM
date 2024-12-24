source ./configs.sh

f=$1

date=$(echo $f | cut -d_ -f4 | sed 's/12$//')
hr=$(echo $f | cut -d_ -f5 | sed 's/t0*//')
export saveDateTime=$(date -d "${date} 12 +${hr} hours" +%Y%m%d_%H)
levels=(5000 4000 3000 2500 2000 1500 1250 1000 900 800 700 600 500 400 350 300 250 200 150 125 100 90 80 70 60 50 45 40 35 30 25 20 15 12 10 8 6 4 2 0)
export field="current"
export extractDir=${MAIN}/extracted/${field}/${MODEL}_${field}_${saveDateTime}

function archive {
    field=$1
    rsync -aurq --remove-source-files -e "ssh -p ${SERVER_PORT_OG}" --rsync-path="mkdir -p ${SERVER_DIR_OG}/${field}; rsync" ${MAIN}/extracted/${field}/${MODEL}_${field}_${saveDateTime} ${SERVER_IP_OG}:${SERVER_DIR_OG}/${field}
}


##  Extract u & v
mkdir -p ${extractDir}
# cdo -O -select,name=water_u,water_v -sellonlatbox,-180,180,-90,90 $f ${extractDir}/uv3z.nc
function extCurrent {
    level=$1
    file=${extractDir}/${MODEL}_current_${saveDateTime}_${level}.nc
    cdo -O -sellevel,${level} ${MAIN}/nc/$f ${file}.1
    ncwa -4 -L1 -O -a time,depth ${file}.1 ${file}.1
    cdo -O -z zip_1 -chname,water_u,u -chname,water_v,v -chname,lat,latitude -chname,lon,longitude ${file}.1 ${file}
    rm ${file}.1
}
export -f extCurrent
parallel "extCurrent {}" ::: ${levels[@]}
# rm ${extractDir}/uv3z.nc


##  Depth average (for PP)
cdo ensmean ${extractDir}/*.nc ${extractDir}/${MODEL}_${field}_${saveDateTime}_mean.nc


##  Extract bottom u & v
# cd ${extractDir}
# file=${extractDir}/${MODEL}_current_${saveDateTime}_bottom.nc
# cdo -O -select,name=water_u_bottom,water_v_bottom -sellonlatbox,-180,180,-90,90 ${MAIN}/nc/$f ${file}.1
# ncwa -O -4 -L1 -a time,depth ${file}.1 ${file}.1
# cdo -O -z zip_1 -chname,water_u_bottom,u -chname,water_v_bottom,v -chname,lat,latitude -chname,lon,longitude ${file}.1 ${file}
# rm ${file}.1


##  EXTRA ZIP
cd ${extractDir}
ls | parallel "python3 /home/taimaz/scripts/ncZip.py {}"

###################################################################################
##  ARCHIEVE
(
    cd ${MAIN}
    archive current

    rm ${MAIN}/.active_$f
    echo -e "$(date +%F_%T)\t${f}" >>${MAIN}/.processed
    ./finalize.sh
) &

rm ${MAIN}/nc/$f
date
