#!/bin/bash
cd "$(dirname "$0")"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build && \
mkdir -p 创客管家V2.app/Contents/MacOS && \
cp .build/debug/耗材管家 创客管家V2.app/Contents/MacOS/ && \
open 创客管家V2.app
echo "更新完成！"
