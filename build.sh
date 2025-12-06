#!/bin/bash

# ===============================================
# N970F (Galaxy Note 10) Kernel Build Script
# with SukiSU Ultra Root
# ===============================================

MODEL=$(echo "$1" | tr '[:lower:]' '[:upper:]')

case "$MODEL" in
    N970F )
        DEVICE="d1"
        ;;        
    * )
        echo "This branch only supports N970F (Galaxy Note 10)"
        echo "Usage: ./build.sh N970F"
        exit 1
        ;;
esac

LOCATION=$(pwd)

# tzdev - N970F uses tzdev_B
rm -rf "${LOCATION}/drivers/misc/tzdev"
cp -ar "${LOCATION}/early_setting/tzdev_case/tzdev_B" "${LOCATION}/drivers/misc/tzdev"

# ===============================================
# Step 1: SukiSU Ultra Integration (Source Level)
# Uses SukiSU-Ultra's own setup script for Non-GKI support
# https://github.com/SukiSU-Ultra/SukiSU-Ultra
# ===============================================
echo "=============================================="
echo "🔓 Step 1: SukiSU Ultra Integration (Source Level)"
echo "=============================================="

SUKISU_VERSION="${SUKISU_VERSION:-v1.0.3}"
echo "Using SukiSU Ultra version: ${SUKISU_VERSION}"

# Run SukiSU Ultra setup script (with Non-GKI support)
cd "${LOCATION}"
curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" | bash -s "${SUKISU_VERSION}"

if [ -d "${LOCATION}/KernelSU" ]; then
    echo "✅ SukiSU Ultra source integrated successfully!"
else
    echo "⚠️  SukiSU Ultra integration may have issues, continuing..."
fi
echo "=============================================="

# ===============================================
# Step 2: SukiSU Ultra Non-GKI Configuration
# Configure kernel for Non-GKI kernel 4.14
# ===============================================
echo "=============================================="
echo "🔓 Step 2: SukiSU Ultra Non-GKI Configuration"
echo "=============================================="

# SukiSU Ultra provides Non-GKI support out of the box
if [ -d "${LOCATION}/KernelSU" ]; then
    # Check kernel version
    KERNEL_VERSION=$(make kernelversion 2>/dev/null | head -1)
    echo "Kernel version: ${KERNEL_VERSION}"
    
    # Enable CONFIG_KSU in defconfig if not already present
    DEFCONFIG="${LOCATION}/arch/arm64/configs/exynos9820-${DEVICE}_defconfig"
    if ! grep -q "CONFIG_KSU=y" "$DEFCONFIG" 2>/dev/null; then
        echo "Adding CONFIG_KSU=y to defconfig..."
        echo "CONFIG_KSU=y" >> "$DEFCONFIG"
    fi
    
    echo "✅ SukiSU Ultra Non-GKI support configured!"
else
    echo "⚠️  KernelSU directory not found, skipping SukiSU patches"
fi
echo "=============================================="

# Compile Setting (OEM Option)
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
rm -rf ${AIK_DIR}/image-new.img
rm -rf ${AIK_DIR}/split_img/boot.img-ramdisk.cpio.gz
rm -rf ${AIK_DIR}/ramdisk/system/etc/ramdisk/build.prop
rm -rf ${AIK_DIR}/ramdisk-new.cpio.gz

# Make Ramdisk file
cp "$(pwd)/early_setting/ramdisk_prop/${MODEL}.prop" "${AIK_DIR}/ramdisk/system/etc/ramdisk/build.prop"
cd ${AIK_DIR}/ramdisk
find . | cpio -o -H newc | gzip > ../split_img/boot.img-ramdisk.cpio.gz
cd "${LOCATION}"

# Build defconfig
make ARCH=arm64 -j32 O=${OUT_DIR} mrproper
make ARCH=arm64 -j32 O=${OUT_DIR} exynos9820-${DEVICE}_defconfig gorhanhee.config || exit 1
make ARCH=arm64 -j32 O=${OUT_DIR} || exit 1

IMAGE="$(pwd)/out/arch/arm64/boot/Image"

# ===============================================
# Step 3: KernelPatch Integration - SukiSU Ultra
# Patches compiled kernel image for Non-GKI support
# ===============================================
echo "=============================================="
echo "🔓 Step 3: SukiSU Ultra KernelPatch"
echo "   Patching kernel image for Non-GKI support"
echo "=============================================="

KERNELPATCH_DIR="${LOCATION}/KernelPatch"
mkdir -p "$KERNELPATCH_DIR"

KPTOOLS="$KERNELPATCH_DIR/kptools"
KPIMG="$KERNELPATCH_DIR/kpimg"

# Version configuration
SUKISU_KP_VERSION="0.12.2"
ORIGINAL_KP_VERSION="0.12.3"

