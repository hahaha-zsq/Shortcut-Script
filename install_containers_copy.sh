#!/bin/bash

# ======================================================
# Docker 容器安装脚本 - 彩色美化版
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

# 默认离线安装目录
offline_dir="usr/offline/packages/"

# 检查是否有指定的离线目录参数
if [ ! -z "$1" ]; then
  offline_dir="$1"
fi

# 检查离线目录是否存在
if [ -d "$offline_dir" ]; then
  print_info "已检测到离线安装包目录: $offline_dir"
  offline_mode=true
else
  print_warning "未检测到离线安装包目录，将使用在线安装模式"
  offline_mode=false
fi

# 记录脚本开始时间
start_time=$(date +%s)

# 打印欢迎信息
print_title "Docker 容器安装脚本"
print_info "脚本开始执行时间: $(date)"
echo ""

# 可供选择的容器列表
containers=("mysql" "redis" "nginx" "mongodb" "rabbitmq" "elasticsearch" "portainer" "退出")

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
    selected_containers+=("$container")
    print_success "已选择: $container"
    ;;
  esac
done

if [ ${#selected_containers[@]} -eq 0 ]; then
  print_warning "未选择任何容器，脚本将退出"
  exit 0
fi

print_title "开始安装容器"
print_info "共选择了 ${#selected_containers[@]} 个容器"

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
  if [ ! -d "$container_dir" ]; then
    print_info "创建 $container 容器目录: $container_dir"
    sudo mkdir -p "$container_dir"
  fi
  
  # 根据不同的容器生成对应的docker-compose.yml文件
  case $container in
  "mysql")
    print_info "配置 MySQL 容器..."
    # 询问MySQL版本
    print_color "yellow" "请选择MySQL版本 [5.7/8.0] (默认: 5.7):"
    read mysql_version
    mysql_version=${mysql_version:-5.7}
    
    # 询问MySQL端口
    print_color "yellow" "请输入MySQL端口 (默认: 3306):"
    read mysql_port
    mysql_port=${mysql_port:-3306}
    
    # 询问MySQL密码
    print_color "yellow" "请输入MySQL root密码 (默认: password):"
    read mysql_password
    mysql_password=${mysql_password:-password}
    
    # 创建MySQL数据目录
    sudo mkdir -p "$container_dir/data"
    sudo mkdir -p "$container_dir/conf"
    sudo mkdir -p "$container_dir/logs"
    
    # 生成docker-compose.yml文件
    sudo tee "$container_dir/docker-compose.yml" > /dev/null << EOF
version: '3'
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
      - ./conf:/etc/mysql/conf.d
      - ./logs:/var/log/mysql
    command: --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci
EOF
    ;;
  "redis")
    print_info "配置 Redis 容器..."
    # 询问Redis版本
    print_color "yellow" "请选择Redis版本 [6.0/6.2/7.0] (默认: 6.2):"
    read redis_version
    redis_version=${redis_version:-6.2}
    
    # 询问Redis端口
    print_color "yellow" "请输入Redis端口 (默认: 6379):"
    read redis_port
    redis_port=${redis_port:-6379}
    
    # 询问是否设置密码
    print_color "yellow" "是否设置Redis密码? [y/n] (默认: n):"
    read set_redis_password
    
    # 创建Redis数据目录
    sudo mkdir -p "$container_dir/data"
    sudo mkdir -p "$container_dir/conf"
    
    # 生成redis.conf配置文件
    sudo tee "$container_dir/conf/redis.conf" > /dev/null << EOF
# Redis配置文件
port 6379
# 开启AOF持久化
appendonly yes
# 设置时区
timezone Asia/Shanghai
EOF
    
    # 如果选择设置密码，则添加密码配置
    if [ "$set_redis_password" == "y" ]; then
      print_color "yellow" "请输入Redis密码 (默认: password):"
      read redis_password
      redis_password=${redis_password:-password}
      echo "requirepass $redis_password" | sudo tee -a "$container_dir/conf/redis.conf" > /dev/null
    fi
    
    # 生成docker-compose.yml文件
    sudo tee "$container_dir/docker-compose.yml" > /dev/null << EOF
version: '3'
services:
  redis:
    image: redis:${redis_version}
    container_name: redis
    restart: always
    ports:
      - ${redis_port}:6379
    volumes:
      - ./data:/data
      - ./conf/redis.conf:/etc/redis/redis.conf
    command: redis-server /etc/redis/redis.conf
