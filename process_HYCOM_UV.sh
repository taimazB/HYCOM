#!/bin/bash

#SBATCH --job-name=HYCOM_UV
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
export HR=$(echo $f | cut -d_ -f5 | sed 's/t//')

field="current"
export extractDir=${MAIN}/extracted/${field}/${MODEL}_${field}_${HR}

###################################################################################
##  Extract u & v
mkdir -p ${extractDir}
function extractLevel {
    level=$1
    file=${extractDir}/${MODEL}_current_${HR}_${level}.nc
    cdo -O -z zip_1 -sellevel,${level} -chname,water_u,u -chname,water_v,v -chname,lat,latitude -chname,lon,longitude -sellonlatbox,-180,180,-90,90 $f ${file}
    ncwa -4 -L1 -O -a time,depth ${file} ${file}
    ncks -O -v u,v ${file} ${file}
    python3 /home/taimaz/scripts/ncZip.py ${file}
}
export -f extractLevel

levels=(5000 4000 3000 2500 2000 1500 1250 1000 900 800 700 600 500 400 350 300 250 200 150 125 100 90 80 70 60 50 45 40 35 30 25 20 15 12 10 8 6 4 2 0)

parallel "extractLevel {}" ::: ${levels[@]}

##  Depth average (for PP)
cdo ensmean ${extractDir}/*.nc ${extractDir}/${MODEL}_${field}_${HR}_mean.nc

aws s3 sync --exclude "tiles/*" ${MAIN}/extracted/current/${MODEL}_current_${HR} s3://oceangns-model-files/HYCOM/${date}/current/${MODEL}_current_${HR} &

###################################################################################
##  CLEANUP
echo -e "`date +%F_%T`\t$f" >> ${MAIN}/.processed


date
