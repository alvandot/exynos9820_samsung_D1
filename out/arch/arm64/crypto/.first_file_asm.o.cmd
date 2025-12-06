cmd_arch/arm64/crypto/first_file_asm.o := ../toolchain/clang/host/linux-x86/clang-4639204-cfp-jopp/bin/clang -Wp,-MD,arch/arm64/crypto/.first_file_asm.o.d -nostdinc -isystem /home/runner/work/exynos9820_samsung_D1/exynos9820_samsung_D1/toolchain/clang/host/linux-x86/clang-4639204-cfp-jopp/lib64/clang/6.0.1/include -I../arch/arm64/include -I./arch/arm64/include/generated  -I../include -I./include -I../arch/arm64/include/uapi -I./arch/arm64/include/generated/uapi -I../include/uapi -I./include/generated/uapi -include ../include/linux/kconfig.h  -I../arch/arm64/crypto -Iarch/arm64/crypto -D__KERNEL__ -mlittle-endian -Qunused-arguments -Wall -Wundef -Wno-trigraphs -fno-strict-aliasing -fno-common -fshort-wchar -Wno-format-security -Xassembler -march=armv8-a+lse -std=gnu89 -DANDROID_VERSION=120000 -DANDROID_MAJOR_VERSION=s --target=aarch64-linux-gnu --prefix=../toolchain/gcc-cfp/gcc-cfp-jopp-only/aarch64-linux-android-4.9/bin/ --gcc-toolchain=/home/runner/work/exynos9820_samsung_D1/exynos9820_samsung_D1/toolchain/gcc-cfp/gcc-cfp-jopp-only/aarch64-linux-android-4.9 -no-integrated-as -fno-PIE -mno-implicit-float -DCONFIG_AS_LSE=1 -DCONFIG_BROKEN_GAS_INST=1 -fno-asynchronous-unwind-tables -fno-pic -Wno-asm-operand-widths -O2 -Wframe-larger-than=4096 -fstack-protector-strong -Wno-format-invalid-specifier -Wno-gnu -Wno-address-of-packed-member -Wno-duplicate-decl-specifier -Wno-tautological-compare -mno-global-merge -Wno-unused-const-variable -fno-omit-frame-pointer -fno-optimize-sibling-calls -g -Wdeclaration-after-statement -Wno-pointer-sign -fno-strict-overflow -fno-merge-all-constants -fno-stack-check -Werror=implicit-int -Werror=date-time -Wno-initializer-overrides -Wno-unused-value -Wno-format -Wno-sign-compare -Wno-format-zero-length -Wno-uninitialized    -DKBUILD_BASENAME='"first_file_asm"'  -DKBUILD_MODNAME='"first_file_asm"' -c -o arch/arm64/crypto/.tmp_first_file_asm.o ../arch/arm64/crypto/first_file_asm.c

source_arch/arm64/crypto/first_file_asm.o := ../arch/arm64/crypto/first_file_asm.c

deps_arch/arm64/crypto/first_file_asm.o := \
  ../include/linux/compiler_types.h \
    $(wildcard include/config/have/arch/compiler/h.h) \
    $(wildcard include/config/enable/must/check.h) \
    $(wildcard include/config/enable/warn/deprecated.h) \
  ../include/linux/compiler-gcc.h \
    $(wildcard include/config/arch/supports/optimized/inlining.h) \
    $(wildcard include/config/optimize/inlining.h) \
    $(wildcard include/config/retpoline.h) \
    $(wildcard include/config/gcov/kernel.h) \
    $(wildcard include/config/arch/use/builtin/bswap.h) \
  ../include/linux/compiler-clang.h \
    $(wildcard include/config/lto/clang.h) \
    $(wildcard include/config/ftrace/mcount/record.h) \

arch/arm64/crypto/first_file_asm.o: $(deps_arch/arm64/crypto/first_file_asm.o)

$(deps_arch/arm64/crypto/first_file_asm.o):
