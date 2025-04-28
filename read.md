Docker-compose安装分为离线和线上两种，当`usr/offline/packages/`包下存在`docker-compose-linux-x86_64`就会优先使用，否则就会线上安装，由于走的是github仓库，可能会安装失败

脚本执行命令：

注意：不用使用sh linux.sh命令，这样soucre命令不会生效应执行下述命令

```sh
source linux.sh
或者
. linux.sh
```

![image-20241007135400956](https://blog-1307687732.cos.ap-beijing.myqcloud.com/image-20241007135400956.png)

选择退出就会安装之前以选择的包

![image-20241007135554616](https://blog-1307687732.cos.ap-beijing.myqcloud.com/image-20241007135554616.png)

![image-20241007135638554](https://blog-1307687732.cos.ap-beijing.myqcloud.com/image-20241007135638554.png)