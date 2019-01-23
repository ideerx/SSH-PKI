#!/bin/bash

DIR=.
DATE=`date +%Y%m`

if [ $# -lt 1 ]; then
    echo Error!
    exit 1
fi
 
for FILE in $DIR/*;
do
    if [[ $FILE =~ $1 ]] && [[ $FILE =~ $DATE ]]; then
        echo $FILE
        FILE_NAME=${FILE#*_}
        echo $FILE_NAME
        mv $FILE $FILE_NAME
    fi
done
