#!/bin/bash
set -e

APP="Latensee.app"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
swiftc main.swift -target arm64-apple-macos13.0 -O -o "$APP/Contents/MacOS/Latensee"
codesign --force --deep --sign - "$APP"
echo "Built $APP"
