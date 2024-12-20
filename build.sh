#!/bin/bash

# build.sh clean

if [ $# -eq 1 ] && [ $1 = clean ]; then
  rm -f *.prg *.lst
  exit 0
fi

# Need dasm > v2
if ! dasm | head -1 | grep -q '^DASM 2\.'; then
  echo 1>&2 "Need dasm v2+!"
  exit 1
fi

YEAR=$(date +"%Y")
echo $YEAR
TAG=$(git describe --exact-match --tags 2> /dev/null || git rev-parse --short HEAD)
echo $TAG

FILES="tloadtest"
#FILES="tsave"
DAOPTS="-f1 -v0 -DREL_Y=$YEAR -DREL_T=\"$TAG\""

for FILE in $FILES; do
  if ! dasm $FILE.asm -l$FILE.lst -o$FILE.prg -Dmod_$FILE $DAOPTS
  then
    echo 1>&2 "Failed to compile $FILE.asm"
    exit 1
  fi
done
