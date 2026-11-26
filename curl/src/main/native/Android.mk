LOCAL_PATH:= $(call my-dir)

include $(CLEAR_VARS)
include $(LOCAL_PATH)/curl/src/Makefile.inc
LOCAL_MODULE            := curl
LOCAL_SRC_FILES         := $(addprefix curl/src/,$(CURL_CFILES))
LOCAL_SRC_FILES         += $(addprefix curl/src/,$(CURLX_CFILES))
LOCAL_HAS_CPP           := true
LOCAL_C_INCLUDES        := $(LOCAL_PATH)/curl/lib $(LOCAL_PATH)/curl/src
ifeq ($(TARGET_ARCH_ABI),armeabi-v7a)
    LOCAL_C_INCLUDES    += $(LOCAL_PATH)/config32
else ifeq ($(TARGET_ARCH_ABI),arm64-v8a)
    LOCAL_C_INCLUDES    += $(LOCAL_PATH)/config64
else ifeq ($(TARGET_ARCH_ABI),x86)
    LOCAL_C_INCLUDES    += $(LOCAL_PATH)/config32
else ifeq ($(TARGET_ARCH_ABI),x86_64)
    LOCAL_C_INCLUDES    += $(LOCAL_PATH)/config64
else ifeq ($(TARGET_ARCH_ABI),riscv64)
    LOCAL_C_INCLUDES    += $(LOCAL_PATH)/config64
endif
LOCAL_CFLAGS            := -DHAVE_CONFIG_H
LOCAL_STATIC_LIBRARIES  := curl_static
include $(LOCAL_PATH)/build-executable.mk

# c-ares, built by scripts/build-cares.sh. Static, so it must not appear in the
# executable's NEEDED list.
include $(CLEAR_VARS)
LOCAL_MODULE            := cares_static
LOCAL_SRC_FILES         := prebuilt/$(TARGET_ARCH_ABI)/libcares.a
LOCAL_EXPORT_C_INCLUDES := $(LOCAL_PATH)/c-ares/include \
                           $(LOCAL_PATH)/prebuilt/$(TARGET_ARCH_ABI)
include $(PREBUILT_STATIC_LIBRARY)

include $(CLEAR_VARS)
include $(LOCAL_PATH)/curl/lib/Makefile.inc
LOCAL_MODULE            := curl_static
LOCAL_SRC_FILES         := $(addprefix curl/lib/,$(CSOURCES))
LOCAL_C_INCLUDES        := $(LOCAL_PATH)/curl/include $(LOCAL_PATH)/curl/lib
ifeq ($(TARGET_ARCH_ABI),armeabi-v7a)
    LOCAL_C_INCLUDES    += $(LOCAL_PATH)/config32
else ifeq ($(TARGET_ARCH_ABI),arm64-v8a)
    LOCAL_C_INCLUDES    += $(LOCAL_PATH)/config64
else ifeq ($(TARGET_ARCH_ABI),x86)
    LOCAL_C_INCLUDES    += $(LOCAL_PATH)/config32
else ifeq ($(TARGET_ARCH_ABI),x86_64)
    LOCAL_C_INCLUDES    += $(LOCAL_PATH)/config64
else ifeq ($(TARGET_ARCH_ABI),riscv64)
    LOCAL_C_INCLUDES    += $(LOCAL_PATH)/config64
endif
LOCAL_EXPORT_C_INCLUDES := $(LOCAL_PATH)/curl/include
LOCAL_EXPORT_LDLIBS     := -lz
LOCAL_CFLAGS            := -DHAVE_CONFIG_H -DBUILDING_LIBCURL
LOCAL_STATIC_LIBRARIES  := ssl_static crypto_static nghttp2_static nghttp3_static ngtcp2_static cares_static
include $(BUILD_STATIC_LIBRARY)

include $(CLEAR_VARS)
include $(LOCAL_PATH)/nghttp2/lib/Makefile.am
LOCAL_MODULE            := nghttp2_static
LOCAL_SRC_FILES         := $(addprefix nghttp2/lib/,$(OBJECTS))
LOCAL_C_INCLUDES        := $(LOCAL_PATH)/nghttp2/lib/includes
LOCAL_C_INCLUDES        += $(LOCAL_PATH)/config
LOCAL_EXPORT_C_INCLUDES := $(LOCAL_PATH)/nghttp2/lib/includes
LOCAL_CFLAGS            := -DHAVE_CONFIG_H
include $(BUILD_STATIC_LIBRARY)

