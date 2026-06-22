#!/bin/bash
cd "$(dirname "$0")"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build && \
rm -rf 创客管家V2.app && \
ditto 耗材管家.app 创客管家V2.app && \
cp .build/debug/耗材管家 创客管家V2.app/Contents/MacOS/ && \
plutil -replace CFBundleDisplayName -string "创客管家V2" 创客管家V2.app/Contents/Info.plist && \
plutil -replace CFBundleName -string "创客管家V2" 创客管家V2.app/Contents/Info.plist && \
plutil -replace CFBundleIdentifier -string "com.jamie.creativesteward.v2" 创客管家V2.app/Contents/Info.plist && \
plutil -replace CFBundleExecutable -string "耗材管家" 创客管家V2.app/Contents/Info.plist && \
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f 创客管家V2.app && \
open 创客管家V2.app
echo "更新完成！"
