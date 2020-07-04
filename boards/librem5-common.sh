#!/bin/false
# Copyright (c) 2019 Dyne.org Foundation
# arm-sdk is written and maintained by Ivan J. <parazyd@dyne.org>
#
# This file is part of arm-sdk
#
# This source code is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This software is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this source code. If not, see <http://www.gnu.org/licenses/>.

## settings & config
vars+=(device_name arch size parted_type parted_boot parted_root bootfs inittab)
vars+=(gitkernel gitkernel atf_git atf_branch atf_platform)
arrs+=(custmodules)

arch="arm64"
size=2048
inittab=()

parted_type="dos"
# The offset and size isn't important, but it must be after the data partition created in postbuild
parted_boot="ext2 4096s 524288s"
parted_root="ext4 528384s 100%"
bootfs="ext2"

extra_packages+=()
custmodules=()

#m4_branch="master"
#m4_git="https://source.puri.sm/Librem5/Cortex_M4.git"

#flash_kernel_branch="librem5"
#flash_kernel_git="https://source.puri.sm/Librem5/flash-kernel.git"

tmpp="$R/tmp/kernels/$device_name"

prebuild() {
	fn prebuild
	req=(device_name tmpp)
	ckreq || return 1

	notice "executing $device_name prebuild"

	copy-root-overlay

	mkdir -p "$tmpp"
}

postbuild() {
	fn postbuild
	req=(tmpp device_name compiler loopdevice strapdir)
	ckreq || return 1

	notice "executing $device_name postbuild"

	notice "building arm-trusted-firmware"
	clone-git "$atf_git" "$tmpp/atf" "$atf_branch"
	make -C "$tmpp/atf" CROSS_COMPILE="$compiler" PLAT="$atf_platform" bl31 || zerr

	notice "obtaining ddr firmware blobs :("
	mkdir -p "$tmpp/firmware-imx/"
	file="$tmpp/firmware-imx/firmware-imx-7.9.bin"
	if ! [ -f "$file" ]
	then
		wget https://www.nxp.com/lgfiles/NMG/MAD/YOCTO/firmware-imx-7.9.bin -O "$file.tmp" || zerr
		if [ "$(sha256sum "$file".tmp | grep -o '^[^ ]*')" != 30e22c3e24a8025d60c52ed5a479e30fad3ad72127c84a870e69ec34e46ea8c0 ]
		then
			echo "Failed to verify checksume of file firmware-imx-7.9.bin!!!" >&2
			zerr
			return 1
		fi
	fi
	mv "$file".tmp "$file"
	tail -n +784 "$file" | ( cd "$tmpp/firmware-imx/" <&- && tar xjvf -; ) || zerr

	# notice "building m4 firmware"
	# clone-git "$m4_git" "$tmpp/m4" "$m4_branch"
	# make -C "$tmpp/m4" || zerr

	notice "building u-boot"
	clone-git "$uboot_git" "$tmpp/uboot" "$uboot_branch"
	# cp "$tmpp/m4/m4.bin" "$tmpp/uboot/" # The m4 firmware isn't built into uboot yet, but maybe some day, it will be
	cp "$tmpp/atf/build/imx8mq/release/bl31.bin" "$tmpp/uboot/"
	cp "$tmpp/firmware-imx/firmware-imx-7.9/firmware/ddr/synopsys/lpddr4_pmu_train_1d_dmem.bin" "$tmpp/uboot/"
	cp "$tmpp/firmware-imx/firmware-imx-7.9/firmware/ddr/synopsys/lpddr4_pmu_train_1d_imem.bin" "$tmpp/uboot/"
	cp "$tmpp/firmware-imx/firmware-imx-7.9/firmware/ddr/synopsys/lpddr4_pmu_train_2d_dmem.bin" "$tmpp/uboot/"
	cp "$tmpp/firmware-imx/firmware-imx-7.9/firmware/ddr/synopsys/lpddr4_pmu_train_2d_imem.bin" "$tmpp/uboot/"
	cp "$tmpp/firmware-imx/firmware-imx-7.9/firmware/hdmi/cadence/signed_hdmi_imx8m.bin" "$tmpp/uboot/"
	make -C "$tmpp/uboot" ARCH=arm CROSS_COMPILE="$compiler" "$uboot_defconfig"_defconfig || zerr
	make -C "$tmpp/uboot" ARCH=arm CROSS_COMPILE="$compiler" flash.bin || zerr
	make -C "$tmpp/uboot" ARCH=arm CROSS_COMPILE="$compiler" u-boot.imx || zerr

	# Protect uboot and stuff from getting acidentally overwritten by placing a partition there.
	# This partition isn't strictly necessary
	# echo "start=4, size=4092, type=da" | sudo sfdisk --append "$loopdevice" --no-reread --no-tell-kernel || zerr # offset 4, enough for mbr, but not for gpt
	echo "start=66, size=4030, type=da" | sudo sfdisk -a "$loopdevice" --no-reread --no-tell-kernel || zerr # Offset if the m4 isn't needed...
	# sudo sfdisk "$loopdevice" --reorder --no-reread --no-tell-kernel || zerr # Don't fix partition order, this image builder can't handle it

	# Make sure the m4 firmware fits into the space before uboot
	# m4_size=$(stat -c "%s" "$tmpp/m4/m4.bin")
	# [ $m4_size -gt 31744 ] || zerr # 31744 = 1024 * 31

	# Make sure the uboot image actually fits into the partition
	uboot_size=$(stat -c "%s" "$tmpp/uboot/u-boot.imx")
	[ $uboot_size -gt 2063360 ] || zerr # 4030 * 512 = 2063360

	# It would be prettier to rediscover the partitions and write to a loop device for the partition
	# That way, the check above would become unnecessary, but I don't see how I could do this here
	# sudo dd conv=notrunc,sync if="$tmpp/m4/m4.bin" bs=1024 seek=2 of="$loopdevice" # 2 * 1024 = 4 * 512
	sudo dd conv=notrunc,sync if="$tmpp/uboot/u-boot.imx" bs=1024 seek=33 of="$loopdevice"

	if [ -n "$FK_DEB_URL" ]
		then wget "$FK_DEB_URL" -O "${strapdir}/tmp/flash-kernel.deb"
	fi

	sudo cat <<EOF >"${strapdir}/l5.sh"
#!/bin/sh
cd /tmp/
export FK_MACHINE="$FK_MACHINE"
apt-get -y install u-boot-tools
if [ -f flash-kernel.deb ]
then
  dpkg -i flash-kernel.deb
  apt-get -f -y install
else
  apt-get -y install flash-kernel
fi
dpkg -i linux-*.deb
EOF
	chroot-script -d "l5.sh"

	postbuild-clean
}

build_kernel_arm64() {
	fn build_kernel_arm64
	req=(R arch device_name gitkernel gitbranch strapdir)
	req+=(strapdir)
	ckreq || return 1

	notice "building $arch kernel"

	prebuild || zerr

	get-kernel-sources

	(
		cd "$tmpp/$device_name-linux/"
		copy-kernel-config
		make ARCH=arm64 CROSS_COMPILE="$compiler" bindeb-pkg || zerr
		mv $(ls -1 "$tmpp/linux-"*.deb | grep -v dbg) "$strapdir/tmp/"
	)

	postbuild || zerr
}
