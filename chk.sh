date=$1

##  If all files are downloaded and processed, add DONE/ to the bucket
n=`ls .active_* | wc -l`
if [[ $n -gt 0 ]]; then
    exit
fi

> .done
s3cmd put .done s3://modeltiles/HYCOM/${date}/DONE/
rm .done


##  Remove the "DONE" directory from the oldest modelDateTime directory before removing the whole directory.
##  This is to overcome api-dev delay in updating its list of models.
modelDateTimes=(`s3cmd ls s3://modeltiles/HYCOM/ | cut -d/ -f5`)
oldest=${modelDateTimes[0]}
s3cmd rm --recursive s3://modeltiles/HYCOM/${oldest}/DONE/


##  REMOVE THE OLDEST DIRECTORY AFTER 1 HOUR
sleep 3600
for field in temperature salinity density; do
    DIRS=(`s3cmd ls s3://modeltiles/HYCOM/${oldest}/${field}/ | awk '{print $2}'`)
    parallel 's3cmd rm --recursive {}' ::: ${DIRS[@]}
done
