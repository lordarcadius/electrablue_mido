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

# Bash Colors
GREEN='\033[01;32m'
RED='\033[01;31m'
BLINK_RED='\033[05;31m'
YELLOW='\e[0;33m'
BLUE='\e[0;34m'
PURPLE='\e[0;35m'
CYAN='\e[0;36m'
WHITE='\e[0;37m'
RESET='\033[0m'

# Resources
export ARCH=arm64
export SUBARCH=arm64
export CROSS_COMPILE="/home/vipul/kernels/toolchains/aarch64-linux-android/bin/aarch64-opt-linux-android-"
KERNEL="ElectraBlue"
THREAD="-j$(nproc --all)"
IMAGE="Image"
DTB="dtb"
DEFCONFIG="mido_defconfig"

# Paths
KERNEL_DIR=$PWD
REPACK_DIR=$KERNEL_DIR/zip
ZIMAGE_DIR=$KERNEL_DIR/arch/arm64/boot
OUT=$KERNEL_DIR/out

# Date
DATE_START=$(date +"%s")

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
		rm -rf kernel
		rm -rf treble
		rm -rf nontreble
		cd $KERNEL_DIR
		rm arch/arm64/boot/Image.gz
		#rm arch/arm64/boot/dts/qcom/msm8953-qrd-sku3-mido-nontreble.dtb
		#rm arch/arm64/boot/dts/qcom/msm8953-qrd-sku3-mido-treble.dtb
}

show_output()
{
		echo -e "${GREEN}"
		echo "======================"
		echo "= Build Successful!! ="
		echo "======================"
		echo -e "${RESET}"
		DATE_END=$(date +"%s")
		DIFF=$(($DATE_END - $DATE_START))
		echo "Your zip is here: $(tput setaf 229)"$OUT"/$(tput sgr0)$(tput setaf 226)"$ZIP_NAME".zip$(tput sgr0)"
		echo
		echo "Your build time: $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."
}

show_fail()
{
		echo -e "${RED}"
		echo "======================"
		echo "=   Build Failed!!   ="
		echo "======================"
		echo -e "${RESET}"
		DATE_END=$(date +"%s")
		DIFF=$(($DATE_END - $DATE_START))
		echo
		echo "Your build time: $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."
}

# Header
tput reset
echo -e "$GREEN"
echo "======================"
echo "= ElectraBlue Kernel ="
echo "======================"
echo -e "$RESET"


# Kernel Details
VERSION="15.0"
VENDOR="xiaomi"
#ANDROID="OREO"
DEVICE="mido"
export KBUILD_BUILD_USER=vipul
export KBUILD_BUILD_HOST=Wraith-Machine
DATE=`date +"%Y%m%d-%H%M"`
ZIP_NAME="$KERNEL"-"$VERSION"-"$DATE"-"$DEVICE"

# Check old build
if [ -f arch/arm64/boot/"Image.gz" ]; then
echo "$(tput setaf 4)Previous build found! Creating Zip.$(tput sgr0)"
	make_zip
	show_output
exit 0;
else
echo "No previous build found!"
fi

echo

# Asks for a clean build
while read -p "$(tput setaf 209)Do you want to clean stuffs? (y/n):$(tput sgr0) " cchoice
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
		echo "Invalid input! Try again you noob (-_-)"
		exit 0;
		break
		echo
		;;
esac
done

echo

# Asks to build
while read -p "$(tput setaf 6)Do you want to build? (y/n):$(tput sgr0) " dchoice
do
case "$dchoice" in
	y|Y )
		make_kernel
		if [ -f arch/arm64/boot/"Image.gz" ]; then
		make_zip
		show_output
		else
		show_fail
		fi
		break
		;;
	n|N )
		echo
		echo "Nothing has been made. Terminating the script ;_;"
		exit 0;
		break
		;;
	* )
		echo
		echo "Invalid input! Try again you noob (-_-)"
		echo
		exit 0;
		break
		;;
esac
done
