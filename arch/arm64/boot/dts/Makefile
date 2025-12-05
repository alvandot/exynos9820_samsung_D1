# SPDX-License-Identifier: GPL-2.0
# N970F (D1) Only - Other devices removed for faster compilation

dtb-y += exynos/exynos9825.dtb

# N970F
dtbo-y += samsung/exynos9820-d1_eur_open_23.dtbo
dtbo-y += samsung/exynos9820-d1_eur_open_19.dtbo
dtbo-y += samsung/exynos9820-d1_eur_open_18.dtbo
dtbo-y += samsung/exynos9820-d1_eur_open_21.dtbo
dtbo-y += samsung/exynos9820-d1_eur_open_22.dtbo

targets += dtbs
DTB_LIST  := $(dtb-y) $(dtbo-y)
always    := $(DTB_LIST)

dtbs: $(addprefix $(obj)/, $(DTB_LIST))

clean-files := *.dtb*
