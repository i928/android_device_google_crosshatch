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
TARGET_KERNEL_SOURCE := kernel/google/msm-4.9
TARGET_NEEDS_DTBOIMAGE := true

# CROSSHATCH_KERNEL_DEBUG=<variant> builds the kernel with the options of
# $(TARGET_KERNEL_SOURCE)/build.config.bluecross_<variant> (debug_api,
# debug_hang, debug_kmemleak, debug_locking, debug_memory,
# debug_memory_accounting, kasan, no-cfi). Those files are for Google's
# build/build.sh, which the ROM build never reads; kernel-debug/
# buildconfig2frag.py turns their scripts/config options into a fragment.
# LineageOS 22.2 only merges fragments from the kernel's configs dir, so it is
# written there as crosshatch_kdebug.config (untracked) and appended to
# TARGET_KERNEL_CONFIG. debug_* variants also get CONFIG_DEBUG_FS=y (off in
# b1c1_defconfig), debug_locking also lockdep. Most variants turn LTO/CFI off; flash the matching
# vendor.img (autorun does). Debug kernels are slow: never use one for timing.
#   CROSSHATCH_KERNEL_DEBUG=debug_locking m bootimage vendorimage
ifneq ($(CROSSHATCH_KERNEL_DEBUG),)
# Google's debug_locking has the spinlock/mutex checks but no lockdep.
CROSSHATCH_KDEBUG_LOCKDEP := CONFIG_LOCKDEP=y CONFIG_DEBUG_LOCK_ALLOC=y \
    CONFIG_PROVE_LOCKING=y CONFIG_PROVE_RCU=y
CROSSHATCH_KDEBUG_FRAG := $(TARGET_KERNEL_SOURCE)/arch/arm64/configs/crosshatch_kdebug.config
_kdebug := $(shell python3 device/google/crosshatch/kernel-debug/buildconfig2frag.py \
    $(TARGET_KERNEL_SOURCE)/build.config.bluecross_$(CROSSHATCH_KERNEL_DEBUG) $(CROSSHATCH_KDEBUG_FRAG) \
    $(if $(filter debug_%,$(CROSSHATCH_KERNEL_DEBUG)),CONFIG_DEBUG_FS=y) \
    $(if $(filter debug_locking,$(CROSSHATCH_KERNEL_DEBUG)),$(CROSSHATCH_KDEBUG_LOCKDEP)))
ifeq ($(filter ok,$(_kdebug)),)
$(error CROSSHATCH_KERNEL_DEBUG=$(CROSSHATCH_KERNEL_DEBUG): $(_kdebug))
endif
# $(warning), not $(info): Soong parses the board config stdout as KEY=value lines
$(warning CROSSHATCH_KERNEL_DEBUG -> kernel fragment $(CROSSHATCH_KDEBUG_FRAG), $(_kdebug))
TARGET_KERNEL_CONFIG += crosshatch_kdebug.config
endif

# Manifests
DEVICE_FRAMEWORK_COMPATIBILITY_MATRIX_FILE += vendor/lineage/config/device_framework_matrix.xml

# Partitions
AB_OTA_PARTITIONS += \
    vendor
ifneq ($(PRODUCT_USE_DYNAMIC_PARTITIONS), true)
    BOARD_VENDORIMAGE_PARTITION_SIZE := 805306368
endif
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := erofs

# Reserve space for gapps install
-include vendor/lineage/config/BoardConfigReservedSize.mk
ifneq ($(WITH_GMS),true)
BOARD_PRODUCTIMAGE_PARTITION_RESERVED_SIZE := 0
endif

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

# libksud.so is shipped via PRODUCT_COPY_FILES in device.mk (see comment
# there for why) -- this flag is what actually permits an ELF binary
# through that mechanism; it's board-scoped and silently ignored if set
# from a product .mk like device.mk instead.
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true

# PRODUCT_COPY_FILES's copy-one-file rule uses plain `cp` (no -p), which
# drops the source file's executable bit regardless of what it was --
# confirmed on-device: file lands as -rw-r--r-- even though the source in
# this tree is -rwxr-xr-x, and the app execs this file directly as a
# subprocess. Force it via a separate stamp file (referencing $(PRODUCT_OUT)
# as a rule prerequisite from device.mk hits a "||PRODUCT-PATH-PH||"
# placeholder-substitution bug -- PRODUCT_OUT isn't fully resolved yet at
# product-config-parse time; BoardConfigLineage.mk runs later and is fine).
libksud_chmod_stamp := $(OUT_DIR)/libksud_chmod.stamp
$(libksud_chmod_stamp): $(PRODUCT_OUT)/$(TARGET_COPY_OUT_PRODUCT)/app/KernelSUNext/lib/arm64/libksud.so
	chmod 755 $<
	touch $@
droidcore: $(libksud_chmod_stamp)

