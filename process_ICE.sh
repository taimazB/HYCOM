#!/bin/bash

#SBATCH --job-name=HYCOM_ICE
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --time=12:00:00
#SBATCH --output=../logs/%j.out
#SBATCH --error=../logs/%j.err
#SBATCH --priority=TOP

date
source ../configs.sh

python3 ${MAIN}/scripts/cnvMaster_RGBcoded_ICE.py --fileName=$f --minZoom=0 --maxZoom=4 || exit 1

date=$(echo $f | cut -d_ -f4 | sed 's/12$//')
hr=$(echo $f | cut -d_ -f5 | sed 's/t0*//')
saveDateTime=$(date -d "${date} 12 +${hr} hours" +%Y%m%d_%H%M)
date=${date}_1200 ## ALL FORMATS: YYYYmmdd_HHMM

(
    for field in seaiceFraction seaiceThickness; do
        cd ${MAIN}/tiles/${field}/${saveDateTime} || exit 1
        ls | parallel "s3cmd put -q -r --acl-public {} s3://modeltiles/HYCOM/${date}/${field}/${saveDateTime}/"
        rm -r ${MAIN}/tiles/${field}/${saveDateTime}
    done

    ##  UPLOAD SST & SSS TO TEMPERATURE & SALINITY DIRECTORIES
    cd ${MAIN}/tiles/seaSurfaceTemperature/${saveDateTime} || exit 1
    ls | parallel "s3cmd put -q -r --acl-public {} s3://modeltiles/HYCOM/${date}/temperature/${saveDateTime}/depth-surface/"
    rm -r ${MAIN}/tiles/seaSurfaceTemperature/${saveDateTime}

    cd ${MAIN}/tiles/seaSurfaceSalinity/${saveDateTime} || exit 1
    ls | parallel "s3cmd put -q -r --acl-public {} s3://modeltiles/HYCOM/${date}/salinity/${saveDateTime}/depth-surface/"
    rm -r ${MAIN}/tiles/seaSurfaceSalinity/${saveDateTime}


    echo -e "$(date +%F_%T)\t$f" >>${MAIN}/.processed
    rm ${MAIN}/.active_$f

    cd ${MAIN}
    python3 chk.py
    ${MAIN}/OC_chk.sh
) &

rm ${MAIN}/nc/$f
date
