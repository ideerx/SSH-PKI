#!/bin/bash

# FileName: ssh-pki.sh
# Authors: Yiwei.Lu(Yiwei.Lu@deer-young.top)
# Create Date: 2019-1-15
# Description: Main file of SSH-PKI.
# Copyright (C) DeerYoung, 2019

#set -e 

ssh_pki_print()
{
    echo -e "\033[1;3$1m$2\033[0m"
}

ssh_pki_conf_set()
{
    key=$2
    value=$3

    chmod 644 $CONF_FILE
    case $1 in
        0|3)
            # nomal and no value
            sed -i "/^${key}/c${key}=${value}" $CONF_FILE
            ;;
        1)
            # no file
            touch $CONF_FILE
            echo "${key}=${value}" >> $CONF_FILE
            ;;
        2)
            # no key
            echo "${key}=${value}" >> $CONF_FILE
            ;;
        *)
            chmod 444 $CONF_FILE
            return 1
            ;;
    esac
    chmod 444 $CONF_FILE
    return 0
}

ssh_pki_conf_get()
{
    key=$1

    if [ ! -f $CONF_FILE ]; then
        # no file key value
        echo "No config file [$CONF_FILE]"
        return 1
    fi

    value=`grep $key $CONF_FILE`
    if [ $? -ne 0 ]; then
        # no key
        echo "No config key [$key]"
        return 2
    fi
    if [ -z "$value" ]; then
        echo "No config value for key [$key]"
        return 3
    fi

    value=${value#*=}
    echo $value
}

ssh_pki_package()
{
    if [ $USERF -eq 1 ]; then
        certype="USER"
    else
        certype="HOST"
    fi

    tempdir=${FILE_NAME}_${certype}_PKG
    pkg_install=pkg_install.sh
    tgz=${FILE_NAME}.tgz

    if [ -d $tempdir ]; then
        rm -rf $tempdir
    fi
    mkdir $tempdir

cat > $pkg_install << 'EOF'
#!/bin/bash

tmpdir=/tmp/ssh-pki-upkg
prog="${tmpdir}/install.sh"
if [ -d $tmpdir ]; then
    rm -rf $tmpdir
fi
mkdir -p $tmpdir
if tail -n +21 "$0"|tar -zxpf - -C ${tmpdir}; then
    cd $tmpdir
    chmod 755 $prog
    if [ x$1 = 'xunpkg' ]; then
        exit 0
    fi
    source $prog $*
    exit 0
else
    echo -e "\033[1;31mCan't decompress $0\033[0m"
    exit 1
fi
EOF

    ssh_pki_print 3 "Packaging..."

    if [ $USERF -eq 1 ]; then
        peer_ca_file=`ssh_pki_conf_get host_ca_file`
    else
        peer_ca_file=`ssh_pki_conf_get user_ca_file`
    fi
    if [ $? -ne 0 ]; then
        ssh_pki_print 1 "$peer_ca_file"
    fi
    if [ ! -f $peer_ca_file ]; then
        ssh_pki_print 1 "Get peer CA file error!"
    fi

cat > ${tempdir}/install.sh << 'EOF'
#!/bin/bash

# Script to install certs.

set -e

EOF
    echo "echo -e \"\\033[1;33mInstall $certype..\\033[0m\"" >> ${tempdir}/install.sh
    echo "" >> ${tempdir}/install.sh
    if [ $USERF -eq 1 ]; then
        echo "Packaging user files."
        cp ${peer_ca_file}.pub $tempdir/
        mv ${FILE_NAME} $tempdir/
        mv ${FILE_NAME}.pub $tempdir/
        mv ${FILE_NAME}-cert.pub $tempdir/
cat >> ${tempdir}/install.sh << 'EOF'
if [ ! -d ~/.ssh/ ]; then
    mkdir ~/.ssh/
fi
EOF
        echo "cp ${peer_ca_file}.pub ~/.ssh/" >> ${tempdir}/install.sh
        echo "cp ${FILE_NAME} ~/.ssh/" >> ${tempdir}/install.sh
        echo "cp ${FILE_NAME}.pub ~/.ssh/" >> ${tempdir}/install.sh
        echo "cp ${FILE_NAME}-cert.pub ~/.ssh/" >> ${tempdir}/install.sh
cat >> ${tempdir}/install.sh << 'EOF'
cd ~/.ssh/
if [ -f id_rsa ]; then
    mv id_rsa id_rsa.bak
fi
if [ -f id_rsa.pub ]; then
    mv id_rsa.pub id_rsa.pub.bak
fi
if [ -f id_rsa-cert.pub ]; then
    mv id_rsa-cert.pub id_rsa-cert.pub.bak
fi
if [ -f known_hosts ]; then
    cp known_hosts known_hosts.bak
fi
EOF
        echo "ln -s ${FILE_NAME} id_rsa" >> ${tempdir}/install.sh
        echo "ln -s ${FILE_NAME}.pub id_rsa.pub" >> ${tempdir}/install.sh
        echo "ln -s ${FILE_NAME}-cert.pub id_rsa-cert.pub" >> ${tempdir}/install.sh
        echo "echo -n \"@cert-authority * \" >> known_hosts" >> ${tempdir}/install.sh
        echo "cat ${peer_ca_file}.pub >> known_hosts" >> ${tempdir}/install.sh
    else
        echo "Packaging host files."
        cp ${peer_ca_file}.pub $tempdir/
        mv ${FILE_NAME} $tempdir/
        mv ${FILE_NAME}.pub $tempdir/
        mv ${FILE_NAME}-cert.pub $tempdir/
cat >> ${tempdir}/install.sh << 'EOF'
if [ `whoami` != "root" ]; then
    echo -e "\033[1;31mPlease run by root!\033[0m"
    exit 1
fi

EOF
        echo "cp ${peer_ca_file}.pub /etc/ssh/" >> ${tempdir}/install.sh
        echo "cp ${FILE_NAME} /etc/ssh/" >> ${tempdir}/install.sh
        echo "cp ${FILE_NAME}.pub /etc/ssh/" >> ${tempdir}/install.sh
        echo "cp ${FILE_NAME}-cert.pub /etc/ssh/" >> ${tempdir}/install.sh
        echo "cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak" >> ${tempdir}/install.sh
        echo "echo \"\" >> /etc/ssh/sshd_config" >> ${tempdir}/install.sh
        echo "echo \"# ssh-pki set\" >> /etc/ssh/sshd_config" >> ${tempdir}/install.sh
        echo "echo \"TrustedUserCAKeys /etc/ssh/${peer_ca_file}.pub\" >> /etc/ssh/sshd_config" >> ${tempdir}/install.sh
        echo "echo \"HostKey /etc/ssh/${FILE_NAME}\" >> /etc/ssh/sshd_config" >> ${tempdir}/install.sh
        echo "echo \"HostCertificate /etc/ssh/${FILE_NAME}-cert.pub\" >> /etc/ssh/sshd_config" >> ${tempdir}/install.sh
cat >> ${tempdir}/install.sh << 'EOF'
echo -e "\n\033[1;31mPlease restart ssh service!\033[0m"
echo "CentOS:"
echo "sudo systemctl restart sshd"
echo "Ubuntu:"
echo "sudo /etc/init.d/ssh restart"
EOF
    fi
    echo "echo -e \"\\033[1;32mInstallation is complete!\\033[0m\"" >> ${tempdir}/install.sh
    chmod 755 ${tempdir}/install.sh
    cd $tempdir
    tar zcvf $tgz *
    mv ${tgz} ..
    cd ..
    cat $pkg_install $tgz > ${FILE_NAME}.install
    chmod 755 ${FILE_NAME}.install
    mv ${FILE_NAME}.install $tempdir
    rm $tgz $pkg_install
    ssh_pki_print 2 "Packaged successfully !!!\n"
}

ssh_pki_gen_key()
{
    ssh_pki_print 3 "Gen new key [${KEY_NAME}]..."
    if [ $USERF -eq 1 ]; then
        FILE_NAME=${DATE}_${KEY_NAME}_for_${KEY_NOTE}
    else
        FILE_NAME=${DATE}_${KEY_NAME}
    fi

    ssh-keygen -t rsa -C ${KEY_NAME} -b $KEY_BIT -f ${KEY_NAME}
    echo

    chmod 400 ${KEY_NAME}
    chmod 444 ${KEY_NAME}.pub

    if [ $GENCAF -eq 1 ]; then
        return
    fi
    mv ${KEY_NAME} ${FILE_NAME}
    mv ${KEY_NAME}.pub ${FILE_NAME}.pub
}

ssh_pki_gen_ca()
{
    case $KEY_NAME in
        *"user"*)
            ssh_pki_conf_get user_ca_file
            ret=$?
            ssh_pki_conf_set $ret user_ca_file $KEY_NAME
            ;;
        *"host"*)
            ssh_pki_conf_get host_ca_file
            ret=$?
            ssh_pki_conf_set $ret host_ca_file $KEY_NAME
            ;;
        *)
            ssh_pki_print 1 "Please input string contains \"user\" or \"host\"!"
            exit 1
            ;;
    esac
    ssh_pki_gen_key
}

