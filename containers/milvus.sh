#!/bin/bash

# ======================================================
# Milvus 容器安装脚本 - 依赖 MinIO 版本
# ======================================================

# 导入公共函数
source "./common/utils.sh"

# 获取参数
container_dir=$1
join_network=$2
network_name=$3

print_info "配置 Milvus 容器..."

# 检查 MinIO 容器是否运行
print_progress "检查 MinIO 容器是否已运行..."
minio_running=$(docker ps --format "{{.Names}}" | grep -E "^minio$")

if [ -z "$minio_running" ]; then
  print_error "未检测到 MinIO 容器运行！"
  print_warning "Milvus 依赖 MinIO 服务，请先安装并启动 MinIO 容器。"
  print_info "您可以通过运行安装脚本并选择 MinIO 选项来安装 MinIO。"
  exit 1
fi

# 获取 MinIO 容器信息
print_progress "获取 MinIO 容器网络信息..."
minio_networks=$(docker inspect -f '{{range $key, $value := .NetworkSettings.Networks}}{{$key}} {{end}}' minio)

# 检查 MinIO 是否在指定网络中
if [ "$join_network" == "y" ]; then
  if [[ ! $minio_networks =~ $network_name ]]; then
    print_warning "警告: MinIO 容器不在网络 '$network_name' 中!"
    print_info "Milvus 必须与 MinIO 在同一个网络下才能正常工作。"
    print_color "yellow" "是否将 MinIO 容器连接到网络 '$network_name'? [y/n] (默认: y):"
    read connect_minio
    connect_minio=${connect_minio:-y}
    
    if [ "$connect_minio" == "y" ]; then
      print_progress "正在将 MinIO 容器连接到网络 '$network_name'..."
      docker network connect $network_name minio
      if [ $? -eq 0 ]; then
        print_success "MinIO 容器已成功连接到网络 '$network_name'"
      else
        print_error "无法将 MinIO 容器连接到网络 '$network_name'，安装终止"
        exit 1
      fi
    else
      print_error "Milvus 必须与 MinIO 在同一个网络下才能正常工作，安装终止"
      exit 1
    fi
  else
    print_success "MinIO 容器已在网络 '$network_name' 中"
  fi
else
  # 如果不加入指定网络，则强制使用 MinIO 所在的网络
  # 获取 MinIO 的第一个网络
  minio_network=$(echo $minio_networks | awk '{print $1}')
  
  if [ -z "$minio_network" ] || [ "$minio_network" == "bridge" ]; then
    # 如果 MinIO 在默认网络或没有网络，则创建新网络并连接 MinIO
    network_name="milvus-minio-network"
    print_info "MinIO 容器没有在自定义网络中，将创建新网络 '$network_name' 并连接 MinIO"
    
    # 检查网络是否已存在
    network_exists=$(docker network ls --format "{{.Name}}" | grep -E "^$network_name$")
    if [ -z "$network_exists" ]; then
      print_progress "创建网络 '$network_name'..."
      docker network create $network_name
      if [ $? -ne 0 ]; then
        print_error "创建网络失败，安装终止"
        exit 1
      fi
    fi
    
    # 连接 MinIO 到新网络
    print_progress "将 MinIO 容器连接到网络 '$network_name'..."
    docker network connect $network_name minio
    if [ $? -ne 0 ]; then
      print_error "无法将 MinIO 容器连接到网络 '$network_name'，安装终止"
      exit 1
    fi
    
    join_network="y"
  else
    print_info "将使用 MinIO 所在的网络: $minio_network"
    network_name=$minio_network
    join_network="y"
  fi
fi

# 询问Milvus版本
print_color "yellow" "请输入Milvus版本 (默认: v2.5.10):"
read milvus_version
milvus_version=${milvus_version:-v2.5.10}

# 询问ETCD版本
print_color "yellow" "请输入ETCD版本 (默认: v3.5.18):"
read etcd_version
etcd_version=${etcd_version:-v3.5.18}

print_color "yellow" "请输入服务器IP地址 (默认: 127.0.0.1):"
read server
server=${server:-127.0.0.1}

# 询问Milvus端口
print_color "yellow" "请输入Milvus服务端口 (默认: 19530):"
read milvus_port
milvus_port=${milvus_port:-19530}

print_color "yellow" "请输入Milvus健康检查端口 (默认: 9091):"
read milvus_health_port
milvus_health_port=${milvus_health_port:-9091}

# 创建Milvus目录
ensure_dir "$container_dir/volumes/etcd"
ensure_dir "$container_dir/volumes/milvus"

# 生成docker-compose.yml文件
compose_content="version: '3.5'

services:
  etcd:
    container_name: milvus-etcd
    image: quay.io/coreos/etcd:${etcd_version}
    environment:
      - ETCD_AUTO_COMPACTION_MODE=revision
      - ETCD_AUTO_COMPACTION_RETENTION=1000
      - ETCD_QUOTA_BACKEND_BYTES=4294967296
      - ETCD_SNAPSHOT_COUNT=50000
    volumes:
      - ./volumes/etcd:/etcd
    command: etcd -advertise-client-urls=http://etcd:2379 -listen-client-urls http://0.0.0.0:2379 --data-dir /etcd
    healthcheck:
      test: ["CMD", "etcdctl", "endpoint", "health"]
      interval: 30s
      timeout: 20s
      retries: 3
    networks:
      - ${network_name}

  standalone:
    container_name: milvus-standalone
    image: milvusdb/milvus:${milvus_version}
    command: ["milvus", "run", "standalone"]
    security_opt:
    - seccomp:unconfined
    environment:
      ETCD_ENDPOINTS: etcd:2379
      MINIO_ADDRESS: minio:9886
    volumes:
      - ./volumes/milvus:/var/lib/milvus
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9091/healthz"]
      interval: 30s
      start_period: 90s
      timeout: 20s
      retries: 3
    ports:
      - ${milvus_port}:19530
      - ${milvus_health_port}:9091
    depends_on:
      - etcd
    networks:
      - ${network_name}

networks:
  ${network_name}:
    external: true"

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
print_progress "正在启动 Milvus 容器..."
start_container "$container_dir"

if [ $? -eq 0 ]; then
  print_success "Milvus 容器启动成功"
  print_info "Milvus 容器信息:"
  print_info "  - Milvus 版本: $milvus_version"
  print_info "  - ETCD 版本: $etcd_version"
  print_info "  - 使用网络: ${network_name} (与 MinIO 共享同一网络)"
  print_info "  - MinIO 连接地址: minio:9886"
  print_info "  - Milvus 服务端口: $milvus_port"
  print_info "  - Milvus 健康检查端口: $milvus_health_port"
  print_info "  - 配置目录: $container_dir"
  print_info "  - Milvus 访问地址: http://${server}:${milvus_port}"
  print_info "  - Milvus 健康检查地址: http://${server}:${milvus_health_port}/healthz"
  print_warning "请确保在防火墙中开放2379和 $milvus_port 和 $milvus_health_port 端口，以便外部网络能够访问Milvus服务"
  print_warning "重要提示: Milvus 和 MinIO 必须在同一个网络中才能正常工作。"
else
  print_error "Milvus 容器启动失败"
  exit 1
fi