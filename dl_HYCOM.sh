#!/bin/bash

source ./configs.sh

##  Do not use more than 10 concurrent connections per IP address downloading from ftp.hycom.org

export ftpLink='ftps://ftp.hycom.org/datasets/GLBy0.08/expt_93.0/data/forecasts'

files=($(curl -l "ftp://ftp.hycom.org/datasets/GLBy0.08/expt_93.0/data/forecasts/"))
noOfFiles=${#files[@]}
export lastAvailDate=$(echo ${files[$((noOfFiles - 1))]} | cut -d_ -f4 | sed 's/12$//')
lastAvailTime=$(echo ${files[$((noOfFiles - 1))]} | cut -d_ -f5 | sed 's/t0*//')

lastDlDate=$(awk '{print $1}' ${MAIN}/.lastDlDateTime)
lastDlTime=$(awk '{print $2}' ${MAIN}/.lastDlDateTime)

if [[ -e ${MAIN}/.active ]] || [[ -z ${lastAvailDate} ]] || [[ ${lastAvailDate}${lastAvailTime} == ${lastDlDate}${lastDlTime} ]]; then
    exit
fi

touch ${MAIN}/.active

############################################################################
##  FUNCTIONS

function dl() {
    t=$1
    
    wget -nc "${ftpLink}/hycom_glby_930_${lastAvailDate}12_t$(printf %03d ${t})_uv3z.nc"
    wget -nc "${ftpLink}/hycom_glby_930_${lastAvailDate}12_t$(printf %03d ${t})_ts3z.nc"
    wget -nc "${ftpLink}/hycom_GLBy0.08_930_${lastAvailDate}12_t$(printf %03d ${t})_sur.nc"
}
export -f dl

##  FUNCTIONS
############################################################################

rm -r ${MAIN}/nc ${MAIN}/extracted 2>/dev/null
mkdir ${MAIN}/nc
cd ${MAIN}/nc

if [[ ${lastAvailDate} != ${lastDlDate} ]]; then
    parallel -j 5 'dl {}' ::: $(seq 0 3 ${lastAvailTime})
elif [[ ${lastAvailTime} != ${lastDlTime} ]]; then
    parallel -j 5 'dl {}' ::: $(seq ${lastDlTime} 3 ${lastAvailTime})
fi

echo "${lastAvailDate} ${lastAvailTime}" > ${MAIN}/.lastDlDateTime

cd ${MAIN}
sbatch job_HYCOM.sh
