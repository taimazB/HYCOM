n=`/usr/bin/squeue | grep HYCOM | wc -l`
if [[ -e .active ]] && [[ ! -e .cleanup ]] && [[ $n -eq 0 ]]; then
    touch .cleanup
    source ./configs.sh

    rsync -aur -e "ssh -p ${SERVER_PORT}" tiles ${SERVER_IP}:${SERVER_DIR}
    rsync -aur -e "ssh -p ${SERVER_PORT}" extracted/ ${SERVER_IP}:${SERVER_DIR}
    rm -r extracted/
    rm -r nc/
    rm .active .cleanup
fi
