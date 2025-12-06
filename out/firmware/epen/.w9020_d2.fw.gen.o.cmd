cmd_firmware/epen/w9020_d2.fw.gen.o := ../toolchain/clang/host/linux-x86/clang-4639204-cfp-jopp/bin/clang -Wp,-MD,firmware/epen/.w9020_d2.fw.gen.o.d -nostdinc -isystem /home/runner/work/exynos9820_samsung_D1/exynos9820_samsung_D1/toolchain/clang/host/linux-x86/clang-4639204-cfp-jopp/lib64/clang/6.0.1/include -I../arch/arm64/include -I./arch/arm64/include/generated  -I../include -I./include -I../arch/arm64/include/uapi -I./arch/arm64/include/generated/uapi -I../include/uapi -I./include/generated/uapi -include ../include/linux/kconfig.h -D__KERNEL__ -mlittle-endian -Qunused-arguments -D__ASSEMBLY__ -march=armv8-a+lse --target=aarch64-linux-gnu --prefix=../toolchain/gcc-cfp/gcc-cfp-jopp-only/aarch64-linux-android-4.9/bin/ --gcc-toolchain=/home/runner/work/exynos9820_samsung_D1/exynos9820_samsung_D1/toolchain/gcc-cfp/gcc-cfp-jopp-only/aarch64-linux-android-4.9 -no-integrated-as -fno-PIE -DCONFIG_AS_LSE=1 -DCONFIG_BROKEN_GAS_INST=1 -Wa,-gdwarf-2   -c -o firmware/epen/w9020_d2.fw.gen.o firmware/epen/w9020_d2.fw.gen.S

source_firmware/epen/w9020_d2.fw.gen.o := firmware/epen/w9020_d2.fw.gen.S

deps_firmware/epen/w9020_d2.fw.gen.o := \
  ../include/linux/compiler_types.h \
    $(wildcard include/config/have/arch/compiler/h.h) \
    $(wildcard include/config/enable/must/check.h) \
    $(wildcard include/config/enable/warn/deprecated.h) \

firmware/epen/w9020_d2.fw.gen.o: $(deps_firmware/epen/w9020_d2.fw.gen.o)

$(deps_firmware/epen/w9020_d2.fw.gen.o):
