source ../configs.sh

f=$1

date=$(echo $f | cut -d_ -f4 | sed 's/12$//')
hr=$(echo $f | cut -d_ -f5 | sed 's/t0*//')
saveDateTime=$(date -d "${date} 12 +${hr} hours" +%Y%m%d_%H)
field="current"
extractDir=${MAIN}/extracted/${field}/${MODEL}_${field}_${saveDateTime}

function archive {
    rsync -aurq --remove-source-files -e "ssh -p ${SERVER_PORT}" ${extractDir} ${SERVER_IP}:${SERVER_DIR}/${field}

    # if [[ ${counter} -ge 10 ]]; then
    #     echo
    #     ##  Send warning by mail                                                                                                                                                                           
    # else
    #     rm -r ${extractDir}
    # fi
}


##  Extract u & v
mkdir -p ${extractDir}
cdo -O -select,name=water_u,water_v -sellonlatbox,-180,180,-90,90 $f ${extractDir}/uv3z.nc
for level in 5000 4000 3000 2500 2000 1500 1250 1000 900 800 700 600 500 400 350 300 250 200 150 125 100 90 80 70 60 50 45 40 35 30 25 20 15 12 10 8 6 4 2 0; do
    file=${extractDir}/${MODEL}_current_${saveDateTime}_${level}.nc
    cdo -O -sellevel,${level} ${extractDir}/uv3z.nc ${file}.1
    ncwa -4 -L1 -O -a time,depth ${file}.1 ${file}.1
    cdo -O -z zip_1 -chname,water_u,u -chname,water_v,v -chname,lat,latitude -chname,lon,longitude ${file}.1 ${file}
    rm ${file}.1
done
rm ${extractDir}/uv3z.nc


##  Depth average (for PP)
cdo ensmean ${extractDir}/*.nc ${extractDir}/${MODEL}_${field}_${saveDateTime}_mean.nc


##  Extract bottom u & v
file=${extractDir}/${MODEL}_current_${saveDateTime}_bottom.nc
cdo -O -select,name=water_u_bottom,water_v_bottom -sellonlatbox,-180,180,-90,90 $f ${file}.1
ncwa -O -4 -L1 -a time,depth ${file}.1 ${file}.1
cdo -O -z zip_1 -chname,water_u_bottom,u -chname,water_v_bottom,v -chname,lat,latitude -chname,lon,longitude ${file}.1 ${file}
rm ${file}.1

rm $f

##  EXTRA ZIP
cd ${extractDir}
for f in *; do
    python3 /home/taimaz/scripts/ncZip.py $f
done

archive current &
