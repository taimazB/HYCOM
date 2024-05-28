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


echo $f
date=$(echo $f | cut -d_ -f4 | sed 's/12$//')
hr=$(echo $f | cut -d_ -f5 | sed 's/t0*//')
export saveDateTime=$(date -d "${date} 12 +${hr} hours" +%Y%m%d_%H)

###################################################################################
##  EXTRACT FIELDS FROM ORIGINAL NC
function extract {
    input=$1
    field=$(echo $input | cut -d- -f1)
    varName=$(echo $input | cut -d- -f2)
    extractDir=${MAIN}/extracted/${field}/${saveDateTime}
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
    extractDir=${MAIN}/extracted/${field}/${saveDateTime}
    file=${extractDir}/depth-${level}.nc
    cdo -O -z zip_1 -sellevel,${level} -chname,lat,latitude -chname,lon,longitude ${extractDir}/${field}.nc ${file}
    ncwa -O -4 -L1 -a time,depth ${file} ${file}
    ncks -O -v ${field} ${file} ${file}
    python3 /home/taimaz/scripts/ncZip.py ${file} ${file}
}
export -f extractLevel

levels=(5000 4000 3000 2500 2000 1500 1250 1000 900 800 700 600 500 400 350 300 250 200 150 125 100 90 80 70 60 50 45 40 35 30 25 20 15 12 10 8 6 4 2 0)
for field in temperature salinity; do
    parallel "extractLevel ${field} {}" ::: ${levels[@]}
    rm ${MAIN}/extracted/${field}/${saveDateTime}/${field}.nc
    aws s3 sync --exclude "tiles/*" ${MAIN}/extracted/${field}/${saveDateTime} s3://oceangns-model-files/HYCOM/${date}/${field}/${saveDateTime} &
done

###################################################################################
##  DENSITY
mkdir -p ${MAIN}/extracted/density/${saveDateTime}

function density {
    level=$1
    fileT=${MAIN}/extracted/temperature/${saveDateTime}/depth-${level}.nc
    fileS=${MAIN}/extracted/salinity/${saveDateTime}/depth-${level}.nc
    fileD=${MAIN}/extracted/density/${saveDateTime}/depth-${level}.nc
    python3 ${MAIN}/scripts/calcDensity.py ${fileT} ${fileS} ${fileD}
}
export -f density

parallel "density {}" ::: ${levels[@]}
aws s3 sync --exclude "tiles/*" ${MAIN}/extracted/density/${saveDateTime} s3://oceangns-model-files/HYCOM/${date}/density/${saveDateTime} &

###################################################################################
##  TILES (LEVEL 0)
cd ${MAIN}/extracted/temperature/${saveDateTime}
python3 ${MAIN}/scripts/cnvMaster_RGBcoded.py --fileName="depth-0.nc" --minZoom=2 --maxZoom=7 --minOrg=-100 --step=0.1
(
    s3cmd put --recursive --acl-public tiles/depth-0 s3://modeltiles/HYCOM/${date}/temperature/
) &

cd ${MAIN}/extracted/salinity/${saveDateTime}
python3 ${MAIN}/scripts/cnvMaster_RGBcoded.py --fileName="depth-0.nc" --minZoom=2 --maxZoom=7 --minOrg=0 --step=0.01
(
    s3cmd put --recursive --acl-public tiles/depth-0 s3://modeltiles/HYCOM/${date}/salinity/
) &

cd ${MAIN}/extracted/density/${saveDateTime}
python3 ${MAIN}/scripts/cnvMaster_RGBcoded.py --fileName="depth-0.nc" --minZoom=2 --maxZoom=7 --minOrg=900 --step=0.1
(
    s3cmd put --recursive --acl-public tiles/depth-0 s3://modeltiles/HYCOM/${date}/density/
) &


###################################################################################
##  CLEANUP
echo -e "`date +%F_%T`\t$f" >> ${MAIN}/.processed


date
