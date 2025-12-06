#!/bin/bash

# Simplified build script for N970F (Galaxy Note 10) only
# Other devices have been removed to speed up compilation

MODEL=$(echo "$1" | tr '[:lower:]' '[:upper:]')

# Only N970F is supported
if [ "$MODEL" != "N970F" ] && [ -n "$MODEL" ]; then
    echo "Only N970F is supported in this build. Using N970F."
fi

MODEL="N970F"
DEVICE="d1"

# KSU Build
read -p "Do you want to build ksu? (y/n): " ASK_KSU

case "${ASK_KSU}" in
    [yY] )
        KSU="true"
		echo "KernelSU-Next = n / SukiSU-Ultra = s "
		read -p "What kind of ksu do you want? (n/s): " CHOOSE_KSU
		case "${CHOOSE_KSU}" in
			[nN] )
				PICK_KSU="next"
				;;		
			[sS] )
				PICK_KSU="suki"
				;;						
    		* )
        		echo "Invalid answer. Please enter 'n' or 's'."
        		exit 1
        		;;
		esac										
        ;;
    [nN] )
        KSU="false"
        ;;
    * )
        echo "Invalid answer. Please enter 'y' or 'n'."
        exit 1
        ;;
esac

LOCATION=$(pwd)

# Setting KernelSU
if [ -d "KernelSU-Next" ]; then
    rm -rf "${LOCATION}/KernelSU-Next"
elif [ -d "KernelSU" ]; then
    rm -rf "${LOCATION}/KernelSU"		
fi	

cp "${LOCATION}/early_setting/ksu_not_ksu/${KSU}_Kconfig" "${LOCATION}/drivers/Kconfig"

if [ "$KSU" = "true" ]; then
	if [ "${PICK_KSU}" = "next" ]; then
    	curl -LSs "https://raw.githubusercontent.com/GoRhanHee/KernelSU-Next/next-susfs-experimental/kernel/setup.sh" | bash - || exit 1
	elif [ "${PICK_KSU}" = "suki" ]; then
    	curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" | bash -s susfs-main  || exit 1
	fi
	
	# Apply compatibility fixes for kernel 4.14
	echo "Applying KernelSU compatibility patches for kernel 4.14..."
	
	# Fix MODULE_IMPORT_NS for kernel < 5.4
	for f in "${LOCATION}/KernelSU/kernel/ksu.c" "${LOCATION}/drivers/kernelsu/ksu.c"; do
		if [ -f "$f" ]; then
			sed -i 's/^#else$/#elif LINUX_VERSION_CODE >= KERNEL_VERSION(5, 4, 0)/' "$f" 2>/dev/null || true
		fi
	done
	
	# Fix TWA_RESUME for kernel < 5.7 - use true instead
	for f in "${LOCATION}/KernelSU/kernel/allowlist.c" "${LOCATION}/drivers/kernelsu/allowlist.c" \
	         "${LOCATION}/KernelSU/kernel/dynamic_manager.c" "${LOCATION}/drivers/kernelsu/dynamic_manager.c"; do
		if [ -f "$f" ]; then
			sed -i 's/TWA_RESUME/true/g' "$f" 2>/dev/null || true
		fi
	done
	
	# Fix pgtable.h include for kernel < 5.10
	for f in "${LOCATION}/KernelSU/kernel/sucompat.c" "${LOCATION}/drivers/kernelsu/sucompat.c"; do
		if [ -f "$f" ]; then
			sed -i 's|#include <linux/pgtable.h>|#include <asm/pgtable.h>|g' "$f" 2>/dev/null || true
		fi
	done
	
	# Fix __NR_clone3 for kernel < 5.3 - comment out clone3 syscall handling
	for f in "${LOCATION}/KernelSU/kernel/syscall_hook_manager.c" "${LOCATION}/drivers/kernelsu/syscall_hook_manager.c"; do
		if [ -f "$f" ]; then
			# Comment out lines containing __NR_clone3
			sed -i 's/\(.*__NR_clone3.*\)/\/\/ \1 \/\/ Disabled for kernel < 5.3/g' "$f" 2>/dev/null || true
		fi
	done
	
	# Fix strncpy_from_user_nofault for kernel < 5.8
	for f in "${LOCATION}/KernelSU/kernel/"*.c "${LOCATION}/drivers/kernelsu/"*.c; do
		if [ -f "$f" ]; then
			sed -i 's/strncpy_from_user_nofault/strncpy_from_user/g' "$f" 2>/dev/null || true
		fi
	done
	
	# Fix handle_inode_event for kernel < 5.1 - use handle_event instead
	# The handle_inode_event field was added in kernel 5.1
	for f in "${LOCATION}/KernelSU/kernel/pkg_observer.c" "${LOCATION}/drivers/kernelsu/pkg_observer.c"; do
		if [ -f "$f" ]; then
			sed -i 's/\.handle_inode_event/.handle_event/g' "$f" 2>/dev/null || true
		fi
	done
	
	echo "KernelSU compatibility patches applied."
fi

# tzdev for N970F
rm -rf "${LOCATION}/drivers/misc/tzdev"
cp -ar "${LOCATION}/early_setting/tzdev_case/tzdev_B" "${LOCATION}/drivers/misc/tzdev"

# Compile Setting
export ARCH=arm64
export PLATFORM_VERSION=12
export ANDROID_MAJOR_VERSION=s

OUT_DIR="$(pwd)/out"

