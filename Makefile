# Define a directory for dependencies in the user's home folder
DEPS_DIR := $(HOME)/Notext-Dependencies
WHISPER_CPP_DIR := $(DEPS_DIR)/whisper.cpp
FRAMEWORK_PATH := $(WHISPER_CPP_DIR)/build-apple/whisper.xcframework
LOCAL_DERIVED_DATA := $(CURDIR)/.local-build

.PHONY: all clean whisper setup build local check healthcheck help dev run release dist

# Default target
all: check build

# Development workflow
dev: build run

# Prerequisites
check:
	@echo "Checking prerequisites..."
	@command -v git >/dev/null 2>&1 || { echo "git is not installed"; exit 1; }
	@command -v xcodebuild >/dev/null 2>&1 || { echo "xcodebuild is not installed (need Xcode)"; exit 1; }
	@command -v swift >/dev/null 2>&1 || { echo "swift is not installed"; exit 1; }
	@echo "Prerequisites OK"

healthcheck: check

# Build process
whisper:
	@mkdir -p $(DEPS_DIR)
	@if [ ! -d "$(FRAMEWORK_PATH)" ]; then \
		echo "Building whisper.xcframework in $(DEPS_DIR)..."; \
		if [ ! -d "$(WHISPER_CPP_DIR)" ]; then \
			git clone https://github.com/ggerganov/whisper.cpp.git $(WHISPER_CPP_DIR); \
		else \
			(cd $(WHISPER_CPP_DIR) && git pull); \
		fi; \
		cd $(WHISPER_CPP_DIR) && ./build-xcframework.sh; \
	else \
		echo "whisper.xcframework already built in $(DEPS_DIR), skipping build"; \
	fi

setup: whisper
	@echo "Whisper framework is ready at $(FRAMEWORK_PATH)"
	@echo "Please ensure your Xcode project references the framework from this new location."

build: setup
	xcodebuild -project Notext.xcodeproj -scheme Notext -configuration Debug CODE_SIGN_IDENTITY="" build

# Build for local use without Apple Developer certificate
local: check setup
	@echo "Building Notext for local use (no Apple Developer certificate required)..."
	@rm -rf "$(LOCAL_DERIVED_DATA)"
	xcodebuild -project Notext.xcodeproj -scheme Notext -configuration Debug \
		-derivedDataPath "$(LOCAL_DERIVED_DATA)" \
		-xcconfig LocalBuild.xcconfig \
		CODE_SIGN_IDENTITY="-" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=YES \
		DEVELOPMENT_TEAM="" \
		CODE_SIGN_ENTITLEMENTS=$(CURDIR)/Notext/Notext.entitlements \
		SWIFT_ACTIVE_COMPILATION_CONDITIONS='$$(inherited) LOCAL_BUILD' \
		build
	@APP_PATH="$(LOCAL_DERIVED_DATA)/Build/Products/Debug/Notext.app" && \
	if [ -d "$$APP_PATH" ]; then \
		echo "Copying Notext.app to ~/Downloads..."; \
		rm -rf "$$HOME/Downloads/Notext.app"; \
		ditto "$$APP_PATH" "$$HOME/Downloads/Notext.app"; \
		xattr -cr "$$HOME/Downloads/Notext.app"; \
		echo ""; \
		echo "Build complete! App saved to: ~/Downloads/Notext.app"; \
		echo "Run with: open ~/Downloads/Notext.app"; \
		echo ""; \
		echo "Limitations of local builds:"; \
		echo "  - No iCloud dictionary sync"; \
		echo "  - No automatic updates (pull new code and rebuild to update)"; \
	else \
		echo "Error: Could not find built Notext.app at $$APP_PATH"; \
		exit 1; \
	fi

