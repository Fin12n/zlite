# =============================================================================
# ctdozlite iOS / iPadOS / iPhone Duo Build System (100% Pure Native Objective-C)
# Minimum iOS 12.0+ — Supports iPhone, iPad Split-View, and iPhone Duo (iPhone19,4)
# Self-contained inside ./ios/ — zero modifications to desktop workspace files
# =============================================================================

APP_NAME       := ctdozlite
VERSION        := 0.0.5
MIN_IOS        := 12.0
BUNDLE_ID      := net.ctdo.ctdozlite.ios

IOS_SDK        := $(shell xcrun --sdk iphoneos --show-sdk-path)
SIM_SDK        := $(shell xcrun --sdk iphonesimulator --show-sdk-path)
CLANG_IOS      := $(shell xcrun --sdk iphoneos --find clang)
CLANG_SIM      := $(shell xcrun --sdk iphonesimulator --find clang)
IBTOOL         := $(shell xcrun --find ibtool)

BUILD_DIR      := build
DEVICE_APP     := $(BUILD_DIR)/device/$(APP_NAME).app
SIM_APP        := $(BUILD_DIR)/sim/$(APP_NAME).app
IPA_OUT        := $(BUILD_DIR)/$(APP_NAME)-$(VERSION)-ios$(MIN_IOS)-universal.ipa

OBJC_SOURCES   := App/main.m App/CTDOBridge.m App/CTDOMainViewController.m
OBJC_HEADERS   := App/CTDOBridge.h App/CTDOMainViewController.h

COMMON_FLAGS   := -fobjc-arc -O2 -Wall -Wextra -Wno-unused-parameter
FRAMEWORKS     := -framework UIKit -framework Foundation -framework CoreGraphics \
                  -framework QuartzCore -framework CoreImage -framework Security

.PHONY: all device sim ipa test clean

all: device sim ipa

device: $(OBJC_SOURCES) $(OBJC_HEADERS) App/Info.plist App/LaunchScreen.storyboard
	@echo "=== [1/3] Compiling Pure Objective-C iOS Device Bundle (arm64, min iOS $(MIN_IOS)) ==="
	@mkdir -p "$(DEVICE_APP)"
	"$(CLANG_IOS)" -arch arm64 -isysroot "$(IOS_SDK)" \
		-mios-version-min=$(MIN_IOS) \
		$(COMMON_FLAGS) $(OBJC_SOURCES) $(FRAMEWORKS) \
		-o "$(DEVICE_APP)/$(APP_NAME)"
	@cp App/Info.plist "$(DEVICE_APP)/Info.plist"
	@printf "APPL????" > "$(DEVICE_APP)/PkgInfo"
	"$(IBTOOL)" --compile "$(DEVICE_APP)/LaunchScreen.storyboardc" \
		--minimum-deployment-target $(MIN_IOS) App/LaunchScreen.storyboard
	@python3 generate_icons.py "$(DEVICE_APP)"
	@codesign --force --sign - --timestamp=none "$(DEVICE_APP)"
	@echo "✅ Device bundle ready: $(DEVICE_APP)"

sim: $(OBJC_SOURCES) $(OBJC_HEADERS) App/Info.plist App/LaunchScreen.storyboard
	@echo "=== [2/3] Compiling Pure Objective-C iOS Simulator Bundle (arm64-sim, min iOS $(MIN_IOS)) ==="
	@mkdir -p "$(SIM_APP)"
	"$(CLANG_SIM)" -arch arm64 -isysroot "$(SIM_SDK)" \
		-miphonesimulator-version-min=$(MIN_IOS) \
		$(COMMON_FLAGS) $(OBJC_SOURCES) $(FRAMEWORKS) \
		-o "$(SIM_APP)/$(APP_NAME)"
	@cp App/Info.plist "$(SIM_APP)/Info.plist"
	@printf "APPL????" > "$(SIM_APP)/PkgInfo"
	"$(IBTOOL)" --compile "$(SIM_APP)/LaunchScreen.storyboardc" \
		--minimum-deployment-target $(MIN_IOS) App/LaunchScreen.storyboard
	@python3 generate_icons.py "$(SIM_APP)"
	@codesign --force --sign - --timestamp=none "$(SIM_APP)"
	@echo "✅ Simulator bundle ready: $(SIM_APP)"

ipa: device
	@echo "=== [3/3] Packaging Unsigned/Ad-Hoc .ipa Installer ($(IPA_OUT)) ==="
	@rm -rf "$(BUILD_DIR)/Payload" "$(IPA_OUT)"
	@mkdir -p "$(BUILD_DIR)/Payload"
	@cp -R "$(DEVICE_APP)" "$(BUILD_DIR)/Payload/$(APP_NAME).app"
	@cd "$(BUILD_DIR)" && zip -qry "$(notdir $(IPA_OUT))" Payload
	@rm -rf "$(BUILD_DIR)/Payload"
	@ls -lh "$(IPA_OUT)"

test: all
	@echo "=== [TEST 1/2] Verifying Mach-O Minimum OS Version == $(MIN_IOS) ==="
	@otool -l "$(DEVICE_APP)/$(APP_NAME)" | grep -A 4 "LC_BUILD_VERSION"
	@otool -l "$(DEVICE_APP)/$(APP_NAME)" | grep -A 4 "LC_BUILD_VERSION" | grep -q "minos 12.0"
	@echo "✅ Verified LC_BUILD_VERSION minos == 12.0 on arm64 device binary"
	@echo "=== [TEST 2/2] Running Pure Objective-C & Live Zalo QR Self-Test on iPhone Duo Simulator ==="
	@xcrun simctl spawn "B1F272E0-C6BD-480E-A941-CD25127135B7" "$(abspath $(SIM_APP)/$(APP_NAME))" --self-test

clean:
	rm -rf "$(BUILD_DIR)"
