#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# FINALPACKAGE=1 / DEBUG=0 的最终链接产物；不选择中间架构文件或历史包。
binary='.theos/obj/DYPlus.dylib'
test -s "$binary"
mkdir -p dist
cp "$binary" dist/DYPlus.dylib

# 使用上游的 internal Logos 生成器；发现越狱路径或外部库依赖即停止交付。
xcrun lipo -verify_arch arm64 dist/DYPlus.dylib
xcrun otool -L dist/DYPlus.dylib | tee dist/dependencies.txt
while IFS= read -r dependency; do
    case "$dependency" in
        /System/Library/*|/usr/lib/*) ;;
        *) printf '不支持的外部依赖：%s\n' "$dependency" >&2; exit 1 ;;
    esac
done < <(xcrun otool -L dist/DYPlus.dylib | awk 'NR > 2 {print $1}')

ldid -S dist/DYPlus.dylib
file dist/DYPlus.dylib > dist/binary-info.txt
xcrun otool -l dist/DYPlus.dylib >> dist/binary-info.txt
git rev-parse HEAD > dist/source-commit.txt
git -C "$THEOS" rev-parse HEAD > dist/theos-commit.txt
cp LICENSE dist/LICENSE
cp INJECTION.md dist/使用说明.md
(cd dist && shasum -a 256 DYPlus.dylib > SHA256SUMS.txt)
