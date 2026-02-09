#!/bin/bash
# setup.sh - 项目初始化脚本

echo "🎬 我的故事 App - 项目初始化"
echo "=============================="

# 检查 Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ 错误: 未找到 Xcode，请先安装 Xcode"
    exit 1
fi

echo "✅ 找到 Xcode"

# 检查项目文件
if [ ! -d "MyStoryApp.xcodeproj" ]; then
    echo "⚠️ 警告: 未找到 Xcode 项目文件"
    echo "请在 Xcode 中创建新项目或使用现有项目"
fi

# 检查 Swift 版本
SWIFT_VERSION=$(swift --version | head -n 1)
echo "✅ Swift 版本: $SWIFT_VERSION"

# 创建必要的目录
echo "📁 检查项目结构..."

mkdir -p MyStoryApp/{Views,Models,Services,Utils}
mkdir -p MyStoryApp/Assets.xcassets/{AppIcon.appiconset,AccentColor.colorset}
mkdir -p MyStoryApp/Preview\ Content

echo "✅ 目录结构检查完成"

# 提示配置 API Key
echo ""
echo "⚙️ 下一步配置:"
echo "1. 打开 MyStoryApp/Services/VideoGenerationService.swift"
echo "2. 替换 YOUR_KLING_API_KEY 为你的实际 API Key"
echo "3. 或在应用设置页面配置 API Key"
echo ""
echo "📖 详细配置请参考 API_SETUP.md"
echo ""

# 打开项目（可选）
read -p "是否在 Xcode 中打开项目? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open MyStoryApp.xcodeproj
fi

echo ""
echo "🚀 准备就绪！开始创作你的故事吧！"
