# CentOS 7 基础环境安装脚本使用文档 🚀

这是一套用于在 CentOS 7 系统上快速部署基础开发环境的脚本集合。主要包含三个脚本文件，分别用于安装基础软件包、配置 Docker 容器环境以及初始化 XXL-JOB 数据库。

## 📁 脚本文件说明

### 1. linux.sh 🛠️
这是主脚本文件，用于安装和配置基础软件环境。主要功能包括：

- 更新 yum 源（可选择阿里云镜像源）
- 安装常用开发工具和软件：
  - vim、net-tools、tree 等基础工具 📝
  - Docker 和 Docker Compose 🐳
  - Git 📚
  - Maven 🏗️
  - OpenJDK（支持 1.8 和 11 版本）☕
  - Node.js 💚
  - Nginx 🌐

### 2. install_containers.sh 🐋
这是 Docker 容器安装脚本，主要功能包括：

- 创建 Docker 网络
- 支持安装以下容器：
  - MySQL 8.0.29 🗄️
  - Redis 6.2 📦
  - MinIO 📂
  - XXL-JOB 🔄

### 3. xxl-job.sql 📊
XXL-JOB 的数据库初始化脚本，包含：

- 创建数据库和表结构
- 初始化基础数据
- 默认管理员账号配置

## 🚀 使用方法

### 1. 准备工作 📋

1. 将所有脚本文件上传到 CentOS 7 服务器的同一目录下
2. 确保脚本具有执行权限：
```bash
chmod +x linux.sh install_containers.sh
```
### 2. 运行主脚本 ▶️
```bash
source ./linux.sh [离线安装包目录]
或者
. linux.sh [离线安装包目录]
```
参数说明：

- [离线安装包目录] ：可选参数，指定离线安装包的目录路径，默认为 "usr/offline/packages/",主要用来存放`docker-compose-linux-x86_64`包,名字只能为这个

### 3. 交互式安装过程 🔄
1. 首先会询问是否更新 yum 源：
2. 选择要安装的软件包：
- 使用数字选择要安装的软件
- 可以多选
- 选择"退出"结束选择
3. 对于特定软件的特殊选项：
   - OpenJDK：可选择版本（1.8 或 11）☕
   - Docker：自动配置阿里云镜像源 🐳
   - Node.js：自动配置 npm 淘宝镜像源并安装 pnpm 💚
4. 最后会询问是否关闭防火墙 🛡️
### 4. 安装 Docker 容器 🐋
主脚本安装完成后，如果选择了 Docker，会自动执行 install_containers.sh ：

1. 输入要创建的 Docker 网络名称 🌐
2. 选择要安装的容器：
   
   - MySQL 🗄️
   - Redis 📦
   - MinIO 📂
   - XXL-JOB 🔄
3. 根据选择的容器，依次配置：
   
   - MySQL：
     
     - 端口号
     - root 密码
     - 数据存储目录
     - 配置目录
     - 日志目录
     - 初始化脚本目录
   - Redis：
     
     - 端口号
     - 密码
     - 容器端口号
   - MinIO：
     
     - 服务端口号
     - 控制台端口号
     - 登录用户名和密码
     - 服务器地址
     - 存储目录
     - 配置目录
   - XXL-JOB：
     
     - 端口号
     - MySQL 容器信息
     - SQL 文件路径
     - 日志目录

## ⚠️ 注意事项
1. 脚本需要 root 权限或 sudo 权限才能执行
2. 建议在全新的 CentOS 7 系统上运行
3. 确保服务器能够访问外网（如果不使用离线安装包）
4. 安装 XXL-JOB 之前必须先安装并启动 MySQL
5. 所有目录路径请使用绝对路径
6. 建议在安装前备份重要数据
## 📋 默认配置
- Docker 版本：25.0.1 🐳
- MySQL 版本：8.0.29 🗄️
- Redis 版本：6.2 📦
- Node.js 版本：16 💚
- XXL-JOB 版本：2.4.0 🔄

### Docker Compose 安装说明 🐳
根据脚本内容，Docker Compose 的安装支持两种方式：

#### 1:离线安装方式 📦
当系统中存在离线安装包时，脚本会优先使用离线安装：

- 安装包路径： usr/offline/packages/docker-compose-linux-x86_64
- 安装步骤：
  
1. 复制安装包到目标目录
```bash
sudo cp "usr/offline/packages/docker-compose-linux-x86_64" /usr/local/bin/docker-compose
```
2. 添加执行权限
```bash
sudo chmod +x /usr/local/bin/docker-compose
```
3. 创建软链接
```bash
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
```
#### 2.在线安装方式 🌐
当系统中不存在离线安装包时，脚本会尝试在线安装：



d:\project\shell\
├── install_containers.sh          # 主脚本
├── common\
│   └── utils.sh                   # 公共函数库
└── containers\
    ├── mysql.sh                   # MySQL容器安装脚本
    ├── redis.sh                   # Redis容器安装脚本
    ├── nginx.sh                   # Nginx容器安装脚本
    ├── mongodb.sh                 # MongoDB容器安装脚本
    ├── rabbitmq.sh                # RabbitMQ容器安装脚本
    ├── elasticsearch.sh           # Elasticsearch容器安装脚本
    └── portainer.sh               # Portainer容器安装脚本