ssh_pki_sign_key()
{
    year=`date  +%Y%m`
    FILE_NAME=${FILE_NAME%.pub*}

    if [ $GENF -eq 0 ]; then
        KEY_NAME=${KEY_NAME#*_}
    fi

    if [ ${WEEKS} -gt 1 ]; then
        validity="-V +${WEEKS}w"
    else
        validity=""
    fi

    if [ ! -f $CA_FILE ]; then
        if [ $USERF -eq 1 ]; then
            CA_FILE=`ssh_pki_conf_get user_ca_file`
        else
            CA_FILE=`ssh_pki_conf_get host_ca_file`
        fi
        ret=$?
        if [ $ret -eq 0 ]; then
            ssh_pki_print 3 "CA file not exist. Do you want sign by [$CA_FILE]?"
            read YN
            case $YN in
                n|no)
                    return
                    ;;
            esac
        else
            ssh_pki_print 1 "[$ret]$CA_FILE"
            exit 1
        fi
    fi

    if [ ! -f $CA_FILE ]; then
        ssh_pki_print 1 "Get CA file error!"
        exit 1
    fi

    ssh_pki_print 3 "Sign key [${KEY_NAME}] by [${CA_FILE}] for [${WEEKS}] weeks...\n"

    if [ $USERF -eq 1 ]; then
        ssh-keygen -s ${CA_FILE} -I ${KEY_NOTE}[${CA_FILE}] -n ${KEY_NAME} ${validity} ${FILE_NAME}.pub
    else
        ssh-keygen -s ${CA_FILE} -I ${KEY_NOTE}[${CA_FILE}] -h -n ${KEY_NAME} ${validity} ${FILE_NAME}.pub
    fi

    if [ $? -eq 0 ]; then
        ssh_pki_print 2 "Sign key success!\n"
        ssh-keygen -Lf ${FILE_NAME}-cert.pub
        ssh_pki_package
    else
        ssh_pki_print 1 "Sign key failed!\n"
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
    ssh_pki_print 3 "\nDeer SSH PKI usage:"
    echo
    echo -e "\t-c\tgen CA\t\tInput CA name."
    echo -e "\t-u\tgen user\tInput username (login name or authentication string or filename)."
    echo -e "\t-h\tgen host\tInput hostname (url or ip or filename)."
    echo
    echo -e "\t-s\tsign\t\tInput CA file name, conf file will read if CA file does not exist."
    echo
    echo -e "\t-y\tvalidity\tInput years, \"0\" means forever."
    echo -e "\t-b\tkey bits\tInput key bits default is 2048."
    echo
    echo -e "\t-n\tkey note\tNote use for record log, recommended host name of the key."
    echo
}


