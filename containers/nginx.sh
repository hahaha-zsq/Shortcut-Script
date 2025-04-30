#!/bin/bash

# ======================================================
# Nginx 容器安装脚本 - 优化版
# ======================================================

# 导入公共函数
source "./common/utils.sh"

# 获取参数
container_dir=$1
join_network=$2
network_name=$3

print_info "配置 Nginx 容器..."


nginx_version=${nginx_version:-1.28.0}

# 询问Nginx端口
print_color "yellow" "请输入Nginx HTTP端口 (默认: 80,只做初始化，后续想监听更多端口，请修改default.conf/nginx.conf，并且在docker-compose.yml添加端口映射):"
read nginx_http_port
nginx_http_port=${nginx_http_port:-80}

print_color "yellow" "请输入Nginx HTTPS端口 (默认: 443):"
read nginx_https_port
nginx_https_port=${nginx_https_port:-443}

# 创建Nginx目录
ensure_dir "$container_dir/conf"
ensure_dir "$container_dir/html"
ensure_dir "$container_dir/logs"
ensure_dir "$container_dir/ssl"

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
if [ "$join_network" == "y" ]; then
  compose_content="version: '3'
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
    networks:
      - ${network_name}
networks:
  ${network_name}:
    external: true"
else
  compose_content="version: '3'
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
      - ./ssl:/etc/nginx/ssl"
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
print_progress "正在启动 Nginx 容器..."
start_container "$container_dir"

if [ $? -eq 0 ]; then
  print_success "Nginx 容器启动成功"
  print_info "Nginx 容器信息:"
  print_info "  - 版本: $nginx_version"
  print_info "  - HTTP端口: $nginx_http_port"
  print_info "  - HTTPS端口: $nginx_https_port"
  print_info "  - 配置目录: $container_dir"
  print_info "  - 访问地址: http://localhost:$nginx_http_port"
else
  print_error "Nginx 容器启动失败"
  exit 1
fi