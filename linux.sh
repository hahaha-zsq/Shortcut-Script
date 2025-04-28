#!/bin/bash

# 默认离线安装目录
offline_dir="usr/offline/packages/"

# 检查是否有指定的离线目录参数
if [ ! -z "$1" ]; then
  offline_dir="$1"
fi

# 记录脚本开始时间
start_time=$(date +%s)

# 询问用户是否更新yum源
echo "是否需要更新yum源？(y/n)"
read update_yum

if [ "$update_yum" == "y" ]; then
  # 更新yum源
  sudo yum clean all
  sudo yum update -y

  # 备份原有的yum源配置文件
  sudo cp -r /etc/yum.repos.d /etc/yum.repos.d.bak

  # 下载阿里云的yum源配置文件
  sudo curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
  sudo yum makecache
else
  echo "将跳过yum源的更新。"
fi

# 可供选择的软件列表
packages=("vim" "net-tools" "tree" "psmisc" "lrzsz" "unzip" "docker" "docker-compose" "git" "maven" "openjdk" "nodejs" "nginx" "退出")

# 用户选择安装的软件列表
selected_packages=()

# 创建选择菜单
echo "请选择您想要安装的软件:"
select package in "${packages[@]}"; do
  case $package in
  "退出")
    break
    ;;
  "")
    echo "无效的选择，请重新选择。"
    continue
    ;;
  "openjdk")
    # 提供选择JDK版本的菜单
    jdk_versions=("1.8.0" "11" "返回")
    echo "请选择您想要安装的OpenJDK版本："
    select jdk_version in "${jdk_versions[@]}"; do
      case $jdk_version in
      "返回")
        break
        ;;
      "")
        echo "无效的选择，请重新选择。"
        continue
        ;;
      *)
        selected_packages+=("java-$jdk_version-openjdk-devel")
        echo "已选择: OpenJDK $jdk_version"
        break
        ;;
      esac
    done
    ;;
  *)
    selected_packages+=("$package")
    echo "已选择: $package"
    ;;
  esac
done

