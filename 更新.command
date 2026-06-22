#!/bin/bash
cd "$(dirname "$0")"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build && \
cp .build/debug/耗材管家 耗材管家.app/Contents/MacOS/ && \
open 耗材管家.app
echo "更新完成！"
