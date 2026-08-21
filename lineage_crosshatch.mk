#
# Copyright (C) 2018-2021 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit some common Lineage stuff.
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

# Inherit device configuration
$(call inherit-product, device/google/crosshatch/aosp_crosshatch.mk)

include device/google/crosshatch/crosshatch/device-lineage.mk

# Device identifier. This must come after all inclusions
PRODUCT_BRAND := google
PRODUCT_MODEL := Pixel 3 XL
PRODUCT_NAME := lineage_crosshatch

# Boot animation
TARGET_SCREEN_HEIGHT := 2960
TARGET_SCREEN_WIDTH := 1440

PRODUCT_BUILD_PROP_OVERRIDES += \
    BuildDesc="crosshatch-user 12 SP1A.210812.016.C2 8618562 release-keys" \
    BuildFingerprint=google/crosshatch/crosshatch:12/SP1A.210812.016.C2/8618562:user/release-keys \
    DeviceProduct=crosshatch

$(call inherit-product, vendor/google/crosshatch/crosshatch-vendor.mk)

# Ship APEXes uncompressed: compressed .capex are unpacked to /data on the first
# boot after every update (~5 s on sunfish). Costs ~150 MB more in super.
PRODUCT_COMPRESSED_APEX := false

# MindTheGapps, baked in: with system_ext and product on EROFS nothing can
# be flashed into them after the ROM.
$(call inherit-product, vendor/gapps/arm64/arm64-vendor.mk)