# Main
GENF=0
GENCAF=0
USERF=0
HOSTF=0
SIGNF=0
YEARF=0
NOTEF=0

YEARS=0

KEY_BIT=2048

CA_FILE=""
FILE_NAME=""
USER_CA_FILE=""
HOST_CA_FILE=""
KEY_NOTE=""

#PROG_DIR=$0
#PROG_DIR=${PROG_DIR%/*}
PROG_DIR=./
CONF_FILE=${PROG_DIR}/ssh_pki.conf

DATE=`date +%Y%m%d-%H%M%S`

if [ $# -lt 1 ]; then
    ssh_pki_help
    exit 1
fi
while getopts "c:u:h:s:y:b:n:" opt; do
    case $opt in
        c)
            GENCAF=1
            KEY_NAME=$OPTARG
            ;;
        u)
            USERF=1
            KEY_NAME=$OPTARG
            ;;
        h)
            HOSTF=1
            KEY_NAME=$OPTARG
            ;;
        s)
            SIGNF=1
            CA_FILE=$OPTARG
            ;;
        y)
            YEARF=1
            YEARS=$OPTARG
            ;;
        b)
            ssh_pki_check_num $OPTARG
            if [ $? -ne 0 ]; then
                ssh_pki_print 1 "Input key bits error [$OPTARG]"
            else
                KEY_BIT=$OPTARG
            fi
            ;;
        n)
            NOTEF=1
            KEY_NOTE=$OPTARG
            ;;
        \?)
            ssh_pki_help
            exit 1
            ;;
    esac
done

if [ $GENCAF -eq 1 ]; then
    ssh_pki_gen_ca
    exit 0
fi

if [ $NOTEF -ne 1 ] && [ $SIGNF -eq 1 ]; then
    if [ $USERF -eq 1 ]; then
        ssh_pki_print 1 "Please input key note!"
        exit 1
    else
        KEY_NOTE=$KEY_NAME
    fi
fi

if [ `expr $USERF + $HOSTF` -ne 1 ]; then
    ssh_pki_print 1  "Error! Please input user or host name."
    exit 1
fi

if [ $YEARF -eq 0 ]; then
    WEEKS=52
else
    ssh_pki_check_num $YEARS
    if [ $? -ne 0 ]; then
        ssh_pki_print 1 "Year input error!"
        exit 1
    fi
    WEEKS=$[YEARS*52]
fi

if [ -f $KEY_NAME ]; then
    FILE_NAME=$KEY_NAME
else
    GENF=1
    ssh_pki_gen_key
fi

if [ $SIGNF -eq 1 ]; then
    ssh_pki_sign_key
fi
