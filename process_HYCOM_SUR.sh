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


date=$(echo $f | cut -d_ -f4 | sed 's/12$//')
hr=$(echo $f | cut -d_ -f5 | sed 's/t0*//')
export saveDateTime=$(date -d "${date} 12 +${hr} hours" +%Y%m%d_%H)

###################################################################################
##  EXTRACT FIELDS FROM ORIGINAL NC
function extract {
    input=$1
    field=$(echo $input | cut -d- -f1)
    varName=$(echo $input | cut -d- -f2)
    extractDir=${MAIN}/extracted/${field}
    mkdir -p ${extractDir}
    cdo -O -z zip_1 -chname,${varName},${field} -select,name=${varName} -chname,lat,latitude -chname,lon,longitude -sellonlatbox,-180,180,-90,90 $f ${extractDir}/${MODEL}_${field}_${saveDateTime}.nc
    ncwa -4 -L1 -O -a time,depth ${extractDir}/${MODEL}_${field}_${saveDateTime}.nc ${extractDir}/${MODEL}_${field}_${saveDateTime}.nc
    ncks -O -v ${field} ${extractDir}/${MODEL}_${field}_${saveDateTime}.nc ${extractDir}/${MODEL}_${field}_${saveDateTime}.nc
    python3 /home/taimaz/scripts/ncZip.py ${extractDir}/${MODEL}_${field}_${saveDateTime}.nc
}
export -f extract

parallel "extract {}" ::: heatFlux-qtot waterFlux-emp seaSurfaceHeight-ssh boundaryLayerThickness-surface_boundary_layer_thickness mixedLayerDepth-mixed_layer_thickness


###################################################################################
##  CLEANUP
rm ${MAIN}/nc/$f
echo -e "`date +%F_%T`\t$f" >> ${MAIN}/.processed

date