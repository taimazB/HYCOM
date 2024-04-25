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

##  Download and Process
function DnP() {
    t=$1

    # TEMPERATURE
    file="hycom_glby_930_${lastAvailDate}12_t$(printf %03d ${t})_ts3z.nc"
    grep ${file} ${MAIN}/.processed >/dev/null 2>&1
    ##  ONLY PROCEED IF FILE IS NOT PROCESSED ALREADY
    if [[ $? -ne 0 ]]; then
        wget -nc "${ftpLink}/${file}"
        if [[ -e ${file} ]]; then
            sbatch --export=f=${file} ${MAIN}/process_HYCOM_TS.sh
        fi
    fi

    # CURRENT
    file="hycom_glby_930_${lastAvailDate}12_t$(printf %03d ${t})_uv3z.nc"
    grep ${file} ${MAIN}/.processed >/dev/null 2>&1
    ##  ONLY PROCEED IF FILE IS NOT PROCESSED ALREADY
    if [[ $? -ne 0 ]]; then
        wget -nc "${ftpLink}/${file}"
        if [[ -e ${file} ]]; then
            sbatch --export=f=${file} ${MAIN}/process_HYCOM_UV.sh
        fi
    fi

    # SURFACE
    file="hycom_GLBy0.08_930_${lastAvailDate}12_t$(printf %03d ${t})_sur.nc"
    grep ${file} ${MAIN}/.processed >/dev/null 2>&1
    ##  ONLY PROCEED IF FILE IS NOT PROCESSED ALREADY
    if [[ $? -ne 0 ]]; then
        wget -nc "${ftpLink}/${file}"
        if [[ -e ${file} ]]; then
            sbatch --export=f=${file} ${MAIN}/process_HYCOM_SUR.sh
        fi
    fi
}
export -f DnP

##  FUNCTIONS
############################################################################

rm -r ${MAIN}/nc ${MAIN}/extracted ${MAIN}/tiles 2>/dev/null
mkdir -p ${MAIN}/nc ${MAIN}/extracted ${MAIN}/tiles/temperature ${MAIN}/tiles/salinity ${MAIN}/tiles/density
mkdir ${MAIN}/logs 2>/dev/null
cd ${MAIN}/nc
parallel -j 8 'DnP {}' ::: $(seq 0 3 180)
