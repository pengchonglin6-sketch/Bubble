#!/bin/bash

# Bubble 一键安装器
# - 如果同目录已有 Bubble.app：直接安装，不需要 Xcode
# - 如果只有源码：先用 Xcode 编译，再安装

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_PATH="$SCRIPT_DIR/Bubble/Bubble.xcodeproj"
BUILD_DIR="$SCRIPT_DIR/.build/OneClickInstall"
TARGET_APP="/Applications/Bubble.app"
APP_SOURCE=""
XCODEBUILD="/usr/bin/xcodebuild"
ENTITLEMENTS_PATH="$SCRIPT_DIR/Bubble/Bubble/Bubble.entitlements"

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
    echo "安装没有完成：$1"
    pause_before_exit
    exit 1
}

clear
echo "========================================"
echo "          Bubble 一键安装程序"
echo "========================================"
echo

if [ "$(uname -s)" != "Darwin" ]; then
    fail "Bubble 只能安装在 Mac 电脑上。"
fi

MACOS_VERSION="$(sw_vers -productVersion)"
MACOS_MAJOR="${MACOS_VERSION%%.*}"
if [ "$MACOS_MAJOR" -lt 14 ]; then
    fail "当前系统是 macOS $MACOS_VERSION，Bubble 需要 macOS 14 或更高版本。"
fi

# 免开发环境安装包会把 Bubble.app 放在安装器旁边。
if [ -d "$SCRIPT_DIR/Bubble.app" ]; then
    APP_SOURCE="$SCRIPT_DIR/Bubble.app"
elif [ -d "$SCRIPT_DIR/安装包/Bubble.app" ]; then
    APP_SOURCE="$SCRIPT_DIR/安装包/Bubble.app"
fi

if [ -z "$APP_SOURCE" ]; then
    echo "没有在安装器旁边找到 Bubble.app，将从源码编译。"
    echo

    if [ ! -d "$PROJECT_PATH" ]; then
        fail "既没有找到 Bubble.app，也没有找到源码项目 Bubble/Bubble.xcodeproj。请使用完整的安装包。"
    fi

    if ! "$XCODEBUILD" -version >/dev/null 2>&1; then
        fail "这份文件只有源码，当前电脑没有完整 Xcode。请安装 Xcode，或者在另一台装有 Xcode 的 Mac 上运行“一键制作免开发环境安装包.command”。"
    fi

    echo "正在用 Xcode 编译 Bubble，第一次执行时可能需要下载依赖……"
    echo

    if ! "$XCODEBUILD" \
        -project "$PROJECT_PATH" \
        -scheme Bubble \
        -configuration Release \
        -destination "platform=macOS" \
        -derivedDataPath "$BUILD_DIR" \
        CODE_SIGNING_ALLOWED=NO \
        ONLY_ACTIVE_ARCH=NO \
        build; then
        fail "Xcode 编译失败。请查看上面的红色错误信息。"
    fi

    APP_SOURCE="$BUILD_DIR/Build/Products/Release/Bubble.app"
    if [ ! -d "$APP_SOURCE" ]; then
        fail "编译已经结束，但没有找到生成的 Bubble.app。"
    fi

    echo "正在为本地应用添加临时签名……"
    if ! /usr/bin/codesign \
        --force \
        --deep \
        --options runtime \
        --timestamp=none \
        --sign - \
        --entitlements "$ENTITLEMENTS_PATH" \
        "$APP_SOURCE"; then
        fail "应用签名失败。"
    fi
fi

if ! /usr/bin/codesign --verify --deep --strict "$APP_SOURCE"; then
    fail "Bubble.app 的签名校验没有通过，请重新制作安装包。"
fi

echo
echo "即将把 Bubble 安装到："
echo "$TARGET_APP"
echo

# 先让旧版本退出，更新安装时避免文件正在使用。
/usr/bin/pkill -x Bubble >/dev/null 2>&1 || true

if [ -w "/Applications" ]; then
    /bin/rm -rf "$TARGET_APP"
    /usr/bin/ditto "$APP_SOURCE" "$TARGET_APP" || fail "复制应用时发生错误。"
    /usr/bin/xattr -dr com.apple.quarantine "$TARGET_APP" >/dev/null 2>&1 || true
else
    echo "系统将询问管理员密码，用于写入“应用程序”文件夹。"
    if ! /usr/bin/osascript - "$APP_SOURCE" "$TARGET_APP" <<'APPLESCRIPT'
on run argv
    set sourcePath to item 1 of argv
    set targetPath to item 2 of argv
    set installCommand to "/bin/rm -rf " & quoted form of targetPath & " && /usr/bin/ditto " & quoted form of sourcePath & " " & quoted form of targetPath & " && /usr/bin/xattr -dr com.apple.quarantine " & quoted form of targetPath
    do shell script installCommand with administrator privileges
end run
APPLESCRIPT
    then
        fail "没有获得管理员授权，或者复制应用时发生错误。"
    fi
fi

if [ ! -d "$TARGET_APP" ]; then
    fail "安装后没有在“应用程序”文件夹中找到 Bubble。"
fi

echo "正在启动 Bubble……"
/usr/bin/open "$TARGET_APP"

echo
echo "========================================"
echo "              安装成功"
echo "========================================"
echo
echo "Bubble 已经放入“应用程序”文件夹并启动。"
echo "如果全局快捷键没有反应，请打开："
echo "系统设置 → 隐私与安全性 → 辅助功能 → 开启 Bubble"

pause_before_exit
