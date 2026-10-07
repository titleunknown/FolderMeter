#!/bin/sh
# Run by the widget target's "Sync Version with App" build phase.
#
# Copies the FolderMeter app target's Version and Build (as set in its General
# tab) into the widget's built Info.plist, so bumping the app is all it takes —
# macOS expects an extension's version to match its containing app.

set -eu

PBX="$PROJECT_FILE_PATH/project.pbxproj"
APP_TARGET=236237122F66730100B702E5 # the FolderMeter app target

read_setting() { plutil -extract "objects.$1" raw -o - "$PBX" 2>/dev/null; }

LIST=$(read_setting "$APP_TARGET.buildConfigurationList")
VERSION=""
BUILD=""
i=0
while CONFIG=$(read_setting "$LIST.buildConfigurations.$i"); do
    if [ "$(read_setting "$CONFIG.name")" = "$CONFIGURATION" ]; then
        VERSION=$(read_setting "$CONFIG.buildSettings.MARKETING_VERSION" || true)
        BUILD=$(read_setting "$CONFIG.buildSettings.CURRENT_PROJECT_VERSION" || true)
        break
    fi
    i=$((i + 1))
done

if [ -z "$VERSION" ] || [ -z "$BUILD" ]; then
    echo "error: Couldn't read FolderMeter's Version/Build for the $CONFIGURATION configuration."
    exit 1
fi

PLIST="$TARGET_BUILD_DIR/$INFOPLIST_PATH"
set_key() {
    /usr/libexec/PlistBuddy -c "Set :$1 $2" "$PLIST" 2>/dev/null ||
        /usr/libexec/PlistBuddy -c "Add :$1 string $2" "$PLIST"
}
set_key CFBundleShortVersionString "$VERSION"
set_key CFBundleVersion "$BUILD"
echo "Widget version set to $VERSION ($BUILD)"
