#!/bin/bash

# 在装有完整 Xcode 的 Mac 上生成可复制给普通用户的 ZIP 安装包。

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_PATH="$SCRIPT_DIR/Bubble/Bubble.xcodeproj"
ENTITLEMENTS_PATH="$SCRIPT_DIR/Bubble/Bubble/Bubble.entitlements"
BUILD_DIR="$SCRIPT_DIR/.build/Distribution"
DIST_DIR="$SCRIPT_DIR/dist"
PACKAGE_NAME="Bubble-安装包"
PACKAGE_DIR="$DIST_DIR/$PACKAGE_NAME"
ZIP_PATH="$DIST_DIR/$PACKAGE_NAME.zip"
BUILT_APP="$BUILD_DIR/Build/Products/Release/Bubble.app"
XCODEBUILD="/usr/bin/xcodebuild"

if [ -x "/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild" ]; then
    XCODEBUILD="/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild"
fi

pause_before_exit() {
    echo
    if [ -t 0 ]; then
        read -r -p "按回车键关闭这个窗口……" _
    fi
}

fail() {
    echo
    echo "制作没有完成：$1"
    pause_before_exit
    exit 1
}

clear
echo "========================================"
echo "      Bubble 免开发环境安装包制作工具"
echo "========================================"
echo

if [ "$(uname -s)" != "Darwin" ]; then
    fail "安装包只能在 Mac 电脑上制作。"
fi

if [ ! -d "$PROJECT_PATH" ]; then
    fail "没有找到 Bubble/Bubble.xcodeproj，请把这个文件放在项目根目录运行。"
fi

if ! "$XCODEBUILD" -version >/dev/null 2>&1; then
    fail "没有检测到完整 Xcode。请先从 App Store 安装 Xcode，并至少打开一次完成初始化。"
fi

echo "正在编译同时支持 Apple 芯片和 Intel 芯片的 Release 版本……"
echo "第一次执行时，Xcode 可能需要联网下载 HotKey 依赖。"
echo

if ! "$XCODEBUILD" \
    -project "$PROJECT_PATH" \
    -scheme Bubble \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$BUILD_DIR" \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGNING_ALLOWED=NO \
    build; then
    fail "Xcode 编译失败。请查看上面的错误信息。"
fi

if [ ! -d "$BUILT_APP" ]; then
    fail "编译已经结束，但没有找到生成的 Bubble.app。"
fi

echo
echo "正在为应用添加本地临时签名……"
if ! /usr/bin/codesign \
    --force \
    --deep \
    --options runtime \
    --timestamp=none \
    --sign - \
    --entitlements "$ENTITLEMENTS_PATH" \
    "$BUILT_APP"; then
    fail "应用签名失败。"
fi

if ! /usr/bin/codesign --verify --deep --strict "$BUILT_APP"; then
    fail "签名校验没有通过。"
fi

echo "正在整理安装包……"
/bin/rm -rf "$PACKAGE_DIR"
/bin/rm -f "$ZIP_PATH"
/bin/mkdir -p "$PACKAGE_DIR"

/usr/bin/ditto "$BUILT_APP" "$PACKAGE_DIR/Bubble.app" || fail "复制 Bubble.app 失败。"
/bin/cp "$SCRIPT_DIR/一键安装.command" "$PACKAGE_DIR/安装 Bubble.command" || fail "复制安装器失败。"
/bin/cp "$SCRIPT_DIR/给另一台电脑的安装说明.txt" "$PACKAGE_DIR/安装说明.txt" || fail "复制安装说明失败。"
/bin/chmod +x "$PACKAGE_DIR/安装 Bubble.command"

/usr/bin/ditto -c -k --keepParent "$PACKAGE_DIR" "$ZIP_PATH" || fail "压缩 ZIP 文件失败。"

echo
echo "========================================"
echo "            安装包制作成功"
echo "========================================"
echo
echo "生成的文件："
echo "$ZIP_PATH"
echo
echo "把这个 ZIP 复制给另一台 Mac。"
echo "对方解压后，双击“安装 Bubble.command”即可。"
echo "对方不需要 Agent，也不需要 Xcode。"
echo

/usr/bin/open -R "$ZIP_PATH"
pause_before_exit
