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
> .rm
s3cmd put .rm s3://modeltiles/HYCOM/${oldest}/RM/
rm .rm
