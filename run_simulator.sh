#!/bin/bash
# 在本地运行 iOS 模拟器的脚本

# 1. 确保使用正确的 Xcode
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

# 2. 打开 Xcode 项目
echo "正在打开 Xcode 项目..."
open MyStoryApp.xcodeproj

# 3. 等待 Xcode 启动
echo "等待 Xcode 启动..."
sleep 5

# 4. 使用 xcodebuild 构建并运行到模拟器
echo "构建并运行到 iPhone 15 Pro 模拟器..."
xcodebuild \
    -project MyStoryApp.xcodeproj \
    -scheme MyStoryApp \
    -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
    -derivedDataPath build \
    build

echo ""
echo "✅ 如果构建成功，模拟器会自动启动"
echo "📸 你可以在 Xcode 中手动截图（Cmd+S）"
echo ""