EOF
    ;;
  "nginx")
    print_info "配置 Nginx 容器..."
    # 询问Nginx版本
    print_color "yellow" "请选择Nginx版本 [1.20/1.22/1.24] (默认: 1.22):"
    read nginx_version
    nginx_version=${nginx_version:-1.22}
    
    # 询问Nginx端口
    print_color "yellow" "请输入Nginx HTTP端口 (默认: 80):"
    read nginx_http_port
    nginx_http_port=${nginx_http_port:-80}
    
    print_color "yellow" "请输入Nginx HTTPS端口 (默认: 443):"
    read nginx_https_port
    nginx_https_port=${nginx_https_port:-443}
    
    # 创建Nginx目录
    sudo mkdir -p "$container_dir/conf"
    sudo mkdir -p "$container_dir/html"
    sudo mkdir -p "$container_dir/logs"
    sudo mkdir -p "$container_dir/ssl"
    
    # 生成默认配置文件
    sudo tee "$container_dir/conf/default.conf" > /dev/null << EOF
server {
    listen       80;
    listen  [::]:80;
    server_name  localhost;

    access_log  /var/log/nginx/host.access.log  main;
    error_log   /var/log/nginx/error.log  error;

    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
    }

    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
}
EOF
    
    # 生成默认HTML页面
    sudo tee "$container_dir/html/index.html" > /dev/null << EOF
<!DOCTYPE html>
<html>
<head>
<title>Welcome to Nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to Nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
EOF
    
    # 生成docker-compose.yml文件
    sudo tee "$container_dir/docker-compose.yml" > /dev/null << EOF
version: '3'
services:
  nginx:
    image: nginx:${nginx_version}
    container_name: nginx
    restart: always
    ports:
      - ${nginx_http_port}:80
      - ${nginx_https_port}:443
    volumes:
      - ./html:/usr/share/nginx/html
      - ./conf:/etc/nginx/conf.d
      - ./logs:/var/log/nginx
      - ./ssl:/etc/nginx/ssl
EOF
    ;;
  "mongodb")
    print_info "配置 MongoDB 容器..."
    # 询问MongoDB版本
    print_color "yellow" "请选择MongoDB版本 [4.4/5.0/6.0] (默认: 4.4):"
    read mongodb_version
    mongodb_version=${mongodb_version:-4.4}
    
    # 询问MongoDB端口
    print_color "yellow" "请输入MongoDB端口 (默认: 27017):"
    read mongodb_port
    mongodb_port=${mongodb_port:-27017}
    
    # 询问是否设置密码
    print_color "yellow" "是否设置MongoDB密码? [y/n] (默认: n):"
    read set_mongodb_password
    
    # 创建MongoDB数据目录
    sudo mkdir -p "$container_dir/data/db"
    sudo mkdir -p "$container_dir/data/configdb"
    
    # 生成docker-compose.yml文件
    if [ "$set_mongodb_password" == "y" ]; then
      print_color "yellow" "请输入MongoDB用户名 (默认: admin):"
      read mongodb_user
      mongodb_user=${mongodb_user:-admin}
      
      print_color "yellow" "请输入MongoDB密码 (默认: password):"
      read mongodb_password
      mongodb_password=${mongodb_password:-password}
      
      sudo tee "$container_dir/docker-compose.yml" > /dev/null << EOF
version: '3'
services:
  mongodb:
    image: mongo:${mongodb_version}
    container_name: mongodb
    restart: always
    environment:
      - MONGO_INITDB_ROOT_USERNAME=${mongodb_user}
      - MONGO_INITDB_ROOT_PASSWORD=${mongodb_password}
    ports:
      - ${mongodb_port}:27017
    volumes:
      - ./data/db:/data/db
      - ./data/configdb:/data/configdb
EOF
    else
      sudo tee "$container_dir/docker-compose.yml" > /dev/null << EOF
version: '3'
services:
  mongodb:
    image: mongo:${mongodb_version}
    container_name: mongodb
    restart: always
    ports:
      - ${mongodb_port}:27017
    volumes:
      - ./data/db:/data/db
      - ./data/configdb:/data/configdb
