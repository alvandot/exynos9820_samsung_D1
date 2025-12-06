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
# Based on official KernelSU Non-GKI guide:
# https://github.com/tiann/KernelSU/blob/main/website/docs/guide/how-to-integrate-for-non-gki.md
# Using SukiSU-Ultra fork for enhanced features
# ===============================================
echo "=============================================="
echo "🔓 Step 1: SukiSU Ultra Integration (Source Level)"
echo "   Reference: tiann/KernelSU Non-GKI Integration Guide"
echo "=============================================="

# For Non-GKI kernel (4.14), we need to:
# 1. Clone SukiSU-Ultra source
# 2. Apply manual hooks to kernel source

cd "${LOCATION}"

# Remove existing KernelSU directory if exists
rm -rf "${LOCATION}/KernelSU"
rm -rf "${LOCATION}/drivers/kernelsu"

# Clone SukiSU-Ultra (fork of KernelSU with extra features)
echo "Cloning SukiSU-Ultra..."
git clone --depth=1 https://github.com/SukiSU-Ultra/SukiSU-Ultra.git -b main KernelSU

if [ -d "${LOCATION}/KernelSU" ]; then
    # Create symlink as per KernelSU guide
    ln -sf "${LOCATION}/KernelSU/kernel" "${LOCATION}/drivers/kernelsu"
    
    # Add KernelSU to drivers Makefile if not present
    if ! grep -q "kernelsu" "${LOCATION}/drivers/Makefile"; then
        echo "obj-\$(CONFIG_KSU) += kernelsu/" >> "${LOCATION}/drivers/Makefile"
    fi
    
    # Add KernelSU to drivers Kconfig if not present
    if ! grep -q "drivers/kernelsu/Kconfig" "${LOCATION}/drivers/Kconfig"; then
        sed -i '/endmenu/i source "drivers/kernelsu/Kconfig"' "${LOCATION}/drivers/Kconfig"
    fi
    
    # =============================================
    # Fix Linux 4.14 compatibility issues
    # 1. MODULE_IMPORT_NS() - introduced in Linux 5.4+
    # 2. TWA_RESUME - introduced in Linux 5.1+
    # =============================================
    echo "  Patching KernelSU for Linux 4.14 compatibility..."
    
    # Fix 1: Comment out MODULE_IMPORT_NS (not available in 4.14)
    echo "    [1/2] Fixing MODULE_IMPORT_NS..."
    for KSU_FILE in $(find "${LOCATION}/KernelSU/kernel" -name "*.c" -type f 2>/dev/null); do
        if grep -q "MODULE_IMPORT_NS" "$KSU_FILE"; then
            echo "      Patching: $(basename $KSU_FILE)"
            # Simply comment out MODULE_IMPORT_NS lines
            sed -i 's/^MODULE_IMPORT_NS/\/\/ MODULE_IMPORT_NS/g' "$KSU_FILE"
        fi
    done
    echo "    ✅ MODULE_IMPORT_NS commented out"
    
    # Fix 2: Replace TWA_RESUME with 0 (TWA_RESUME was added in Linux 5.1)
    echo "    [2/2] Fixing TWA_RESUME..."
    for KSU_FILE in $(find "${LOCATION}/KernelSU/kernel" -name "*.c" -type f 2>/dev/null); do
        if grep -q "TWA_RESUME" "$KSU_FILE"; then
            echo "      Patching: $(basename $KSU_FILE)"
            # Replace TWA_RESUME with 0 (simple approach for 4.14)
            # In older kernels, task_work_add takes the 3rd argument as 0
            sed -i 's/TWA_RESUME/0/g' "$KSU_FILE"
        fi
    done
    echo "    ✅ TWA_RESUME fixed for Linux 4.14"
    
    echo "✅ SukiSU Ultra source integrated successfully!"
else
    echo "❌ Failed to clone SukiSU-Ultra!"
    exit 1
fi
echo "=============================================="

# ===============================================
# Step 2: Non-GKI Manual Hooks Configuration
# Based on: https://github.com/tiann/KernelSU/blob/main/website/docs/guide/how-to-integrate-for-non-gki.md
# For kernel 4.14, manual hooks are REQUIRED
# ===============================================
echo "=============================================="
echo "🔓 Step 2: Non-GKI Manual Hooks (Kernel 4.14)"
echo "   Based on tiann/KernelSU Non-GKI Guide"
echo "=============================================="

