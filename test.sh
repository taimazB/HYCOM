#!/bin/bash

#SBATCH --job-name=HYCOM_UV
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --time=12:00:00
#SBATCH --priority=1001

source ../configs.sh
rsync -aurq -e "ssh -p ${SERVER_PORT}" ${MAIN}/hycom_glby_930_2024042212_t006_ts3z.nc ${SERVER_IP}:${SERVER_DIR}/temperature/ &
