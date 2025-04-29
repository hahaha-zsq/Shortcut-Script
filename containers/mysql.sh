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

# 生成my.cnf配置文件
sudo tee "$container_dir/conf/my.cnf" > /dev/null << EOF
[mysqld]
server-id=1

binlog_format = ROW
bind-address=0.0.0.0
character-set-server=utf8mb4
collation-server=utf8mb4_general_ci
long_query_time=8

slow_query_log=1
slow_query_log_file=/var/log/mysql/show_query.log

[client]
default-character-set=utf8mb4
[mysql]
default-character-set=utf8
EOF

# 生成docker-compose.yml文件
if [ "$join_network" == "y" ]; then
  compose_content="version: '3'
services:
  mysql:
    image: mysql:${mysql_version}
    container_name: mysql
    restart: always
    environment:
      - MYSQL_ROOT_PASSWORD=${mysql_password}
      - TZ=Asia/Shanghai
    ports:
      - ${mysql_port}:3306
    volumes:
      - ./data:/var/lib/mysql
      - ./conf:/etc/mysql
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
  print_info "  - 连接命令: mysql -h 127.0.0.1 -P $mysql_port -u root -p"
else
  print_error "MySQL 容器启动失败"
  exit 1
fi