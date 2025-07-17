TARGET := iphone:clang:16.5:14.0
INSTALL_TARGET_PROCESSES = MuffinStore
ARCHS = arm64
PACKAGE_VERSION = $(THEOS_PACKAGE_BASE_VERSION)
PACKAGE_FORMAT = ipa

GO_EASY_ON_ME = 1

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = MuffinStore
TOOL_NAME = muffinhelper

MuffinStore_FILES = main.m StoreKitDownloader.m TSUtil.m
MuffinStore_SWIFT_FILES = $(shell find . -name "*.swift")
MuffinStore_FRAMEWORKS = UIKit CoreGraphics CoreServices
MuffinStore_PRIVATE_FRAMEWORKS = StoreKitUI
MuffinStore_CFLAGS = -fobjc-arc
MuffinStore_SWIFTFLAGS = -swift-version 5 -import-objc-header MuffinStore-Bridging-Header.h
MuffinStore_CODESIGN_FLAGS = -Sentitlements.plist

muffinhelper_FILES = RootHelper/main.m
muffinhelper_CFLAGS = -fobjc-arc
muffinhelper_CODESIGN_FLAGS = -SRootHelper/entitlements.plist
muffinhelper_INSTALL_PATH = /Applications/MuffinStore.app

include $(THEOS_MAKE_PATH)/application.mk
include $(THEOS_MAKE_PATH)/tool.mk

after-package::
	@echo "Converting .ipa to .tipa..."
	@cd packages && \
	for ipa_file in *.ipa; do \
		if [ -f "$$ipa_file" ]; then \
			tipa_file="$${ipa_file%.ipa}.tipa"; \
			mv "$$ipa_file" "$$tipa_file"; \
			echo "Created: $$tipa_file"; \
		fi; \
	done
