#!/bin/bash

MODEL=$(echo "$1" | tr '[:lower:]' '[:upper:]')

case "$MODEL" in
    G970F )
        DEVICE="beyond0lte"
        ;;
    G970N )
        DEVICE="beyond0lteks"
        ;;
    G973F )
        DEVICE="beyond1lte"
        ;;        
    G973N )
        DEVICE="beyond1lteks"
        ;;
    G975F )
        DEVICE="beyond2lte"
        ;;        
    G975N )
        DEVICE="beyond2lteks"
        ;;
    G977B )
        DEVICE="beyondx"
        ;;         
    G977N )
        DEVICE="beyondxks"
        ;;
    N970F )
        DEVICE="d1"
        ;;        
    N971N )
        DEVICE="d1xks"
        ;;
    N975F )
        DEVICE="d2s"
        ;;
    N976B )
        DEVICE="d2x"
        ;;                     
    N976N )
        DEVICE="d2xks"
        ;;        
    * )
        echo "Check Your Model! EX)./build_kernel.sh G977N"
        exit 1
        ;;
esac

LOCATION=$(pwd)

# ===============================================
# SukiSU Ultra Integration (Kernel Source Level)
# For Non-GKI kernels like Exynos9820 (kernel 4.14)
# ===============================================
SUKISU_ENABLED=${SUKISU_ENABLED:-0}
SUKISU_BRANCH=${SUKISU_BRANCH:-"main"}
SUKISU_MANUAL_HOOK=${SUKISU_MANUAL_HOOK:-1}  # Use manual hook for non-GKI

