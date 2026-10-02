#!/bin/bash
# Bonus: Xorg + dwm + st + dmenu. Run as root in the booted LFS system.
# Commands follow BLFS 12.4. No Mesa: the X server uses the modesetting
# driver with software rendering.
# Each step leaves a marker in $SRC/.done. A second run continues after the
# last complete step.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
SRC=/sources/bonus
LOGIN=myousaf
KVER=6.16.1
XORG_CONFIG="--prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static"
export MAKEFLAGS=-j$(nproc)

log() { echo "=== $(date +%T) $*"; }

# $1 = tarball name prefix, $2... = build function and its arguments.
step() {
    local name=$1 tb dir
    shift
    [ -e $SRC/.done/$name ] && return
    log $name
    tb=$(ls $SRC/$name-[0-9]*.tar.*)
    dir=$(tar -tf $tb | head -1 | cut -d/ -f1)
    rm -rf $SRC/$dir
    tar -xf $tb -C $SRC
    (cd $SRC/$dir; "$@") > $SRC/logs/$name.log 2>&1
    rm -rf $SRC/$dir
    ldconfig
    touch $SRC/.done/$name
}

ac() { ./configure $XORG_CONFIG "$@"; make; make install; }

mes() {
    mkdir build
    cd build
    meson setup --prefix=/usr --buildtype=release "$@" ..
    ninja
    ninja install
}

freetype() {
    sed -ri "s:.*(AUX_MODULES.*valid):\1:" modules.cfg
    sed -r "s:.*(#.*SUBPIXEL_RENDERING) .*:\1:" \
        -i include/freetype/config/ftoption.h
    ./configure --prefix=/usr --enable-freetype-config --disable-static
    make
    make install
}

fontconfig() {
    ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var \
        --disable-docs
    make
    make install
}

xcb_proto() {
    PYTHON=python3 ./configure $XORG_CONFIG
    make install
}

xorg_server() {
    mes --localstatedir=/var -D glamor=false -D glx=false \
        -D systemd_logind=false -D xephyr=false -D xnest=false -D xvfb=false \
        -D secure-rpc=false -D suid_wrapper=true -D xkb_output_dir=/var/lib/xkb
    mkdir -p /etc/X11/xorg.conf.d
    install -d -m1777 /tmp/.ICE-unix /tmp/.X11-unix
    cat >> /etc/sysconfig/createfiles << "EOF"
/tmp/.ICE-unix dir 1777 root root
/tmp/.X11-unix dir 1777 root root
EOF
}

xinit() {
    ac --with-xinitdir=/etc/X11/app-defaults
    sed -i '/$serverargs $vtarg/ s/serverargs/: #&/' /usr/bin/startx
}

dejavu() {
    install -d /usr/share/fonts/dejavu
    install -m644 ttf/*.ttf /usr/share/fonts/dejavu
    fc-cache -f
}

suckless() {
    make CC="gcc -std=c99" PREFIX=/usr X11INC=/usr/include X11LIB=/usr/lib \
        FREETYPEINC=/usr/include/freetype2 install
}

kernel() {
    [ -e $SRC/.done/kernel ] && return
    log "kernel (graphics and input drivers)"
    (
        cd /usr/src/kernel-$KVER
        scripts/config --enable DRM --enable DRM_VMWGFX --enable DRM_VBOXVIDEO \
            --enable DRM_FBDEV_EMULATION --enable INPUT_EVDEV \
            --enable NET_VENDOR_AMD --enable PCNET32
        make olddefconfig
        make
        make modules_install
        mountpoint -q /boot
        cp -v arch/x86/boot/bzImage /boot/vmlinuz-$KVER-$LOGIN
        cp -v System.map /boot/System.map-$KVER-$LOGIN
        cp -v .config /boot/config-$KVER-$LOGIN
    ) > $SRC/logs/kernel.log 2>&1
    touch $SRC/.done/kernel
}

session() {
    cat > /etc/X11/xorg.conf.d/20-modesetting.conf << "EOF"
Section "Device"
    Identifier "card0"
    Driver     "modesetting"
    Option     "AccelMethod" "none"
EndSection
EOF
    # No logind: the X server needs root rights to open the display device.
    cat > /etc/X11/Xwrapper.config << "EOF"
allowed_users = console
needs_root_rights = yes
EOF
    echo "exec dwm" > /root/.xinitrc
    install -o $LOGIN -g $LOGIN -m644 /root/.xinitrc /home/$LOGIN/.xinitrc
}

mkdir -p $SRC/.done $SRC/logs
cd $SRC
awk '{print $2}' $HERE/bonus-sources | wget -q -nc -T 30 -i - || true
awk '{n = $2; sub(".*/", "", n); print $1 "  " n}' $HERE/bonus-sources |
    md5sum -c --quiet

step libpng ac
step freetype freetype
step fontconfig fontconfig
step pixman mes
step util-macros ac
step xorgproto mes
step libXau ac
step libXdmcp ac
step xcb-proto xcb_proto
step libxcb ac --without-doxygen
step font-util ac
for lib in xtrans libX11 libXext libICE libSM; do step $lib ac; done
step libXt ac --with-appdefaultdir=/etc/X11/app-defaults
for lib in libXmu libXfixes libXrender libXcursor libfontenc; do
    step $lib ac
done
step libXfont2 ac --disable-devel-docs
for lib in libXft libXi libXinerama libXrandr; do step $lib ac; done
step libpciaccess mes
for lib in libxkbfile libxshmfence; do step $lib ac; done
step libdrm mes -D udev=true -D valgrind=disabled
step libxcvt mes
step xkeyboard-config mes
step xkbcomp ac
step libevdev mes -D documentation=disabled -D tests=disabled
step mtdev ac
step xorg-server xorg_server
step xf86-input-evdev ac
step xauth ac
step xinit xinit
step setxkbmap ac
step xrandr ac
step dejavu-fonts-ttf dejavu
for tool in dwm st dmenu; do step $tool suckless; done
kernel
session
log "BONUS DONE"
