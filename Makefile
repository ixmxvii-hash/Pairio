# Pairio Makefile
# Build and install Pairio menu bar app

WORKSPACE = Pairio.xcworkspace
SCHEME = Pairio
CONFIGURATION = Release
BUILD_DIR = build
APP_NAME = Pairio.app
INSTALL_DIR = /Applications

.PHONY: all build install uninstall clean help

all: build

build:
	@echo "Building Pairio..."
	@xcodebuild -workspace $(WORKSPACE) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-derivedDataPath $(BUILD_DIR) \
		-destination 'platform=macOS' \
		CODE_SIGN_IDENTITY="-" \
		CODE_SIGNING_ALLOWED=YES \
		build
	@echo "Build complete!"

install: build
	@echo "Installing Pairio to $(INSTALL_DIR)..."
	@rm -rf "$(INSTALL_DIR)/$(APP_NAME)"
	@cp -R "$(BUILD_DIR)/Build/Products/$(CONFIGURATION)/$(APP_NAME)" "$(INSTALL_DIR)/"
	@echo "Pairio installed successfully!"
	@echo ""
	@echo "You can now launch Pairio from Applications or Spotlight."
	@echo "It will appear as a menu bar icon."

uninstall:
	@echo "Uninstalling Pairio..."
	@rm -rf "$(INSTALL_DIR)/$(APP_NAME)"
	@echo "Pairio uninstalled."

clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@xcodebuild -workspace $(WORKSPACE) -scheme $(SCHEME) clean 2>/dev/null || true
	@echo "Clean complete."

help:
	@echo "Pairio Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make build    - Build the app"
	@echo "  make install  - Build and install to /Applications"
	@echo "  make uninstall - Remove from /Applications"
	@echo "  make clean    - Remove build artifacts"
	@echo "  make help     - Show this help"
