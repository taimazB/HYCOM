#!/bin/bash

source ./configs.sh

if [[ -e ${MAIN}/.dl ]]; then
    exit
fi
> ${MAIN}/.dl

export ftpLink='https://tds.hycom.org/thredds/fileServer/datasets/ESPC-D-V02/data/forecasts'
export yesterday=$(date -d 'yesterday' +%Y%m%d)

############################################################################
##  FUNCTIONS

##  Download and Process
function DnP_TS() {
    t=$1
    HR=$(printf %03d ${t})

    file="US058GCOM-OPSnce.espc-d-031-hycom_fcst_glby008_${yesterday}12_t0${HR}_ts3z.nc"
    grep ${file} ${MAIN}/.processed >/dev/null 2>&1

    ##  ONLY PROCEED IF FILE IS NOT PROCESSED ALREADY
    if [[ $? -ne 0 ]]; then
        mkdir ${MAIN}/nc ${MAIN}/logs 2>/dev/null
        fileT="US058GCOM-OPSnce.espc-d-031-hycom_fcst_glby008_${yesterday}12_t0${HR}_t3z.nc"
        fileS="US058GCOM-OPSnce.espc-d-031-hycom_fcst_glby008_${yesterday}12_t0${HR}_s3z.nc"
        wget -nc -t 2 "${ftpLink}/${fileT}" -P ${MAIN}/nc
        wget -nc -t 2 "${ftpLink}/${fileS}" -P ${MAIN}/nc
        if [[ -e ${fileT} ]] && [[ -e ${fileS} ]]; then
            cdo merge ${MAIN}/nc/${fileT} ${MAIN}/nc/${fileS} ${MAIN}/nc/${file}
            echo -e "$(date +%F_%T)\t${file}" >>${MAIN}/.processed
            touch ${MAIN}/.active_${file}
            rm ${MAIN}/nc/${fileT} ${MAIN}/nc/${fileS}
            sbatch --export=f=${file} ${MAIN}/process_TS.sh
        fi
    fi
}
export -f DnP_TS

function DnP_UV() {
    t=$1
    HR=$(printf %03d ${t})

    file="US058GCOM-OPSnce.espc-d-031-hycom_fcst_glby008_${yesterday}12_t0${HR}_uv3z.nc"
    grep ${file} ${MAIN}/.processed >/dev/null 2>&1

    ##  ONLY PROCEED IF FILE IS NOT PROCESSED ALREADY
    if [[ $? -ne 0 ]]; then
        fileU="US058GCOM-OPSnce.espc-d-031-hycom_fcst_glby008_${yesterday}12_t0${HR}_u3z.nc"
        fileV="US058GCOM-OPSnce.espc-d-031-hycom_fcst_glby008_${yesterday}12_t0${HR}_v3z.nc"
        wget -nc -t 2 "${ftpLink}/${fileU}"
        wget -nc -t 2 "${ftpLink}/${fileV}"
        if [[ -e ${fileU} ]] && [[ -e ${fileV} ]]; then
            echo -e "$(date +%F_%T)\t${file}" >>${MAIN}/.processed
            touch ${MAIN}/.active_${file}
            cdo merge ${fileU} ${fileV} ${file}
            rm ${fileU} ${fileV}
            sbatch --export=f=${file} ${MAIN}/process_UV.sh
        fi
    fi
}
export -f DnP_UV

# function DnP_SUR() {
#     t=$1
#     HR=$(printf %03d ${t})

#     # SURFACE
#     file="hycom_GLBy0.08_930_${yesterday}12_t${HR}_sur.nc"
#     grep ${file} ${MAIN}/.processed >/dev/null 2>&1

#     ##  ONLY PROCEED IF FILE IS NOT PROCESSED ALREADY
#     if [[ $? -ne 0 ]]; then
#         wget -nc -t 2 "${ftpLink}/${file}"
#         if [[ -e ${file} ]]; then
#             touch ${MAIN}/.active_${file}
#             ##  Submit all sur files together later
#         fi
#     fi
# }
# export -f DnP_SUR

function DnP_ICE() {
    t=$1
    HR=$(printf %03d ${t})

    # SURFACE
    file="US058GCOM-OPSnce.espc-d-031-hycom_fcst_glby008_${yesterday}12_t0${HR}_ice.nc"
    grep ${file} ${MAIN}/.processed >/dev/null 2>&1

    ##  ONLY PROCEED IF FILE IS NOT PROCESSED ALREADY
    if [[ $? -ne 0 ]]; then
        wget -nc -t 2 "${ftpLink}/${file}"
        if [[ -e ${file} ]]; then
            echo -e "$(date +%F_%T)\t${file}" >>${MAIN}/.processed
            touch ${MAIN}/.active_${file}
            ##  Submit all sur files together later
        fi
    fi
}
export -f DnP_ICE

##  FUNCTIONS
############################################################################

parallel -j 4 'DnP_TS {}' ::: $(seq 0 3 177)
parallel -j 4 'DnP_UV {}' ::: $(seq 0 3 177)
# parallel -j 4 'DnP_SUR {}' ::: $(seq 0 1 177)
parallel -j 4 'DnP_ICE {}' ::: $(seq 0 1 179)

for file in *_ice.nc; do
    sbatch --export=f=${file} ${MAIN}/process_ICE.sh
done

rm ${MAIN}/.dl
