#!/bin/bash

# ======================================================
# Redis 容器安装脚本 - 优化版
# ======================================================

# 导入公共函数
source "./common/utils.sh"

# 获取参数
container_dir=$1
join_network=$2
network_name=$3

print_info "配置 Redis 容器..."

# 询问Redis版本
redis_version=${redis_version:-6.0}

# 询问Redis端口
print_color "yellow" "请输入Redis端口 (默认: 6379):"
read redis_port
redis_port=${redis_port:-6379}

# 询问是否设置密码
print_color "yellow" "是否设置Redis密码? [y/n] (默认: n):"
read set_redis_password

# 创建Redis数据目录
ensure_dir "$container_dir/data"
ensure_dir "$container_dir/conf"

# 生成redis.conf配置文件
sudo tee "$container_dir/conf/redis.conf" > /dev/null << EOF
protected-mode yes
port 6379
tcp-backlog 511
timeout 0
tcp-keepalive 300
daemonize no
supervised no
pidfile /var/run/redis_6379.pid
loglevel notice
logfile ""
databases 16
always-show-logo yes
save 900 1
save 300 10
save 60 10000
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename dump.rdb
rdb-del-sync-files no
dir ./
replica-serve-stale-data yes
replica-read-only yes
repl-diskless-sync no
repl-diskless-sync-delay 5
repl-diskless-load disabled
repl-disable-tcp-nodelay no
replica-priority 100
acllog-max-len 128
lazyfree-lazy-eviction no
lazyfree-lazy-expire no
lazyfree-lazy-server-del no
replica-lazy-flush no
lazyfree-lazy-user-del no
appendonly yes
appendfilename "appendonly.aof"
appendfsync everysec
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
aof-load-truncated yes
aof-use-rdb-preamble yes
lua-time-limit 5000
slowlog-log-slower-than 10000
slowlog-max-len 128
latency-monitor-threshold 0
notify-keyspace-events ""
hash-max-ziplist-value 64
list-max-ziplist-size -2
list-compress-depth 0
set-max-intset-entries 512
zset-max-ziplist-entries 128
zset-max-ziplist-value 64
hll-sparse-max-bytes 3000
stream-node-max-bytes 4096
stream-node-max-entries 100
activerehashing yes
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit replica 256mb 64mb 60
client-output-buffer-limit pubsub 32mb 8mb 60
hz 10
dynamic-hz yes
aof-rewrite-incremental-fsync yes
rdb-save-incremental-fsync yes
jemalloc-bg-thread yes
EOF

# 如果选择设置密码，则添加密码配置
if [ "$set_redis_password" == "y" ]; then
  print_color "yellow" "请输入Redis密码 (默认: password):"
  read redis_password
  redis_password=${redis_password:-password}
  echo "requirepass $redis_password" | sudo tee -a "$container_dir/conf/redis.conf" > /dev/null
fi

# 生成docker-compose.yml文件
if [ "$join_network" == "y" ]; then
  compose_content="version: '3'
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
    networks:
      - ${network_name}
networks:
  ${network_name}:
    external: true"
else
  compose_content="version: '3'
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
    command: redis-server /etc/redis/redis.conf"
fi

create_compose_file "$container_dir" "$compose_content"

# 启动容器
print_progress "正在启动 Redis 容器..."
start_container "$container_dir"

if [ $? -eq 0 ]; then
  print_success "Redis 容器启动成功"
  print_info "Redis 容器信息:"
  print_info "  - 版本: $redis_version"
  print_info "  - 端口: $redis_port"
  if [ "$set_redis_password" == "y" ]; then
    print_info "  - 密码: $redis_password"
    print_info "  - 连接命令: redis-cli -h 127.0.0.1 -p $redis_port -a $redis_password"
  else
    print_info "  - 连接命令: redis-cli -h 127.0.0.1 -p $redis_port"
  fi
  print_info "  - 配置目录: $container_dir"
else
  print_error "Redis 容器启动失败"
  exit 1
fi