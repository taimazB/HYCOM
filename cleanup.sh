n=`/usr/bin/squeue | grep HYCOM | wc -l`
if [[ $n -eq 0 ]]; then
    rm -r extracted/*
    rm .active
fi
