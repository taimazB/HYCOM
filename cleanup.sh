n=`/usr/bin/squeue | grep HYCOM | wc -l`
if [[ -e .active ]] && [[ ! -e .cleanup ]] && [[ $n -eq 0 ]]; then
    source ./configs.sh
    touch ${MAIN}/.cleanup

    cd ${MAIN}/tiles
    ls | parallel 'rsync -aurq --remove-source-files -e "ssh -p ${SERVER_PORT}" {} ${SERVER_IP}:${SERVER_DIR}/tiles'
    
    cd ${MAIN}/extracted
    ls | parallel 'rsync -aurq --remove-source-files -e "ssh -p ${SERVER_PORT}" {} ${SERVER_IP}:${SERVER_DIR}/'

    cd ${MAIN}
    rm -r ${MAIN}/nc/ ${MAIN}/extracted/ ${MAIN}/tiles/
    rm ${MAIN}/.active ${MAIN}/.cleanup
fi
