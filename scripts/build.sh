#!/bin/bash
# Build LFS 12.4 (SysV) on /dev/sdb from the Debian host. Run as root:
#   sudo LFS_PASSWORD=<password> bash scripts/build.sh
# Each step leaves a marker in $LFS/sources/.done. A second run continues
# after the last complete step.
set -euo pipefail

# The password of root and of the login user on the new system.
: "${LFS_PASSWORD:?Set LFS_PASSWORD}"
export LFS=/mnt/lfs
DISK=/dev/sdb
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=$LFS/sources
JOBS=$(nproc)
BOOK=https://www.linuxfromscratch.org/lfs/downloads/12.4
MIRROR=https://ftp.osuosl.org/pub/lfs/lfs-packages/12.4

log() { echo "=== $(date +%T) $*"; }

prepare_disk() {
    if ! blkid ${DISK}3 >/dev/null 2>&1; then
        log "partition $DISK"
        parted -s $DISK mklabel msdos \
            mkpart primary ext2 1MiB 513MiB \
            mkpart primary linux-swap 513MiB 2561MiB \
            mkpart primary ext4 2561MiB 100% \
            set 1 boot on
        partprobe $DISK; sleep 2
        mkfs.ext2 -q -L boot ${DISK}1
        mkswap -L swap ${DISK}2
        mkfs.ext4 -q -L root ${DISK}3
    fi
    mkdir -p $LFS
    mountpoint -q $LFS || mount ${DISK}3 $LFS
    mkdir -p $LFS/boot
    mountpoint -q $LFS/boot || mount ${DISK}1 $LFS/boot
}

get_sources() {
    mkdir -p $SRC/.done
    chmod a+wt $SRC
    [ -e $SRC/.done/sources ] && return
    log "download sources"
    cd $SRC
    for f in wget-list-sysv md5sums; do wget -q -N $BOOK/$f; done
    wget -q -nc -T 30 -t 2 -i wget-list-sysv || true
    # Second source for a file that the first server did not give.
    for f in $(awk '{print $2}' md5sums); do
        [ -s $f ] || wget -q -T 30 $MIRROR/$f || true
    done
    md5sum -c md5sums --quiet
    chown root:root $SRC/*
    touch $SRC/.done/sources
}

layout() {
    [ -e $SRC/.done/layout ] && return
    log "chapter 4 layout and lfs user"
    mkdir -p $LFS/{etc,var,tools,lib64} $LFS/usr/{bin,lib,sbin}
    for i in bin lib sbin; do ln -sfn usr/$i $LFS/$i; done
    id lfs >/dev/null 2>&1 || useradd -s /bin/bash -m -k /dev/null lfs
    chown lfs $LFS/{usr{,/*},var,etc,tools,lib64}
    touch $SRC/.done/layout
}

# Write the script that builds one page. $1 = page file, $2 = sources dir.
wrap() {
    local tb
    tb=$(sed -n 's/^# tarball: //p' "$1")
    echo "set -e; set +h; umask 022; cd $2"
    if [ -n "$tb" ]; then
        echo "d=\$(tar -tf $tb | head -1 | cut -d/ -f1); rm -rf \$d"
        echo "tar -xf $tb; cd \$d"
    fi
    case "$1" in
        *stripping*|*cleanup*|*texinfo*) echo "set +e" ;;
    esac
    cat "$1"
    echo
    [ -z "$tb" ] || echo "cd $2; rm -rf \$d"
}

run_pages() {     # $1 = lfs | chroot, $2... = page files
    local mode=$1 page name
    shift
    for page in "$@"; do
        name=$(basename $page .sh)
        [ -e $SRC/.done/$name ] && continue
        log "$name"
        if [ $mode = lfs ]; then
            wrap $page $SRC > $SRC/run.sh
            sudo -u lfs env -i HOME=/home/lfs TERM=xterm LFS=$LFS LC_ALL=POSIX \
                LFS_TGT=x86_64-lfs-linux-gnu PATH=$LFS/tools/bin:/usr/bin \
                CONFIG_SITE=$LFS/usr/share/config.site MAKEFLAGS=-j$JOBS \
                bash $SRC/run.sh > $SRC/logs/$name.log 2>&1
        else
            wrap $page /sources > $SRC/run.sh
            in_chroot /sources/run.sh > $SRC/logs/$name.log 2>&1
        fi
        touch $SRC/.done/$name
    done
}

in_chroot() {
    chroot $LFS /usr/bin/env -i HOME=/root TERM=xterm PATH=/usr/bin:/usr/sbin \
        MAKEFLAGS=-j$JOBS TESTSUITEFLAGS=-j$JOBS LFS_PASSWORD="$LFS_PASSWORD" \
        /bin/bash "$@"
}

kernfs() {
    mkdir -p $LFS/{dev,proc,sys,run}
    mountpoint -q $LFS/dev || mount --bind /dev $LFS/dev
    mountpoint -q $LFS/dev/pts || mount -t devpts devpts -o gid=5,mode=0620 $LFS/dev/pts
    mountpoint -q $LFS/proc || mount -t proc proc $LFS/proc
    mountpoint -q $LFS/sys || mount -t sysfs sysfs $LFS/sys
    mountpoint -q $LFS/run || mount -t tmpfs tmpfs $LFS/run
    if [ -h $LFS/dev/shm ]; then
        install -d -m 1777 $LFS$(realpath /dev/shm)
    else
        mountpoint -q $LFS/dev/shm || mount -t tmpfs -o nosuid,nodev tmpfs $LFS/dev/shm
    fi
}

run_script() {    # $1 = script in scripts/, run in the chroot one time
    local name=${1%.sh}
    [ -e $SRC/.done/$name ] && return
    log "$name"
    cp $HERE/$1 $SRC/$1
    in_chroot -e /sources/$1 > $SRC/logs/$name.log 2>&1
    touch $SRC/.done/$name
}

prepare_disk
get_sources
layout
mkdir -p $SRC/logs
rm -rf $SRC/gen && cp -r $HERE/gen $SRC/gen

run_pages lfs $SRC/gen/*chapter0[56]*

if [ ! -e $SRC/.done/chown ]; then
    chown --from lfs -R root:root $LFS/{usr,var,etc,tools,lib64}
    touch $SRC/.done/chown
fi
kernfs
run_pages chroot $SRC/gen/*chapter07*
if [ ! -e $SRC/.done/ch7-cleanup ]; then
    in_chroot -c 'rm -rf /usr/share/{info,man,doc}/*
        find /usr/{lib,libexec} -name \*.la -delete; rm -rf /tools'
    touch $SRC/.done/ch7-cleanup
fi
run_pages chroot $SRC/gen/*chapter08*

# Sources for extras.sh, and the SSH keys of the build host user.
(cd $SRC && wget -q -nc -i $HERE/extra-sources) || true
install -o root -g root -m600 /home/myousaf/.ssh/authorized_keys $SRC/authorized_keys

for s in config.sh kernel.sh extras.sh grub.sh; do
    run_script $s
done
rm -f $SRC/authorized_keys
log "ALL DONE"