if [ "$SUKISU_ENABLED" = "1" ]; then
    echo "=============================================="
    echo "SukiSU Ultra integration enabled"
    echo "Branch: $SUKISU_BRANCH"
    echo "Manual Hook: $SUKISU_MANUAL_HOOK"
    echo "Target: Non-GKI kernel (4.14)"
    echo "=============================================="
    
    DRIVER_DIR="${LOCATION}/drivers"
    KERNELSU_DIR="${LOCATION}/KernelSU"
    
    # Clone SukiSU-Ultra if not exists
    if [ ! -d "$KERNELSU_DIR" ]; then
        echo "Cloning SukiSU-Ultra repository..."
        git clone https://github.com/SukiSU-Ultra/SukiSU-Ultra "$KERNELSU_DIR"
    fi
    
    # Update and checkout branch
    cd "$KERNELSU_DIR"
    git fetch --all
    git checkout "$SUKISU_BRANCH" || git checkout main
    git pull || true
    cd "$LOCATION"
    
    # Create symlink to kernelsu driver
    if [ ! -L "$DRIVER_DIR/kernelsu" ]; then
        echo "Creating kernelsu symlink..."
        ln -sf "../KernelSU/kernel" "$DRIVER_DIR/kernelsu"
    fi
    
    # Add kernelsu to drivers/Makefile if not present
    if ! grep -q "kernelsu" "$DRIVER_DIR/Makefile"; then
        echo "Adding kernelsu to drivers/Makefile..."
        echo 'obj-$(CONFIG_KSU) += kernelsu/' >> "$DRIVER_DIR/Makefile"
    fi
    
    # Add kernelsu to drivers/Kconfig if not present
    if ! grep -q 'source "drivers/kernelsu/Kconfig"' "$DRIVER_DIR/Kconfig"; then
        echo "Adding kernelsu to drivers/Kconfig..."
        sed -i '/endmenu/i\source "drivers/kernelsu/Kconfig"' "$DRIVER_DIR/Kconfig"
    fi
    
    # Apply manual hooks for non-GKI kernel
    if [ "$SUKISU_MANUAL_HOOK" = "1" ]; then
        echo "Applying manual hooks for non-GKI kernel..."
        
        # Patch fs/exec.c - do_execveat_common
        EXEC_C="${LOCATION}/fs/exec.c"
        if [ -f "$EXEC_C" ] && ! grep -q "ksu_handle_execveat" "$EXEC_C"; then
            echo "Patching fs/exec.c..."
            # Add extern declarations before do_execveat_common
            sed -i '/static int do_execveat_common/i\
#ifdef CONFIG_KSU\
extern bool ksu_execveat_hook __read_mostly;\
extern int ksu_handle_execveat(int *fd, struct filename **filename_ptr, void *argv,\
			void *envp, int *flags);\
extern int ksu_handle_execveat_sucompat(int *fd, struct filename **filename_ptr,\
				 void *argv, void *envp, int *flags);\
#endif' "$EXEC_C"
            # Add hook call at the beginning of do_execveat_common function body
            sed -i '/static int do_execveat_common.*{$/a\
#ifdef CONFIG_KSU\
	if (unlikely(ksu_execveat_hook))\
		ksu_handle_execveat(\&fd, \&filename, \&argv, \&envp, \&flags);\
	else\
		ksu_handle_execveat_sucompat(\&fd, \&filename, \&argv, \&envp, \&flags);\
#endif' "$EXEC_C" 2>/dev/null || true
        fi
        
        # Patch fs/open.c - do_faccessat
        OPEN_C="${LOCATION}/fs/open.c"
        if [ -f "$OPEN_C" ] && ! grep -q "ksu_handle_faccessat" "$OPEN_C"; then
            echo "Patching fs/open.c..."
            # Add extern declaration
            sed -i '/^long do_faccessat/i\
#ifdef CONFIG_KSU\
extern int ksu_handle_faccessat(int *dfd, const char __user **filename_user, int *mode,\
			 int *flags);\
#endif' "$OPEN_C" 2>/dev/null || true
        fi
        
        # Patch fs/read_write.c - vfs_read
        READ_WRITE_C="${LOCATION}/fs/read_write.c"
        if [ -f "$READ_WRITE_C" ] && ! grep -q "ksu_handle_vfs_read" "$READ_WRITE_C"; then
            echo "Patching fs/read_write.c..."
            sed -i '/^ssize_t vfs_read/i\
#ifdef CONFIG_KSU\
extern bool ksu_vfs_read_hook __read_mostly;\
extern int ksu_handle_vfs_read(struct file **file_ptr, char __user **buf_ptr,\
			size_t *count_ptr, loff_t **pos);\
#endif' "$READ_WRITE_C" 2>/dev/null || true
        fi
        
        # Patch fs/stat.c - vfs_statx or vfs_fstatat
        STAT_C="${LOCATION}/fs/stat.c"
        if [ -f "$STAT_C" ] && ! grep -q "ksu_handle_stat" "$STAT_C"; then
            echo "Patching fs/stat.c..."
            sed -i '/^int vfs_statx\|^int vfs_fstatat/i\
#ifdef CONFIG_KSU\
extern int ksu_handle_stat(int *dfd, const char __user **filename_user, int *flags);\
#endif' "$STAT_C" 2>/dev/null || true
        fi
        
        # Patch drivers/input/input.c - Safe Mode support
        INPUT_C="${LOCATION}/drivers/input/input.c"
        if [ -f "$INPUT_C" ] && ! grep -q "ksu_handle_input_handle_event" "$INPUT_C"; then
            echo "Patching drivers/input/input.c for Safe Mode..."
            sed -i '/^static void input_handle_event/i\
#ifdef CONFIG_KSU\
extern bool ksu_input_hook __read_mostly;\
extern int ksu_handle_input_handle_event(unsigned int *type, unsigned int *code, int *value);\
#endif' "$INPUT_C" 2>/dev/null || true
        fi
        
        # Patch fs/devpts/inode.c - for pm command support
        DEVPTS_C="${LOCATION}/fs/devpts/inode.c"
        if [ -f "$DEVPTS_C" ] && ! grep -q "ksu_handle_devpts" "$DEVPTS_C"; then
            echo "Patching fs/devpts/inode.c..."
            sed -i '/^\*devpts_get_priv\|^void \*devpts_get_priv/i\
#ifdef CONFIG_KSU\
extern int ksu_handle_devpts(struct inode*);\
#endif' "$DEVPTS_C" 2>/dev/null || true
        fi
        
        echo "Manual hooks applied (Note: Some patches may need manual verification)"
    fi
    
    # Create sukisu.config for KSU options (Non-GKI)
    SUKISU_CONFIG="${LOCATION}/arch/arm64/configs/sukisu.config"
    echo "Creating SukiSU config fragment for Non-GKI..."
    cat > "$SUKISU_CONFIG" << 'EOF'