# 安装选中的软件
for package in "${selected_packages[@]}"; do
  echo "正在安装 $package.."
  if [ "$package" == "docker" ]; then
    # 检查Docker是否已经安装
    if ! command -v docker &>/dev/null; then
      # 指定Docker版本
      docker_version="25.0.1"
      # 安装Docker
      sudo yum install -y yum-utils
      # 添加阿里云的Docker源
      sudo yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
      # 更新yum源
      sudo yum makecache fast
      # 安装指定版本的Docker
      sudo yum install -y "docker-ce-$docker_version" "docker-ce-cli-$docker_version" containerd.io
      # 启动Docker服务
      sudo systemctl start docker
      # 启用Docker服务
      sudo systemctl enable docker
      # 配置Docker镜像源
      sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": [
                       "https://docker.1panel.live",
                       "https://hub.uuuadc.top",
                       "https://docker.anyhub.us.kg",
                       "https://dockerhub.jobcher.com",
                       "https://dockerhub.icu",
                       "https://docker.ckyl.me",
                       "https://docker.awsl9527.cn"
                      ]
}
EOF
      sudo systemctl restart docker
      echo "Docker 版本 $docker_version 安装完成"
      # 调用子脚本安装 Docker 容器
      chmod +x install_containers.sh
      ./install_containers.sh
    else
      sudo systemctl restart docker
      echo "Docker 已经安装，跳过安装步骤。"
      # 调用子脚本安装 Docker 容器
      chmod +x install_containers.sh
      ./install_containers.sh
    fi
  elif [ "$package" == "docker-compose" ]; then
    if ! command -v docker-compose &>/dev/null; then
      # 检查离线安装包是否存在
      if [ -f "$offline_dir/docker-compose-linux-x86_64" ]; then
        # 安装 Docker Compose
        sudo cp "$offline_dir/docker-compose-linux-x86_64" /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
        echo "Docker Compose 离线安装完成."
      else
        # 在线安装2.24.2版本的Docker Compose
        sudo curl -L "https://github.com/docker/compose/releases/download/2.24.2/docker-compose-Linux-x86_64" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
        echo "Docker Compose 2.24.2 在线安装完成."
      fi
    fi
  elif [[ "$package" =~ ^java-(1\.8\.0|11)-openjdk-devel$ ]]; then
    # 安装JDK
    sudo yum install -y "$package"
    echo "OpenJDK $(echo $package | cut -d'-' -f2) 安装完成."

    # 获取JDK的实际安装路径
    jdk_version=$(echo $package | cut -d'-' -f2)
    jdk_home=$(readlink -f /usr/lib/jvm/java-$jdk_version-openjdk)
    echo "JDK 安装路径: $jdk_home"

    # 检查/etc/profile文件中是否已经存在相同的环境变量配置
    if grep -q "export JAVA_HOME=$jdk_home" /etc/profile; then
      source /etc/profile
      echo "环境变量已存在，跳过配置。"
    else
      # 配置环境变量
      echo "正在配置环境变量.."
      sudo sh -c "echo 'export JAVA_HOME=$jdk_home' >> /etc/profile"
      sudo sh -c "echo 'export PATH=\$JAVA_HOME/bin:\$PATH' >> /etc/profile"
      source /etc/profile
      echo "环境变量配置完成."
    fi
  elif [ "$package" == "nodejs" ]; then
    # 安装 Node.js
    node_version="16" # 可以选择其他版本
    sudo yum install -y epel-release
    sudo yum install -y nodejs-${node_version} npm

    # 获取Node.js的实际安装路径
    node_path=$(which node)
    node_home=$(dirname $(dirname $node_path))
    echo "Node.js 安装路径: $node_home"
    # 检查/etc/profile文件中是否已经存在相同的环境变量配置
    if grep -q "export NODE_HOME=$node_home" /etc/profile; then
      source /etc/profile
      echo "Node.js 环境变量已存在，跳过配置。"
    else
      # 配置环境变量
      echo "正在配置Node.js环境变量.."
      sudo sh -c "echo 'export NODE_HOME=$node_home' >> /etc/profile"
      sudo sh -c "echo 'export PATH=\$NODE_HOME/bin:\$PATH' >> /etc/profile"
      source /etc/profile
      echo "Node.js 环境变量配置完成."
    fi
    # 设置npm的镜像源为淘宝的镜像源
    echo "正在设置npm镜像源为淘宝镜像源.."
    npm config set registry https://registry.npmmirror.com
    npm install -g pnpm@8.15.4
    echo "pnpm 安装完成."
    pnpm config set registry https://registry.npmmirror.com/
    echo "pnpm淘宝镜像源设置完成."
    echo "Node.js ${node_version} 安装完成."
  elif [ "$package" == "nginx" ]; then
    # 安装 Nginx
    sudo yum install -y nginx
    sudo systemctl start nginx
    sudo systemctl enable nginx
    echo "Nginx 安装完成."
    # 输出 Nginx 的安装目录信息
    echo "Nginx 安装目录信息："
    echo "  - 主配置文件: /etc/nginx/nginx.conf"
    echo "  - 站点配置文件: /etc/nginx/conf.d/"
    echo "  - 可执行文件: /usr/sbin/nginx"
    echo "  - Web 根目录: /usr/share/nginx/html"
    echo "  - 访问日志: /var/log/nginx/access.log"
    echo "  - 错误日志: /var/log/nginx/error.log"
    echo "  - PID 文件: /run/nginx.pid"
  else
    # 安装其他软件
    sudo yum install -y "$package"
  fi
  echo "$package 安装完成."
done

# 关闭防火墙
echo "是否关闭防火墙？(y/n)"
read answer
if [ "$answer" == "y" ]; then
  sudo systemctl disable firewalld
  sudo systemctl stop firewalld
  echo "防火墙已关闭."
fi

# 记录脚本结束时间
end_time=$(date +%s)
# 计算脚本总耗时
elapsed_time=$((end_time - start_time))
echo "success! 脚本总耗时：$elapsed_time 秒"
