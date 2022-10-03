#!/bin/sh
linux_efi_stub="/usr/lib/systemd/boot/efi/linuxx64.efi.stub"
output_efi="output.efi"

cmdline_file="/tmp/cmdline"
kernel_file="/boot/vmlinuz"
initrd_file="initrd.cpio"
initramfs_dir="initramfs/"

partition_file="esp.fat"
partition_size=50M
partition_mountdir="/mnt/esp"

firmware_file="/usr/share/ovmf/OVMF.fd"

cmdline="console=ttyS0 initrd=/dev/ram0 rdinit=/bin/sh"

build_initrd()
{
    pwd="$(pwd)"
    cd "$initramfs_dir"
    (find . | (cpio -o --format newc --owner 0:0 2>/dev/null) > $pwd/$initrd_file) || exit 1
    cd "$pwd"
}

build_image()
{
    echo "$cmdline" > "$cmdline_file"
    objcopy \
        --add-section .cmdline="$cmdline_file" --change-section-vma .cmdline=0x30000 \
        --add-section .linux="$kernel_file" --change-section-vma .linux=0x40000 \
        --add-section .initrd="$initrd_file" --change-section-vma .initrd=0x3000000 \
        "$linux_efi_stub" "$output_efi" || exit 1
    rm "$cmdline_file"
}

build_partition()
{
    truncate -s "$partition_size" "$partition_file" || exit 1
    mkfs.fat "$partition_file" || exit 1
    mkdir -p "$partition_mountdir" || exit 1
    mount "$partition_file" "$partition_mountdir" || exit 1
    mkdir -p "$partition_mountdir/EFI/BOOT" || exit 1
    cp "$output_efi" "$partition_mountdir/EFI/BOOT/BOOTX64.EFI" || exit 1
    umount "$partition_mountdir" || exit 1
    rmdir "$partition_mountdir" || exit 1
}

qemu()
{
    qemu-system-x86_64 -bios "$firmware_file" -drive format=raw,file="$partition_file" -net none -nographic -m 512M
}

build_initrd && build_image && build_partition && qemu