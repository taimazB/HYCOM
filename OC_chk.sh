source ./configs.sh

n=`ls .active_* | wc -l`
if [[ $n > 0 ]]; then
    exit
fi

ssh -p ${SERVER_PORT} ${SERVER_IP} <<EOF
date -u +%Y%m%dT%H%M%S > ${SERVER_DIR}/lastProcessed
cd ${SERVER_DIR}/
for d in */; do
cd ${SERVER_DIR}/\$d
ls | xargs -I{} basename {} .nc > .availDateTimes
done
EOF
