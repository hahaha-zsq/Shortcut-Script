#!/bin/bash

# ======================================================
# MinIO 容器安装脚本 - 优化版
# ======================================================

# 导入公共函数
source "./common/utils.sh"

# 获取参数
container_dir=$1
join_network=$2
network_name=$3

print_info "配置 MinIO 容器..."


# 询问MinIO版本
minio_version=${minio_version:-RELEASE.2025-03-12T18-04-18Z}

print_color "yellow" "请输入服务器IP地址 (默认: 127.0.0.1):"
read server
server=${server:-127.0.0.1}



# 询问MinIO端口
print_color "yellow" "请输入宿主机MinIO服务端口 (默认: 9090):"
read minio_port
minio_port=${minio_port:-9090}

print_color "yellow" "请输入宿主机MinIO控制台端口 (默认: 9886):"
read console_port
console_port=${console_port:-9886}

# 询问MinIO访问凭证并验证长度
while true; do
  print_color "yellow" "请输入MinIO访问用户名 (默认: minioadmin, 至少3个字符):"
  read minio_root_user
  minio_root_user=${minio_root_user:-minioadmin}
  
  if [ ${#minio_root_user} -lt 3 ]; then
    print_error "错误: 用户名长度必须至少为3个字符"
  else
    break
  fi
done

while true; do
  print_color "yellow" "请输入MinIO访问密码 (默认: minioadmin, 至少8个字符):"
  read minio_root_password
  minio_root_password=${minio_root_password:-minioadmin}
  
  if [ ${#minio_root_password} -lt 8 ]; then
    print_error "错误: 密码长度必须至少为8个字符"
  else
    break
  fi
done

# 构建MinIO服务器URL
minio_server_url="http://${server}:${minio_port}"
print_info "MinIO服务器URL: $minio_server_url"

# 创建MinIO目录
ensure_dir "$container_dir/data"
ensure_dir "$container_dir/config"

# 生成docker-compose.yml文件
if [ "$join_network" == "y" ]; then
  compose_content="version: '3'
services:
  minio:
    image: minio/minio:${minio_version}
    container_name: minio
    restart: always
    environment:
      - MINIO_ROOT_USER=${minio_root_user}
      - MINIO_ROOT_PASSWORD=${minio_root_password}
      - MINIO_SERVER_URL=http://${server}:${console_port}
    ports:
      - ${minio_port}:9090
      - ${console_port}:9886
    volumes:
      - ./data:/data
      - ./config:/root/.minio
    command: server /data --console-address \":9090\" --address \":9886\"
    networks:
      - ${network_name}
networks:
  ${network_name}:
    external: true"
else
  compose_content="version: '3'
services:
  minio:
    image: minio/minio:${minio_version}
    container_name: minio
    restart: always
    environment:
      - MINIO_ROOT_USER=${minio_root_user}
      - MINIO_ROOT_PASSWORD=${minio_root_password}
      - MINIO_SERVER_URL=http://${server}:${console_port}
    ports:
      - ${minio_port}:9090
      - ${console_port}:9886
    volumes:
      - ./data:/data
      - ./config:/root/.minio
    command: server /data --console-address \":9090\" --address \":9886\""
fi

# 检查 docker-compose.yml 文件是否已存在
compose_file="$container_dir/docker-compose.yml"
if [ -f "$compose_file" ]; then
  print_color "yellow" "检测到已存在的 docker-compose.yml 文件，是否覆盖？[y/n] (默认: n):"
  read overwrite
  overwrite=${overwrite:-n}
  
  if [ "$overwrite" == "y" ]; then
    # 备份原有配置文件
    backup_file="${compose_file}.backup.$(date +%Y%m%d_%H%M%S)"
    sudo cp "$compose_file" "$backup_file"
    print_info "已备份原有配置文件到: $backup_file"
  else
    print_warning "保留原有配置文件，跳过创建新的配置文件"
    exit 0
  fi
fi

# 生成docker-compose.yml文件
create_compose_file "$container_dir" "$compose_content"

# 启动容器
print_progress "正在启动 MinIO 容器..."
start_container "$container_dir"

if [ $? -eq 0 ]; then
  print_success "MinIO 容器启动成功"
  print_info "MinIO 容器信息:"
  print_info "  - 版本: $minio_version"
  print_info "  - 服务端口: $minio_port"
  print_info "  - 控制台端口: $console_port"
  print_info "  - 访问用户名: $minio_root_user"
  print_info "  - 访问密码: $minio_root_password"
  print_info "  - 配置目录: $container_dir"
  print_info "  - 访问地址: $minio_server_url"
  print_info "  - 后台访问地址: http://${server}:${console_port}"
  print_warning "请确保在防火墙中开放 $minio_port 和 $console_port 端口，以便外部网络能够访问MinIO服务和控制台"
else
  print_error "MinIO 容器启动失败"
  exit 1
fi