# kptools-linux is from original KernelPatch (runs on x86_64 Linux host)
KPTOOLS_URL="https://github.com/bmax121/KernelPatch/releases/download/${ORIGINAL_KP_VERSION}/kptools-linux"

# SukiSU Ultra kpimg for Android
echo "KernelPatch: SukiSU Ultra variant"
echo "  kpimg: SukiSU v${SUKISU_KP_VERSION}"
echo "  kptools: Original v${ORIGINAL_KP_VERSION} (host tool)"
KPIMG_URL="https://github.com/SukiSU-Ultra/SukiSU_KernelPatch_patch/releases/download/${SUKISU_KP_VERSION}/kpimg"

# Download prebuilt kpimg
if [ ! -f "$KPIMG" ]; then
    echo "Downloading KernelPatch kpimg..."
    if ! curl -L -f -o "$KPIMG" "$KPIMG_URL"; then
        echo "Error: Failed to download kpimg. Check internet connection."
        rm -f "$KPIMG"
        exit 1
    fi
fi

# Download prebuilt kptools (Linux x86_64 version for host)
if [ ! -f "$KPTOOLS" ]; then
    echo "Downloading KernelPatch kptools (Linux x86_64)..."
    if ! curl -L -f -o "$KPTOOLS" "$KPTOOLS_URL"; then
        echo "Error: Failed to download kptools. Check internet connection."
        rm -f "$KPTOOLS"
        exit 1
    else
        chmod +x "$KPTOOLS"
    fi
fi

# Patch kernel image
if [ -f "$KPTOOLS" ] && [ -f "$KPIMG" ]; then
    echo "Patching kernel with KernelPatch (SukiSU Ultra)..."
    PATCHED_IMAGE="${OUT_DIR}/arch/arm64/boot/Image-kp"
    
    # Generate a random superkey for KernelPatch
    # You can change this in SukiSU Manager app later
    SUPERKEY=${SUPERKEY:-"sukisu_n970f"}
    echo "Using superkey: $SUPERKEY"
    echo "Note: You can change this in SukiSU Manager app after flashing"
    
    if "$KPTOOLS" -p -i "$IMAGE" -k "$KPIMG" -s "$SUPERKEY" -o "$PATCHED_IMAGE"; then
        if [ -f "$PATCHED_IMAGE" ]; then
            echo "✅ Kernel patched successfully with SukiSU Ultra!"
            IMAGE="$PATCHED_IMAGE"
        else
            echo "Error: KernelPatch patching failed"
            exit 1
        fi
    else
        echo "Error: KernelPatch tool execution failed"
        exit 1
    fi
else
    echo "Error: KernelPatch tools not found"
    exit 1
fi
echo "=============================================="
# ===============================================
# End Step 3: KernelPatch Integration
# ===============================================

# Make boot.img file
cp "${IMAGE}" "${AIK_DIR}/split_img/boot.img-kernel"

# N970F board identifier
BOARD="${AIK_DIR}/split_img/boot.img-board"
echo "SRPSD26B009KU" > "$BOARD"

cd "${AIK_DIR}"

./repackimg.sh

cd "${LOCATION}"
mv "${AIK_DIR}/image-new.img" "${GORHANHEE}/boot.img"

# Make dt.img file - N970F uses exynos9825
cd "${LOCATION}"
python3 early_setting/mkdtboimg.py create dt.img \
  --page_size=2048 \
  --version=0 \
  --id=0x0 --rev=0x0 --custom0=0x0 --custom1=0x0 --custom2=0x0 --custom3=0x0 \
  ${OUT_DIR}/arch/arm64/boot/dts/exynos/exynos9825.dtb --custom0=0x00 --custom1=0xff --id=0x0 --rev=0x0 
mv "dt.img" "${GORHANHEE}/dt.img"

# Make dtbo.img file - N970F specific
cd "${LOCATION}"
python3 early_setting/mkdtboimg.py create dtbo.img \
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
tar -cvf ${MODEL}_SukiSU_Ultra_Odin.tar boot.img dt.img dtbo.img

# Make zip_file for TWRP
cd "${LOCATION}"
cp -ar "$(pwd)/early_setting/META-INF" "${GORHANHEE}/META-INF"

cd ${GORHANHEE}
zip -r ${MODEL}_SukiSU_Ultra_TWRP.zip META-INF boot.img dt.img dtbo.img

rm -rf ${AIK_DIR}/split_img/boot.img-kernel
rm -rf ${AIK_DIR}/split_img/boot.img-ramdisk.cpio.gz
rm -rf ${AIK_DIR}/ramdisk-new.cpio.gz

echo ""
echo "=============================================="
echo "✅ Build completed successfully!"
echo "   Output files in gorhanhee/ directory:"
echo "   - ${MODEL}_SukiSU_Ultra_Odin.tar (for Odin)"
echo "   - ${MODEL}_SukiSU_Ultra_TWRP.zip (for TWRP)"
echo "=============================================="
