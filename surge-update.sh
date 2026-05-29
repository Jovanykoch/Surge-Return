#!/bin/bash

# ============================================================
# Surge 规则自动更新脚本
# 功能: 定时更新 Surge-Return 规则，保持配置最新
# 支持系统: Ubuntu 22.04/24.04, Debian 12
# 作者: Jovanykoch
# 最后更新: 2026-05-29
# ============================================================

set -e

# 配置项
REPO_OWNER="Jovanykoch"
REPO_NAME="Surge-Return"
GITHUB_PAGES_URL="https://jkoch14.me/Surge-Return"
LOCAL_CONFIG_DIR="/etc/surge-return"
LOG_FILE="/var/log/surge-update.log"
LOCK_FILE="/tmp/surge-update.lock"
UPDATE_INTERVAL=21600  # 6小时（秒数）

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================
# 日志函数
# ============================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# ============================================================
# 检查依赖
# ============================================================

check_dependencies() {
    log_info "检查依赖..."
    
    local missing_deps=()
    
    # 检查必需工具
    command -v curl >/dev/null 2>&1 || missing_deps+=("curl")
    command -v wget >/dev/null 2>&1 || missing_deps+=("wget")
    command -v openssl >/dev/null 2>&1 || missing_deps+=("openssl")
    
    if [ ${#missing_deps[@]} -eq 2 ]; then
        log_error "需要 curl 或 wget，请先安装: sudo apt install curl wget"
        exit 1
    fi
    
    log_success "依赖检查完成"
}

# ============================================================
# 初始化目录和日志
# ============================================================

init_environment() {
    log_info "初始化环境..."
    
    # 创建配置目录
    if [ ! -d "$LOCAL_CONFIG_DIR" ]; then
        sudo mkdir -p "$LOCAL_CONFIG_DIR"
        sudo chmod 755 "$LOCAL_CONFIG_DIR"
        log_info "已创建配置目录: $LOCAL_CONFIG_DIR"
    fi
    
    # 创建日志目录
    log_dir=$(dirname "$LOG_FILE")
    if [ ! -d "$log_dir" ]; then
        sudo mkdir -p "$log_dir"
        sudo touch "$LOG_FILE"
        sudo chmod 644 "$LOG_FILE"
    fi
    
    # 初始化日志文件
    if [ ! -f "$LOG_FILE" ]; then
        sudo touch "$LOG_FILE"
        sudo chmod 666 "$LOG_FILE"
    fi
    
    log_success "环境初始化完成"
}

# ============================================================
# 下载规则文件
# ============================================================

download_ruleset() {
    local file_name=$1
    local file_path="$LOCAL_CONFIG_DIR/$file_name"
    local remote_url="$GITHUB_PAGES_URL/List/non_ip/$file_name"
    
    log_info "下载规则: $file_name"
    
    # 使用临时文件保存
    local temp_file="${file_path}.tmp"
    
    # 尝试下载
    if command -v curl >/dev/null 2>&1; then
        if curl -f -s -L -o "$temp_file" "$remote_url"; then
            sudo mv "$temp_file" "$file_path"
            sudo chmod 644 "$file_path"
            log_success "✓ 已下载: $file_name"
            return 0
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget -q -O "$temp_file" "$remote_url"; then
            sudo mv "$temp_file" "$file_path"
            sudo chmod 644 "$file_path"
            log_success "✓ 已下载: $file_name"
            return 0
        fi
    fi
    
    log_warning "✗ 下载失败: $file_name (网络可能不可达)"
    rm -f "$temp_file"
    return 1
}

# ============================================================
# 下载所有规则
# ============================================================

download_all_rulesets() {
    log_info "开始下载所有规则文件..."
    
    local files=(
        "domestic.conf"
        "reject-drop.conf"
        "reject.conf"
        "reject-no-drop.conf"
        "lan.conf"
        "apple_cn.conf"
        "apple_services.conf"
        "ai.conf"
        "telegram.conf"
        "neteasemusic.conf"
        "stream.conf"
        "microsoft_cdn.conf"
        "microsoft.conf"
        "global.conf"
        "direct.conf"
    )
    
    local success_count=0
    local fail_count=0
    
    for file in "${files[@]}"; do
        if download_ruleset "$file"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
    done
    
    # 下载 IP 规则
    log_info "下载 IP 规则..."
    local ip_files=(
        "domestic.conf:ip"
        "reject.conf:ip"
        "china_ip.conf:ip"
        "telegram.conf:ip"
        "telegram_asn.conf:ip"
        "neteasemusic.conf:ip"
        "stream.conf:ip"
        "lan.conf:ip"
    )
    
    for file_entry in "${ip_files[@]}"; do
        IFS=':' read -r file_name dir <<< "$file_entry"
        local remote_url="$GITHUB_PAGES_URL/List/$dir/$file_name"
        local file_path="$LOCAL_CONFIG_DIR/${dir}_${file_name}"
        local temp_file="${file_path}.tmp"
        
        log_info "下载规则: $dir/$file_name"
        
        if command -v curl >/dev/null 2>&1; then
            if curl -f -s -L -o "$temp_file" "$remote_url"; then
                sudo mv "$temp_file" "$file_path"
                sudo chmod 644 "$file_path"
                log_success "✓ 已下载: $dir/$file_name"
                ((success_count++))
            else
                log_warning "✗ 下载失败: $dir/$file_name"
                ((fail_count++))
            fi
        fi
    done
    
    log_info "下载完成: 成功 $success_count 个, 失败 $fail_count 个"
}

# ============================================================
# 验证规则文件
# ============================================================

verify_rulesets() {
    log_info "验证规则文件..."
    
    local corrupt_files=()
    
    for file in "$LOCAL_CONFIG_DIR"/*.conf; do
        if [ -f "$file" ]; then
            # 检查文件大小
            local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
            if [ "$size" -lt 100 ]; then
                corrupt_files+=("$(basename $file)")
            fi
            
            # 检查文件完整性 (检查是否包含最后一行)
            if ! tail -1 "$file" | grep -q "EOF\|#"; then
                corrupt_files+=("$(basename $file) - 不完整")
            fi
        fi
    done
    
    if [ ${#corrupt_files[@]} -gt 0 ]; then
        log_warning "发现可能损坏的文件: ${corrupt_files[@]}"
        return 1
    else
        log_success "所有规则文件验证通过"
        return 0
    fi
}

# ============================================================
# 计算规则统计
# ============================================================

show_statistics() {
    log_info "规则统计信息:"
    
    for file in "$LOCAL_CONFIG_DIR"/*.conf; do
        if [ -f "$file" ]; then
            local file_name=$(basename "$file")
            local line_count=$(wc -l < "$file")
            local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
            local size_mb=$(echo "scale=2; $size / 1024 / 1024" | bc)
            
            echo "  ├─ $file_name: $line_count 行, $size_mb MB"
        fi
    done
}

# ============================================================
# 防止重复执行
# ============================================================

acquire_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local lock_age=$(($(date +%s) - $(stat -f%m "$LOCK_FILE" 2>/dev/null || stat -c%Y "$LOCK_FILE" 2>/dev/null)))
        if [ "$lock_age" -lt "$UPDATE_INTERVAL" ]; then
            log_warning "更新已在进行中或距离上次更新不足6小时，跳过此次更新"
            return 1
        fi
    fi
    
    touch "$LOCK_FILE"
    return 0
}

release_lock() {
    rm -f "$LOCK_FILE"
}

# ============================================================
# 主更新函数
# ============================================================

update_rulesets() {
    log_info "=========================================="
    log_info "开始更新 Surge-Return 规则"
    log_info "=========================================="
    
    if ! acquire_lock; then
        return 1
    fi
    
    # 检查网络连接
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1 && ! ping -c 1 1.1.1.1 >/dev/null 2>&1; then
        log_error "网络连接失败，更新中止"
        release_lock
        return 1
    fi
    
    # 下载所有规则
    download_all_rulesets
    
    # 验证规则
    if verify_rulesets; then
        log_success "规则验证成功"
        show_statistics
        log_success "规则更新完成！"
    else
        log_warning "规则验证存在问题，但继续进行"
        show_statistics
    fi
    
    release_lock
    log_info "=========================================="
}

# ============================================================
# 定时任务设置
# ============================================================

setup_cron() {
    log_info "设置定时任务..."
    
    local cron_job="0 */6 * * * /usr/local/bin/surge-update.sh >> /var/log/surge-update.log 2>&1"
    local cron_file="/tmp/surge_cron.tmp"
    
    # 检查cron任务是否已存在
    if crontab -l 2>/dev/null | grep -q "surge-update.sh"; then
        log_warning "定时任务已存在，跳过设置"
        return 0
    fi
    
    # 创建新的cron任务
    (crontab -l 2>/dev/null; echo "$cron_job") | crontab - 2>/dev/null
    
    if [ $? -eq 0 ]; then
        log_success "定时任务已设置: 每6小时执行一次"
        echo "  ├─ 时间间隔: 6小时"
        echo "  ├─ 执行脚本: /usr/local/bin/surge-update.sh"
        echo "  ├─ 日志文件: $LOG_FILE"
        echo "  └─ 查看定时任务: crontab -l"
    else
        log_error "定时任务设置失败"
        return 1
    fi
}

# ============================================================
# 显示帮助
# ============================================================

show_help() {
    cat << EOF
${BLUE}Surge-Return 规则自动更新脚本${NC}

${YELLOW}用法:${NC}
    $0 [选项]

${YELLOW}选项:${NC}
    --update            立即更新规则
    --install           安装脚本到系统
    --setup-cron        设置定时任务
    --status            查看更新状态
    --remove            删除定时任务
    --help              显示帮助信息

${YELLOW}示例:${NC}
    sudo $0 --update          # 立即更新所有规则
    sudo $0 --install         # 安装为系统服务
    sudo $0 --setup-cron      # 设置6小时定时更新
    $0 --status               # 查看最后更新时间

${YELLOW}配置文件位置:${NC}
    - 规则文件: $LOCAL_CONFIG_DIR/
    - 日志文件: $LOG_FILE

${YELLOW}更新间隔:${NC}
    - 默认: 6小时
    - 修改: 编辑脚本中的 UPDATE_INTERVAL 变量

EOF
}

# ============================================================
# 安装脚本到系统
# ============================================================

install_script() {
    log_info "安装脚本到系统..."
    
    if [ ! -w /usr/local/bin ]; then
        log_error "需要 sudo 权限来安装脚本"
        return 1
    fi
    
    sudo cp "$0" /usr/local/bin/surge-update.sh
    sudo chmod 755 /usr/local/bin/surge-update.sh
    
    log_success "脚本已安装到: /usr/local/bin/surge-update.sh"
    log_info "后续可直接运行: surge-update.sh --update"
    
    return 0
}

# ============================================================
# 删除定时任务
# ============================================================

remove_cron() {
    log_info "删除定时任务..."
    
    if ! crontab -l 2>/dev/null | grep -q "surge-update.sh"; then
        log_warning "未找到定时任务"
        return 0
    fi
    
    crontab -l 2>/dev/null | grep -v "surge-update.sh" | crontab -
    
    log_success "定时任务已删除"
    return 0
}

# ============================================================
# 显示状态
# ============================================================

show_status() {
    echo -e "${BLUE}Surge-Return 更新状态${NC}\n"
    
    if [ -f "$LOG_FILE" ]; then
        echo "最后更新时间:"
        tail -1 "$LOG_FILE"
        echo ""
    fi
    
    echo "规则文件统计:"
    if [ -d "$LOCAL_CONFIG_DIR" ]; then
        local total_files=$(find "$LOCAL_CONFIG_DIR" -name "*.conf" | wc -l)
        echo "  总数: $total_files 个文件"
        
        if [ $total_files -gt 0 ]; then
            local total_size=$(du -sh "$LOCAL_CONFIG_DIR" | awk '{print $1}')
            echo "  大小: $total_size"
            echo ""
            show_statistics
        fi
    else
        echo "  配置目录不存在"
    fi
    
    echo ""
    echo "定时任务状态:"
    if crontab -l 2>/dev/null | grep -q "surge-update.sh"; then
        echo "  ✓ 定时任务已启用"
        echo ""
        echo "定时任务列表:"
        crontab -l 2>/dev/null | grep "surge-update.sh"
    else
        echo "  ✗ 定时任务未启用"
    fi
}

# ============================================================
# 主程序入口
# ============================================================

main() {
    # 检查是否为 root 用户（某些操作需要）
    # if [ "$EUID" -ne 0 ]; then
    #     log_error "此脚本需要 sudo 权限运行"
    #     exit 1
    # fi
    
    case "${1:-}" in
        --update)
            check_dependencies
            init_environment
            update_rulesets
            ;;
        --install)
            install_script
            init_environment
            setup_cron
            ;;
        --setup-cron)
            setup_cron
            ;;
        --remove)
            remove_cron
            ;;
        --status)
            show_status
            ;;
        --help|-h)
            show_help
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

# 执行主程序
main "$@"
