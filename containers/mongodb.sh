#!/bin/bash

# ======================================================
# MongoDB 容器安装脚本 - 优化版
# ======================================================

# 导入公共函数
source "./common/utils.sh"

# 获取参数
container_dir=$1
join_network=$2
network_name=$3

print_info "配置 MongoDB 容器..."

# 询问MongoDB版本
print_color "yellow" "请输入MongoDB版本 (默认: 6.0):"
read mongodb_version
mongodb_version=${mongodb_version:-6.0}

print_color "yellow" "请输入服务器IP地址 (默认: 127.0.0.1):"
read server
server=${server:-127.0.0.1}

# 询问MongoDB端口
print_color "yellow" "请输入宿主机MongoDB服务端口 (默认: 27017):"
read mongodb_port
mongodb_port=${mongodb_port:-27017}

# 询问MongoDB Express端口
print_color "yellow" "请输入宿主机MongoDB Express服务端口 (默认: 8081):"
read mongo_express_port
mongo_express_port=${mongo_express_port:-8081}

# 询问MongoDB访问凭证
while true; do
  print_color "yellow" "请输入MongoDB管理员用户名 (默认: admin, 至少3个字符):"
  read mongodb_root_user
  mongodb_root_user=${mongodb_root_user:-admin}
  
  if [ ${#mongodb_root_user} -lt 3 ]; then
    print_error "错误: 用户名长度必须至少为3个字符"
  else
    break
  fi
done

while true; do
  print_color "yellow" "请输入MongoDB管理员密码 (默认: 123456, 至少6个字符):"
  read mongodb_root_password
  mongodb_root_password=${mongodb_root_password:-123456}
  
  if [ ${#mongodb_root_password} -lt 6 ]; then
    print_error "错误: 密码长度必须至少为6个字符"
  else
    break
  fi
done

# 创建MongoDB目录
ensure_dir "$container_dir/mongodb/data/db"
ensure_dir "$container_dir/mongodb/data/log"

# 生成docker-compose.yml文件
if [ "$join_network" == "y" ]; then
  compose_content="version: '3'
services:
  mongodb:
    image: mongo:${mongodb_version}
    container_name: mongodb
    restart: unless-stopped
    environment:
      MONGO_INITDB_ROOT_USERNAME: ${mongodb_root_user}
      MONGO_INITDB_ROOT_PASSWORD: ${mongodb_root_password}
    ports:
      - ${mongodb_port}:27017
    volumes:
      - ./mongodb/data/db:/data/db
      - ./mongodb/data/log:/data/log
    networks:
      - ${network_name}

  mongo-express:
    image: mongo-express
    container_name: mongo-express
    restart: unless-stopped
    environment:
      ME_CONFIG_MONGODB_ADMINUSERNAME: ${mongodb_root_user}
      ME_CONFIG_MONGODB_ADMINPASSWORD: ${mongodb_root_password}
      ME_CONFIG_MONGODB_SERVER: mongodb
    ports:
      - ${mongo_express_port}:8081
    depends_on:
      - mongodb
    networks:
      - ${network_name}
networks:
  ${network_name}:
    external: true"
else
  compose_content="version: '3'
networks:
  mongo:

services:
  mongodb:
    image: mongo:${mongodb_version}
    container_name: mongodb
    restart: unless-stopped
    environment:
      MONGO_INITDB_ROOT_USERNAME: ${mongodb_root_user}
      MONGO_INITDB_ROOT_PASSWORD: ${mongodb_root_password}
    ports:
      - ${mongodb_port}:27017
    volumes:
      - ./mongodb/data/db:/data/db
      - ./mongodb/data/log:/data/log
    networks:
      - mongo

  mongo-express:
    image: mongo-express
    container_name: mongo-express
    restart: unless-stopped
    environment:
      ME_CONFIG_MONGODB_ADMINUSERNAME: ${mongodb_root_user}
      ME_CONFIG_MONGODB_ADMINPASSWORD: ${mongodb_root_password}
      ME_CONFIG_MONGODB_SERVER: mongodb
    ports:
      - ${mongo_express_port}:8081
    depends_on:
      - mongodb
    networks:
      - mongo"
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
print_progress "正在启动 MongoDB 容器..."
start_container "$container_dir"

if [ $? -eq 0 ]; then
  print_success "MongoDB 容器启动成功"
  print_info "MongoDB 容器信息:"
  print_info "  - 版本: $mongodb_version"
  print_info "  - 服务端口: $mongodb_port"
  print_info "  - 管理员用户名: $mongodb_root_user"
  print_info "  - 管理员密码: $mongodb_root_password"
  print_info "  - 连接字符串: mongodb://${mongodb_root_user}:${mongodb_root_password}@${server}:${mongodb_port}"
  print_info "  - MongoDB Express 访问地址: http://${server}:${mongo_express_port}"
  print_info "  - 配置目录: $container_dir"
  print_warning "请确保在防火墙中开放 $mongodb_port 端口，以便外部网络能够访问MongoDB服务"
  print_warning "请确保在防火墙中开放 $mongo_express_port 端口，以便外部网络能够访问MongoDB Express管理界面"
else
  print_error "MongoDB 容器启动失败"
  exit 1
fi