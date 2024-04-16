source ../configs.sh

f=$1

date=$(echo $f | cut -d_ -f4 | sed 's/12$//')
hr=$(echo $f | cut -d_ -f5 | sed 's/t0*//')
export saveDateTime=$(date -d "${date} 12 +${hr} hours" +%Y%m%d_%H)

function archive {
    field=$1
    rsync -aurq --remove-source-files -e "ssh -p ${SERVER_PORT}" ${MAIN}/extracted/${field}/${MODEL}_${field}_${saveDateTime}.nc ${SERVER_IP}:${SERVER_DIR}/${field}
}

###################################################################################
##  Extract
cdo -O -sellonlatbox,-180,180,-90,90 $f ${MODEL}_SUR_${saveDateTime}.nc.1
ncwa -4 -L1 -O -a time,depth ${MODEL}_SUR_${saveDateTime}.nc.1 ${MODEL}_SUR_${saveDateTime}.nc.1
cdo -O -z zip_1 -chname,qtot,heatFlux -chname,emp,waterFlux -chname,ssh,seaSurfaceHeight -chname,surface_boundary_layer_thickness,boundaryLayerThickness -chname,mixed_layer_thickness,mixedLayerDepth -chname,lat,latitude -chname,lon,longitude ${MODEL}_SUR_${saveDateTime}.nc.1 ${MODEL}_SUR_${saveDateTime}.nc

for var in heatFlux waterFlux seaSurfaceHeight boundaryLayerThickness mixedLayerDepth; do
    extractDir=${MAIN}/extracted/${var}
    mkdir -p ${extractDir} 2>/dev/null
    file=${extractDir}/${MODEL}_${var}_${saveDateTime}.nc
    ncks -v ${var} ${MODEL}_SUR_${saveDateTime}.nc ${file}
    python3 /home/taimaz/scripts/ncZip.py ${file}
    archive ${var} &
done

rm ${MODEL}_SUR_${saveDateTime}.nc*
rm $f
