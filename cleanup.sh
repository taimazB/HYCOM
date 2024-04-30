n=`/usr/bin/squeue | grep HYCOM | wc -l`
if [[ -e .active ]] && [[ ! -e .cleanup ]] && [[ $n -eq 0 ]]; then
    source ./configs.sh
    touch .cleanup

    cd ${MAIN}/extracted
    ls | parallel 'rsync -aurq --remove-source-files -e "ssh -p ${SERVER_PORT}" {} ${SERVER_IP}:${SERVER_DIR}/'

    cd ${MAIN}
    rm -r ${MAIN}/nc/ ${MAIN}/extracted/
    rm ${MAIN}/.active ${MAIN}/.cleanup
fi
