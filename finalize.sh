modelDateTimes=(`s3cmd ls s3://modeltiles/HYCOM/ | cut -d/ -f5`)
oldest=${modelDateTimes[0]}
s3cmd rm --recursive s3://modeltiles/HYCOM/${oldest}/DONE/

for field in temperature salinity density; do
    DIRS=(`s3cmd ls s3://modeltiles/HYCOM/${oldest}/${field}/ | awk '{print $2}'`)
    parallel 's3cmd rm --recursive {}' ::: ${DIRS[@]}
done