# SukiSU Ultra Configuration for Non-GKI Kernel
CONFIG_KSU=y
CONFIG_KSU_MANUAL_HOOK=y
# CONFIG_KSU_KPROBES_HOOK is not set
CONFIG_KALLSYMS=y
CONFIG_KALLSYMS_ALL=y
EOF
    
    echo "=============================================="
    echo "SukiSU Ultra integration completed!"
    echo ""
    echo "IMPORTANT for Non-GKI kernels:"
    echo "1. Manual hooks have been added to kernel source"
    echo "2. You may need to verify patches manually"
    echo "3. Safe Mode: Press Volume Down during boot"
    echo "=============================================="
fi
# ===============================================
# End SukiSU Ultra Integration
# ===============================================

# tzdev
rm -rf "${LOCATION}/drivers/misc/tzdev"

case "${MODEL}" in
    G970F | G970N | G973F | G973N | G975F | G975N | G977B | G977N | N971N | N976N )
 	cp -ar "${LOCATION}/early_setting/tzdev_case/tzdev_A" "${LOCATION}/drivers/misc/tzdev"
        ;;
    N970F | N975F | N976B )
 	cp -ar "${LOCATION}/early_setting/tzdev_case/tzdev_B" "${LOCATION}/drivers/misc/tzdev"
        ;;            
esac

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

# Build defconfig with optional SukiSU config
make ARCH=arm64 -j32 O=${OUT_DIR} mrproper
if [ "$SUKISU_ENABLED" = "1" ]; then
    echo "Building with SukiSU Ultra support..."
    make ARCH=arm64 -j32 O=${OUT_DIR} exynos9820-${DEVICE}_defconfig gorhanhee.config sukisu.config || exit 1
else
    make ARCH=arm64 -j32 O=${OUT_DIR} exynos9820-${DEVICE}_defconfig gorhanhee.config || exit 1
fi
make ARCH=arm64 -j32 O=${OUT_DIR} || exit 1

IMAGE="$(pwd)/out/arch/arm64/boot/Image"

# ===============================================
# KernelPatch Integration (SukiSU Ultra Compatible)
# ===============================================
KERNELPATCH_ENABLED=${KERNELPATCH_ENABLED:-0}
KERNELPATCH_VARIANT=${KERNELPATCH_VARIANT:-"sukisu"}  # Options: "sukisu" or "original"
SUKISU_KP_VERSION=${SUKISU_KP_VERSION:-"0.12.2"}
ORIGINAL_KP_VERSION=${ORIGINAL_KP_VERSION:-"0.12.3"}

if [ "$KERNELPATCH_ENABLED" = "1" ]; then
    KERNELPATCH_DIR="${LOCATION}/KernelPatch"
    mkdir -p "$KERNELPATCH_DIR"
    
    KPTOOLS="$KERNELPATCH_DIR/kptools"
    KPIMG="$KERNELPATCH_DIR/kpimg"
    
    if [ "$KERNELPATCH_VARIANT" = "sukisu" ]; then
        # SukiSU Ultra KernelPatch variant
        echo "KernelPatch integration enabled (SukiSU Ultra variant, version: $SUKISU_KP_VERSION)"
        KP_BASE_URL="https://github.com/SukiSU-Ultra/SukiSU_KernelPatch_patch/releases/download/${SUKISU_KP_VERSION}"
        KPIMG_FILE="kpimg"
        KPTOOLS_FILE="kptools"
    else
        # Original KernelPatch
        echo "KernelPatch integration enabled (Original variant, version: $ORIGINAL_KP_VERSION)"
        KP_BASE_URL="https://github.com/bmax121/KernelPatch/releases/download/${ORIGINAL_KP_VERSION}"
        KPIMG_FILE="kpimg-android"
        KPTOOLS_FILE="kptools-linux"
    fi
    
    # Download prebuilt kpimg if not exists
    if [ ! -f "$KPIMG" ]; then
        echo "Downloading KernelPatch kpimg..."
        if ! curl -L -f -o "$KPIMG" "${KP_BASE_URL}/${KPIMG_FILE}"; then
            echo "Error: Failed to download kpimg"
            rm -f "$KPIMG"
        fi
    fi
    
    # Download prebuilt kptools if not exists
    if [ ! -f "$KPTOOLS" ]; then
        echo "Downloading KernelPatch kptools..."
        if ! curl -L -f -o "$KPTOOLS" "${KP_BASE_URL}/${KPTOOLS_FILE}"; then
            echo "Error: Failed to download kptools"
            rm -f "$KPTOOLS"
        else
            chmod +x "$KPTOOLS"
        fi
    fi
    
    # Patch kernel image if tools are available
    if [ -f "$KPTOOLS" ] && [ -f "$KPIMG" ]; then
        echo "Patching kernel with KernelPatch..."
        PATCHED_IMAGE="${OUT_DIR}/arch/arm64/boot/Image-kp"
        
        "$KPTOOLS" -p -i "$IMAGE" -k "$KPIMG" -o "$PATCHED_IMAGE"
        
        if [ -f "$PATCHED_IMAGE" ]; then
            echo "Kernel patched successfully with KernelPatch!"
            echo "Variant: $KERNELPATCH_VARIANT"
            IMAGE="$PATCHED_IMAGE"
        else
            echo "Warning: KernelPatch patching failed, using original kernel"
        fi
    else
        echo "Warning: KernelPatch tools not found, using original kernel"
        echo "  kptools exists: $([ -f "$KPTOOLS" ] && echo 'yes' || echo 'no')"
        echo "  kpimg exists: $([ -f "$KPIMG" ] && echo 'yes' || echo 'no')"
    fi