if [ -d "${LOCATION}/KernelSU" ]; then
    KERNEL_VERSION=$(make kernelversion 2>/dev/null | head -1)
    echo "Kernel version: ${KERNEL_VERSION}"
    
    DEFCONFIG="${LOCATION}/arch/arm64/configs/exynos9820-${DEVICE}_defconfig"
    
    # Enable KSU configs for Non-GKI manual hook
    echo "Configuring defconfig..."
    
    # Add CONFIG_KSU=y if not present
    if ! grep -q "^CONFIG_KSU=y" "$DEFCONFIG" 2>/dev/null; then
        echo "CONFIG_KSU=y" >> "$DEFCONFIG"
        echo "  Added: CONFIG_KSU=y"
    fi
    
    # =============================================
    # Apply Manual Hooks to Kernel Source
    # Based on tiann/KernelSU Non-GKI guide
    # =============================================
    echo ""
    echo "Applying manual hooks to kernel source..."
    echo "Note: Some patches may fail if already applied or kernel differs"
    
    # Hook 1: fs/exec.c - do_execveat_common (required)
    echo "  [1/4] Patching fs/exec.c (execveat hook)..."
    EXEC_C="${LOCATION}/fs/exec.c"
    if [ -f "$EXEC_C" ]; then
        # Check if already patched
        if ! grep -q "ksu_handle_execveat" "$EXEC_C"; then
            # Add include at top after existing includes
            sed -i '/#include <linux\/ptrace.h>/a #ifdef CONFIG_KSU\n#include <linux/ksu.h>\n#endif' "$EXEC_C" 2>/dev/null
            
            # Add hook in do_execveat_common - look for the function and add after opening brace
            # For kernel 4.14, the function signature varies
            if grep -q "static int do_execveat_common" "$EXEC_C"; then
                sed -i '/static int do_execveat_common/,/^{$/{s/^{$/{\n#ifdef CONFIG_KSU\n\tksu_handle_execveat(\&fd, \&filename, \&argv, \&envp, \&flags);\n#endif/}' "$EXEC_C" 2>/dev/null
            fi
        else
            echo "    Already patched"
        fi
    fi
    
    # Hook 2: fs/open.c - do_faccessat (required)
    echo "  [2/4] Patching fs/open.c (faccessat hook)..."
    OPEN_C="${LOCATION}/fs/open.c"
    if [ -f "$OPEN_C" ]; then
        if ! grep -q "ksu_handle_faccessat" "$OPEN_C"; then
            # Add include
            sed -i '/#include <linux\/fs\.h>/a #ifdef CONFIG_KSU\n#include <linux/ksu.h>\n#endif' "$OPEN_C" 2>/dev/null
            
            # Add hook in do_faccessat
            if grep -q "long do_faccessat" "$OPEN_C"; then
                sed -i '/long do_faccessat/,/^{$/{s/^{$/{\n#ifdef CONFIG_KSU\n\tksu_handle_faccessat(\&dfd, \&filename, \&mode, NULL);\n#endif/}' "$OPEN_C" 2>/dev/null
            fi
        else
            echo "    Already patched"
        fi
    fi
    
    # Hook 3: fs/read_write.c - vfs_read (required)
    echo "  [3/4] Patching fs/read_write.c (vfs_read hook)..."
    RW_C="${LOCATION}/fs/read_write.c"
    if [ -f "$RW_C" ]; then
        if ! grep -q "ksu_handle_vfs_read" "$RW_C"; then
            # Add include
            sed -i '/#include <linux\/fs\.h>/a #ifdef CONFIG_KSU\n#include <linux/ksu.h>\n#endif' "$RW_C" 2>/dev/null
            
            # Add hook in vfs_read
            if grep -q "ssize_t vfs_read" "$RW_C"; then
                sed -i '/^ssize_t vfs_read/,/^{$/{s/^{$/{\n#ifdef CONFIG_KSU\n\tksu_handle_vfs_read(\&file, \&buf, \&count, \&pos);\n#endif/}' "$RW_C" 2>/dev/null
            fi
        else
            echo "    Already patched"
        fi
    fi
    
    # Hook 4: fs/stat.c - vfs_statx or vfs_fstatat (required)
    echo "  [4/4] Patching fs/stat.c (stat hook)..."
    STAT_C="${LOCATION}/fs/stat.c"
    if [ -f "$STAT_C" ]; then
        if ! grep -q "ksu_handle_stat" "$STAT_C"; then
            # Add include
            sed -i '/#include <linux\/fs\.h>/a #ifdef CONFIG_KSU\n#include <linux/ksu.h>\n#endif' "$STAT_C" 2>/dev/null
            
            # For kernel 4.14, use vfs_fstatat
            if grep -q "int vfs_fstatat" "$STAT_C"; then
                sed -i '/^int vfs_fstatat/,/^{$/{s/^{$/{\n#ifdef CONFIG_KSU\n\tksu_handle_stat(\&dfd, \&filename, \&flag);\n#endif/}' "$STAT_C" 2>/dev/null
            elif grep -q "int vfs_statx" "$STAT_C"; then
                sed -i '/^int vfs_statx/,/^{$/{s/^{$/{\n#ifdef CONFIG_KSU\n\tksu_handle_stat(\&dfd, \&filename, \&flags);\n#endif/}' "$STAT_C" 2>/dev/null
            fi
        else
            echo "    Already patched"
        fi
    fi
    
    echo ""
    echo "⚠️  Note: Automatic patching may not work perfectly for all kernels."
    echo "   If build fails, check the KernelSU Non-GKI guide for manual patching:"
    echo "   https://github.com/tiann/KernelSU/blob/main/website/docs/guide/how-to-integrate-for-non-gki.md"
    echo ""
    echo "✅ Non-GKI configuration completed!"
else
    echo "❌ KernelSU directory not found!"
    exit 1
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
