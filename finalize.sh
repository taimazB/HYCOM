source ./configs.sh

n=$(ls .active_* | wc -l)
if [[ $n -eq 0 ]]; then
    ##  CLEANUP
    docker run -v ./:/app/v/ --rm taimaz/cleanup:latest

#     ## UPDATE SERVER
#     lastProcessedDate=$(tail -1 .processed | cut -f2 | cut -d_ -f4 | sed 's/12$//')
#     n=`grep _${lastProcessedDate} ${MAIN}/.processed | wc -l`
#     if [[ $n -eq 300 ]]; then
#         ssh root@${SERVER_IP} <<EOF
# mv ${SERVER_DIR} ${SERVER_DIR}.old
# mv ${SERVER_DIR}.new ${SERVER_DIR}
# rm -r ${SERVER_DIR}.old
# cd ${SERVER_DIR}
# python3 ../updateAvails.py
# EOF

    ##  OCEANGNS
    ssh -p ${SERVER_PORT_OG} ${SERVER_IP_OG} <<EOF
    cd ${SERVER_DIR_OG}
    bash ./update.sh
EOF
fi