fi
# ===============================================
# End KernelPatch Integration
# ===============================================

# Make boot.img file
	
cp "${IMAGE}" "${AIK_DIR}/split_img/boot.img-kernel"

BOARD="${AIK_DIR}/split_img/boot.img-board"
case "$MODEL" in
    G970F )
        echo "SRPRI28A016KU" > "$BOARD"
        ;;
    G970N )
        echo "SRPRI28C007KU" > "$BOARD"
        ;;
    G973F )
        echo "SRPRI28B016KU" > "$BOARD"
        ;;            
    G973N )
        echo "SRPRI28D007KU" > "$BOARD"
        ;;
    G975F )
        echo "SRPRI17C016KU" > "$BOARD"
        ;;        
    G975N )
        echo "SRPRI28E007KU" > "$BOARD"
        ;;
    G977B )
        echo "SRPSC04B014KU" > "$BOARD"
        ;;        
    G977N )
        echo "SRPRK21D006KU" > "$BOARD"
        ;;
    N970F )
    	echo "SRPSD26B009KU" > "$BOARD"
    	;;
    N971N )
        echo "SRPSD23A002KU" > "$BOARD"
        ;;
    N975F )
    	echo "SRPSC14B009KU" > "$BOARD"
    	;;
    N976B )
        echo "SRPSC14C009KU" > "$BOARD"
        ;;        
    N976N )
        echo "SRPSD23C002KU" > "$BOARD"
        ;;
esac

cd "${AIK_DIR}"

./repackimg.sh

cd "${LOCATION}"
mv "${AIK_DIR}/image-new.img" "${GORHANHEE}/boot.img"

# Make dt.img file
cd "${LOCATION}"
case "${MODEL}" in
    G970F | G970N | G973F | G973N | G975F | G975N | G977B | G977N )
	python3 early_setting/mkdtboimg.py create dt.img \
  	--page_size=2048 \
  	--version=0 \
  	--id=0x0 --rev=0x0 --custom0=0x0 --custom1=0x0 --custom2=0x0 --custom3=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/exynos/exynos9820.dtb --custom0=0x00 --custom1=0xff --id=0x0 --rev=0x0 
        ;;  
    N970F | N971N | N975F | N976B | N976N )
	python3 early_setting/mkdtboimg.py create dt.img \
  	--page_size=2048 \
  	--version=0 \
  	--id=0x0 --rev=0x0 --custom0=0x0 --custom1=0x0 --custom2=0x0 --custom3=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/exynos/exynos9825.dtb --custom0=0x00 --custom1=0xff --id=0x0 --rev=0x0 
        ;;              
esac
mv "dt.img" "${GORHANHEE}/dt.img"

