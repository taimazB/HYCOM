#!/bin/bash

source ./configs.sh

if [[ -e ${MAIN}/.active ]] || [[ -e ${MAIN}/.cleanup ]]; then
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
}
export -f DnP

##  FUNCTIONS
############################################################################

rm -r ${MAIN}/nc ${MAIN}/extracted ${MAIN}/tiles 2>/dev/null
mkdir -p ${MAIN}/nc ${MAIN}/extracted ${MAIN}/tiles/temperature ${MAIN}/tiles/salinity ${MAIN}/tiles/density
mkdir ${MAIN}/logs 2>/dev/null
cd ${MAIN}/nc
parallel -j 4 'DnP {}' ::: $(seq 0 3 180)
