#!/bin/bash
# Swift 语法检查脚本

echo "🔍 检查 Swift 文件语法..."

for file in *.swift Views/*.swift Models/*.swift Services/*.swift; do
    if [ -f "$file" ]; then
        echo "检查: $file"
        swift -typecheck "$file" 2>&1 | head -5
        if [ $? -eq 0 ]; then
            echo "  ✅ 语法正确"
        else
            echo "  ❌ 有语法错误"
        fi
    fi
done
