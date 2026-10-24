export TARGET := iphone:clang:latest:15.0
export ARCHS := arm64 arm64e
export THEOS_PACKAGE_SCHEME := rootless

INSTALL_TARGET_PROCESSES := XoaInfo

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = XoaInfoPatch

XoaInfoPatch_FILES = Tweak.xm
XoaInfoPatch_CFLAGS = -fobjc-arc
XoaInfoPatch_FRAMEWORKS = Foundation UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
