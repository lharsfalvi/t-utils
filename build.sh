#!/bin/bash

# Syntax:
#
# ./build.sh			Build "all" in bundle.
# ./build.sh clean		Remove generated files
# ./build.sh f1.asm f2.asm ..	Assemble specified file(s)
# ./build.sh dist		Create source release tarball
# ./build.sh bdist		Create binary release tarball

# Files to be built by default
read -r -d '' BFILES <<'EOF'
tsave.asm
tload.asm
bootstrapmod.ple.asm
bootstrapmod.gcr.asm
tmaster
tloadtest.asm
EOF

# Auxiliary source files (assembled to yield intermediate files)
read -r -d '' AUXFILES <<'EOF'
bootstrapmod.ple.asm
bootstrapmod.gcr.asm
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
bootstrapmod.ple.asm
bootstrapmod.gcr.asm
tmaster
EOF

# Files to be included in the binary release archive
read -r -d '' BRFILES <<'EOF'
LICENSE
README.md
ver.inc
tsave.prg
tload.prg
tloadtest.prg
tmaster
EOF

BUILDDIR="build"

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
  rm -f *.prg *.tap *.old *.tar.gz
  rm -rf "$BUILDDIR"

  for I in *.inc; do
    if [ -L "$I" ]; then
      rm -f "$I";
    fi
  done
}

# Assemble source file
assemble () {

  local file="$1"
  local path

  if grep -qxF "$file.asm" <<< "$AUXFILES"; then
    path="$BUILDDIR"
  else
    path="."
  fi

  if ! dasm "$file.asm" \
	    "-l$BUILDDIR/$file.lst" \
	    "-o$path/$file.prg" \
	    "-s$BUILDDIR/$file.sym" \
	    "-Dmod_$file" \
	    "$DAOPTS"
  then
    echo >&2 "Failed to assemble $filename"
    exit 1
  fi
}

# Extract specified module to offsets and hexdumps
extractmod () {

  local file="$1"
  local typ
  local of="$BUILDDIR/$file.ext"
  
  typ="${file##*.}"
  typ="${typ^^}"
  
  echo >&2 "Compiling $of"
  
  eval "$(grep '^I_' "$BUILDDIR/$file.sym" | sed -Ee 's/\s+/=0x/')"

  echo "_EXT_$typ = {" > "$of"

  grep '^O_' "$BUILDDIR/$file.sym" \
  | sed -Ee "s/\s+/'\: 0x/" \
  | sed -Ee "s/^/    '/" \
  | sed -Ee "s/\s*$/,/" >> "$of"

  for I in 1 2 3; do
    echo "    'BSBLOCK${I}': bytes.fromhex(" >> "$of"
    dd if="$BUILDDIR/$file.prg" \
       bs=1 \
       skip="$((I_B${I}S))" \
       count="$(($((I_B${I}E))-$((I_B${I}S))))" \
       status=none \
    | od -An -tx1 \
    | sed -Ee 's/^\s/        "/g' \
    | sed -Ee 's/$/"/g' >> "$of"
    echo "    )," >> "$of"
  done

  echo "}" >> "$of"
}

# Patch specified module into tmaster
patchmod () {

  local file="$1"
  local typ
  local s
  local rep
  local f
  local ext

  cp -pf "$file" "$file.new"

  for f in $2; do
    ext="${f%.*}"
    typ="${ext##*.}"
    typ="${typ^^}"
    s="_EXT_$typ"

    rep=$(sed 's/\\/\\\\/g' "build/$ext.ext" | sed -e '$!s/$/\\/')
    sed -i "/^\s*${s}\s*=\s*{/,/^\s*}\s*$/ c\\${rep}" "$file.new"
  done

  mv "$file" "$file.old"
  mv "$file.new" "$file"
}

# Create tap file out of tloadtest.prg and a (predictively) pseudo
# random payload file.
buildtap () {

  local file="$1"
  local pf="$BUILDDIR/testfile.prg"
  
  if [ ! -e "$pf" ]; then
    echo -n -e '\x00\x10' > "$pf"
    dd if=/dev/zero bs=1 count=49152 status=none \
    | openssl enc -aes-256-ctr -pass \
      pass:"$(dd if=/dev/zero bs=128 count=1 status=none | base64)" \
      -nosalt 2>/dev/null >> "$pf"
  fi

  python3 tmaster "$file.prg" tloadtest -Sy -Oy -nova -run \
    "$pf" payload -s $file.tap

}

# Build specified file(s)
build () {

  local files="$1"
  local file
  local ext
  local filename

# Need Dasm 2+
  if ! dasm | head -1 | grep -q '^DASM 2\.'; then
    echo >&2 "Need dasm v2+!"
    exit 1
  fi

# Make sure that build dir exists.
  if [ ! -e "$BUILDDIR" ]; then
    mkdir "$BUILDDIR"
  fi

# Need version and year in ver.inc
  get_ver_year
  out_ver_inc
  echo >&2 "Building V$VER, year $YEAR"

# Need inc file symlinks if inc files don't exist
  for filename in *.template; do
    file="${filename%.*}"
    if [ ! -e "$file" ]; then
      ln -s "$filename" "$file"
    fi
  done

  for filename in $files; do
    if [ -e "$filename" ]; then
      file="${filename%.*}"
      ext="${filename##*.}"
      case "$ext" in
        asm)
          echo >&2 "Assembling $filename"
          assemble "$file"
          case "$file" in
            bootstrapmod*)
              extractmod "$file"
            ;;
            tloadtest*)
              buildtap "$file"
            ;;
          esac
        ;;
        *)
          echo >&2 "Patching $file"
          patchmod "$file" "$AUXFILES"
        ;;

      esac
    else
      echo >&2 "$filename not found"
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
  echo >&2 "Building source release dist archive $archfile"
  tar --owner=root --group=root -czf "$archfile" $SRFILES
}

# Create binary release tarball
bdist () {

  local archfile

  build "$BFILES"
  archfile="t-utils-bin-$VER.tar.gz"
  echo >&2 "Building binary release dist archive $archfile"
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
