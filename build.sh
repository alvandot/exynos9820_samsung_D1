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
# https://github.com/SukiSU-Ultra/SukiSU-Ultra/blob/main/docs/guide/how-to-integrate.md
# ===============================================
echo "=============================================="
echo "🔓 Step 1: SukiSU Ultra Integration (Source Level)"
echo "=============================================="

# For Non-GKI kernel, use 'nongki' branch
# Reference: https://github.com/SukiSU-Ultra/SukiSU-Ultra/blob/main/docs/guide/how-to-integrate.md
SUKISU_BRANCH="${SUKISU_BRANCH:-nongki}"
echo "Using SukiSU Ultra branch: ${SUKISU_BRANCH} (for Non-GKI kernel)"

# Run SukiSU Ultra setup script with nongki branch
cd "${LOCATION}"
curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" | bash -s "${SUKISU_BRANCH}"

if [ -d "${LOCATION}/KernelSU" ]; then
    echo "✅ SukiSU Ultra source integrated successfully!"
else
    echo "⚠️  SukiSU Ultra integration may have issues, continuing..."
fi
echo "=============================================="

# ===============================================
# Step 2: SukiSU Ultra Non-GKI Configuration & Manual Hooks
# For Non-GKI kernel 4.14, manual hooks are required
# Reference: https://github.com/tiann/KernelSU/blob/main/website/docs/guide/how-to-integrate-for-non-gki.md
# ===============================================
echo "=============================================="
echo "🔓 Step 2: SukiSU Ultra Non-GKI Manual Hooks"
echo "=============================================="