include $(CLEAR_VARS)
include $(LOCAL_PATH)/ngtcp2/lib/Makefile.am
LOCAL_MODULE            := ngtcp2_static
LOCAL_SRC_FILES         := $(addprefix ngtcp2/lib/,$(OBJECTS))
LOCAL_C_INCLUDES        := $(LOCAL_PATH)/ngtcp2/lib/includes
LOCAL_C_INCLUDES        += $(LOCAL_PATH)/config
LOCAL_EXPORT_C_INCLUDES := $(LOCAL_PATH)/ngtcp2/lib/includes
LOCAL_CFLAGS            := -DHAVE_CONFIG_H
LOCAL_STATIC_LIBRARIES  := ngtcp2_crypto_static
include $(BUILD_STATIC_LIBRARY)

include $(CLEAR_VARS)
# Do not include the upstream Makefile.am directly: recent ngtcp2 adds
# automake conditionals (`if HAVE_CRYPTOTEST`) that ndk-build's make cannot
# parse ("missing separator"). Extract just the sources variable, and fail
# loudly if upstream renames or restructures it.
NGTCP2_CRYPTO_BORINGSSL_SOURCES := $(shell sed -n 's/^libngtcp2_crypto_boringssl_a_SOURCES[[:space:]]*=[[:space:]]*//p' $(LOCAL_PATH)/ngtcp2/crypto/boringssl/Makefile.am)
ifeq ($(strip $(NGTCP2_CRYPTO_BORINGSSL_SOURCES)),)
$(error cannot extract libngtcp2_crypto_boringssl_a_SOURCES from ngtcp2/crypto/boringssl/Makefile.am)
endif
LOCAL_MODULE            := ngtcp2_crypto_static
LOCAL_SRC_FILES         += $(addprefix ngtcp2/crypto/boringssl/,$(NGTCP2_CRYPTO_BORINGSSL_SOURCES))
LOCAL_C_INCLUDES        := $(LOCAL_PATH)/ngtcp2/lib $(LOCAL_PATH)/ngtcp2/lib/includes
LOCAL_C_INCLUDES        += $(LOCAL_PATH)/ngtcp2/crypto $(LOCAL_PATH)/ngtcp2/crypto/includes
LOCAL_C_INCLUDES        += $(LOCAL_PATH)/config
LOCAL_EXPORT_C_INCLUDES := $(LOCAL_PATH)/ngtcp2/crypto/includes
LOCAL_CFLAGS            := -DHAVE_CONFIG_H
LOCAL_STATIC_LIBRARIES  := ssl_static crypto_static
include $(BUILD_STATIC_LIBRARY)

include $(CLEAR_VARS)
include $(LOCAL_PATH)/nghttp3/lib/Makefile.am
LOCAL_MODULE            := nghttp3_static
LOCAL_SRC_FILES         := $(addprefix nghttp3/lib/,$(OBJECTS))
LOCAL_C_INCLUDES        := $(LOCAL_PATH)/nghttp3/lib/includes
LOCAL_C_INCLUDES        += $(LOCAL_PATH)/config
LOCAL_EXPORT_C_INCLUDES := $(LOCAL_PATH)/nghttp3/lib/includes
LOCAL_CFLAGS            := -DHAVE_CONFIG_H
include $(BUILD_STATIC_LIBRARY)

# BoringSSL, built from the boringssl submodule by scripts/build-boringssl.sh
# (with vvb2060's cert-dir patch applied). Static, so the libraries must not
# appear in the executable's NEEDED list. Same module names the prefab
# exported, so the consumers above are unchanged.
include $(CLEAR_VARS)
LOCAL_MODULE            := crypto_static
LOCAL_SRC_FILES         := prebuilt/$(TARGET_ARCH_ABI)/libcrypto.a
LOCAL_EXPORT_C_INCLUDES := $(LOCAL_PATH)/boringssl/include
include $(PREBUILT_STATIC_LIBRARY)

include $(CLEAR_VARS)
LOCAL_MODULE            := ssl_static
LOCAL_SRC_FILES         := prebuilt/$(TARGET_ARCH_ABI)/libssl.a
LOCAL_EXPORT_C_INCLUDES := $(LOCAL_PATH)/boringssl/include
LOCAL_STATIC_LIBRARIES  := crypto_static
include $(PREBUILT_STATIC_LIBRARY)
