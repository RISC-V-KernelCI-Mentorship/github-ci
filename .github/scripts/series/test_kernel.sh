#!/bin/bash
# SPDX-FileCopyrightText: 2023 Rivos Inc.
#
# SPDX-License-Identifier: Apache-2.0

# Executes the VMs, and report.

set -x
set -euo pipefail

d=$(dirname "${BASH_SOURCE[0]}")
. $d/utils.sh
. $d/qemu_test_utils.sh

xlen=$1
config=$2
fragment=$3
toolchain=$4
rootfs=$5

cpu=$6
fw=$7
hw=$8
tst=$9

cpu_to_qemu() {
    local cpu=$1

    case "$cpu" in
	"default32")
	    echo "rv32"
	    ;;
	"default64")
	    echo "rv64"
	    ;;
	"server64")
	    echo "rv64,v=true,vlen=256,elen=64,h=true,zbkb=on,zbkc=on,zbkx=on,zkr=on,zkt=on,svinval=on,svnapot=on,svpbmt=on"
	    ;;
	"sifive")
	    echo "sifive-u54"
	    ;;
	*)
	    echo "BADCPU"
	    ;;
    esac
}

fw_to_qemu() {
    local fw=$1
    local vmlinuz=$2

    case "$fw" in
	"no_uefi")
	    echo "$vmlinuz"
	    ;;
	"uboot_uefi")
	    echo "${ci_root}/firmware/rv64/rv64-u-boot.bin"
	    ;;
	*)
	    echo "BADFW"
	    ;;
    esac
}

qemu_kernel_append="root=/dev/vda2 rw earlycon console=tty0 console=ttyS0 panic=-1 oops=panic sysctl.vm.panic_on_oom=1"

qemu_rv64 () {
    local qemu_to=$1
    local qemu_log=$2
    local qemu_bios=$3
    local qemu_kernel=$4
    local qemu_cpu=$5
    local qemu_acpi=$6
    local qemu_image=$7

    timeout --foreground ${qemu_to}s qemu-system-riscv64 \
        -no-reboot \
        -nodefaults \
        -nographic \
        -machine virt,acpi=${qemu_acpi} \
        -smp 4 \
        -bios ${qemu_bios} \
        -cpu ${qemu_cpu} \
        -kernel ${qemu_kernel} \
        -append "${qemu_kernel_append}" \
        -m 8G \
        -object rng-random,filename=/dev/urandom,id=rng0 \
        -device virtio-rng-device,rng=rng0 \
        -chardev stdio,id=char0,mux=on,signal=off,logfile="${qemu_log}" \
        -serial chardev:char0 \
        -drive if=none,file=${qemu_image},format=raw,id=hd0 \
        -device virtio-blk-pci,drive=hd0
}

qemu_rv32 () {
    local qemu_to=$1
    local qemu_log=$2
    local qemu_bios=$3
    local qemu_kernel=$4
    local qemu_cpu=$5
    local qemu_acpi=$6
    local qemu_image=$7

    timeout --foreground ${qemu_to}s qemu-system-riscv32 \
        -no-reboot \
        -nodefaults \
        -nographic \
        -machine virt \
	-cpu rv32 \
        -smp 4 \
        -bios ${qemu_bios} \
        -kernel ${qemu_kernel} \
        -append "${qemu_kernel_append}" \
        -m 1G \
        -object rng-random,filename=/dev/urandom,id=rng0 \
        -device virtio-rng-device,rng=rng0 \
        -chardev stdio,id=char0,mux=on,signal=off,logfile="${qemu_log}" \
        -serial chardev:char0 \
        -drive if=none,file=${qemu_image},format=raw,id=hd0 \
        -device virtio-blk-pci,drive=hd0
}

check_shutdown () {
    local image=$1
    local rc=0
    
    export LIBGUESTFS_BACKEND_SETTINGS=force_kvm
    shutdown="$(guestfish --ro -a "$image" -i cat /shutdown-status 2>/dev/null)"
    if [[ $shutdown == "clean" ]]; then
	f=$(mktemp -p ${tmp})
        guestfish --rw -a "$image" -i download /dmesg $f
        if grep -q "BUG: " $f; then
            rc=1
        fi
    else
	rc=1
    fi

    return $rc
}

tmp=$(mktemp -d -p "${ci_root}")
trap 'rm -rf "$tmp"' EXIT

kernelpath=${ci_root}/$(gen_kernel_name $xlen $config $fragment $toolchain)
vmlinuz=$(find $kernelpath -name '*vmlinuz*')
rootfs_tar=$(echo ${ci_rootfs_root}/rootfs_${xlen}_${rootfs}_*.tar.zst)
qemu_image=$tmp/rootfs.img

rc=0
\time --quiet -f "took prepare_rootfs %e" \
      $d/prepare_rootfs.sh $kernelpath $rootfs_tar $tst $qemu_image || rc=$?
if (( $rc )); then
    echo "Failed preparing rootfs image"
    exit 1
fi

qemu_to=120
if [[ $rootfs == "ubuntu" ]]; then
    qemu_to=$(( $qemu_to * 3 ))
    if [[ $fragment =~ nosmp ]]; then
	qemu_to=$(( $qemu_to * 10 ))
    fi
fi
if [[ $config =~ kselftest ]]; then
    qemu_to=$((2 * 24 * 3600)) # 40h
fi
if [[ $fragment =~ lockdep ]]; then
    qemu_to=$(( $qemu_to * 10 ))
fi

qemu_log=${tmp}/qemu.log
qemu_bios=${ci_root}/firmware/${xlen}/fw_dynamic.bin
qemu_kernel=$(fw_to_qemu $fw $vmlinuz)
qemu_cpu=$(cpu_to_qemu $cpu)
qemu_acpi=off

export TIMEFORMAT="took qemu %0R"
time qemu_${xlen} ${qemu_to} ${qemu_log} ${qemu_bios} ${qemu_kernel} ${qemu_cpu} ${qemu_acpi} ${qemu_image}

export TIMEFORMAT="took check_shutdown %0R"
time check_shutdown $qemu_image || rc=$?
exit $rc
