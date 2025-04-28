#!/bin/bash

# ======================================================
# CentOS 7 基础环境安装脚本 - 彩色美化版
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

# 检查离线包是否存在
check_offline_package() {
  local package=$1
  local pattern=$2
  
  if [ -d "$offline_dir" ]; then
    local pkg_file=$(find "$offline_dir" -name "$pattern" 2>/dev/null | head -n 1)
    if [ -n "$pkg_file" ]; then
      return 0 # 找到离线包
    fi
  fi
  return 1 # 未找到离线包
}

# 安装离线包
install_offline_package() {
  local package=$1
  local pattern=$2
  local install_cmd=$3
  
  local pkg_file=$(find "$offline_dir" -name "$pattern" 2>/dev/null | head -n 1)
  if [ -n "$pkg_file" ]; then
    print_info "使用离线包安装 $package: $pkg_file"
    eval "$install_cmd \"$pkg_file\""
    if [ $? -eq 0 ]; then
      print_success "$package 离线安装完成"
      return 0
    else
      print_error "$package 离线安装失败"
      return 1
    fi
  fi
  return 1
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
packages=("vim" "net-tools" "tree" "psmisc" "lrzsz" "unzip" "docker" "docker-compose" "git" "maven" "openjdk" "nodejs" "nginx" "python" "退出")

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
      
      # 调用子脚本安装 Docker 容器
      print_progress "准备安装Docker容器..."
      chmod +x install_containers.sh
      ./install_containers.sh
    else
      print_info "Docker 已经安装，跳过安装步骤"
      sudo systemctl restart docker
      # 调用子脚本安装 Docker 容器
      print_progress "准备安装Docker容器..."
      chmod +x install_containers.sh
      ./install_containers.sh
    fi
  elif [ "$package" == "docker-compose" ]; then
    # 首先检查是否已安装且可用
    if ! docker-compose version &>/dev/null; then
      
      # 检查离线安装包是否存在
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
        else
          print_error "Docker Compose 在线安装失败，请检查网络连接"
          exit 1
        fi
      fi
    else
      print_info "Docker Compose 已经安装且运行正常，跳过安装步骤"
    fi
  elif [[ "$package" =~ ^java-(1\.8\.0|11)-openjdk-devel$ ]]; then
    # 在线安装JDK
    jdk_version=$(echo $package | cut -d'-' -f2)
    print_info "使用在线方式安装OpenJDK $jdk_version..."
    sudo yum install -y "$package"
    
    print_success "OpenJDK $jdk_version 安装完成"

    # 获取JDK的实际安装路径
    jdk_home=$(readlink -f /usr/lib/jvm/java-$jdk_version-openjdk)
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
  elif [ "$package" == "python" ]; then
    # 提供选择多个Python版本
    python_versions=("3.7" "3.8" "3.9" "3.10" "3.11" "完成选择")
    selected_python_versions=()

    print_color "bold" "请选择您想要安装的Python版本(可多选，完成选择时选'完成选择'):"
    PS3="请输入Python版本选项编号 [1-${#python_versions[@]}]: "
    select python_version in "${python_versions[@]}"; do
      case $python_version in
      "完成选择")
        break
        ;;
      "")
        print_error "无效选择，请重新选择"
        ;;
      *)
        selected_python_versions+=("$python_version")
        print_success "已选择: Python $python_version"
        ;;
      esac
    done
    PS3="请输入选项编号 [1-${#packages[@]}]: "

    if [ ${#selected_python_versions[@]} -eq 0 ]; then
      print_warning "未选择任何Python版本，跳过安装"
    else
      # 安装基础开发工具组
      print_progress "正在安装开发工具组..."
      # 在线安装开发工具组
      sudo yum -y groupinstall "Development Tools"

      # 安装Python所需依赖
      print_progress "正在安装Python依赖包..."
      # 在线安装Python依赖
      sudo yum -y install gcc gcc-c++ make \
        zlib-devel bzip2 bzip2-devel readline-devel sqlite sqlite-devel \
        openssl-devel tk-devel libffi-devel xz-devel \
        wget curl

      # 安装EPEL仓库
      print_progress "正在安装EPEL仓库..."
      sudo yum -y install epel-release

      # 创建临时目录用于下载和编译
      mkdir -p /tmp/python-build
      cd /tmp/python-build

      for version in "${selected_python_versions[@]}"; do
        print_progress "正在安装Python $version..."
        
        # 在线下载源码并编译安装
        print_info "使用在线方式下载并编译安装Python $version..."
        
        # 获取最新的小版本号
        case "$version" in
          "3.7")
            full_version="3.7.17"
            ;;
          "3.8")
            full_version="3.8.18"
            ;;
          "3.9")
            full_version="3.9.18"
            ;;
          "3.10")
            full_version="3.10.13"
            ;;
          "3.11")
            full_version="3.11.8"
            ;;
          *)
            print_error "不支持的Python版本: $version"
            continue
            ;;
        esac
        
        # 下载源码
        print_progress "正在下载Python $full_version 源码..."
        wget https://www.python.org/ftp/python/$full_version/Python-$full_version.tgz
        
        if [ $? -ne 0 ]; then
          print_error "Python $full_version 源码下载失败"
          continue
        fi
        
        # 解压源码
        tar -xzf Python-$full_version.tgz
        cd Python-$full_version
        
        # 配置、编译和安装
        print_progress "正在配置Python $full_version..."
        ./configure --enable-optimizations
        
        print_progress "正在编译Python $full_version (这可能需要一些时间)..."
        make -j $(nproc)
        
        print_progress "正在安装Python $full_version..."
        sudo make altinstall
        
        # 返回上级目录
        cd /tmp/python-build
        
        print_success "Python $full_version 源码编译安装完成"

        # 创建软链接（如果不存在）
        if [ ! -f "/usr/local/bin/python$version" ]; then
          sudo ln -sf /usr/local/bin/python$full_version "/usr/local/bin/python$version"
          print_success "软链接 /usr/local/bin/python$version 创建完成"
        fi
        if [ ! -f "/usr/local/bin/pip$version" ]; then
          sudo ln -sf /usr/local/bin/pip$full_version "/usr/local/bin/pip$version"
          print_success "软链接 /usr/local/bin/pip$version 创建完成"
        fi

        # 配置pip镜像源
        print_progress "正在配置pip镜像源..."
        pip_conf_dir="$HOME/.pip$version"
        mkdir -p "$pip_conf_dir"
        cat > "$pip_conf_dir/pip.conf" << EOF
