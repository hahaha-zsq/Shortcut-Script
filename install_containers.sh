#!/bin/bash

# 创建Docker网络
# 提示用户输入网络名称
echo "请输入要创建的Docker网络名称："
read network_name

# 检查网络是否已存在
if sudo docker network ls | grep -q "$network_name"; then
  echo "Docker网络 $network_name 已经存在。"
else
  # 创建网络
  sudo docker network create "$network_name"
  if [ $? -eq 0 ]; then
    echo "Docker网络 $network_name 创建完成。"
  else
    echo "创建Docker网络 $network_name 失败。"
  fi
fi
# 检查MySQL容器是否已经安装并运行
mysql_container=$(sudo docker ps -q -f name=mysql)
# 容器选项
containers=("mysql" "redis" "minio" "xxl-job" "退出")
selected_containers=()

# 创建选择菜单
echo "请选择您想要启动的容器:"
select container in "${containers[@]}"; do
  case $container in
  "退出")
    break
    ;;
  "")
    echo "无效的选择，请重新选择。"
    continue
    ;;
  *)
    selected_containers+=("$container")
    echo "已选择: $container"
    ;;
  esac
done

# 启动选中的容器
for container in "${selected_containers[@]}"; do
  case $container in
  "mysql")
    echo "请输入MySQL宿主机的端口号："
    read mysql_port
    echo "请输入MySQL的root密码："
    read mysql_root_password
    echo "请输入MySQL的存储目录："
    read mysql_data_dir
    echo "请输入MySQL的配置目录："
    read mysql_conf_dir
    echo "请输入MySQL的日志目录："
    read mysql_log_dir
    echo "请输入MySQL的初始化脚本目录："
    read mysql_init_dir
    # 确保目录存在，如果不存在则创建
    mkdir -p "$mysql_data_dir" "$mysql_conf_dir" "$mysql_log_dir" "$mysql_init_dir"
    echo "正在启动 mysql 容器..."
    sudo docker run -d --privileged=true --restart=always -p "$mysql_port":3306 -e MYSQL_ROOT_PASSWORD="$mysql_root_password" -v "$mysql_data_dir":/var/lib/mysql -v "$mysql_conf_dir":/etc/mysql/conf.d -v "$mysql_log_dir":/var/log/mysql -v "$mysql_init_dir":/docker-entrypoint-initdb.d --network "$network_name" --name mysql8 mysql:8.0.29
    ;;
  "redis")
    echo "请输入redisL宿主机的端口号："
    read redis_port
    echo "请输入redis的密码："
    read redis_password
    echo "请输入容器redis的端口号"
    read redis_container_port
    echo "正在启动 redis 容器..."
    sudo docker run -d --privileged=true --restart=always -p "$redis_port":"$redis_container_port" -e REDIS_PASSWORD="$redis_password" -e REDIS_APPENDONLY=yes -e REDIS_APPENDFSYNC=everysec -e REDIS_PROTECTED_MODE=yes -e REDIS_LOGLEVEL=notice -e REDIS_BIND=0.0.0.0 --network "$network_name" --name redis redis:6.2
    ;;
  "minio")
    echo "请输入minio的服务端口号："
    read minio_service_port
    echo "请输入minio的控制台端口号"
    read minio_console_port
    echo "请输入minio的登录用户名"
    read minio_user_name
    echo "请输入minio的登录密码"
    read minio_password
    echo "请输入服务器地址(ip地址不含http(s)://)"
    read minio_url
    echo "请输入minio的存储目录"
    read minio_data_dir
    echo "请输入minio的配置目录"
    read minio_conf_dir
    # 确保目录存在，如果不存在则创建
    mkdir -p "$minio_data_dir" "$minio_conf_dir"
    echo "正在启动 minio 容器..."
    sudo docker run -d --privileged=true --restart=always -it -p "$minio_service_port":9886 -p "$minio_console_port":9090 -e MINIO_ROOT_USER="$minio_user_name" -e MINIO_ROOT_PASSWORD="$minio_password" -e MINIO_SERVER_URL="http://$minio_url:$minio_service_port" -v "$minio_data_dir":/data -v "$minio_conf_dir":/root/.minio --network "$network_name" minio/minio:RELEASE.2022-10-29T06-21-33Z server /data --console-address ":$minio_console_port" --address ":$minio_service_port" --name minio
    ;;
  "xxl-job")
    echo "请输入xxl-job宿主机的端口号："
    read xxl_job_port
    echo "请输入mysql容器的别名："
    read mysql_name
    echo "请输入mysql容器的端口号"
    read mysql_port
    echo "请输入宿主机上xxl-job的sql文件地址"
    read xxl_job_sql_file_path
    echo "请输入MySQL的用户名："
    read mysql_user_name
    echo "请输入MySQL的密码："
    read mysql_user_password
    echo "请输入xxl-job日志目录"
    read xxl_job_log_dir
    # 确保目录存在，如果不存在则创建
    mkdir -p "$xxl_job_log_dir"

     # 检查MySQL容器状态，如果未安装或未运行则跳过XXL-JOB安装
    if [ -z "$mysql_name" ]; then
      echo "XXL-JOB需要MySQL容器，但MySQL容器未安装或未运行，跳过XXL-JOB安装。"
      continue
    fi
    echo "正在初始化 XXL-JOB 数据库..."
    # 这个符号 < 表示重定向，即将文件 xxx.sql 的内容作为 MySQL 客户端的标准输入。这意味着 SQL 文件中的所有 SQL 语句都会被发送到 MySQL 服务器进行执行。
    chmod +x "$xxl_job_sql_file_path"
    sudo docker exec -i "$mysql_name" mysql -u"$mysql_user_name" -p"$mysql_user_password" < "$xxl_job_sql_file_path"
    if [ $? -eq 0 ]; then
        echo "XXL-JOB 数据库初始化成功."
    else
        echo "XXL-JOB 数据库初始化失败."
        exit 1
    fi
    echo "正在启动 XXL-JOB 容器..."
    sudo docker run --privileged=true --restart=always -d --network "$network_name" -e PARAMS="--spring.datasource.url=jdbc:mysql://$mysql_name:$mysql_port/xxl_job?useUnicode=true&characterEncoding=UTF-8&autoReconnect=true&serverTimezone=Asia/Shanghai --spring.datasource.username=$mysql_user_name --spring.datasource.password=$mysql_user_password" -p "$xxl_job_port":8080 -v "$xxl_job_log_dir":/data/applogs --name xxl-job-admin xuxueli/xxl-job-admin:2.4.0
    ;;
  esac
  echo "$container 容器启动完成."
done
