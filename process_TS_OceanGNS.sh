source ../configs.sh

f=$1

date=$(echo $f | cut -d_ -f4 | sed 's/12$//')
hr=$(echo $f | cut -d_ -f5 | sed 's/t0*//')
export saveDateTime=$(date -d "${date} 12 +${hr} hours" +%Y%m%d_%H)
levels=(5000 4000 3000 2500 2000 1500 1250 1000 900 800 700 600 500 400 350 300 250 200 150 125 100 90 80 70 60 50 45 40 35 30 25 20 15 12 10 8 6 4 2 0)

function archive {
    field=$1
    rsync -aurq --remove-source-files -e "ssh -p ${SERVER_PORT}" --rsync-path="mkdir -p ${SERVER_DIR}/${field}; rsync" ${MAIN}/extracted/${field}/${MODEL}_${field}_${saveDateTime} ${SERVER_IP}:${SERVER_DIR}/${field}
}

###################################################################################
##  Extract temperature
export extractDirT=${MAIN}/extracted/temperature/${MODEL}_temperature_${saveDateTime}
mkdir -p ${extractDirT}
cdo -O -select,name=water_temp -sellonlatbox,-180,180,-90,90 $f ${extractDirT}/t3z.nc

function extTemperature {
    level=$1
    file=${extractDirT}/${MODEL}_temperature_${saveDateTime}_${level}.nc
    cdo -O -sellevel,${level} ${extractDirT}/t3z.nc ${file}.1
    ncwa -O -4 -L1 -a time,depth ${file}.1 ${file}.1
    cdo -z zip_1 -chname,water_temp,temperature -chname,lat,latitude -chname,lon,longitude ${file}.1 ${file}
    rm ${file}.*
}
export -f extTemperature
parallel "extTemperature {}" ::: ${levels[@]}


##  Extract bottom temperature
# file=${extractDirT}/${MODEL}_temperature_${saveDateTime}_bottom.nc
# cdo -O -select,name=water_temp_bottom -sellonlatbox,-180,180,-90,90 $f ${file}.1
# ncwa -O -4 -L1 -a time,depth ${file}.1 ${file}.1
# cdo -z zip_1 -chname,water_temp_bottom,temperature -chname,lat,latitude -chname,lon,longitude ${file}.1 ${file}

rm ${extractDirT}/t3z.nc ${file}.*

###################################################################################
##  Extract salinity
export extractDirS=${MAIN}/extracted/salinity/${MODEL}_salinity_${saveDateTime}
mkdir -p ${extractDirS}
cdo -O -select,name=salinity -sellonlatbox,-180,180,-90,90 $f ${extractDirS}/s3z.nc

function extSalinity {
    level=$1
    file=${extractDirS}/${MODEL}_salinity_${saveDateTime}_${level}.nc
    cdo -O -sellevel,${level} ${extractDirS}/s3z.nc ${file}.1
    ncwa -O -4 -L1 -a time,depth ${file}.1 ${file}.1
    cdo -z zip_1 -chname,lat,latitude -chname,lon,longitude ${file}.1 ${file}
    rm ${file}.*
}
export -f extSalinity
parallel "extSalinity {}" ::: ${levels[@]}

##  Extract bottom salinity
# file=${extractDirS}/${MODEL}_salinity_${saveDateTime}_bottom.nc
# cdo -O -select,name=salinity_bottom -sellonlatbox,-180,180,-90,90 $f ${file}.1
# ncwa -O -4 -L1 -a time,depth ${file}.1 ${file}.1
# cdo -z zip_1 -chname,lat,latitude -chname,lon,longitude ${file}.1 ${file}

rm ${extractDirS}/s3z.nc
rm ${file}.*


###################################################################################
##  DENSITY
export extractDirD=${MAIN}/extracted/density/${MODEL}_density_${saveDateTime}
mkdir -p ${extractDirD}

function extDensity {
    level=$1
    fileT=${extractDirT}/${MODEL}_temperature_${saveDateTime}_${level}.nc
    fileS=${extractDirS}/${MODEL}_salinity_${saveDateTime}_${level}.nc
    fileD=${extractDirD}/${MODEL}_density_${saveDateTime}_${level}.nc
    python3 ${MAIN}/scripts/calcDensity.py ${fileT} ${fileS} ${fileD}
}
export -f extDensity
parallel "extDensity {}" ::: ${levels[@]}


##  EXTRA ZIP
cd ${extractDirT}
ls | parallel "python3 /home/taimaz/scripts/ncZip.py {}"

cd ${extractDirS}
ls | parallel "python3 /home/taimaz/scripts/ncZip.py {}"

cd ${extractDirD}
ls | parallel "python3 /home/taimaz/scripts/ncZip.py {}"


###################################################################################
##  ARCHIEVE
(
    archive temperature
    archive salinity
    archive density
) &
