#!/bin/bash

#
# Copyright © 2018, "Vipul Jha" aka "LordArcadius" <vipuljha08@gmail.com>
#
# This software is licensed under the terms of the GNU General Public
# License version 2, as published by the Free Software Foundation, and
# may be copied, distributed, and modified under those terms.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# Please maintain this if you use this script or any part of it

# Bash Color
green='\033[01;32m'
red='\033[01;31m'
blink_red='\033[05;31m'
restore='\033[0m'

clear

# Resources
export ARCH=arm64
export SUBARCH=arm64
export CROSS_COMPILE="/home/vipul/kernels/toolchains/aarch64-linux-android/bin/aarch64-opt-linux-android-"
kernel="ElectraBlue"
THREAD="-j$(grep -c ^processor /proc/cpuinfo)"
KERNEL="Image"
DTBIMAGE="dtb"

DEFCONFIG="mido_defconfig"

## Always use all threads
THREADS=$(nproc --all)

# Paths
KERNEL_DIR=$PWD
REPACK_DIR=$KERNEL_DIR/zip
ZIMAGE_DIR=$KERNEL_DIR/arch/arm64/boot
OUT=$KERNEL_DIR/out

# Functions
clean_all() 
{
		rm -rf out
		mkdir out
		make clean && make mrproper
}

make_kernel()
{
		echo
		make $DEFCONFIG
		make $THREAD


}

make_zip()
{
		cd $REPACK_DIR
		mkdir kernel
		mkdir treble
		mkdir nontreble
		cp $KERNEL_DIR/arch/arm64/boot/dts/qcom/msm8953-qrd-sku3-mido-nontreble.dtb $REPACK_DIR/nontreble/
		cp $KERNEL_DIR/arch/arm64/boot/dts/qcom/msm8953-qrd-sku3-mido-treble.dtb $REPACK_DIR/treble/
		cp $KERNEL_DIR/arch/arm64/boot/Image.gz $REPACK_DIR/kernel/
		zip -r9 `echo $ZIP_NAME`.zip *
		cp *.zip $OUT
		rm *.zip
		cd $KERNEL_DIR
}


DATE_START=$(date +"%s")


echo -e "$green"
echo "--------------------------------"
echo "- Compiling ElectraBlue Kernel -"
echo "--------------------------------"
echo -e "$restore"


# Kernel Details
version="12.1"
vendor="xiaomi"
android="OREO"
device="mido"
export KBUILD_BUILD_USER=vipul
export KBUILD_BUILD_HOST=lordarcadius
date=`date +"%Y%m%d-%H%M"`
ZIP_NAME="$kernel"-"$version"-"$date"-"$android"-"$device"

if [ -f arch/arm64/boot/"Image.gz" ]; then
echo "$(tput setaf 4)Previos build found! Creating Zip.$(tput sgr0)"
	make_zip
else
echo "No previos build found!"
fi

echo

while read -p "$(tput setaf 1)Do you want to clean stuffs? (y/n):$(tput sgr0) " cchoice
do
case "$cchoice" in
	y|Y )
		clean_all
		echo
		echo "All Cleaned now."
		break
		;;
	n|N )
		break
		;;
	* )
		echo
		echo "Invalid try again!"
		break
		echo
		;;
esac
done

echo

while read -p "$(tput setaf 6)Do you want to build? (y/n):$(tput sgr0) " dchoice
do
case "$dchoice" in
	y|Y )
		make_kernel
		make_zip
		break
		;;
	n|N )
		break
		;;
	* )
		echo
		echo "Invalid try again!"
		echo
		;;
esac
done


echo -e "${green}"
echo "-------------------"
echo "Build Completed in:"
echo "-------------------"
echo -e "${restore}"

DATE_END=$(date +"%s")
DIFF=$(($DATE_END - $DATE_START))
echo "Time: $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."
