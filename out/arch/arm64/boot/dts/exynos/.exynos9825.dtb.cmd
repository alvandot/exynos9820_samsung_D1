cmd_arch/arm64/boot/dts/exynos/exynos9825.dtb := mkdir -p arch/arm64/boot/dts/exynos/ ; ../toolchain/clang/host/linux-x86/clang-4639204-cfp-jopp/bin/clang -E -Wp,-MD,arch/arm64/boot/dts/exynos/.exynos9825.dtb.d.pre.tmp -nostdinc -I../scripts/dtc/include-prefixes -undef -D__DTS__ -DANDROID_VERSION=120000 -DANDROID_MAJOR_VERSION=s -x assembler-with-cpp -o arch/arm64/boot/dts/exynos/.exynos9825.dtb.dts.tmp ../arch/arm64/boot/dts/exynos/exynos9825.dts ; ./scripts/dtc/dtc -O dtb -o arch/arm64/boot/dts/exynos/exynos9825.dtb -b 0 -a 4 -i../arch/arm64/boot/dts/exynos/ -i../scripts/dtc/include-prefixes -@ -Wno-unit_address_vs_reg -d arch/arm64/boot/dts/exynos/.exynos9825.dtb.d.dtc.tmp arch/arm64/boot/dts/exynos/.exynos9825.dtb.dts.tmp ; ./scripts/dtc/dtc -O dts -I dtb -o arch/arm64/boot/dts/exynos/exynos9825.dtb.reverse.dts arch/arm64/boot/dts/exynos/exynos9825.dtb ; cat arch/arm64/boot/dts/exynos/.exynos9825.dtb.d.pre.tmp arch/arm64/boot/dts/exynos/.exynos9825.dtb.d.dtc.tmp > arch/arm64/boot/dts/exynos/.exynos9825.dtb.d

source_arch/arm64/boot/dts/exynos/exynos9825.dtb := ../arch/arm64/boot/dts/exynos/exynos9825.dts

deps_arch/arm64/boot/dts/exynos/exynos9825.dtb := \

arch/arm64/boot/dts/exynos/exynos9825.dtb: $(deps_arch/arm64/boot/dts/exynos/exynos9825.dtb)

$(deps_arch/arm64/boot/dts/exynos/exynos9825.dtb):