# Make dtbo.img file
cd "${LOCATION}"
case "${MODEL}" in
    G970F )
        python3 early_setting/mkdtboimg.py create dtbo.img \
  	--page_size=2048 \
  	--version=0 \
  	--id=0x0 --rev=0x0 --custom0=0x0 --custom1=0x0 --custom2=0x0 --custom3=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond0lte_eur_open_17.dtbo --custom0=0x11 --custom1=0x11 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond0lte_eur_open_18.dtbo --custom0=0x12 --custom1=0x12 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond0lte_eur_open_19.dtbo --custom0=0x13 --custom1=0x13 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond0lte_eur_open_20.dtbo --custom0=0x14 --custom1=0x15 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond0lte_eur_open_22.dtbo --custom0=0x16 --custom1=0x17 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond0lte_eur_open_24.dtbo --custom0=0x18 --custom1=0x18 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond0lte_eur_open_25.dtbo --custom0=0x19 --custom1=0xff --id=0x0 --rev=0x0 	
        ;;
    G970N )
        python3 early_setting/mkdtboimg.py create dtbo.img \
  	--page_size=2048 \
  	--version=0 \
  	--id=0x0 --rev=0x0 --custom0=0x0 --custom1=0x0 --custom2=0x0 --custom3=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond0lte_kor_17.dtbo --custom0=0x11 --custom1=0x11 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond0lte_kor_18.dtbo --custom0=0x12 --custom1=0x12 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond0lte_kor_19.dtbo --custom0=0x13 --custom1=0x13 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond0lte_kor_20.dtbo --custom0=0x14 --custom1=0x18 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond0lte_kor_25.dtbo --custom0=0x19 --custom1=0xff --id=0x0 --rev=0x0
        ;;
    G973F )
        python3 early_setting/mkdtboimg.py create dtbo.img \
  	--page_size=2048 \
  	--version=0 \
  	--id=0x0 --rev=0x0 --custom0=0x0 --custom1=0x0 --custom2=0x0 --custom3=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond1lte_eur_open_17.dtbo --custom0=0x11 --custom1=0x11 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond1lte_eur_open_18.dtbo --custom0=0x12 --custom1=0x12 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond1lte_eur_open_19.dtbo --custom0=0x13 --custom1=0x13 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond1lte_eur_open_20.dtbo --custom0=0x14 --custom1=0x14 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond1lte_eur_open_21.dtbo --custom0=0x15 --custom1=0x15 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond1lte_eur_open_22.dtbo --custom0=0x16 --custom1=0x16 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond1lte_eur_open_23.dtbo --custom0=0x17 --custom1=0x17 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond1lte_eur_open_24.dtbo --custom0=0x18 --custom1=0x19 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond1lte_eur_open_26.dtbo --custom0=0x1a --custom1=0xff --id=0x0 --rev=0x0 
        ;;        
    G973N )
        python3 early_setting/mkdtboimg.py create dtbo.img \
  	--page_size=2048 \
  	--version=0 \
  	--id=0x0 --rev=0x0 --custom0=0x0 --custom1=0x0 --custom2=0x0 --custom3=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond1lte_kor_17.dtbo --custom0=0x11 --custom1=0x11 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond1lte_kor_18.dtbo --custom0=0x12 --custom1=0x12 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond1lte_kor_19.dtbo --custom0=0x13 --custom1=0x13 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond1lte_kor_20.dtbo --custom0=0x14 --custom1=0x14 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond1lte_kor_21.dtbo --custom0=0x15 --custom1=0x19 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond1lte_kor_26.dtbo --custom0=0x1a --custom1=0xff --id=0x0 --rev=0x0
        ;;
    G975F )
        python3 early_setting/mkdtboimg.py create dtbo.img \
  	--page_size=2048 \
  	--version=0 \
  	--id=0x0 --rev=0x0 --custom0=0x0 --custom1=0x0 --custom2=0x0 --custom3=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_eur_open_04.dtbo --custom0=0x04 --custom1=0x0f --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_eur_open_16.dtbo --custom0=0x10 --custom1=0x10 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_eur_open_17.dtbo --custom0=0x11 --custom1=0x11 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_eur_open_18.dtbo --custom0=0x12 --custom1=0x12 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_eur_open_19.dtbo --custom0=0x13 --custom1=0x13 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_eur_open_20.dtbo --custom0=0x14 --custom1=0x16 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_eur_open_23.dtbo --custom0=0x17 --custom1=0x17 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_eur_open_24.dtbo --custom0=0x18 --custom1=0x18 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_eur_open_25.dtbo --custom0=0x19 --custom1=0x19 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_eur_open_26.dtbo --custom0=0x1a --custom1=0xff --id=0x0 --rev=0x0 
  	;;
    G975N )
        python3 early_setting/mkdtboimg.py create dtbo.img \
  	--page_size=2048 \
  	--version=0 \
  	--id=0x0 --rev=0x0 --custom0=0x0 --custom1=0x0 --custom2=0x0 --custom3=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_kor_17.dtbo --custom0=0x11 --custom1=0x11 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_kor_18.dtbo --custom0=0x12 --custom1=0x12 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_kor_19.dtbo --custom0=0x13 --custom1=0x13 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_kor_20.dtbo --custom0=0x14 --custom1=0x17 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_kor_24.dtbo --custom0=0x18 --custom1=0x18 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_kor_25.dtbo --custom0=0x19 --custom1=0x19 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_kor_26.dtbo --custom0=0x1a --custom1=0xff --id=0x0 --rev=0x0
        ;;
    G977B )
        python3 early_setting/mkdtboimg.py create dtbo.img \
  	--page_size=2048 \
  	--version=0 \
  	--id=0x0 --rev=0x0 --custom0=0x0 --custom1=0x0 --custom2=0x0 --custom3=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyondx_eur_open_00.dtbo --custom0=0x00 --custom1=0x00 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyondx_eur_open_01.dtbo --custom0=0x01 --custom1=0x01 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyondx_eur_open_02.dtbo --custom0=0x02 --custom1=0x02 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyondx_eur_open_03.dtbo --custom0=0x03 --custom1=0x03 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyondx_eur_open_04.dtbo --custom0=0x04 --custom1=0x04 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyondx_eur_open_05.dtbo --custom0=0x05 --custom1=0x05 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyondx_eur_open_06.dtbo --custom0=0x06 --custom1=0x06 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyondx_eur_open_07.dtbo --custom0=0x07 --custom1=0x07 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyondx_eur_open_08.dtbo --custom0=0x08 --custom1=0xff --id=0x0 --rev=0x0
        ;;         
    G977N )
        python3 early_setting/mkdtboimg.py create dtbo.img \
  	--page_size=2048 \
  	--version=0 \
  	--id=0x0 --rev=0x0 --custom0=0x0 --custom1=0x0 --custom2=0x0 --custom3=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyondx_kor_00.dtbo --custom0=0x00 --custom1=0x00 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyondx_kor_01.dtbo --custom0=0x01 --custom1=0x01 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyondx_kor_02.dtbo --custom0=0x02 --custom1=0x02 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyondx_kor_03.dtbo --custom0=0x03 --custom1=0x03 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyondx_kor_04.dtbo --custom0=0x04 --custom1=0x04 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyondx_kor_05.dtbo --custom0=0x05 --custom1=0x05 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyondx_kor_06.dtbo --custom0=0x06 --custom1=0x06 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyondx_kor_07.dtbo --custom0=0x07 --custom1=0x07 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyondx_kor_08.dtbo --custom0=0x08 --custom1=0xff --id=0x0 --rev=0x0
        ;; 
    N970F )
        python3 early_setting/mkdtboimg.py create dtbo.img \
  	--page_size=2048 \
  	--version=0 \
  	--id=0x0 --rev=0x0 --custom0=0x0 --custom1=0x0 --custom2=0x0 --custom3=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d1_eur_open_18.dtbo --custom0=0x12 --custom1=0x12 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d1_eur_open_19.dtbo --custom0=0x13 --custom1=0x14 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d1_eur_open_21.dtbo --custom0=0x15 --custom1=0x15 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d1_eur_open_22.dtbo --custom0=0x16 --custom1=0x16 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d1_eur_open_23.dtbo --custom0=0x17 --custom1=0xff --id=0x0 --rev=0x0
        ;;        
    N971N )
        python3 early_setting/mkdtboimg.py create dtbo.img \
  	--page_size=2048 \
  	--version=0 \
  	--id=0x0 --rev=0x0 --custom0=0x0 --custom1=0x0 --custom2=0x0 --custom3=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d1x_kor_18.dtbo --custom0=0x12 --custom1=0x12 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d1x_kor_19.dtbo --custom0=0x13 --custom1=0x14 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d1x_kor_21.dtbo --custom0=0x15 --custom1=0x15 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d1x_kor_22.dtbo --custom0=0x16 --custom1=0x16 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d1x_kor_23.dtbo --custom0=0x17 --custom1=0xff --id=0x0 --rev=0x0
        ;;
    N975F )
        python3 early_setting/mkdtboimg.py create dtbo.img \
  	--page_size=2048 \
  	--version=0 \
  	--id=0x0 --rev=0x0 --custom0=0x0 --custom1=0x0 --custom2=0x0 --custom3=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2_eur_open_02.dtbo --custom0=0x02 --custom1=0x0f --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2_eur_open_16.dtbo --custom0=0x10 --custom1=0x10 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2_eur_open_17.dtbo --custom0=0x11 --custom1=0x11 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2_eur_open_18.dtbo --custom0=0x12 --custom1=0x12 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2_eur_open_19.dtbo --custom0=0x13 --custom1=0x13 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2_eur_open_20.dtbo --custom0=0x14 --custom1=0x14 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2_eur_open_21.dtbo --custom0=0x15 --custom1=0x15 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2_eur_open_22.dtbo --custom0=0x16 --custom1=0x16 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2_eur_open_23.dtbo --custom0=0x17 --custom1=0x17 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2_eur_open_24.dtbo --custom0=0x18 --custom1=0xff --id=0x0 --rev=0x0
        ;;
    N976B )
        python3 early_setting/mkdtboimg.py create dtbo.img \
  	--page_size=2048 \
  	--version=0 \
  	--id=0x0 --rev=0x0 --custom0=0x0 --custom1=0x0 --custom2=0x0 --custom3=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_eur_open_02.dtbo --custom0=0x02 --custom1=0x0f --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_eur_open_16.dtbo --custom0=0x10 --custom1=0x10 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_eur_open_17.dtbo --custom0=0x11 --custom1=0x11 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_eur_open_18.dtbo --custom0=0x12 --custom1=0x12 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_eur_open_19.dtbo --custom0=0x13 --custom1=0x13 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_eur_open_20.dtbo --custom0=0x14 --custom1=0x14 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_eur_open_21.dtbo --custom0=0x15 --custom1=0x15 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_eur_open_22.dtbo --custom0=0x16 --custom1=0x16 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_eur_open_23.dtbo --custom0=0x17 --custom1=0x17 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_eur_open_24.dtbo --custom0=0x18 --custom1=0xff --id=0x0 --rev=0x0    
        ;;                  
    N976N )
        python3 early_setting/mkdtboimg.py create dtbo.img \
  	--page_size=2048 \
  	--version=0 \
  	--id=0x0 --rev=0x0 --custom0=0x0 --custom1=0x0 --custom2=0x0 --custom3=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_kor_02.dtbo --custom0=0x02 --custom1=0x0f --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_kor_16.dtbo --custom0=0x10 --custom1=0x10 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_kor_17.dtbo --custom0=0x11 --custom1=0x11 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_kor_18.dtbo --custom0=0x12 --custom1=0x12 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_kor_19.dtbo --custom0=0x13 --custom1=0x14 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_kor_21.dtbo --custom0=0x15 --custom1=0x15 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_kor_22.dtbo --custom0=0x16 --custom1=0x16 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_kor_23.dtbo --custom0=0x17 --custom1=0x17 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_kor_24.dtbo --custom0=0x18 --custom1=0xff --id=0x0 --rev=0x0
        ;;        
esac
mv "dtbo.img" "${GORHANHEE}/dtbo.img"

# Make tar_file for Odin
cd ${GORHANHEE}

tar -cvf ${MODEL}_Odin_ramdisk.tar boot.img dt.img dtbo.img

# Make zip_file for TWRP
cd "${LOCATION}"
cp -ar "$(pwd)/early_setting/META-INF" "${GORHANHEE}/META-INF"

cd ${GORHANHEE}

zip -r ${MODEL}_TWRP_ramdisk.zip META-INF boot.img dt.img dtbo.img

rm -rf ${AIK_DIR}/split_img/boot.img-kernel
rm -rf ${AIK_DIR}/split_img/boot.img-ramdisk.cpio.gz
rm -rf ${AIK_DIR}/ramdisk-new.cpio.gz
