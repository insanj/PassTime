THEOS_PACKAGE_DIR_NAME = debs
TARGET=:clang
ARCHS = armv7 arm64
include theos/makefiles/common.mk

TWEAK_NAME = PassTime
PassTime_OBJC_FILES = PassTime.xm
PassTime_FRAMEWORKS = UIKit
PassTime_PRIVATE_FRAMEWORKS = Preferences
PassTime_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

internal-after-install::
	install.exec "killall -9 backboardd"