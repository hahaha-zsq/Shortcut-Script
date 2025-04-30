#!/bin/bash

# ======================================================
# Docker 容器安装脚本 - 主脚本 (优化版)
# ======================================================

# 导入公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common/utils.sh"

# 记录脚本开始时间
start_time=$(date +%s)
# 显示当前系统Docker镜像状态
print_title "当前系统Docker镜像状态"
print_info "已下载的Docker镜像列表："
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
echo ""

# 显示当前系统容器状态
print_title "当前系统容器状态"
print_info "已安装的容器列表："
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
echo ""
print_info "正在运行的容器列表："
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
echo ""


# 创建Docker网络
print_title "创建Docker网络"
print_color "yellow" "请输入要创建的Docker网络名称（留空则不创建）："
read network_name

if [ -n "$network_name" ]; then
  # 检查用户是否输入了网络名称
  # -n 判断字符串长度是否大于0
  # $network_name 是用户之前输入的网络名称
  
  if sudo docker network ls | grep -q "$network_name"; then
    # 使用 docker network ls 列出所有 Docker 网络
    # grep -q 静默搜索指定的网络名称，不输出任何内容
    # 如果找到网络，grep 命令返回状态码 0（成功）
    print_info "Docker网络 $network_name 已经存在。"
  else
    # 如果网络不存在，创建新的网络
    sudo docker network create "$network_name"
    # docker network create 创建新的 Docker 网络
    # 使用 sudo 以管理员权限执行命令
    # "$network_name" 使用双引号避免名称中包含空格等特殊字符
    
    if [ $? -eq 0 ]; then
      # $? 获取上一个命令的退出状态码
      # -eq 0 判断状态码是否等于0（表示成功）
      print_success "Docker网络 $network_name 创建完成。"
    else
      # 如果状态码不为0，表示创建失败
      print_error "创建Docker网络 $network_name 失败。"
    fi
  fi
else
  # 如果用户没有输入网络名称（按回车跳过）
  print_warning "未输入网络名称，跳过网络创建。"
fi

# 打印欢迎信息
print_title "Docker 容器安装脚本"
print_info "脚本开始执行时间: $(date)"
echo ""

# 可供选择的容器列表
containers=("mysql" "redis" "nginx" "mongodb" "rabbitmq" "minio" "elasticsearch" "xxl-job" "退出")

# 用户选择安装的容器列表
selected_containers=()

# 创建选择菜单
print_title "容器安装选择"
print_color "bold" "请选择您想要安装的Docker容器:"
PS3="请输入选项编号 [1-${#containers[@]}]: "
select container in "${containers[@]}"; do
  case $container in
  "退出")
    break
    ;;
  "")
    print_error "无效的选择，请重新选择"
    continue
    ;;
  *)
    # 检查是否已经选择了该容器
    if [[ " ${selected_containers[@]} " =~ " ${container} " ]]; then
      # 检查用户选择的容器是否已经在选中列表中
      # ${selected_containers[@]} 获取已选容器数组中的所有元素
      # 在数组元素前后添加空格，避免部分匹配（如 redis 匹配到 redis-cli）
      # =~ 使用正则表达式匹配
      print_warning "已经选择了 $container，请选择其他容器"
    else
      # 如果容器未被选择过，则添加到已选列表中
      selected_containers+=("$container")  # 将新容器添加到数组末尾
      print_success "已选择: $container"   # 打印成功信息
    fi
    ;;
  esac
done

if [ ${#selected_containers[@]} -eq 0 ]; then
  print_warning "未选择任何容器，脚本将退出"
  exit 0
fi

print_title "开始安装容器"
print_info "共选择了 ${#selected_containers[@]} 个容器: ${selected_containers[*]}"

# 创建docker-compose目录
compose_dir="/opt/docker-compose"
if [ ! -d "$compose_dir" ]; then
  print_progress "创建docker-compose目录: $compose_dir"
  sudo mkdir -p "$compose_dir"
fi

# 安装选中的容器
for container in "${selected_containers[@]}"; do
  print_progress "正在安装 $container 容器..."
  
  # 为每个容器创建单独的目录
  container_dir="$compose_dir/$container"
  ensure_dir "$container_dir"
  
  # 询问是否加入网络
  if [ -n "$network_name" ]; then
    print_color "yellow" "是否将 $container 容器加入到 $network_name 网络？ [y/n] (默认: n):"
    read join_network
    join_network=${join_network:-n}
  else
    join_network="n"
  fi
  
  # 检查容器安装脚本是否存在
  container_script="$(dirname "$0")/containers/${container}.sh"
  if [ ! -f "$container_script" ]; then
    print_error "$container 容器安装脚本不存在: $container_script"
    continue
  fi
  
  # 调用对应的容器安装脚本
  bash "$container_script" "$container_dir" "$join_network" "$network_name"
  
  if [ $? -eq 0 ]; then
    print_success "$container 容器安装成功"
  else
    print_error "$container 容器安装失败"
  fi
done

# 计算脚本执行时间
end_time=$(date +%s)
execution_time=$((end_time - start_time))
minutes=$((execution_time / 60))
seconds=$((execution_time % 60))

print_title "安装完成"
print_info "脚本执行时间: ${minutes}分${seconds}秒"
print_info "安装的容器: ${selected_containers[*]}"
print_info "容器配置目录: $compose_dir"
print_info "完成时间: $(date)"
