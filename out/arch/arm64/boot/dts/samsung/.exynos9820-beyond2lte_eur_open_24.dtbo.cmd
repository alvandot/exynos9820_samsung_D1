cmd_arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_eur_open_24.dtbo := mkdir -p arch/arm64/boot/dts/samsung/ ; ../toolchain/clang/host/linux-x86/clang-4639204-cfp-jopp/bin/clang -E -Wp,-MD,arch/arm64/boot/dts/samsung/.exynos9820-beyond2lte_eur_open_24.dtbo.d.pre.tmp -nostdinc -I../scripts/dtc/include-prefixes -undef -D__DTS__ -DANDROID_VERSION=120000 -DANDROID_MAJOR_VERSION=s -x assembler-with-cpp -o arch/arm64/boot/dts/samsung/.exynos9820-beyond2lte_eur_open_24.dtbo.dts.tmp ../arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_eur_open_24.dts ; ./scripts/dtc/dtc -O dtb -o arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_eur_open_24.dtbo -b 0 -a 4 -i../arch/arm64/boot/dts/samsung/ -i../scripts/dtc/include-prefixes -@ -Wno-unit_address_vs_reg -d arch/arm64/boot/dts/samsung/.exynos9820-beyond2lte_eur_open_24.dtbo.d.dtc.tmp arch/arm64/boot/dts/samsung/.exynos9820-beyond2lte_eur_open_24.dtbo.dts.tmp ; ./scripts/dtc/dtc -O dts -I dtb -o arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_eur_open_24.dtbo.reverse.dts arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_eur_open_24.dtbo ; cat arch/arm64/boot/dts/samsung/.exynos9820-beyond2lte_eur_open_24.dtbo.d.pre.tmp arch/arm64/boot/dts/samsung/.exynos9820-beyond2lte_eur_open_24.dtbo.d.dtc.tmp > arch/arm64/boot/dts/samsung/.exynos9820-beyond2lte_eur_open_24.dtbo.d

source_arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_eur_open_24.dtbo := ../arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_eur_open_24.dts

deps_arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_eur_open_24.dtbo := \

arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_eur_open_24.dtbo: $(deps_arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_eur_open_24.dtbo)

$(deps_arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_eur_open_24.dtbo):