# Build and package for distribution (pre-compiled app for users)
release: check setup
	@echo "📦 Building Notext for distribution..."
	@rm -rf "$(LOCAL_DERIVED_DATA)"
	xcodebuild -project Notext.xcodeproj -scheme Notext -configuration Release \
		-derivedDataPath "$(LOCAL_DERIVED_DATA)" \
		-xcconfig LocalBuild.xcconfig \
		CODE_SIGN_IDENTITY="-" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=YES \
		DEVELOPMENT_TEAM="" \
		CODE_SIGN_ENTITLEMENTS=$(CURDIR)/Notext/Notext.entitlements \
		SWIFT_ACTIVE_COMPILATION_CONDITIONS='$$(inherited) LOCAL_BUILD' \
		build
	@APP_PATH="$(LOCAL_DERIVED_DATA)/Build/Products/Release/Notext.app" && \
	if [ -d "$$APP_PATH" ]; then \
		VERSION=$$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$$APP_PATH/Contents/Info.plist"); \
		BUILD=$$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$$APP_PATH/Contents/Info.plist"); \
		echo ""; \
		echo "✅ Build complete: Notext v$$VERSION ($$BUILD)"; \
		echo ""; \
		echo "📁 App location: $$APP_PATH"; \
		echo ""; \
		echo "📦 Creating distribution packages..."; \
		OUTPUT_DIR="$(CURDIR)/dist"; \
		mkdir -p "$$OUTPUT_DIR"; \
		ZIP_PATH="$$OUTPUT_DIR/Notext.zip"; \
		rm -f "$$ZIP_PATH"; \
		ditto -c -k --keepParent "$$APP_PATH" "$$ZIP_PATH"; \
		echo "✅ ZIP created: $$ZIP_PATH"; \
		xattr -cr "$$APP_PATH"; \
		echo ""; \
		echo "🎨 Creating custom installation DMG..."; \
		$(CURDIR)/create_dmg.sh; \
		echo ""; \
		echo "🎉 Distribution packages ready!"; \
		echo ""; \
		echo "📂 Files in $$OUTPUT_DIR:"; \
		ls -lh "$$OUTPUT_DIR"; \
		echo ""; \
		echo "📤 For GitHub Release:"; \
		echo "   gh release create v$$VERSION --title \"Notext v$$VERSION\" --generate-notes"; \
		echo "   gh release upload v$$VERSION $$ZIP_PATH $$OUTPUT_DIR/Notext_Install.dmg"; \
		echo ""; \
		echo "👤 Users can now:"; \
		echo "   - Download Notext.zip or Notext_Install.dmg from GitHub Releases"; \
		echo "   - Drag Notext.app to their Applications folder"; \
		echo "   - Open the app (first time: System Settings > Privacy & Security > Open Anyway)"; \
		echo ""; \
	else \
		echo "❌ Error: Could not find built Notext.app at $$APP_PATH"; \
		exit 1; \
	fi

# Alias for release
dist: release

# Run application
run:
	@if [ -d "$$HOME/Downloads/Notext.app" ]; then \
		echo "Opening ~/Downloads/Notext.app..."; \
		open "$$HOME/Downloads/Notext.app"; \
	else \
		echo "Looking for Notext.app in DerivedData..."; \
		APP_PATH=$$(find "$$HOME/Library/Developer/Xcode/DerivedData" -name "Notext.app" -type d | head -1) && \
		if [ -n "$$APP_PATH" ]; then \
			echo "Found app at: $$APP_PATH"; \
			open "$$APP_PATH"; \
		else \
			echo "Notext.app not found. Please run 'make build' or 'make local' first."; \
			exit 1; \
		fi; \
	fi

# Cleanup
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(DEPS_DIR)
	@echo "Clean complete"

# Help
help:
	@echo "Available targets:"
	@echo "  check/healthcheck  Check if required CLI tools are installed"
	@echo "  whisper            Clone and build whisper.cpp XCFramework"
	@echo "  setup              Copy whisper XCFramework to VoiceInk project"
	@echo "  build              Build the VoiceInk Xcode project"
	@echo "  local              Build for local use (no Apple Developer certificate needed)"
	@echo "  run                Launch the built VoiceInk app"
	@echo "  dev                Build and run the app (for development)"
	@echo "  release/dist       Build and package for distribution (ZIP + DMG)"
	@echo "  publish            Sign and publish update via Sparkle"
	@echo "  all                Run full build process (default)"
	@echo "  clean              Remove build artifacts"
	@echo "  help               Show this help message"