EOF
    fi
    ;;
  "rabbitmq")
    print_info "配置 RabbitMQ 容器..."
    # 询问RabbitMQ版本
    print_color "yellow" "请选择RabbitMQ版本 [3.9/3.10/3.11] (默认: 3.9-management):"
    read rabbitmq_version
    rabbitmq_version=${rabbitmq_version:-3.9}
    
    # 询问RabbitMQ端口
    print_color "yellow" "请输入RabbitMQ端口 (默认: 5672):"
    read rabbitmq_port
    rabbitmq_port=${rabbitmq_port:-5672}
    
    print_color "yellow" "请输入RabbitMQ管理界面端口 (默认: 15672):"
    read rabbitmq_management_port
    rabbitmq_management_port=${rabbitmq_management_port:-15672}
    
    # 询问是否设置默认用户和密码
    print_color "yellow" "是否设置RabbitMQ默认用户和密码? [y/n] (默认: y):"
    read set_rabbitmq_user
    set_rabbitmq_user=${set_rabbitmq_user:-y}
    
    # 创建RabbitMQ数据目录
    sudo mkdir -p "$container_dir/data"
    
    # 生成docker-compose.yml文件
    if [ "$set_rabbitmq_user" == "y" ]; then
      print_color "yellow" "请输入RabbitMQ默认用户名 (默认: admin):"
      read rabbitmq_user
      rabbitmq_user=${rabbitmq_user:-admin}
      
      print_color "yellow" "请输入RabbitMQ默认密码 (默认: password):"
      read rabbitmq_password
      rabbitmq_password=${rabbitmq_password:-password}
      
      sudo tee "$container_dir/docker-compose.yml" > /dev/null << EOF
version: '3'
services:
  rabbitmq:
    image: rabbitmq:${rabbitmq_version}-management
    container_name: rabbitmq
    restart: always
    environment:
      - RABBITMQ_DEFAULT_USER=${rabbitmq_user}
      - RABBITMQ_DEFAULT_PASS=${rabbitmq_password}
    ports:
      - ${rabbitmq_port}:5672
      - ${rabbitmq_management_port}:15672
    volumes:
      - ./data:/var/lib/rabbitmq
EOF
    else
      sudo tee "$container_dir/docker-compose.yml" > /dev/null << EOF
version: '3'
services:
  rabbitmq:
    image: rabbitmq:${rabbitmq_version}-management
    container_name: rabbitmq
    restart: always
    ports:
      - ${rabbitmq_port}:5672
      - ${rabbitmq_management_port}:15672
    volumes:
      - ./data:/var/lib/rabbitmq
EOF
    fi
    ;;
  "elasticsearch")
    print_info "配置 Elasticsearch 容器..."
    # 询问Elasticsearch版本
    print_color "yellow" "请选择Elasticsearch版本 [7.14/7.17/8.0] (默认: 7.17.0):"
    read es_version
    es_version=${es_version:-7.17.0}
    
    # 询问Elasticsearch端口
    print_color "yellow" "请输入Elasticsearch HTTP端口 (默认: 9200):"
    read es_http_port
    es_http_port=${es_http_port:-9200}
    
    print_color "yellow" "请输入Elasticsearch TCP端口 (默认: 9300):"
    read es_tcp_port
    es_tcp_port=${es_tcp_port:-9300}
    
    # 创建Elasticsearch数据目录
    sudo mkdir -p "$container_dir/data"
    sudo mkdir -p "$container_dir/logs"
    sudo mkdir -p "$container_dir/plugins"
    
    # 生成docker-compose.yml文件
    sudo tee "$container_dir/docker-compose.yml" > /dev/null << EOF
version: '3'
services:
  elasticsearch:
    image: elasticsearch:${es_version}
    container_name: elasticsearch
    restart: always
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
      - bootstrap.memory_lock=true
    ulimits:
      memlock:
        soft: -1
        hard: -1
    ports:
      - ${es_http_port}:9200
      - ${es_tcp_port}:9300
    volumes:
      - ./data:/usr/share/elasticsearch/data
      - ./logs:/usr/share/elasticsearch/logs
      - ./plugins:/usr/share/elasticsearch/plugins
