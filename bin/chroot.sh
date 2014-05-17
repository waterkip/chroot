#!/bin/bash

mounted=$(mount)
mnt_devices_start="proc dev dev/pts sys var/log home opt"
upstart=0
chroot=bash

SELF=$(basename $0)
SELF_DIR=$(dirname $0)

usage() {
   echo "$SELF [chrootname] <start|stop>"
   exit 0
}

if [ -n "$1" ] ; then
    if [ ! -f "$SELF_DIR/../etc/$1.conf" ] ; then
        echo "chroot '$1' does not exist!" >&2
        exit 1
    fi
    source $SELF_DIR/../etc/$1.conf
    shift
else
    usage
fi


if [ -z "$mnt_devices_stop" ] ; then
    mnt_devices_stop=$(echo $mnt_devices_start | tac -s ' ')
fi

resolv="$mnt"/etc/resolv.conf
resolv_o="$resolv.orig"

start() {

    [ ! -d "$mnt" ] && sudo mkdir -p "$mnt"

    echo -e "$mounted" | grep -q "$mnt"

    if [ $? -ne 0 ] ; then
        sudo mount $root_disk "$mnt"
        if [ $? -ne 0 ] ; then
            echo "Unable to mount '$root_disk' on '$mnt'" >&2
            exit 1
        fi
    fi

    local i
    for i in $mnt_devices_start ; do

        echo -e "$mounted" | grep -q "$mnt/$i"
        [ $? -eq 0 ] && continue

        sudo mount -o bind /$i "$mnt"/$i

    done

    if [ ! -e "$resolv_o" ] ; then
        sudo cat "/etc/resolv.conf" | sudo tee "$resolv_o" >/dev/null
    fi
    cat /etc/resolv.conf | sudo tee "$resolv" >/dev/null

    if [ $upstart -ne 0 ] && [ ! -e "$mnt/sbin/initctl.distrib" ] ; then
        sudo chroot "$mnt" dpkg-divert --local --rename --add /sbin/initctl
        sudo chroot "$mnt" ln -s /bin/true /sbin/initctl
    fi
    eval sudo chroot "$mnt" "$chroot"
}

stop() {

    [ ! -e "$mnt" ] && return

    if [ "$upstart" -ne 0 ] && [ -e "$mnt/sbin/initctl.distrib" ] ; then
        sudo chroot "$mnt" rm /sbin/initctl
        sudo chroot "$mnt" dpkg-divert --local --rename --remove /sbin/initctl
    fi

    if [ -e "$resolv_o" ] ; then
        cat $resolv_o | tee "$resolv" >/dev/null
        sudo rm "$resolv_o"
    fi

    local i
    for i in $mnt_devices_stop; do
        echo -e "$mounted" | grep -q "$mnt/$i"
        [ $? -ne 0 ] && continue
        sudo umount "$mnt/$i"
    done

    echo -e "$mounted" | grep -q "$mnt"

    if [ $? -eq 0 ] ; then
        sudo umount "$mnt"
        [ $? -ne 0 ] && return
        sudo rmdir "$mnt"
    fi
}


case $1 in
    start|stop) $1;;
    *) usage;;
esac
