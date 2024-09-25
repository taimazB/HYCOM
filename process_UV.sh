#!/bin/bash

#SBATCH --job-name=HYCOM_UV
#SBATCH --ntasks=32
#SBATCH --cpus-per-task=1
#SBATCH --time=12:00:00
#SBATCH --output=../logs/%j.out
#SBATCH --error=../logs/%j.err
#SBATCH --priority=1001

date
source ../configs.sh

python3 ${MAIN}/scripts/cnvMaster_current.py --fileName=$f --minZoom=0 --maxZoom=4 || exit 1

date=$(echo $f | cut -d_ -f4 | sed 's/12$//')
hr=$(echo $f | cut -d_ -f5 | sed 's/t0*//')
saveDateTime=$(date -d "${date} 12 +${hr} hours" +%Y%m%d_%H%M)

(
    rsync -aur --rsync-path="mkdir -p ${SERVER_DIR}.new/current && rsync" ${MAIN}/tiles/current/${saveDateTime} root@${SERVER_IP}:${SERVER_DIR}.new/current/

    cd ${MAIN}
    rm ${MAIN}/.active_$f
    ./finalize.sh
) &

rm ${MAIN}/nc/$f
date