EOF
    ;;
  "portainer")
    print_info "配置 Portainer 容器..."
    # 询问Portainer版本
    print_color "yellow" "请选择Portainer版本 [latest/2.15.1/2.16.2] (默认: latest):"
    read portainer_version
    portainer_version=${portainer_version:-latest}
    
    # 询问Portainer端口
    print_color "yellow" "请输入Portainer端口 (默认: 9000):"
    read portainer_port
    portainer_port=${portainer_port:-9000}
    
    # 创建Portainer数据目录
    sudo mkdir -p "$container_dir/data"
    
    # 生成docker-compose.yml文件
    sudo tee "$container_dir/docker-compose.yml" > /dev/null << EOF
version: '3'
services:
  portainer:
    image: portainer/portainer-ce:${portainer_version}
    container_name: portainer
    restart: always
    ports:
      - ${portainer_port}:9000
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./data:/data
EOF
    ;;
  esac
  
  # 启动容器
  print_progress "正在启动 $container 容器..."
  cd "$container_dir"
  sudo docker-compose up -d
  
  if [ $? -eq 0 ]; then
    print_success "$container 容器启动成功"
    
    # 显示容器访问信息
    case $container in
    "mysql")
      print_info "MySQL 容器信息:"
      print_color "cyan" "  - 端口: $mysql_port"
      print_color "cyan" "  - 用户名: root"
      print_color "cyan" "  - 密码: $mysql_password"
      print_color "cyan" "  - 连接命令: mysql -h 127.0.0.1 -P $mysql_port -u root -p"
      ;;
    "redis")
      print_info "Redis 容器信息:"
      print_color "cyan" "  - 端口: $redis_port"
      if [ "$set_redis_password" == "y" ]; then
        print_color "cyan" "  - 密码: $redis_password"
        print_color "cyan" "  - 连接命令: redis-cli -h 127.0.0.1 -p $redis_port -a $redis_password"
      else
        print_color "cyan" "  - 连接命令: redis-cli -h 127.0.0.1 -p $redis_port"
      fi
      ;;
    "nginx")
      print_info "Nginx 容器信息:"
      print_color "cyan" "  - HTTP端口: $nginx_http_port"
      print_color "cyan" "  - HTTPS端口: $nginx_https_port"
      print_color "cyan" "  - 配置目录: $container_dir/conf"
      print_color "cyan" "  - 网站目录: $container_dir/html"
      print_color "cyan" "  - 访问地址: http://localhost:$nginx_http_port"
      ;;
    "mongodb")
      print_info "MongoDB 容器信息:"
      print_color "cyan" "  - 端口: $mongodb_port"
      if [ "$set_mongodb_password" == "y" ]; then
        print_color "cyan" "  - 用户名: $mongodb_user"
        print_color "cyan" "  - 密码: $mongodb_password"
        print_color "cyan" "  - 连接命令: mongo mongodb://$mongodb_user:$mongodb_password@127.0.0.1:$mongodb_port"
      else
        print_color "cyan" "  - 连接命令: mongo 127.0.0.1:$mongodb_port"
      fi
      ;;
    "rabbitmq")
      print_info "RabbitMQ 容器信息:"
      print_color "cyan" "  - 端口: $rabbitmq_port"
      print_color "cyan" "  - 管理界面端口: $rabbitmq_management_port"
      if [ "$set_rabbitmq_user" == "y" ]; then
        print_color "cyan" "  - 用户名: $rabbitmq_user"
        print_color "cyan" "  - 密码: $rabbitmq_password"
      fi
      print_color "cyan" "  - 管理界面: http://localhost:$rabbitmq_management_port"
      ;;
    "elasticsearch")
      print_info "Elasticsearch 容器信息:"
      print_color "cyan" "  - HTTP端口: $es_http_port"
      print_color "cyan" "  - TCP端口: $es_tcp_port"
      print_color "cyan" "  - 访问地址: http://localhost:$es_http_port"
      ;;
    "portainer")
      print_info "Portainer 容器信息:"
      print_color "cyan" "  - 端口: $portainer_port"
      print_color "cyan" "  - 访问地址: http://localhost:$portainer_port"
      print_color "cyan" "  - 首次访问需要创建管理员账户"
      ;;
    esac
  else
    print_error "$container 容器启动失败，请检查配置"
  fi
  
  echo ""
done

# 记录脚本结束时间
end_time=$(date +%s)
# 计算脚本总耗时
elapsed_time=$((end_time - start_time))
print_title "安装完成"
print_info "脚本结束执行时间: $(date)"
print_success "脚本总耗时：$elapsed_time 秒"

# 显示所有已安装的容器
print_title "已安装的容器"
sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"