[global]
index-url = https://mirrors.aliyun.com/pypi/simple/
[install]
trusted-host = mirrors.aliyun.com
EOF
        print_success "pip ($version) 镜像源配置完成: $pip_conf_dir/pip.conf"

        # 配置环境变量（统一加在/etc/profile里）
        python_home="/usr/local"
        env_flag="PYTHON${version//./}_HOME"

        if ! grep -q "export $env_flag=" /etc/profile; then
          print_progress "正在配置Python $version 环境变量..."
          sudo tee -a /etc/profile << EOF
# Python $version 环境变量
export $env_flag=$python_home
export PATH=$python_home/bin:\$PATH
EOF
          print_success "Python $version 环境变量配置完成"
        else
          print_info "Python $version 环境变量已存在，跳过配置"
        fi

        print_success "Python $version 安装和配置完成"
      done

      # 在所有Python版本安装完成后，选择一个默认版本作为python3
      if [ ${#selected_python_versions[@]} -gt 0 ]; then
        # 使用最后安装的版本作为默认python3
        default_version=${selected_python_versions[-1]}
        default_full_version=""
        
        # 获取完整版本号
        case "$default_version" in
          "3.7") default_full_version="3.7.17" ;;
          "3.8") default_full_version="3.8.18" ;;
          "3.9") default_full_version="3.9.18" ;;
          "3.10") default_full_version="3.10.13" ;;
          "3.11") default_full_version="3.11.8" ;;
        esac
        
        # 创建python3软链接
        print_progress "正在设置Python $default_version 为默认Python 3..."
        sudo ln -sf /usr/local/bin/python$default_full_version /usr/local/bin/python3
        sudo ln -sf /usr/local/bin/pip$default_full_version /usr/local/bin/pip3
        
        print_success "已将Python $default_version 设置为默认Python 3"
      fi

      # 清理临时文件
      cd ~
      rm -rf /tmp/python-build
      
      source /etc/profile
      print_success "所有选定的Python版本已安装并配置完成"
    fi  
  else
    # 安装其他软件
    # 检查离线包
    if $offline_mode && check_offline_package "$package" "$package*.rpm"; then
      print_info "使用离线包安装 $package..."
      for rpm_file in $(find "$offline_dir" -name "$package*.rpm" 2>/dev/null); do
        print_info "安装: $rpm_file"
        sudo yum localinstall -y "$rpm_file"
      done
    else
      # 在线安装
      print_info "使用在线方式安装 $package..."
      sudo yum install -y "$package"
    fi
  fi
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
