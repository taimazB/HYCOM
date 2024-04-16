source ../configs.sh

f=$1

date=$(echo $f | cut -d_ -f4 | sed 's/12$//')
hr=$(echo $f | cut -d_ -f5 | sed 's/t0*//')
export saveDateTime=$(date -d "${date} 12 +${hr} hours" +%Y%m%d_%H)

function archive {
    field=$1
    rsync -aurq --remove-source-files -e "ssh -p ${SERVER_PORT}" ${MAIN}/extracted/${field}/${MODEL}_${field}_${saveDateTime} ${SERVER_IP}:${SERVER_DIR}/${field}
}

###################################################################################
##  Extract temperature
extractDirT=${MAIN}/extracted/temperature/${MODEL}_temperature_${saveDateTime}
mkdir -p ${extractDirT}
cdo -O -select,name=water_temp -sellonlatbox,-180,180,-90,90 $f ${extractDirT}/t3z.nc
for level in 5000 4000 3000 2500 2000 1500 1250 1000 900 800 700 600 500 400 350 300 250 200 150 125 100 90 80 70 60 50 45 40 35 30 25 20 15 12 10 8 6 4 2 0; do
    file=${extractDirT}/${MODEL}_temperature_${saveDateTime}_${level}.nc
    cdo -O -sellevel,${level} ${extractDirT}/t3z.nc ${file}.1
    ncwa -O -4 -L1 -a time,depth ${file}.1 ${file}.1
    cdo -z zip_1 -chname,water_temp,temperature -chname,lat,latitude -chname,lon,longitude ${file}.1 ${file}
    rm ${file}.*
done

##  Extract bottom temperature
file=${extractDirT}/${MODEL}_temperature_${saveDateTime}_bottom.nc
cdo -O -select,name=water_temp_bottom -sellonlatbox,-180,180,-90,90 $f ${file}.1
ncwa -O -4 -L1 -a time,depth ${file}.1 ${file}.1
cdo -z zip_1 -chname,water_temp_bottom,temperature -chname,lat,latitude -chname,lon,longitude ${file}.1 ${file}

rm ${extractDirT}/t3z.nc ${file}.*

###################################################################################
##  Extract salinity
extractDirS=${MAIN}/extracted/salinity/${MODEL}_salinity_${saveDateTime}
mkdir -p ${extractDirS}
cdo -O -select,name=salinity -sellonlatbox,-180,180,-90,90 $f ${extractDirS}/s3z.nc
for level in 5000 4000 3000 2500 2000 1500 1250 1000 900 800 700 600 500 400 350 300 250 200 150 125 100 90 80 70 60 50 45 40 35 30 25 20 15 12 10 8 6 4 2 0; do
    file=${extractDirS}/${MODEL}_salinity_${saveDateTime}_${level}.nc
    cdo -O -sellevel,${level} ${extractDirS}/s3z.nc ${file}.1
    ncwa -O -4 -L1 -a time,depth ${file}.1 ${file}.1
    cdo -z zip_1 -chname,lat,latitude -chname,lon,longitude ${file}.1 ${file}
    rm ${file}.*
done

##  Extract bottom salinity
file=${extractDirS}/${MODEL}_salinity_${saveDateTime}_bottom.nc
cdo -O -select,name=salinity_bottom -sellonlatbox,-180,180,-90,90 $f ${file}.1
ncwa -O -4 -L1 -a time,depth ${file}.1 ${file}.1
cdo -z zip_1 -chname,lat,latitude -chname,lon,longitude ${file}.1 ${file}

rm ${extractDirS}/s3z.nc
rm ${file}.*
rm $f

###################################################################################
##  DENSITY
extractDirD=${MAIN}/extracted/density/${MODEL}_density_${saveDateTime}
mkdir -p ${extractDirD}

for level in 5000 4000 3000 2500 2000 1500 1250 1000 900 800 700 600 500 400 350 300 250 200 150 125 100 90 80 70 60 50 45 40 35 30 25 20 15 12 10 8 6 4 2 0; do
    fileT=${extractDirT}/${MODEL}_temperature_${saveDateTime}_${level}.nc
    fileS=${extractDirS}/${MODEL}_salinity_${saveDateTime}_${level}.nc
    fileD=${extractDirD}/${MODEL}_density_${saveDateTime}_${level}.nc
    python3 ${MAIN}/scripts/calcDensity.py ${fileT} ${fileS} ${fileD}
done


##  EXTRA ZIP
cd ${extractDirT}
for f in *; do
    python3 /home/taimaz/scripts/ncZip.py $f
done

cd ${extractDirS}
for f in *; do
    python3 /home/taimaz/scripts/ncZip.py $f
done

cd ${extractDirD}
for f in *; do
    python3 /home/taimaz/scripts/ncZip.py $f
done


###################################################################################
##  TILES
cd ${extractDirT}
for d in *; do
    python3 ${MAIN}/scripts/cnvMaster_RGBcoded.py --filePath="${d}/${d}.nc" --minZoom=2 --maxZoom=7 --minOrg=-100 --step=0.1
done


###################################################################################
##  ARCHIEVE
archive temperature &
archive salinity &
archive density &