if [ -d "$OUT_DIR" ]; then
    rm -rf "$OUT_DIR"/*
else
    mkdir -p "$OUT_DIR"
fi

GORHANHEE="$(pwd)/gorhanhee"

if [ -d "$GORHANHEE" ]; then
    rm -rf "$GORHANHEE"/*
else
    mkdir -p "$GORHANHEE"
fi

AIK_DIR="$(pwd)/AIK"

rm -rf ${AIK_DIR}/split_img/boot.img-kernel
rm -rf ${AIK_DIR}/split_img/boot.img-ramdisk.cpio.gz
rm -rf ${AIK_DIR}/ramdisk/system/etc/ramdisk/build.prop
rm -rf ${AIK_DIR}/image-new.img
rm -rf ${AIK_DIR}/ramdisk-new.cpio.gz

# Make Ramdisk file
cp "$(pwd)/early_setting/ramdisk_prop/${MODEL}.prop" "${AIK_DIR}/ramdisk/system/etc/ramdisk/build.prop"

cd ${AIK_DIR}/ramdisk

find . | cpio -o -H newc | gzip > ../split_img/boot.img-ramdisk.cpio.gz

cd "${LOCATION}"

# Make file
make ARCH=arm64 -j$(nproc) O=${OUT_DIR} mrproper

case "${KSU}" in
    true )
        make ARCH=arm64 -j$(nproc) O=${OUT_DIR} exynos9820-${DEVICE}_defconfig gorhanhee.config ksu.config || exit 1
        ;;
    false )
        make ARCH=arm64 -j$(nproc) O=${OUT_DIR} exynos9820-${DEVICE}_defconfig gorhanhee.config not_ksu.config || exit 1
        ;;
esac

# Build with verbose output to see errors clearly
make ARCH=arm64 -j$(nproc) O=${OUT_DIR} 2>&1 | tee build.log
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "Build failed! Last 100 lines of build.log:"
    tail -100 build.log
    echo ""
    echo "Searching for errors in build.log:"
    grep -i "error:" build.log | tail -50
    exit 1
fi

IMAGE="$(pwd)/out/arch/arm64/boot/Image"

# Make boot.img file
if [ "${PICK_KSU}" = "suki" ]; then
	cp "${IMAGE}" "${AIK_DIR}/"
	cd "${AIK_DIR}"
	./patch_linux || exit 1
	mv "oImage" "$(pwd)/split_img/boot.img-kernel"
	rm -rf "Image"
	cd "${LOCATION}"
else	
	cp "${IMAGE}" "${AIK_DIR}/split_img/boot.img-kernel"
fi	

BOARD="${AIK_DIR}/split_img/boot.img-board"
# N970F board identifier
echo "SRPSD26B009KU" > "$BOARD"

cd "${AIK_DIR}"

./repackimg.sh

cd "${LOCATION}"
mv "${AIK_DIR}/image-new.img" "${GORHANHEE}/boot.img"

# Make dt.img file for N970F (uses exynos9820)
cd "${LOCATION}"
python3 mkdtboimg.py create dt.img \
  --page_size=2048 \
  --version=0 \
  --id=0x0 --rev=0x0 --custom0=0x0 --custom1=0x0 --custom2=0x0 --custom3=0x0 \
  ${OUT_DIR}/arch/arm64/boot/dts/exynos/exynos9820.dtb --custom0=0x00 --custom1=0xff --id=0x0 --rev=0x0 
mv "dt.img" "${GORHANHEE}/dt.img"

# Make dtbo.img file for N970F
cd "${LOCATION}"
python3 mkdtboimg.py create dtbo.img \
  --page_size=2048 \
  --version=0 \
  --id=0x0 --rev=0x0 --custom0=0x0 --custom1=0x0 --custom2=0x0 --custom3=0x0 \
  ${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d1_eur_open_18.dtbo --custom0=0x12 --custom1=0x12 --id=0x0 --rev=0x0 \
  ${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d1_eur_open_19.dtbo --custom0=0x13 --custom1=0x14 --id=0x0 --rev=0x0 \
  ${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d1_eur_open_21.dtbo --custom0=0x15 --custom1=0x15 --id=0x0 --rev=0x0 \
  ${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d1_eur_open_22.dtbo --custom0=0x16 --custom1=0x16 --id=0x0 --rev=0x0 \
  ${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d1_eur_open_23.dtbo --custom0=0x17 --custom1=0xff --id=0x0 --rev=0x0
mv "dtbo.img" "${GORHANHEE}/dtbo.img"

# Make tar_file for Odin
cd ${GORHANHEE}

case "${KSU}" in
    true )
		case "${PICK_KSU}" in
			next )
				tar -cvf ${MODEL}_Odin_NEXT_SUSFS.tar boot.img dt.img dtbo.img
				;;		
			suki )
				tar -cvf ${MODEL}_Odin_SUKI_SUSFS.tar boot.img dt.img dtbo.img
				;;						
		esac										
        ;;
    false )
        tar -cvf ${MODEL}_Odin_ramdisk.tar boot.img dt.img dtbo.img
        ;;
esac

# Make zip_file for TWRP
cd "${LOCATION}"
cp -ar "$(pwd)/early_setting/META-INF" "${GORHANHEE}/META-INF"

cd ${GORHANHEE}

case "${KSU}" in
    true )
		case "${PICK_KSU}" in
			next )
				zip -r ${MODEL}_TWRP_NEXT_SUSFS.zip META-INF boot.img dt.img dtbo.img
				;;		
			suki )
				zip -r ${MODEL}_TWRP_SUKI_SUSFS.zip META-INF boot.img dt.img dtbo.img
				;;						
		esac
        ;;
    false )
        zip -r ${MODEL}_TWRP_ramdisk.zip META-INF boot.img dt.img dtbo.img
        ;;
esac

rm -rf ${AIK_DIR}/split_img/boot.img-kernel
rm -rf ${AIK_DIR}/split_img/boot.img-ramdisk.cpio.gz
rm -rf ${AIK_DIR}/ramdisk-new.cpio.gz
