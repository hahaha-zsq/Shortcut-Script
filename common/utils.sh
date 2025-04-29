#!/bin/bash

# ======================================================
# 公共函数库 - 优化版
# ======================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # 无色

# 打印彩色文本函数
print_color() {
  case $1 in
    "red") echo -e "${RED}$2${NC}" ;;
    "green") echo -e "${GREEN}$2${NC}" ;;
    "yellow") echo -e "${YELLOW}$2${NC}" ;;
    "blue") echo -e "${BLUE}$2${NC}" ;;
    "purple") echo -e "${PURPLE}$2${NC}" ;;
    "cyan") echo -e "${CYAN}$2${NC}" ;;
    "bold") echo -e "${BOLD}$2${NC}" ;;
    *) echo -e "$2" ;;
  esac
}

# 打印分隔线
print_separator() {
  print_color "cyan" "======================================================="
}

# 打印标题
print_title() {
  print_separator
  print_color "bold" "  $1"
  print_separator
}

# 打印成功消息
print_success() {
  print_color "green" "✓ $1"
}

# 打印错误消息
print_error() {
  print_color "red" "✗ $1"
}

# 打印警告消息
print_warning() {
  print_color "yellow" "⚠ $1"
}

# 打印信息消息
print_info() {
  print_color "blue" "ℹ $1"
}

# 打印进度消息
print_progress() {
  print_color "purple" "➤ $1"
}

# 检查命令是否存在
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# 创建docker-compose文件的函数
create_compose_file() {
  local container_dir=$1
  local content=$2
  
  sudo tee "$container_dir/docker-compose.yml" > /dev/null << EOF
$content
EOF
}

# 启动容器的函数
start_container() {
  local container_dir=$1
  
  cd "$container_dir"
  sudo docker-compose up -d
  return $?
}

# 检查目录是否存在，不存在则创建
ensure_dir() {
  local dir=$1
  if [ ! -d "$dir" ]; then
    sudo mkdir -p "$dir"
    print_info "创建目录: $dir"
  fi
}

# 检查离线包是否存在
check_offline_package() {
  local package=$1
  local pattern=$2
  local offline_dir=$3
  
  if [ -d "$offline_dir" ]; then
    local pkg_file=$(find "$offline_dir" -name "$pattern" 2>/dev/null | head -n 1)
    if [ -n "$pkg_file" ]; then
      echo "$pkg_file"  # 返回找到的文件路径
      return 0 # 找到离线包
    fi
  fi
  return 1 # 未找到离线包
}

# 安装离线包
install_offline_package() {
  local package=$1
  local pattern=$2
  local install_cmd=$3
  local offline_dir=$4
  
  local pkg_file=$(check_offline_package "$package" "$pattern" "$offline_dir")
  local status=$?
  
  if [ $status -eq 0 ]; then
    print_info "使用离线包安装 $package: $pkg_file"
    eval "$install_cmd \"$pkg_file\""
    if [ $? -eq 0 ]; then
      print_success "$package 离线安装完成"
      return 0
    else
      print_error "$package 离线安装失败"
      return 1
    fi
  fi
  return 1
}