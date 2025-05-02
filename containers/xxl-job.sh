#!/bin/bash

# ======================================================
# XXL-JOB 容器安装脚本 - 优化版
# ======================================================

# 导入公共函数
source "./common/utils.sh"

# 获取参数
container_dir=$1
join_network=$2
network_name=$3

print_info "配置 XXL-JOB 容器..."

# 询问XXL-JOB版本
xxl_job_version=${xxl_job_version:-2.4.0}

print_color "yellow" "请输入服务器IP地址 (默认: 127.0.0.1):"
read server
server=${server:-127.0.0.1}
# 询问端口
print_color "yellow" "请输入宿主机的XXL-JOB端口 (默认: 7379):"
read xxl_job_port
xxl_job_port=${xxl_job_port:-7379}

# 询问MySQL连接信息
print_color "yellow" "请输入MySQL主机名 (默认: 127.0.0.1,可以为主机IP 、容器IP（不推荐，重启容器可能会变）如果xxl-job和mysql在同一个网络下，可以使用mysql的容器的名称（推荐）作为主机名):"
read mysql_host
mysql_host=${mysql_host:-127.0.0.1}

print_color "yellow" "请输入MySQL端口 (默认: 3306,如果xxl-job和mysql在同一个网络下,这里的端口号是mysql容器设置的端口号):"
read mysql_port
mysql_port=${mysql_port:-3306}

print_color "yellow" "请输入MySQL用户名 (默认: root):"
read mysql_username
mysql_username=${mysql_username:-root}

print_color "yellow" "请输入MySQL密码 (默认: password):"
read mysql_password
mysql_password=${mysql_password:-password}

# 创建XXL-JOB目录
ensure_dir "$container_dir/logs"

# 检查是否需要初始化数据库
print_color "yellow" "是否需要初始化XXL-JOB数据库？[y/n] (默认: y):"
read init_db
init_db=${init_db:-y}
if [ "$init_db" == "y" ]; then
  print_progress "正在初始化XXL-JOB数据库..."
  
  # 检查SQL脚本是否存在
  print_color "yellow" "请输入SQL脚本路径 (默认: /offline/packages/xxl-job.sql):"
  read sql_script_path
  sql_script_path=${sql_script_path:-"/offline/packages/xxl-job.sql"}
  
  # 检查SQL脚本是否存在
  if [ ! -f "$sql_script_path" ]; then
    print_error "SQL脚本不存在: $sql_script_path"
    exit 1
  fi
  
  # 询问MySQL容器名称
  print_color "yellow" "请输入MySQL容器名称 (默认: mysql8):"
  read mysql_container
  mysql_container=${mysql_container:-"mysql8"}
  
  # 在MySQL容器内执行SQL脚本
  print_info "正在MySQL容器内执行SQL脚本..."
  cat "$sql_script_path" | docker exec -i "$mysql_container" mysql -u"$mysql_username" -p"$mysql_password" --default-character-set=utf8
  
  if [ $? -eq 0 ]; then
    print_success "XXL-JOB数据库初始化成功"
  else
    print_error "XXL-JOB数据库初始化失败"
    print_info "请尝试手动在MySQL容器中执行SQL脚本:"
    print_info "1. 复制SQL脚本到容器:"
    print_info "   docker cp \"$sql_script_path\" \"$mysql_container\":/tmp/xxl-job.sql"
    print_info "2. 进入容器执行脚本:"
    print_info "   docker exec -it \"$mysql_container\" bash"
    print_info "3. 在容器内执行:"
    print_info "   mysql -u\"$mysql_username\" -p\"$mysql_password\" < /tmp/xxl-job.sql"
  fi
fi

# 生成docker-compose.yml文件
if [ "$join_network" == "y" ]; then
  compose_content="version: '3'
services:
  xxl-job-admin:
    image: xuxueli/xxl-job-admin:${xxl_job_version}
    container_name: xxl-job-admin
    restart: always
    environment:
      PARAMS: '--spring.datasource.url=jdbc:mysql://${mysql_host}:${mysql_port}/xxl_job?useUnicode=true&characterEncoding=UTF-8&autoReconnect=true&serverTimezone=Asia/Shanghai --spring.datasource.username=${mysql_username} --spring.datasource.password=${mysql_password}'
    ports:
      - ${xxl_job_port}:8080
    volumes:
      - ./logs:/data/applogs
    networks:
      - ${network_name}
networks:
  ${network_name}:
    external: true"
else
  compose_content="version: '3'
services:
  xxl-job-admin:
    image: xuxueli/xxl-job-admin:${xxl_job_version}
    container_name: xxl-job-admin
    restart: always
    environment:
      PARAMS: '--spring.datasource.url=jdbc:mysql://${mysql_host}:${mysql_port}/xxl_job?useUnicode=true&characterEncoding=UTF-8&autoReconnect=true&serverTimezone=Asia/Shanghai --spring.datasource.username=${mysql_username} --spring.datasource.password=${mysql_password}'
    ports:
      - ${xxl_job_port}:8080
    volumes:
      - ./logs:/data/applogs"
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

create_compose_file "$container_dir" "$compose_content"

# 启动容器
print_progress "正在启动 XXL-JOB 容器..."
start_container "$container_dir"

if [ $? -eq 0 ]; then
  print_success "XXL-JOB 容器启动成功"
  print_info "XXL-JOB 容器信息:"
  print_info "  - 版本: $xxl_job_version"
  print_info "  - 宿主机端口: $xxl_job_port"
  print_info "  - 配置目录: $container_dir"
  print_info "  - 访问地址: http://$server:$xxl_job_port/xxl-job-admin/toLogin"
  print_info "  - 默认登录账号: admin"
  print_info "  - 默认登录密码: 123456"
else
  print_error "XXL-JOB 容器启动失败"
  exit 1
fi