n=`/usr/bin/squeue | grep HYCOM | wc -l`
if [[ $n -eq 0 ]] && [[ ! -e .cleanup ]]; then
    touch .cleanup
    source ./configs.sh

    cd extracted
    for d in *; do
        mkdir -p ../tiles/${d}/
        mv ${d}/*/tiles/* ../tiles/${d}/
    done

    cd ..
    rsync -aur -e "ssh -p ${SERVER_PORT}" tiles ${SERVER_IP}:${SERVER_DIR}
    rsync -aur -e "ssh -p ${SERVER_PORT}" extracted/ ${SERVER_IP}:${SERVER_DIR}
    rm -r extracted/*
    rm -r nc/
    rm .active .cleanup
fi
