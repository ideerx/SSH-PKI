#!/bin/bash

# FileName: ssh-pki.sh
# Authors: Yiwei.Lu(Yiwei.Lu@deer-young.top)
# Create Date: 2019-1-15
# Description: Main file of SSH-PKI.
# Copyright (C) DeerYoung, 2019

#set -e 

ssh_pki_gen_key()
{
    echo -e "\033[1;33mGen new key [${KEY_NAME}].\033[0m\n"
    FILE_NAME=${DATE}_${KEY_NAME}

    ssh-keygen -t rsa -C ${KEY_NAME} -b 4096 -f ${KEY_NAME}

    mv ${KEY_NAME} ${FILE_NAME}
    mv ${KEY_NAME}.pub ${FILE_NAME}.pub

    echo
}

ssh_pki_sign_key()
{
    echo -e "\033[1;33mSign key [${KEY_NAME}] by [${CA_FILE}] for [${WEEKS}] weeks.\033[0m\n"

    if [ ${WEEKS} -gt 1 ]; then
        validity="-V +${WEEKS}w"
    else
        validity=""
    fi

    if [ $HOSTF -eq 0 ]; then
        ssh-keygen -s ${CA_FILE} -I ${KEY_NAME}--${CA_FILE} -n ${KEY_NAME} ${validity} ${FILE_NAME}.pub
    else
        ssh-keygen -s ${CA_FILE} -I ${KEY_NAME}--${CA_FILE} -h -n ${KEY_NAME} ${validity} ${FILE_NAME}.pub
    fi

    if [ $? -eq 0 ]; then
        echo -e "\033[1;32mSign key success!\033[0m"
        ssh-keygen -Lf ${FILE_NAME}-cert.pub
    else
        echo -e "\033[1;31mSign key failed!\033[0m"
    fi
}

ssh_pki_check_num()
{
    if grep '^[[:digit:]]*$' <<< "$1" >> /dev/null ; then
        return 0
    else
        return 1
    fi
}

ssh_pki_help()
{
    echo -e "\nDeer SSH PKI usage:"
    echo
    echo -e "\t-u\tuser\tinput username"
    echo -e "\t-h\thost\tinput hostname"
    echo
    echo -e "\t-g\tgen\tgenerate a new key"
    echo -e "\t-i\tinkey\tinput key file name"
    echo -e "\t-s\tsign\tinput ca file name"
    echo
    echo -e "\t-y\tyear\tinput years default is 1"
}


CA_FILE=""
FILE_NAME=""
YEARF=0
YEARS=0
GENF=0
INPF=0
SIGNF=0
USERF=0
HOSTF=0

DATE=`/bin/date +%Y%m%d-%H%M%S`

# main
if [ $# -lt 1 ]; then
    ssh_pki_help
    exit 1
fi
while getopts "u:h:gi:s:y:" opt; do
    case $opt in
        u)
            USERF=1
            KEY_NAME=$OPTARG
            ;;
        h)
            HOSTF=1
            KEY_NAME=$OPTARG
            ;;
        g)
            GENF=1
            ;;
        i)
            INPF=1
            FILE_NAME=$OPTARG
            ;;
        s)
            SIGNF=1
            CA_FILE=$OPTARG
            ;;
        y)
            YEARF=1
            YEARS=$OPTARG
            ;;
        \?)
            ssh_pki_help
            exit 1
            ;;
    esac
done

if [ `expr $USERF + $HOSTF` -ne 1 ]; then
    echo "Error: Not input user or host name."
    exit 1
fi
if [ `expr $GENF + $INPF` -ne 1 ]; then
    echo "Error: Not gen or input key."
    exit 1
fi

if [ $YEARF -eq 0 ]; then
    WEEKS=52
else
    ssh_pki_check_num $YEARS
    if [ $? -ne 0 ]; then
        echo "Year input error!"
        exit 1
    fi
    WEEKS=$[YEARS*52]
fi

if [ $GENF -eq 1 ]; then
    ssh_pki_gen_key
fi
if [ $SIGNF -eq 1 ]; then
    ssh_pki_sign_key
fi
