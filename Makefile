THEOS_PACKAGE_DIR_NAME = debs
TARGET = iphone:clang:latest:7.0
ARCHS = armv7 arm64
include theos/makefiles/common.mk

TWEAK_NAME = PassTime
PassTime_FILES = PassTime.xm
PassTime_FRAMEWORKS = UIKit
PassTime_PRIVATE_FRAMEWORKS = Preferences
PassTime_CFLAGS = -fobjc-arc
PassTime_LIBRARIES = cephei

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

internal-after-install::
	install.exec "killall -9 Preferences"
