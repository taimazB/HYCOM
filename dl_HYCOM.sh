#!/bin/bash

source ./configs.sh
n=`ls .active_* | wc -l`

if [[ $n -gt 0 ]] || [[ -e ${MAIN}/.cleanup ]]; then
    exit
fi

##  Do not use more than 10 concurrent connections per IP address downloading from ftp.hycom.org
export ftpLink='ftps://ftp.hycom.org/datasets/GLBy0.08/expt_93.0/data/forecasts'

files=($(curl -l "ftp://ftp.hycom.org/datasets/GLBy0.08/expt_93.0/data/forecasts/"))
noOfFiles=${#files[@]}
export lastAvailDate=$(echo ${files[$((noOfFiles - 1))]} | cut -d_ -f4 | sed 's/12$//')

if [[ -z ${lastAvailDate} ]]; then
    exit
fi

############################################################################
##  FUNCTIONS

##  Download and Process
function DnP() {
    t=$1

    # TEMPERATURE
    file="hycom_glby_930_${lastAvailDate}12_t$(printf %03d ${t})_ts3z.nc"
    grep ${file} ${MAIN}/.processed >/dev/null 2>&1
    ##  ONLY PROCEED IF FILE IS NOT PROCESSED ALREADY
    if [[ $? -ne 0 ]]; then
        wget -nc -t 2 "${ftpLink}/${file}"
        if [[ -e ${file} ]]; then
            sbatch --export=f=${file} ${MAIN}/process.sh
            touch ${MAIN}/.active_${file}
        fi
    fi

    # # CURRENT
    # file="hycom_glby_930_${lastAvailDate}12_t$(printf %03d ${t})_uv3z.nc"
    # grep ${file} ${MAIN}/.processed >/dev/null 2>&1
    # ##  ONLY PROCEED IF FILE IS NOT PROCESSED ALREADY
    # if [[ $? -ne 0 ]]; then
    #     wget -nc -t 2 "${ftpLink}/${file}"
    #     if [[ -e ${file} ]]; then
    #         sbatch --export=f=${file} ${MAIN}/process_HYCOM_UV.sh
    #     fi
    # fi

    # # SURFACE
    # file="hycom_GLBy0.08_930_${lastAvailDate}12_t$(printf %03d ${t})_sur.nc"
    # grep ${file} ${MAIN}/.processed >/dev/null 2>&1
    # ##  ONLY PROCEED IF FILE IS NOT PROCESSED ALREADY
    # if [[ $? -ne 0 ]]; then
    #     wget -nc -t 2 "${ftpLink}/${file}"
    #     if [[ -e ${file} ]]; then
    #         sbatch --export=f=${file} ${MAIN}/process_HYCOM_SUR.sh
    #     fi
    # fi
}
export -f DnP

##  FUNCTIONS
############################################################################

mkdir ${MAIN}/nc ${MAIN}/logs 2>/dev/null
cd ${MAIN}/nc
parallel -j 4 'DnP {}' ::: $(seq 0 3 180)
