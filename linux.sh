#!/bin/bash

# ======================================================
# CentOS 7 基础环境安装脚本 - 彩色美化版
# ======================================================

# 导入公共函数
# $(dirname "$0") - 这是一个命令替换，用于获取当前脚本所在的目录路径
# $0 是一个特殊变量，表示当前执行的脚本的名称（包含路径）
# dirname 命令用于提取路径中的目录部分，去掉文件名
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common/utils.sh"

# 默认离线安装目录
offline_dir="/offline/packages/"

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
print_title "CentOS 7 基础环境安装脚本"
print_info "脚本开始执行时间: $(date)"
echo ""

# 询问用户是否更新yum源
print_color "yellow" "是否需要更新yum源？(y/n)"
read update_yum

if [ "$update_yum" == "y" ]; then
  print_progress "正在更新yum源..."
  # 更新yum源
  sudo yum clean all
  sudo yum update -y

  # 备份原有的yum源配置文件
  print_info "备份原有yum源配置文件到 /etc/yum.repos.d.bak"
  sudo cp -r /etc/yum.repos.d /etc/yum.repos.d.bak

  # 下载阿里云的yum源配置文件
  print_progress "下载阿里云yum源配置文件..."
  sudo curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
  sudo yum makecache
  print_success "yum源更新完成"
else
  print_info "将跳过yum源的更新"
fi

# 可供选择的软件列表
packages=("vim" "net-tools" "tree" "psmisc" "lrzsz" "unzip" "docker" "docker-compose" "git" "maven" "openjdk" "nodejs" "nginx" "vfox" "退出")

# 用户选择安装的软件列表
selected_packages=()

# 创建选择菜单
print_title "软件安装选择"
print_color "bold" "请选择您想要安装的软件:"
PS3="请输入选项编号 [1-${#packages[@]}]: "
select package in "${packages[@]}"; do
  case $package in
  "退出")
    break
    ;;
  "")
    print_error "无效的选择，请重新选择"
    continue
    ;;
  "openjdk")
    # 提供选择JDK版本的菜单
    jdk_versions=("1.8.0" "11" "返回")
    print_color "bold" "请选择您想要安装的OpenJDK版本："
    PS3="请输入JDK版本选项编号 [1-${#jdk_versions[@]}]: "
    select jdk_version in "${jdk_versions[@]}"; do
      case $jdk_version in
      "返回")
        break
        ;;
      "")
        print_error "无效的选择，请重新选择"
        continue
        ;;
      *)
        selected_packages+=("java-$jdk_version-openjdk-devel")
        print_success "已选择: OpenJDK $jdk_version"
        break
        ;;
      esac
    done
    PS3="请输入选项编号 [1-${#packages[@]}]: "
    ;;
  *)
    selected_packages+=("$package")
    print_success "已选择: $package"
    ;;
  esac
done

