FROM debian:12-slim

# Build the container first:
#
# docker build -t tbuild:latest .

# To run the build.sh script in this Docker environment, supply your
# own UID, GID, and workdir. See basic example (provided that your
# workdir is the current directory):
#
# docker run -e USER=$(id -u) -e GROUP=$(id -g) -v $(pwd):/build -it --rm tbuild [args]

# There's a special arg 'sh', i.e.
#
# docker run -e USER=$(id -u) -e GROUP=$(id -g) -v $(pwd):/build -it --rm tbuild sh
#
# It spawns the build environment and drops you into a shell.

# On Windows Docker you might be able to start this up by running this from PowerShell:
#
# docker run -v "$pwd:/build" -it --rm tbuild [args]
#
# (File ownerships will likely be incorrect.)

ENV LANG=C.UTF-8
ENV USER=0
ENV GROUP=0

RUN <<EOF
set -ex
apt-get update
DEBIAN_FRONTEND=noninteractive TZ=GMT \
  apt-get install -y --no-install-recommends \
    sudo \
    git \
    dasm \
    python3
apt-get clean
rm -rf /tmp/* /var/tmp/*
mkdir -p /build
cat <<"EOF2" >/dockerentry.sh
#!/bin/bash
set -o errexit

groupadd -g $GROUP build

case "$1" in
    sh)
	useradd -m -g build -G sudo -s /bin/bash -u $USER build
	echo '%sudo   ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/sudo
	cd /build
	su build
    ;;
    *)
	useradd -m -g build -s /bin/bash -u $USER build
	cd /build
	sudo -u build ./build.sh "$@"
    ;;
esac
EOF2

chmod a+x /dockerentry.sh
EOF

ENTRYPOINT ["/dockerentry.sh"]
