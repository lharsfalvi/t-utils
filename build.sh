#!/bin/bash

# Syntax:
#
# ./build.sh			Build "all" in bundle.
# ./build.sh clean		Remove generated files
# ./build.sh f1.asm f2.asm ..	Assemble specified file(s)
# ./build.sh dist		Create source release tarball
# ./build.sh bdist		Create binary release tarball

# Files to be assembled by default
read -r -d '' BFILES <<'EOF'
tsave.asm
tload.asm
tloadtest.asm
bootstrapmod.asm
EOF

# Files to be included in the source release archive
read -r -d '' SRFILES <<'EOF'
LICENSE
README.md
ver.inc
build.sh
Dockerfile
*.template
basicstub.asm
tload.asm
tloadtest.asm
tsave.asm
bootstrap.asm
bootstrapmod.asm
EOF

# Files to be included in the binary release archive
read -r -d '' BRFILES <<'EOF'
LICENSE
README.md
ver.inc
tsave.prg
tload.prg
tloadtest.prg
EOF

# Dasm command line options
DAOPTS="-f3 -v0"

# Version and year defaults
VER="?.?"
YEAR=$(date +"%Y")


# Output ver.inc file with version and year
out_ver_inc () {

  local ver="${VER^^}"
  local year="$YEAR"

  echo -e "REL_V\tSET \"$ver\"" > ver.inc
  echo -e "REL_Y\tSET $year" >> ver.inc

}

# Get version string and year (and store them in global variables)
get_ver_year () {

  if git status -s >/dev/null 2>&1; then
    VER=$(git describe --tags)
    if git describe --tags --exact-match >/dev/null 2>&1; then
      YEAR=$(git log -1 --format=%ad --date=format:'%Y' "$VER")
    else
      VER=$(echo "$VER" | sed -e 's/\-g[[:alnum:]]*$//')
    fi
  else
    if [ -f ver.inc ]; then
      VER=$(grep REL_V ver.inc | awk -F '"' '{print $2}' )
      YEAR=$(grep REL_Y ver.inc | awk '{print $(NF)}' )
    fi
  fi

  VER="${VER:0:11}"
  VER="${VER^^}"
}

# Clean build directory
clean () {
  rm -f *.prg *.lst *.tar.gz
  for I in *.inc; do
    if [ -L "$I" ]; then
      rm -f "$I";
    fi
  done
}

# Build
build () {

  local files="$1"
  local file
  local filename

# Need Dasm 2+
  if ! dasm | head -1 | grep -q '^DASM 2\.'; then
    echo 1>&2 "Need dasm v2+!"
    exit 1
  fi

# Need version and year in ver.inc
  get_ver_year
  out_ver_inc
  echo 1>&2 "Building V$VER, year $YEAR"

# Need inc file symlinks if inc files don't exist
  for filename in *.template; do
    file="${filename%.*}"
    if [ ! -e "$file" ]; then
      ln -s "$filename" "$file"
    fi
  done

  for filename in $files; do
    if [ -e "$filename" ]; then
      echo "Assembling $filename"
      file="${filename%.*}"
      if ! dasm "$file.asm" \
		"-l$file.lst" \
		"-o$file.prg" \
		"-Dmod_$file" \
		"$DAOPTS"
      then
        echo 1>&2 "Failed to assemble $filename"
        exit 1
      fi
    else
      echo 1>&2 "$filename not found"
      exit 1
    fi
  done
}

# Create source release tarball
dist () {

  local archfile

# Need version and year in ver.inc
  get_ver_year
  out_ver_inc
  archfile="t-utils-$VER.tar.gz"
  echo 1>&2 "Building source release dist archive $archfile"
  tar --owner=root --group=root -czf "$archfile" $SRFILES
}

# Create binary release tarball
bdist () {

  local archfile

  build "$BFILES"
  archfile="t-utils-bin-$VER.tar.gz"
  echo 1>&2 "Building binary release dist archive $archfile"
  tar --owner=root --group=root -czf "$archfile" $BRFILES
}


# Main

# Check and exec mode
if [ $# -eq 1 ]; then
  case "$1" in
    clean)
      clean
      exit 0
    ;;
    build)
      build "$BFILES"
      exit
    ;;
    dist)
      dist
      exit
    ;;
    bdist)
      bdist
      exit
    ;;
  esac
fi

# Case of build.sh file1.asm file2.asm
if [ $# -ge 1 ]; then
  BFILES="$*"
fi

# default
build "$BFILES"
