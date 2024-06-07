#!/bin/bash
#SBATCH --job-name=RM_HYCOM
#SBATCH --ntasks=32
#SBATCH --cpus-per-task=1
#SBATCH --time=12:00:00
#SBATCH --output=../logs/RM_%j.out
#SBATCH --error=../logs/RM_%j.err
#SBATCH --priority=1001

##  Remove the "DONE" directory from the oldest modelDateTime directory before removing the whole directory.
##  This is to overcome api-dev delay in updating its list of models.


modelDateTimes=(`s3cmd ls s3://modeltiles/HYCOM/ | cut -d/ -f5`)
oldest=${modelDateTimes[0]}
s3cmd rm --recursive s3://modeltiles/HYCOM/${oldest}/DONE/
> .rm
s3cmd put .rm s3://modeltiles/HYCOM/${oldest}/RM/
rm .rm