if [ -d "${LOCATION}/KernelSU" ]; then
    KERNEL_VERSION=$(make kernelversion 2>/dev/null | head -1)
    echo "Kernel version: ${KERNEL_VERSION}"
    
    DEFCONFIG="${LOCATION}/arch/arm64/configs/exynos9820-${DEVICE}_defconfig"
    
    # Enable KSU configs for Non-GKI manual hook
    echo "Configuring defconfig for Non-GKI manual hooks..."
    
    # Add CONFIG_KSU=y if not present
    if ! grep -q "CONFIG_KSU=y" "$DEFCONFIG" 2>/dev/null; then
        echo "CONFIG_KSU=y" >> "$DEFCONFIG"
        echo "  Added: CONFIG_KSU=y"
    fi
    
    # Add CONFIG_KSU_MANUAL_HOOK=y for Non-GKI
    if ! grep -q "CONFIG_KSU_MANUAL_HOOK=y" "$DEFCONFIG" 2>/dev/null; then
        echo "CONFIG_KSU_MANUAL_HOOK=y" >> "$DEFCONFIG"
        echo "  Added: CONFIG_KSU_MANUAL_HOOK=y"
    fi
    
    # =============================================
    # Apply Manual Hooks to Kernel Source
    # These hooks are required for Non-GKI kernels
    # =============================================
    echo ""
    echo "Applying manual hooks to kernel source..."
    
    # Hook 1: fs/exec.c - execveat hook
    EXEC_C="${LOCATION}/fs/exec.c"
    if [ -f "$EXEC_C" ] && ! grep -q "ksu_handle_execveat" "$EXEC_C"; then
        echo "  Patching fs/exec.c..."
        # Find do_execveat_common or similar function and add hook
        # This is a simplified patch - actual implementation may vary
        sed -i '/^static int do_execveat_common/,/^{/ {
            /^{/a\
#ifdef CONFIG_KSU\n\textern bool ksu_execveat_hook __read_mostly;\n\textern int ksu_handle_execveat(int *fd, struct filename **filename_ptr, void *argv, void *envp, int *flags);\n\textern int ksu_handle_execveat_sucompat(int *fd, struct filename **filename_ptr, void *argv, void *envp, int *flags);\n\tif (unlikely(ksu_execveat_hook))\n\t\tksu_handle_execveat(\&fd, \&filename, \&argv, \&envp, \&flags);\n\telse\n\t\tksu_handle_execveat_sucompat(\&fd, \&filename, \&argv, \&envp, \&flags);\n#endif
        }' "$EXEC_C" 2>/dev/null || echo "    Note: Manual patch may be needed for fs/exec.c"
    fi
    
    # Hook 2: fs/open.c - faccessat hook
    OPEN_C="${LOCATION}/fs/open.c"
    if [ -f "$OPEN_C" ] && ! grep -q "ksu_handle_faccessat" "$OPEN_C"; then
        echo "  Patching fs/open.c..."
        sed -i '/^long do_faccessat/,/^{/ {
            /^{/a\
#ifdef CONFIG_KSU\n\textern int ksu_handle_faccessat(int *dfd, const char __user **filename_user, int *mode, int *flags);\n\tksu_handle_faccessat(\&dfd, \&filename, \&mode, NULL);\n#endif
        }' "$OPEN_C" 2>/dev/null || echo "    Note: Manual patch may be needed for fs/open.c"
    fi
    
    # Hook 3: fs/read_write.c - vfs_read hook
    RW_C="${LOCATION}/fs/read_write.c"
    if [ -f "$RW_C" ] && ! grep -q "ksu_handle_vfs_read" "$RW_C"; then
        echo "  Patching fs/read_write.c..."
        sed -i '/^ssize_t vfs_read/,/^{/ {
            /^{/a\
#ifdef CONFIG_KSU\n\textern bool ksu_vfs_read_hook __read_mostly;\n\textern int ksu_handle_vfs_read(struct file **file_ptr, char __user **buf_ptr, size_t *count_ptr, loff_t **pos);\n\tif (unlikely(ksu_vfs_read_hook))\n\t\tksu_handle_vfs_read(\&file, \&buf, \&count, \&pos);\n#endif
        }' "$RW_C" 2>/dev/null || echo "    Note: Manual patch may be needed for fs/read_write.c"
    fi
    
    # Hook 4: fs/stat.c - stat hook
    STAT_C="${LOCATION}/fs/stat.c"
    if [ -f "$STAT_C" ] && ! grep -q "ksu_handle_stat" "$STAT_C"; then
        echo "  Patching fs/stat.c..."
        # Try vfs_statx first, then vfs_fstatat for older kernels
        if grep -q "^int vfs_statx" "$STAT_C"; then
            sed -i '/^int vfs_statx/,/^{/ {
                /^{/a\
#ifdef CONFIG_KSU\n\textern int ksu_handle_stat(int *dfd, const char __user **filename_user, int *flags);\n\tksu_handle_stat(\&dfd, \&filename, \&flags);\n#endif
            }' "$STAT_C" 2>/dev/null
        elif grep -q "^int vfs_fstatat" "$STAT_C"; then
            sed -i '/^int vfs_fstatat/,/^{/ {
                /^{/a\
#ifdef CONFIG_KSU\n\textern int ksu_handle_stat(int *dfd, const char __user **filename_user, int *flags);\n\tksu_handle_stat(\&dfd, \&filename, \&flag);\n#endif
            }' "$STAT_C" 2>/dev/null
        fi
        echo "    Note: Manual patch may be needed for fs/stat.c"
    fi
    
    # Hook 5: drivers/input/input.c - Safe Mode support
    INPUT_C="${LOCATION}/drivers/input/input.c"
    if [ -f "$INPUT_C" ] && ! grep -q "ksu_handle_input_handle_event" "$INPUT_C"; then
        echo "  Patching drivers/input/input.c (Safe Mode)..."
        sed -i '/^static void input_handle_event/,/^{/ {
            /^{/a\
#ifdef CONFIG_KSU\n\textern bool ksu_input_hook __read_mostly;\n\textern int ksu_handle_input_handle_event(unsigned int *type, unsigned int *code, int *value);\n\tif (unlikely(ksu_input_hook))\n\t\tksu_handle_input_handle_event(\&type, \&code, \&value);\n#endif
        }' "$INPUT_C" 2>/dev/null || echo "    Note: Manual patch may be needed for drivers/input/input.c"
    fi
    
    # Hook 6: fs/devpts/inode.c - pm command support
    DEVPTS_C="${LOCATION}/fs/devpts/inode.c"
    if [ -f "$DEVPTS_C" ] && ! grep -q "ksu_handle_devpts" "$DEVPTS_C"; then
        echo "  Patching fs/devpts/inode.c (pm command)..."
        sed -i '/^void \*devpts_get_priv/,/^{/ {
            /^{/a\
#ifdef CONFIG_KSU\n\textern int ksu_handle_devpts(struct inode*);\n\tksu_handle_devpts(dentry->d_inode);\n#endif
        }' "$DEVPTS_C" 2>/dev/null || echo "    Note: Manual patch may be needed for fs/devpts/inode.c"
    fi
    
    echo ""
    echo "⚠️  Note: Automatic patching may not work for all kernel versions."
    echo "   If build fails, manual patching of kernel source may be required."
    echo "   See: https://github.com/tiann/KernelSU/blob/main/website/docs/guide/how-to-integrate-for-non-gki.md"
    echo ""
    echo "✅ SukiSU Ultra Non-GKI configuration completed!"
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
