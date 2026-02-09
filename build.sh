#!/bin/bash
# build.sh - 构建 iOS 项目

cd "$(dirname "$0")"

echo "🏗️ 构建 MyStoryApp..."
echo "======================"

# 尝试使用系统默认工具链
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

# 检查 Xcode
if [ ! -d "/Applications/Xcode.app" ]; then
    echo "❌ 错误: 未找到 Xcode.app"
    exit 1
fi

echo "✅ 找到 Xcode"

# 尝试构建（用于检查语法错误）
echo ""
echo "🔍 检查项目配置..."

# 列出项目信息
xcodebuild -project MyStoryApp.xcodeproj -list 2>&1

echo ""
echo "📦 尝试编译 Swift 文件..."

# 创建临时目录
mkdir -p build

# 使用 swiftc 检查语法
for file in MyStoryApp/*.swift MyStoryApp/Views/*.swift MyStoryApp/Models/*.swift MyStoryApp/Services/*.swift; do
    if [ -f "$file" ]; then
        echo "  编译: $file"
        swiftc -parse "$file" 2>&1 | grep -E "(error|warning):" | head -3
    fi
done

echo ""
echo "✅ 语法检查完成"
echo ""
echo "💡 提示: 要运行到模拟器，请在 Xcode 中打开项目:"
echo "   open MyStoryApp.xcodeproj"
