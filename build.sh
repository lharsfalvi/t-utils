#!/bin/bash

# Syntax:
#
# ./build.sh			Build "all" in bundle.
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

if git status -s >/dev/null 2>&1; then
# got git and repo data
  BRANCH="$(git rev-parse --abbrev-ref HEAD)"
  if [ "$BRANCH" = "master" ]; then
# on master branch
    TAG=$(git tag --points-at HEAD)
    if [ -n "$TAG" ]; then
# also got a tag attached
      YEAR=$(git for-each-ref "refs/tags/$TAG" \
             --format='%(taggerdate:short)' 2>/dev/null | \
             sed -e 's/\-.*$//' || \
             git log -1 --format=%ad --date=format:'%Y' "$TAG")
      VER="$TAG"
    else
# commit without tag
      YEAR=$(git show -s --format=%ad --date=format:'%Y' HEAD)
      VER=$(git rev-parse --short HEAD)
    fi
  else
# on some other branch
    YEAR=$(git show -s --format=%ad --date=format:'%Y' HEAD)
    HASH=$(git rev-parse --short HEAD)
    VER="${HASH:0:2}${BRANCH:0:6}"
  fi
else
# no git, and/or no repo
  YEAR=$(date +"%Y")
  VER="n/a"
fi

echo "Building V$VER, year $YEAR"

# upper case
VER=${VER^^}

# Workaround --> https://github.com/dasm-assembler/dasm/issues/156
echo -e "REL_T\tSET \"$VER\"" > ver.inc

#DAOPTS="-f1 -v0 -DREL_Y=$YEAR -DREL_T=\"$VER\""
DAOPTS="-f1 -v0 -DREL_Y=$YEAR"

# "Patch" - create tloadcfg.asm symlink if the file doesn't exist
if [ ! -e tloadcfg.inc ]; then
  ln -s tloadcfg.inc.template tloadcfg.inc
fi

for FILENAME in $FILES; do
  if [ -e "$FILENAME" ]; then
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
  else
    echo 1>&2 "$FILENAME not found"
    exit 1
  fi
done
