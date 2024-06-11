#!/bin/bash

#SBATCH --job-name=HYCOM
#SBATCH --ntasks=32
#SBATCH --cpus-per-task=1
#SBATCH --time=12:00:00
#SBATCH --output=../logs/%j.out
#SBATCH --error=../logs/%j.err
#SBATCH --priority=1001

date
source ../configs.sh

python3 ${MAIN}/scripts/cnvMaster_RGBcoded.py --fileName=$f --minZoom=0 --maxZoom=4 || exit 1

date=$(echo $f | cut -d_ -f4 | sed 's/12$//')
hr=$(echo $f | cut -d_ -f5 | sed 's/t0*//')
saveDateTime=$(date -d "${date} 12 +${hr} hours" +%Y%m%d_%H%M)
date=${date}_1200 ## ALL FORMATS: YYYYmmdd_HHMM

(
    s3cmd put --recursive --acl-public ${MAIN}/tiles/temperature/${saveDateTime} s3://modeltiles/HYCOM/${date}/temperature/
    rm -r ${MAIN}/tiles/temperature/${saveDateTime}
    s3cmd put --recursive --acl-public ${MAIN}/tiles/salinity/${saveDateTime} s3://modeltiles/HYCOM/${date}/salinity/
    rm -r ${MAIN}/tiles/salinity/${saveDateTime}
    s3cmd put --recursive --acl-public ${MAIN}/tiles/density/${saveDateTime} s3://modeltiles/HYCOM/${date}/density/
    rm -r ${MAIN}/tiles/density/${saveDateTime}

    echo -e "$(date +%F_%T)\t$f" >>${MAIN}/.processed
    rm ${MAIN}/.active_$f

    ##  MARK AS DONE IF POSSIBLE
    ${MAIN}/chk.sh ${date}
) &

rm ${MAIN}/nc/$f
date
