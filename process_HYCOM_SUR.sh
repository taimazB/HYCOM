#!/bin/bash

#SBATCH --job-name=HYCOM_SUR
#SBATCH --ntasks=5
#SBATCH --cpus-per-task=1
#SBATCH --time=12:00:00
#SBATCH --output=../logs/%j.out
#SBATCH --error=../logs/%j.err
#SBATCH --priority=1001

source ../configs.sh
date


echo $f
date=$(echo $f | cut -d_ -f4 | sed 's/12$//')
export HR=$(echo $f | cut -d_ -f5 | sed 's/t//')

###################################################################################
##  EXTRACT FIELDS FROM ORIGINAL NC
function extract {
    input=$1
    field=$(echo $input | cut -d- -f1)
    varName=$(echo $input | cut -d- -f2)
    extractDir=${MAIN}/extracted/${field}
    mkdir -p ${extractDir}
    cdo -O -z zip_1 -chname,${varName},${field} -select,name=${varName} -chname,lat,latitude -chname,lon,longitude -sellonlatbox,-180,180,-90,90 $f ${extractDir}/${MODEL}_${field}_${HR}.nc
    ncwa -4 -L1 -O -a time,depth ${extractDir}/${MODEL}_${field}_${HR}.nc ${extractDir}/${MODEL}_${field}_${HR}.nc
    ncks -O -v ${field} ${extractDir}/${MODEL}_${field}_${HR}.nc ${extractDir}/${MODEL}_${field}_${HR}.nc
    python3 /home/taimaz/scripts/ncZip.py ${extractDir}/${MODEL}_${field}_${HR}.nc
    aws s3 sync --exclude "tiles/*" ${MAIN}/extracted/${field}/${MODEL}_${field}_${HR}.nc s3://oceangns-model-files/HYCOM/${date}/${field}/ &
}
export -f extract

parallel "extract {}" ::: heatFlux-qtot waterFlux-emp seaSurfaceHeight-ssh boundaryLayerThickness-surface_boundary_layer_thickness mixedLayerDepth-mixed_layer_thickness


###################################################################################
##  TILES (LEVEL 0)
cd ${MAIN}/extracted/temperature/HYCOM_temperature_${HR}
python3 ${MAIN}/scripts/cnvMaster_RGBcoded.py --fileName="HYCOM_temperature_${HR}_0.nc" --minZoom=2 --maxZoom=7 --minOrg=-100 --step=0.1
(
    s3cmd put --recursive --acl-public tiles/HYCOM_temperature_${HR}_0 s3://modeltiles/HYCOM/${date}/temperature/
) &


###################################################################################
##  CLEANUP
echo -e "`date +%F_%T`\t$f" >> ${MAIN}/.processed


date