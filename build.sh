#!/bin/bash
set -e

APP="Latensee.app"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"
swiftc main.swift -o "$APP/Contents/MacOS/Latensee"
echo "Built $APP"
