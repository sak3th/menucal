.PHONY: all build app dmg clean

APP_NAME := MenuCal
BUILD_DIR := build
DIST_DIR := dist
CONFIGURATION := Release

all: dmg

build:
	xcodebuild -project $(APP_NAME).xcodeproj \
		-scheme $(APP_NAME) \
		-configuration $(CONFIGURATION) \
		CONFIGURATION_BUILD_DIR=$(CURDIR)/$(BUILD_DIR) \
		build

app: build
	@echo "Assembling $(APP_NAME).app..."
	rm -rf $(DIST_DIR)/$(APP_NAME).app
	mkdir -p $(DIST_DIR)
	cp -R $(BUILD_DIR)/$(APP_NAME).app $(DIST_DIR)/$(APP_NAME).app
	@# Keep xcodebuild's Apple Development signature — a stable signing identity
	@# is required for TCC (Calendar/Reminders) grants to persist. Re-signing
	@# ad-hoc here ("--sign -") breaks permissions, so we only verify instead.
	codesign --verify --strict $(DIST_DIR)/$(APP_NAME).app && echo "signature OK"
	@echo "Done: $(DIST_DIR)/$(APP_NAME).app"

dmg: app
	@echo "Creating DMG..."
	rm -rf $(DIST_DIR)/dmg-stage
	mkdir -p $(DIST_DIR)/dmg-stage
	cp -R $(DIST_DIR)/$(APP_NAME).app $(DIST_DIR)/dmg-stage/
	ln -s /Applications $(DIST_DIR)/dmg-stage/Applications
	hdiutil create -volname $(APP_NAME) -srcfolder $(DIST_DIR)/dmg-stage -ov -format UDZO $(DIST_DIR)/$(APP_NAME).dmg
	rm -rf $(DIST_DIR)/dmg-stage
	@echo "Done: $(DIST_DIR)/$(APP_NAME).dmg"

clean:
	rm -rf $(BUILD_DIR) $(DIST_DIR)
	xcodebuild -project $(APP_NAME).xcodeproj -scheme $(APP_NAME) clean 2>/dev/null || true
