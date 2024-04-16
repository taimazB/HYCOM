#!/bin/bash

#SBATCH --job-name=HYCOM
#SBATCH --nodes=1
#SBATCH --cpus-per-task=32
#SBATCH --time=12:00:00
#SBATCH --output=logs/%j.out
#SBATCH --error=logs/%j.err

source ./configs.sh

function updateLastProcessed {
    ssh -p ${SERVER_PORT} ${SERVER_IP} <<EOF
date -u +%Y%m%dT%H%M%S > ${SERVER_DIR}/lastProcessed
cd ${SERVER_DIR}/
for d in */; do
cd ${SERVER_DIR}/\$d
ls | xargs -I{} basename {} .nc > .availDateTimes
done
EOF

    rm ${MAIN}/.active
}

cd ${MAIN}/nc

ls *sur.nc | parallel "bash ${MAIN}/process_HYCOM_SUR.sh {}"  ## Do SUR first to free up some space.
ls *_ts3z.nc | parallel "bash ${MAIN}/process_HYCOM_TS.sh {}"
ls *_uv3z.nc | parallel -j 16 "bash ${MAIN}/process_HYCOM_UV.sh {}"

updateLastProcessed
