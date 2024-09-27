#!/bin/bash

#SBATCH --job-name=HYCOM_ICE
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --time=12:00:00
#SBATCH --output=./logs/%j.out
#SBATCH --error=./logs/%j.err
#SBATCH --priority=TOP

date
source ./configs.sh
echo $f

python3 ${MAIN}/scripts/cnvMaster_RGBcoded_ICE.py --fileName=$f --minZoom=0 --maxZoom=4

date=$(echo $f | cut -d_ -f4 | sed 's/12$//')
hr=$(echo $f | cut -d_ -f5 | sed 's/t0*//')
saveDateTime=$(date -d "${date} 12 +${hr} hours" +%Y%m%d_%H%M)

(
    for field in seaiceFraction seaiceThickness; do
        rsync -aur --rsync-path="mkdir -p ${SERVER_DIR}.new/${field} && rsync" ${MAIN}/tiles/${field}/${saveDateTime} root@${SERVER_IP}:${SERVER_DIR}.new/${field}/
    done

    cd ${MAIN}
    rm ${MAIN}/.active_$f
    ./finalize.sh
) &

rm ${MAIN}/nc/$f
date
