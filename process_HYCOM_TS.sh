#!/bin/bash

#SBATCH --job-name=HYCOM_TS
#SBATCH --ntasks=32
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
    extractDir=${MAIN}/extracted/${field}/${MODEL}_${field}_${saveDateTime}
    mkdir -p ${extractDir}
    cdo -O -chname,${varName},${field} -select,name=${varName} -sellonlatbox,-180,180,-90,90 $f ${extractDir}/${field}.nc
}
export -f extract

parallel "extract {}" ::: temperature-water_temp salinity-salinity

###################################################################################
##  EXTRACT TEMPERATURE & SALINITY LEVELS
function extractLevel {
    field=$1
    level=$2
    extractDir=${MAIN}/extracted/${field}/${MODEL}_${field}_${saveDateTime}
    file=${extractDir}/${MODEL}_${field}_${saveDateTime}_${level}.nc
    cdo -O -z zip_1 -sellevel,${level} -chname,lat,latitude -chname,lon,longitude ${extractDir}/${field}.nc ${file}
    ncwa -O -4 -L1 -a time,depth ${file} ${file}
    ncks -O -v ${field} ${file} ${file}
    python3 /home/taimaz/scripts/ncZip.py ${file} ${file}
}
export -f extractLevel

levels=(5000 4000 3000 2500 2000 1500 1250 1000 900 800 700 600 500 400 350 300 250 200 150 125 100 90 80 70 60 50 45 40 35 30 25 20 15 12 10 8 6 4 2 0)

parallel "extractLevel temperature {}" ::: ${levels[@]}
rm ${MAIN}/extracted/temperature/${MODEL}_temperature_${saveDateTime}/temperature.nc
# rsync -aurq -e "ssh -p ${SERVER_PORT}" ${MAIN}/extracted/temperature/${MODEL}_temperature_${saveDateTime} ${SERVER_IP}:${SERVER_DIR}/temperature/ &

parallel "extractLevel salinity {}" ::: ${levels[@]}
rm ${MAIN}/extracted/salinity/${MODEL}_salinity_${saveDateTime}/salinity.nc
# rsync -aurq -e "ssh -p ${SERVER_PORT}" ${MAIN}/extracted/salinity/${MODEL}_salinity_${saveDateTime} ${SERVER_IP}:${SERVER_DIR}/salinity/ &

###################################################################################
##  DENSITY
mkdir -p ${MAIN}/extracted/density/${MODEL}_density_${saveDateTime}

function density {
    level=$1
    fileT=${MAIN}/extracted/temperature/${MODEL}_temperature_${saveDateTime}/${MODEL}_temperature_${saveDateTime}_${level}.nc
    fileS=${MAIN}/extracted/salinity/${MODEL}_salinity_${saveDateTime}/${MODEL}_salinity_${saveDateTime}_${level}.nc
    fileD=${MAIN}/extracted/density/${MODEL}_density_${saveDateTime}/${MODEL}_density_${saveDateTime}_${level}.nc
    python3 ${MAIN}/scripts/calcDensity.py ${fileT} ${fileS} ${fileD}
}
export -f density

parallel "density {}" ::: ${levels[@]}
# rsync -aurq -e "ssh -p ${SERVER_PORT}" ${MAIN}/extracted/density/ ${SERVER_IP}:${SERVER_DIR}/density/ &

###################################################################################
##  TILES (LEVEL 0)
cd ${MAIN}/extracted/temperature/HYCOM_temperature_${saveDateTime}
python3 ${MAIN}/scripts/cnvMaster_RGBcoded.py --fileName="HYCOM_temperature_${saveDateTime}_0.nc" --minZoom=2 --maxZoom=7 --minOrg=-100 --step=0.1
mv tiles/* ${MAIN}/tiles/temperature/
rm -r tiles

cd ${MAIN}/extracted/salinity/HYCOM_salinity_${saveDateTime}
python3 ${MAIN}/scripts/cnvMaster_RGBcoded.py --fileName="HYCOM_salinity_${saveDateTime}_0.nc" --minZoom=2 --maxZoom=7 --minOrg=0 --step=0.01
mv tiles/* ${MAIN}/tiles/salinity/
rm -r tiles

cd ${MAIN}/extracted/density/HYCOM_density_${saveDateTime}
python3 ${MAIN}/scripts/cnvMaster_RGBcoded.py --fileName="HYCOM_density_${saveDateTime}_0.nc" --minZoom=2 --maxZoom=7 --minOrg=900 --step=0.1
mv tiles/* ${MAIN}/tiles/density/
rm -r tiles

###################################################################################
##  CLEANUP
rm ${MAIN}/nc/$f
echo $f >> ${MAIN}/.processed


date
