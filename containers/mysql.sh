#!/bin/bash

# ======================================================
# MySQL 容器安装脚本 - 优化版
# ======================================================

# 导入公共函数

source "./common/utils.sh"

# 获取参数
container_dir=$1
join_network=$2
network_name=$3

print_info "配置 MySQL 容器..."

mysql_version=${mysql_version:-8.0.24}

# 询问MySQL端口
print_color "yellow" "请输入MySQL端口 (默认: 3306):"
read mysql_port
mysql_port=${mysql_port:-3306}

# 询问MySQL密码
print_color "yellow" "请输入MySQL root密码 (默认: password):"
read mysql_password
mysql_password=${mysql_password:-password}

# 创建MySQL数据目录
ensure_dir "$container_dir/data"
ensure_dir "$container_dir/conf"
ensure_dir "$container_dir/logs"

# 设置目录权限（MySQL 用户的 UID 是 999）999:999 是 MySQL 容器内的 mysql 用户和组的 UID 和 GID。通过将权限设置为 999:999，确保容器能够正确地读写数据和日志文件。
sudo chown -R 999:999 "$container_dir/data"
sudo chown -R 999:999 "$container_dir/logs"
sudo chmod -R 755 "$container_dir/data"
sudo chmod -R 755 "$container_dir/logs"

# 文件名随意，文件格式必须为 .cnf.生成dadandiaoming.cnf配置文件
# MySQL默认配置文件 /etc/my.cnf 末尾中有这么一行：!includedir /etc/mysql/conf.d/ ，意思是，在 /etc/mysql/conf.d/ 目录下新建自定义的配置文件 custom.cnf也会被读取到，而且还是优先读取的（Docker Hub中的MySQL教程文档有说到
sudo tee "$container_dir/conf/dadandiaoming.cnf" > /dev/null << EOF
[mysqld]
server-id=1
# MySQL 数据存储路径
datadir=/var/lib/mysql
# 基础配置
bind-address=0.0.0.0
port=3306
# 字符集配置
character-set-server=utf8mb4
collation-server=utf8mb4_general_ci
init_connect='SET NAMES utf8mb4'

# 日志配置
log_error=/var/log/mysql/error.log
slow_query_log=1
slow_query_log_file=/var/log/mysql/slow_query.log
long_query_time=8

# 二进制日志配置
binlog_format=ROW
log-bin=/var/log/mysql/mysql-bin.log
expire_logs_days=7

# 性能配置
max_connections=1000
max_allowed_packet=16M
thread_cache_size=128
sort_buffer_size=4M
read_buffer_size=2M
read_rnd_buffer_size=4M
join_buffer_size=4M

[client]
default-character-set=utf8mb4

[mysql]
default-character-set=utf8mb4
EOF

# 生成docker-compose.yml文件
if [ "$join_network" == "y" ]; then
  compose_content="version: '3'
services:
  mysql:
    image: mysql:${mysql_version}
    container_name: mysql8
    restart: always
    environment:
      - MYSQL_ROOT_PASSWORD=${mysql_password}
      - TZ=Asia/Shanghai
    ports:
      - ${mysql_port}:3306
    volumes:
      - ./data:/var/lib/mysql
      - ./conf:/etc/mysql/conf.d
      - ./logs:/var/log/mysql
    command: --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci
    networks:
      - ${network_name}
networks:
  ${network_name}:
    external: true"
else
  compose_content="version: '3'
services:
  mysql:
    image: mysql:${mysql_version}
    container_name: mysql8
    restart: always
    environment:
      - MYSQL_ROOT_PASSWORD=${mysql_password}
      - TZ=Asia/Shanghai
    ports:
      - ${mysql_port}:3306
    volumes:
      - ./data:/var/lib/mysql
      - ./conf:/etc/mysql/conf.d
      - ./logs:/var/log/mysql
    command: --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci"
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
print_progress "正在启动 MySQL 容器..."
start_container "$container_dir"

if [ $? -eq 0 ]; then
  print_success "MySQL 容器启动成功"
  print_info "MySQL 容器信息:"
  print_info "  - 版本: $mysql_version"
  print_info "  - 端口: $mysql_port"
  print_info "  - 用户名: root"
  print_info "  - 密码: $mysql_password"
  print_info "  - 配置目录: $container_dir"
  print_info "  - 连接命令: mysql  -P $mysql_port -u root -p"
  print_warning "请确保在防火墙中开放 $mysql_port 端口，以便外部网络能够访问MySQL服务"

  sleep 5
  # 询问是否创建新用户
  print_color "yellow" "是否需要创建新的MySQL用户？[y/n] (默认: n):"
  read create_user
  create_user=${create_user:-n}

  if [ "$create_user" == "y" ]; then
    # 询问新用户名
    print_color "yellow" "请输入新用户名 (默认: admin):"
    read new_username
    new_username=${new_username:-admin}

    # 询问新用户密码
    print_color "yellow" "请输入新用户密码 (默认: password):"
    read new_password
    new_password=${new_password:-password}

    # 创建新用户
    print_progress "正在创建新用户..."
    docker exec mysql8 mysql -uroot -p"${mysql_password}" -e "CREATE USER '${new_username}'@'%' IDENTIFIED BY '${new_password}'; GRANT ALL ON *.* TO '${new_username}'@'%' WITH GRANT OPTION; FLUSH PRIVILEGES;"
    
    if [ $? -eq 0 ]; then
      print_success "新用户创建成功"
      print_info "新用户信息:"
      print_info "  - 用户名: ${new_username}"
      print_info "  - 密码: ${new_password}"
      print_info "  - 权限: 所有权限"
    else
      print_error "新用户创建失败"
    fi
  fi
else
  print_error "MySQL 容器启动失败"
  exit 1
fi