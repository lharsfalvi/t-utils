#!/bin/bash

# Syntax:
#
# ./build.sh			Build all
# ./build.sh clean		Remove files created by build
# ./build.sh f1.asm f2.asm ..	Assemble specified file(s)

# Files to be assembled by default
FILES="tsave.asm tloadtest.asm tload.asm"

# build.sh clean

if [ $# -eq 1 ] && [ $1 = clean ]; then
  rm -f *.prg *.lst
  exit 0
fi

# build.sh file1.asm file2.asm ...

if [ $# -ge 1 ]; then
  FILES="$*"
fi

# Need dasm > v2

if ! dasm | head -1 | grep -q '^DASM 2\.'; then
  echo 1>&2 "Need dasm v2+!"
  exit 1
fi

# Get year and version string

YEAR=$(date +"%Y")
TAG=$(git describe --exact-match --tags 2>/dev/null \
   || git rev-parse --short HEAD 2>/dev/null \
   || echo "n/a")

echo "Building V$TAG in $YEAR"

TAG=${TAG^^}

# Workaround --> https://github.com/dasm-assembler/dasm/issues/156
echo -e "REL_T\tSET \"$TAG\"" > ver.inc

#DAOPTS="-f1 -v0 -DREL_Y=$YEAR -DREL_T=\"$TAG\""
DAOPTS="-f1 -v0 -DREL_Y=$YEAR"

# "Patch" - create tloadcfg.asm symlink if the file doesn't exist
if [ ! -e tloadcfg.inc ]; then
  ln -s tloadcfg.inc.template tloadcfg.inc
fi

for FILENAME in $FILES; do
  echo "Assembling $FILENAME"
  FILE="${FILENAME%.*}"
  if ! dasm "$FILE.asm" \
	    "-l$FILE.lst" \
	    "-o$FILE.prg" \
	    "-Dmod_$FILE" \
	    "$DAOPTS"
  then
    echo 1>&2 "Failed to assemble $FILENAME"
    exit 1
  fi
done
