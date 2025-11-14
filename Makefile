CONFIG = debug
XCODE_CONFIG = Debug

DERIVED_DATA_PATH = .build/derivedData/$(CONFIG)

PLATFORM_IOS = iOS Simulator,id=$(call udid_for,iPhone 16)
PLATFORM_MACOS = macOS
PLATFORM_MAC_CATALYST = macOS,variant=Mac Catalyst
PLATFORM_VISIONOS = visionOS Simulator,id=$(call udid_for,Apple Vision Pro)

PLATFORM = IOS
DESTINATION = platform="$(PLATFORM_$(PLATFORM))"

SCHEME = swift-debug-todo

ifneq ($(strip $(shell which xcbeautify)),)
    XCBEAUTIFY = | xcbeautify
else
    XCBEAUTIFY =
endif

default: test-swift

# Swift package manager builds
build-swift:
	@echo "Building with Swift Package Manager..."
	@swift build -c $(CONFIG)

test-swift:
	@echo "Testing with Swift Package Manager..."
	@swift test -c $(CONFIG)

# Xcodebuild for specific platform
build-xcode:
	@echo "Building for $(PLATFORM)..."
	@xcodebuild build \
		-scheme $(SCHEME) \
		-configuration $(XCODE_CONFIG) \
		-destination $(DESTINATION) \
		-derivedDataPath $(DERIVED_DATA_PATH) \
		$(XCBEAUTIFY)

test-xcode:
	@echo "Testing on $(PLATFORM)..."
	@xcodebuild test \
		-scheme $(SCHEME) \
		-configuration $(XCODE_CONFIG) \
		-destination $(DESTINATION) \
		-derivedDataPath $(DERIVED_DATA_PATH) \
		$(XCBEAUTIFY)

# Build all platforms
build-all-platforms:
	@echo "Building for all platforms..."
	@$(MAKE) build-swift
	@$(MAKE) build-xcode PLATFORM=MAC_CATALYST || echo "⚠️  Mac Catalyst build failed"
	@$(MAKE) build-xcode PLATFORM=VISIONOS || echo "⚠️  visionOS build failed (simulator may not be installed)"
	@echo "✅ All available platforms built"

# Test all platforms
test-all-platforms:
	@echo "Testing all platforms..."
	@$(MAKE) test-swift
	@$(MAKE) test-xcode PLATFORM=MAC_CATALYST || echo "⚠️  Mac Catalyst test failed"
	@$(MAKE) test-xcode PLATFORM=VISIONOS || echo "⚠️  visionOS test failed (simulator may not be installed)"
	@echo "✅ All available platform tests completed"

# Individual platform targets
build-ios:
	@$(MAKE) build-xcode PLATFORM=IOS

build-macos:
	@$(MAKE) build-swift

build-maccatalyst:
	@$(MAKE) build-xcode PLATFORM=MAC_CATALYST

build-visionos:
	@$(MAKE) build-xcode PLATFORM=VISIONOS

test-ios:
	@$(MAKE) test-xcode PLATFORM=IOS

test-macos:
	@$(MAKE) test-swift

test-maccatalyst:
	@$(MAKE) test-xcode PLATFORM=MAC_CATALYST

test-visionos:
	@$(MAKE) test-xcode PLATFORM=VISIONOS

# Utility targets
clean:
	@swift package clean
	@rm -rf .build

format:
	@find . \
		-name '*.swift' \
		-not -path '*/.*' \
		-not -path '*/.build/*' \
		-print0 \
		| xargs -0 swift format --ignore-unparsable-files --in-place --recursive || true

.PHONY: build-swift test-swift build-xcode test-xcode \
	build-all-platforms test-all-platforms \
	build-ios build-macos build-maccatalyst build-visionos \
	test-ios test-macos test-maccatalyst test-visionos \
	clean format

define udid_for
$(shell xcrun simctl list --json devices available | jq -r '.devices | to_entries[] | .value[] | select(.name == "$(1)") | .udid' | head -n 1)
endef
