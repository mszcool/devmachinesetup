#!/bin/bash

relativePath=$1

#
# Use the path as relative path
#
targetPath="$(pwd)/$relativePath"
echo "Targeting file '$targetPath'"

#
# Test if the file exists
#
if [ ! -f "$targetPath" ]; then
    echo "File with name '$targetPath' does not exist!"
    exit 10
fi

#
# If the file exists, verify its syntax
#
bash -n "$targetPath"

exit $?