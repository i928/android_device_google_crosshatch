#
# Copyright (C) 2018-2021 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Kernel
BOARD_KERNEL_IMAGE_NAME := Image.lz4
TARGET_COMPILE_WITH_MSM_KERNEL := true
TARGET_KERNEL_CLANG_VERSION := r614150
TARGET_KERNEL_CLANG_PATH := $(abspath .)/prebuilts/clang/kernel/$(HOST_PREBUILT_TAG)/clang-$(TARGET_KERNEL_CLANG_VERSION)
TARGET_KERNEL_CONFIG := b1c1_defconfig
TARGET_KERNEL_LLVM_BINUTILS := false
# ld.lld for the LTO link (4.9 kernel branch clang23-lld-lto: Clang 23 ships no
# LLVMgold.so for gold). Only LD: LLVM_BINUTILS would also force LLVM=1 LLVM_IAS=1.
TARGET_KERNEL_ADDITIONAL_FLAGS := LD=$(TARGET_KERNEL_CLANG_PATH)/bin/ld.lld
TARGET_KERNEL_SOURCE := kernel/google/msm-4.9
TARGET_NEEDS_DTBOIMAGE := true

# Bootanimation: LineageOS' generated 1440-wide animation with the loop (part1) and
# outro (part2) changed from "c" (always played to the end) to "p", so they stop once boot
# is done instead of holding sys.boot_completed (part1 loop 1.4 s, outro ~3.5 s).
# Rename the zip whenever its content changes: vendor/lineage's genrule copies it by
# path from its cmd without declaring it as an input, so only a new path reruns it.
TARGET_BOOTANIMATION := device/google/crosshatch/bootanimation/bootanimation-p1p2.zip

# Partitions
AB_OTA_PARTITIONS += \
    vendor
ifneq ($(PRODUCT_USE_DYNAMIC_PARTITIONS), true)
    BOARD_VENDORIMAGE_PARTITION_SIZE := 805306368
endif
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := erofs

# No GApps reserve: product is EROFS (read-only) and GApps are built in, so
# nothing can be installed into it after the ROM.
WITHOUT_RESERVED_SIZE := true

# SELinux
BOARD_SEPOLICY_DIRS += device/google/crosshatch/sepolicy-lineage/dynamic
BOARD_SEPOLICY_DIRS += device/google/crosshatch/sepolicy-lineage/vendor

# Verified Boot
ifneq (,$(AVB_CUSTOM_KEY_PATH))
BOARD_AVB_ALGORITHM := $(AVB_CUSTOM_ALGORITHM)
BOARD_AVB_KEY_PATH := $(AVB_CUSTOM_KEY_PATH)
endif

ifneq ($(WITH_AVB),true)
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3
endif

include device/google/crosshatch/prebuilts/extra-apps/sepolicy/Android.mk

