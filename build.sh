#!/bin/bash
set -e

APP="Latensee.app"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
swiftc main.swift -O -o "$APP/Contents/MacOS/Latensee"
echo "Built $APP"
