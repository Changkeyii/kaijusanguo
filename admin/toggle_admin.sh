#!/bin/bash
# ============================================================================
# 管理员模式切换脚本
# 用法:
#   ./admin/toggle_admin.sh on    # 启用管理员模式（复制admin代码到scripts/，设IS_ADMIN_BUILD=true）
#   ./admin/toggle_admin.sh off   # 关闭管理员模式（删除scripts/admin/，设IS_ADMIN_BUILD=false）
#   ./admin/toggle_admin.sh       # 无参数时显示当前状态
# ============================================================================

WORKSPACE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ADMIN_SRC="$WORKSPACE_DIR/admin"
ADMIN_DST="$WORKSPACE_DIR/scripts/admin"
MAIN_LUA="$WORKSPACE_DIR/scripts/main.lua"

show_status() {
    if [ -d "$ADMIN_DST" ]; then
        echo "[STATUS] scripts/admin/ 目录存在"
    else
        echo "[STATUS] scripts/admin/ 目录不存在"
    fi
    local flag=$(grep "^IS_ADMIN_BUILD" "$MAIN_LUA" 2>/dev/null | head -1)
    echo "[STATUS] main.lua: $flag"
}

enable_admin() {
    echo "=== 启用管理员模式 ==="

    # 1. 复制管理员代码到 scripts/admin/
    mkdir -p "$ADMIN_DST"
    cp "$ADMIN_SRC"/admin_mail_ui.lua "$ADMIN_DST/"
    cp "$ADMIN_SRC"/admin_mail_input.lua "$ADMIN_DST/"
    cp "$ADMIN_SRC"/admin_mail_keyboard.lua "$ADMIN_DST/"
    echo "[OK] 已复制管理员代码到 scripts/admin/"

    # 2. 设置 IS_ADMIN_BUILD = true
    sed -i 's/^IS_ADMIN_BUILD = false/IS_ADMIN_BUILD = true/' "$MAIN_LUA"
    echo "[OK] 已设置 IS_ADMIN_BUILD = true"

    echo ""
    echo "管理员模式已启用。请运行构建命令来生效。"
}

disable_admin() {
    echo "=== 关闭管理员模式 ==="

    # 1. 删除 scripts/admin/ 目录
    if [ -d "$ADMIN_DST" ]; then
        rm -rf "$ADMIN_DST"
        echo "[OK] 已删除 scripts/admin/"
    else
        echo "[SKIP] scripts/admin/ 不存在"
    fi

    # 2. 设置 IS_ADMIN_BUILD = false
    sed -i 's/^IS_ADMIN_BUILD = true/IS_ADMIN_BUILD = false/' "$MAIN_LUA"
    echo "[OK] 已设置 IS_ADMIN_BUILD = false"

    echo ""
    echo "管理员模式已关闭。请运行构建命令来生效。"
}

case "${1}" in
    on|enable|1)
        enable_admin
        ;;
    off|disable|0)
        disable_admin
        ;;
    status)
        show_status
        ;;
    *)
        echo "三国武灵传 - 管理员模式切换"
        echo ""
        show_status
        echo ""
        echo "用法:"
        echo "  $0 on     启用管理员模式"
        echo "  $0 off    关闭管理员模式"
        echo "  $0 status 查看当前状态"
        ;;
esac