if [ ${#selected_packages[@]} -eq 0 ]; then
  print_warning "未选择任何软件，脚本将退出"
  exit 0
fi

print_title "开始安装软件"
print_info "共选择了 ${#selected_packages[@]} 个软件包"

# 安装选中的软件
for package in "${selected_packages[@]}"; do
  print_progress "正在安装 $package..."
  
  if [ "$package" == "docker" ]; then
    # 检查Docker是否已经安装
    if ! command -v docker &>/dev/null; then
      # 指定Docker版本
      docker_version="25.0.1"
      
      # 在线安装Docker
      print_info "使用在线方式安装Docker..."
      # 安装Docker
      sudo yum install -y yum-utils
      # 添加阿里云的Docker源
      sudo yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
      # 更新yum源
      sudo yum makecache fast
      # 安装指定版本的Docker
      sudo yum install -y "docker-ce-$docker_version" "docker-ce-cli-$docker_version" containerd.io
      
      # 启动Docker服务
      print_progress "启动Docker服务..."
      sudo systemctl start docker
      # 启用Docker服务
      sudo systemctl enable docker
      # 配置Docker镜像源
      print_progress "配置Docker镜像源..."
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
      print_success "Docker 版本 $docker_version 安装完成"
    else
      print_info "Docker 已经安装，跳过安装步骤"
      sudo systemctl restart docker
    fi
  elif [ "$package" == "docker-compose" ]; then
    # 首先检查是否已安装且可用
    if ! docker-compose version &>/dev/null; then
      
      # 检查离线安装包是否存在docker-compose-linux-x86_64
      if [ -f "$offline_dir/docker-compose-linux-x86_64" ]; then
        print_info "使用离线包安装Docker Compose..."
        # 安装 Docker Compose
        sudo cp "$offline_dir/docker-compose-linux-x86_64" /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        sudo rm -f /usr/bin/docker-compose  # 先删除可能存在的软链接
        sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
        
        # 验证安装
        if docker-compose version &>/dev/null; then
          print_success "Docker Compose 离线安装完成"
          
          # 调用子脚本安装 Docker 容器
          print_progress "准备安装Docker容器..."
          chmod +x install_containers.sh
          ./install_containers.sh
        else
          print_error "Docker Compose 安装失败，请检查安装包是否完整"
          exit 1
        fi
      else
        # 在线安装2.24.2版本的Docker Compose
        print_info "使用在线方式安装Docker Compose 2.24.2..."
        # 确保目标目录存在
        sudo mkdir -p /usr/local/bin
        # 下载并直接保存为可执行文件
        sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.2/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        sudo rm -f /usr/bin/docker-compose  # 先删除可能存在的软链接
        sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
        
        # 验证安装
        if docker-compose version &>/dev/null; then
          print_success "Docker Compose 2.24.2 在线安装完成"
          
          # 调用子脚本安装 Docker 容器
          print_progress "准备安装Docker容器..."
          chmod +x install_containers.sh
          ./install_containers.sh
        else
          print_error "Docker Compose 在线安装失败，请检查网络连接"
          exit 1
        fi
      fi
    else
      print_info "Docker Compose 已经安装且运行正常，跳过安装步骤"
      
      # Docker Compose 已安装，仍然调用容器安装脚本
      print_progress "准备安装Docker容器..."
      chmod +x install_containers.sh
      ./install_containers.sh
    fi
  elif [[ "$package" =~ ^java-(1\.8\.0|11)-openjdk-devel$ ]]; then
    # 在线安装JDK
    jdk_version=$(echo $package | cut -d'-' -f2)
    print_info "使用在线方式安装OpenJDK $jdk_version..."
    sudo yum install -y "$package"
    
    print_success "OpenJDK $jdk_version 安装完成"

    # 获取JDK的实际安装路径
    jdk_home=$(readlink -f /etc/lib/jvm/java-$jdk_version-openjdk)
    print_info "JDK 安装路径: $jdk_home"

    # 检查/etc/profile文件中是否已经存在相同的环境变量配置
    if grep -q "export JAVA_HOME=$jdk_home" /etc/profile; then
      source /etc/profile
      print_info "环境变量已存在，跳过配置"
    else
      # 配置环境变量
      print_progress "正在配置环境变量..."
      sudo sh -c "echo 'export JAVA_HOME=$jdk_home' >> /etc/profile"
      sudo sh -c "echo 'export PATH=\$JAVA_HOME/bin:\$PATH' >> /etc/profile"
      source /etc/profile
      print_success "环境变量配置完成"
    fi
  elif [ "$package" == "nodejs" ]; then
    # 安装 Node.js
    node_version="16" # 可以选择其他版本
    
    # 在线安装Node.js
    print_info "使用在线方式安装Node.js $node_version..."
    sudo yum install -y epel-release
    sudo yum install -y nodejs-${node_version} npm

    # 获取Node.js的实际安装路径
    node_path=$(which node)
    node_home=$(dirname $(dirname $node_path))
    print_info "Node.js 安装路径: $node_home"
    
    # 检查/etc/profile文件中是否已经存在相同的环境变量配置
    if grep -q "export NODE_HOME=$node_home" /etc/profile; then
      source /etc/profile
      print_info "Node.js 环境变量已存在，跳过配置"
    else
      # 配置环境变量
      print_progress "正在配置Node.js环境变量..."
      sudo sh -c "echo 'export NODE_HOME=$node_home' >> /etc/profile"
      sudo sh -c "echo 'export PATH=\$NODE_HOME/bin:\$PATH' >> /etc/profile"
      source /etc/profile
      print_success "Node.js 环境变量配置完成"
    fi
    
    # 设置npm的镜像源为淘宝的镜像源
    print_progress "正在设置npm镜像源为淘宝镜像源..."
    npm config set registry https://registry.npmmirror.com
    
    # 安装pnpm
    print_progress "正在安装pnpm 8.15.4..."
    npm install -g pnpm@8.15.4
    print_success "pnpm 安装完成"
    
    # 设置pnpm镜像源
    pnpm config set registry https://registry.npmmirror.com/
    print_success "pnpm淘宝镜像源设置完成"
    print_success "Node.js ${node_version} 安装完成"
  elif [ "$package" == "nginx" ]; then
    # 在线安装Nginx
    print_info "使用在线方式安装Nginx..."
    sudo yum install -y nginx
    
    # 启动Nginx服务
    sudo systemctl start nginx
    sudo systemctl enable nginx
    print_success "Nginx 安装完成"
    
    # 输出 Nginx 的安装目录信息
    print_info "Nginx 安装目录信息："
    print_color "cyan" "  - 主配置文件: /etc/nginx/nginx.conf"
    print_color "cyan" "  - 站点配置文件: /etc/nginx/conf.d/"
    print_color "cyan" "  - 可执行文件: /usr/sbin/nginx"
    print_color "cyan" "  - Web 根目录: /usr/share/nginx/html"
    print_color "cyan" "  - 访问日志: /var/log/nginx/access.log"
    print_color "cyan" "  - 错误日志: /var/log/nginx/error.log"
    print_color "cyan" "  - PID 文件: /run/nginx.pid"
  elif [ "$package" == "vfox" ]; then
    # 安装vfox
    print_progress "正在安装vfox..."
    if ! command -v vfox &>/dev/null; then
      # 添加vfox仓库
      echo '[vfox]
name=VersionFox Repo
baseurl=https://yum.fury.io/versionfox/
enabled=1
gpgcheck=0' | sudo tee /etc/yum.repos.d/vfox.repo

      # 安装vfox
      sudo yum install -y vfox

      # 配置vfox环境变量
      echo 'eval "$(vfox activate bash)"' >> ~/.bashrc
      source ~/.bashrc
      print_success "vfox 安装完成"
    else
      print_info "vfox 已经安装，跳过安装步骤"
    fi

    # 添加Python插件
    print_progress "正在添加Python插件..."
    vfox add python
    print_progress "正在添加Python SDK..."
    vfox install python
    fi  # <-- 正确的结束位置

  print_success "$package 安装完成"
  echo ""
done

# 关闭防火墙
print_color "yellow" "是否关闭防火墙？(y/n)"
read answer
if [ "$answer" == "y" ]; then
  print_progress "正在关闭防火墙..."
  sudo systemctl disable firewalld
  sudo systemctl stop firewalld
  print_success "防火墙已关闭"
fi

# 记录脚本结束时间
end_time=$(date +%s)
# 计算脚本总耗时
elapsed_time=$((end_time - start_time))
print_title "安装完成"
print_info "脚本结束执行时间: $(date)"
print_success "脚本总耗时：$elapsed_time 秒"