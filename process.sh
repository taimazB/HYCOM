#!/bin/bash

#SBATCH --job-name=HYCOM
#SBATCH --ntasks=32
#SBATCH --cpus-per-task=1
#SBATCH --time=12:00:00
#SBATCH --output=../logs/%j.out
#SBATCH --error=../logs/%j.err
#SBATCH --priority=1001

source ../configs.sh
date


python3 ${MAIN}/scripts/cnvMaster_RGBcoded.py --fileName=$f --minZoom=2 --maxZoom=4

date=$(echo $f | cut -d_ -f4 | sed 's/12$//')
hr=$(echo $f | cut -d_ -f5 | sed 's/t0*//')
saveDateTime=$(date -d "${date} 12 +${hr} hours" +%Y%m%d_%H%M)
s3cmd put --recursive --acl-public tiles/temperature/${saveDateTime} s3://modeltiles/HYCOM/${date}/temperature/ &
s3cmd put --recursive --acl-public tiles/salinity/${saveDateTime} s3://modeltiles/HYCOM/${date}/salinity/ &
s3cmd put --recursive --acl-public tiles/density/${saveDateTime} s3://modeltiles/HYCOM/${date}/density/ &


echo -e "`date +%F_%T`\t$f" >> ${MAIN}/.processed
date
