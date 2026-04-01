# Docker 快速上手


## 1) 概念与常用命令

- 镜像（Image）：运行环境模板，包含系统、依赖、工具、应用代码，类似 C++ 的类。
- 容器（Container）：镜像运行后的实例，类似 C++ 的对象。
- Dockerfile：构建镜像的脚本。
- 仓库（Registry）：存放镜像的服务器，如 Docker Hub、Harbor、阿里云镜像仓库。
- 数据卷/挂载（Volume/Bind Mount）：把容器数据映射到宿主机，避免容器删除后数据丢失。


```bash
# 查看 Docker 版本
docker version

# 查看本机镜像
docker images

# 查看正在运行的容器
docker ps

# 查看全部容器（含已退出）
docker ps -a

# 进入容器
docker exec -it <容器名> bash

# 查看容器日志
docker logs -f <容器名>

# 停止 / 启动 / 删除容器
docker stop <容器名>
docker start <容器名>
docker rm -f <容器名>
```

## 2) 网络模式与端口映射

### 2.1 常见网络模式

- bridge（默认）：容器在独立网络命名空间，适合大多数场景。容器间通信推荐配合自定义网络使用。
- host：容器与宿主机共享网络栈。性能高，但端口隔离弱，Linux 常用。
- none：不给容器分配网络。

### 2.2 端口映射

- `-p 宿主机端口:容器端口`，例如 `-p 19520:22`。
- 外部访问走宿主机 IP + 宿主机端口，不是容器 IP。

## 3) 挂载

### 3.1 Bind Mount（绑定挂载）

- 形式：`-v /host/path:/container/path[:ro|rw]`
- 特点：直接映射宿主机目录，开发调试最常用。
- 示例：`-v /data:/data`

### 3.2 Volume（Docker 管理卷）

- 形式：`-v volume_name:/container/path`
- 特点：由 Docker 管理，迁移和备份更标准，适合数据库等持久化场景。

### 3.3 只读挂载建议

- 对系统目录或驱动信息推荐加 `:ro`，降低误操作风险。
- 例如：`-v /usr/local/Ascend:/usr/local/Ascend:ro`

## 4) 操作链路：打包、分发、部署

- 打包：把环境和应用做成镜像（`docker build`）。
- 分发：把镜像推送到仓库（`docker push`）。
- 部署：在任意机器拉取并启动（`docker run`）。

这样可以保证不同机器上运行环境一致，便于迁移和复现。

## 5) 拉起容器

### 5.1快速拉起容器（Ascend 示例）
```bash
docker run -d --name=code_dev \
  -p 19520:22 \
  -p 19521:8000 \
  -p 19522:8001 \
  --privileged \
  --shm-size 40g \
  --security-opt seccomp=unconfined \
  -v /data:/data \
  -v /usr/local/Ascend:/usr/local/Ascend:ro \
  -v /etc/ascend_install.info:/etc/ascend_install.info:ro \
  -v /sys/kernel/debug:/sys/kernel/debug:rw \
  --device=/dev/davinci0 \
  --device=/dev/davinci1 \
  --device=/dev/davinci2 \
  --device=/dev/davinci3 \
  --device=/dev/davinci_manager \
  --device=/dev/hisi_hdc \
  arm64v8/ubuntu:20.04 \
  tail -f /dev/null
```

进入容器后配置 SSH：

```bash
docker exec -it code_dev bash

apt update
apt install -y net-tools gdb openssh-server vim

# 可选：设置 root 密码
passwd

# 编辑 SSH 配置
vim /etc/ssh/sshd_config
  LogLevel INFO
  PermitRootLogin yes
  PasswordAuthentication yes
  Subsystem sftp /usr/lib/openssh/sftp-server

#重启ssh服务
service ssh start
```

此时可通过 `root@宿主机IP -p 19520` 连接容器。

### 5.2完整拉起容器


1. 镜像校验（镜像是否存在）。
2. 同名容器处理（提示删除或退出）。
3. 启动容器（端口、挂载、设备、重启策略）。
4. 配置容器内 apt 源。
5. 安装 SSH 与基础工具，设置 root 密码。
6. 输出连接信息与日志路径。


容器参数(采用的镜像源，挂载目录，网络模式，指定端口根据具体需求改)
```bash
IMAGE=$1
CONTAINER_NAME="develop_container"
PORT=19521
IMAGES_PATH="/data"
LOG_FILE="/tmp/container_setup_$(date +%Y%m%d_%H%M%S).log"
```

<details>
<summary>入口函数</summary>

```bash
main() {
    log "开始容器自动化配置"
    log "日志文件: $LOG_FILE"
    
    validate_image
    check_existing_container
    launch_container
    configure_network
    configure_remote

    log "\n容器配置已完成！"
    log "容器名称: $CONTAINER_NAME"
    log "容器ID: $(docker inspect --format '{{.Id}}' $CONTAINER_NAME | cut -c1-12)"
    log "SSH连接信息:"
    log "  主机: $(docker inspect --format '{{.NetworkSettings.IPAddress}}' $CONTAINER_NAME)"
    log "  端口: $PORT"
    log "  用户: root"
    log "  密码: 您刚才设置的密码"
    log "\n您可以使用以下命令进入容器:"
    log "docker exec -it $CONTAINER_NAME /bin/bash"
    log "或通过SSH连接容器(使用主机的ip地址，这个脚本是容器的ip无法连接shh的):"
    log "ssh root@$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $CONTAINER_NAME) -p $PORT"
    log "\n详细日志已保存到: $LOG_FILE"
}

main
```
</details>


<details>
<summary>镜像检查</summary>

```bash
validate_image() {
    log "验证镜像 $IMAGE 是否存在..."
    if ! docker image inspect $IMAGE &> /dev/null; then
        log "错误：指定的镜像 $IMAGE 不存在"
        exit 1
    fi
    log "镜像 $IMAGE 验证通过"
}
```

</details>



<details>
<summary>检查是否有同名容器</summary>

```bash
check_existing_container() {
    log "检查是否已存在同名容器..."
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log "发现已存在的容器 $CONTAINER_NAME"
        read -p "是否要删除现有容器？(y/n): " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            log "正在删除现有容器..."
            docker rm -f $CONTAINER_NAME || {
                log "错误：无法删除容器 $CONTAINER_NAME"
                exit 1
            }
        else
            log "用户选择保留现有容器，退出脚本"
            exit 0
        fi
    fi
}
`
</details>



<details>
<summary>拉起容器</summary>

```bash
launch_container() {
    log "正在拉起容器 $CONTAINER_NAME..."
    log "使用镜像: $IMAGE"
    log "端口映射: $PORT->22"
    log "数据卷挂载: $IMAGES_PATH -> /data"
    log "GPU支持: 启用"

    docker run -itd \
      --name $CONTAINER_NAME \
      -p $PORT:22 \
      --privileged \
      --gpus all \
      --restart=unless-stopped \
      --shm-size 32g \
      -v $IMAGES_PATH:/data \
      $IMAGE \
      /bin/bash || {
        log "错误：容器启动失败"
        exit 1
    }

    log "等待容器启动..."
    sleep 2

    if ! docker ps | grep -q $CONTAINER_NAME; then
        log "错误：容器 $CONTAINER_NAME 启动后未运行"
        docker logs $CONTAINER_NAME | tee -a $LOG_FILE
        exit 1
    fi

    log "容器 $CONTAINER_NAME 已成功启动 (ID: $(docker inspect --format '{{.Id}}' $CONTAINER_NAME | cut -c1-12))"
}
```
</details>



<details>
<summary>配置容器网络</summary>

```bash
configure_network() {
    log "开始配置容器内的网络源..."

    NETWORK_SETUP_SCRIPT=$(mktemp)
    cat > "$NETWORK_SETUP_SCRIPT" << 'EOF'
#!/bin/bash

set -e
set -o pipefail

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始网络配置"

# 检查系统类型
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 检测系统信息:"
echo "发行版: $(lsb_release -ds 2>/dev/null || cat /etc/*release 2>/dev/null | head -n1)"
echo "内核版本: $(uname -r)"
echo "架构: $(uname -m)"

# 备份sources.list
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 备份源列表..."
cp -v /etc/apt/sources.list /etc/apt/sources.list.bak

# 修改sources.list
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 配置清华源..."
sed -i 's|http://.*archive.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list
sed -i 's|http://.*security.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 修改后的源列表:"
cat /etc/apt/sources.list | head -n5

# 更新软件包
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 更新软件包列表..."
apt-get update -o Debug::pkgProblemResolver=yes 2>&1 | tee /tmp/apt_update.log

# 检查更新结果
if grep -q "Failed" /tmp/apt_update.log; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 警告：更新过程中发现错误"
    grep "Failed" /tmp/apt_update.log
fi

# 临时替换为 HTTP 源（非加密，仅用于安装证书）
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 临时使用HTTP源安装证书..."
sed -i 's|https://|http://|g' /etc/apt/sources.list
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 临时源列表:"
cat /etc/apt/sources.list | head -n5

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 更新临时源..."
apt-get update -o Debug::pkgProblemResolver=yes 2>&1 | tee /tmp/apt_update_temp.log

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 安装ca-certificates..."
apt-get install -y ca-certificates 2>&1 | tee /tmp/cert_install.log

# 恢复 HTTPS 源
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 恢复HTTPS源..."
sed -i 's|http://|https://|g' /etc/apt/sources.list
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 最终源列表:"
cat /etc/apt/sources.list | head -n5

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 最终更新..."
apt-get update -o Debug::pkgProblemResolver=yes 2>&1 | tee /tmp/apt_update_final.log

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 网络配置完成"
EOF

    log "生成网络配置脚本: $NETWORK_SETUP_SCRIPT"
    docker cp "$NETWORK_SETUP_SCRIPT" "$CONTAINER_NAME:/tmp/setup_network.sh"
    docker exec "$CONTAINER_NAME" chmod +x /tmp/setup_network.sh
    log "正在容器内执行网络配置..."
    docker exec "$CONTAINER_NAME" /tmp/setup_network.sh | tee -a $LOG_FILE
    rm -f "$NETWORK_SETUP_SCRIPT"

    log "网络源配置完成，检查结果..."
    docker exec "$CONTAINER_NAME" cat /etc/apt/sources.list | head -n5 | tee -a $LOG_FILE
}
```
</details>



<details>
<summary>配置SSH连接</summary>

```bash
configure_remote() {
    log "开始配置远程开发环境..."

    REMOTE_SETUP_SCRIPT=$(mktemp)
    cat > "$REMOTE_SETUP_SCRIPT" << 'EOF'
#!/bin/bash

set -e
set -o pipefail

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始远程开发环境配置"

# 更新软件包列表
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 更新软件包列表..."
apt-get update -o Debug::pkgProblemResolver=yes 2>&1 | tee /tmp/remote_apt_update.log

# 检查并安装SSH服务
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 检查SSH服务..."
if ! command -v ssh &> /dev/null; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SSH未安装，正在安装openssh-server..."
    apt-get install -y openssh-server 2>&1 | tee /tmp/ssh_install.log
    
    if ! command -v ssh &> /dev/null; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 错误：无法安装openssh-server"
        cat /tmp/ssh_install.log
        exit 1
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SSH安装成功"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SSH已安装 (版本: $(ssh -V 2>&1))"
fi

# 安装必要工具
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 安装必要工具..."

# === 防止 tzdata 交互 ===
export DEBIAN_FRONTEND=noninteractive
ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo 'Asia/Shanghai' > /etc/timezone
apt-get update -y
apt-get install -y tzdata 2>&1 | tee /tmp/tools_install.log

apt-get install -y vim net-tools gdb cmake build-essential 2>&1 | tee /tmp/tools_install.log

# 配置SSH
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 配置SSH服务..."
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 备份原始配置文件..."
cp -v /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 修改SSH配置..."
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sed -i 's/#Port 22/Port 22/g' /etc/ssh/sshd_config
echo "LogLevel DEBUG3" >> /etc/ssh/sshd_config

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 当前SSH配置:"
grep -E 'PermitRootLogin|PasswordAuthentication|Port|LogLevel' /etc/ssh/sshd_config

# 创建SSH目录
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 检查SSH目录..."
mkdir -pv /var/run/sshd

# 生成SSH密钥
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 生成SSH主机密钥..."
ssh-keygen -A -v

# 启动SSH服务
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 启动SSH服务..."
if [ -d /run/systemd/system ]; then
    systemctl start ssh 2>/dev/null || {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] systemd启动失败，尝试传统方式..."
        /etc/init.d/ssh start
    }
else
    /etc/init.d/ssh start
fi

# 检查SSH服务状态
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 检查SSH服务状态..."
if ! ps aux | grep -v grep | grep -q sshd; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 警告：SSH进程未运行"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 尝试重新启动SSH服务..."
    /etc/init.d/ssh restart
    sleep 2
    if ! ps aux | grep -v grep | grep -q sshd; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 错误：SSH服务启动失败"
        journalctl -u ssh --no-pager 2>/dev/null || cat /var/log/auth.log 2>/dev/null
        exit 1
    fi
fi

# 设置SSH服务开机自启
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 设置SSH开机自启..."
echo "service ssh restart" >> ~/.bashrc
echo "succeed..."

# 修改root密码
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 请设置root密码："
passwd

# 配置git凭证存储
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 检查并安装git..."
if ! command -v git &> /dev/null; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Git未安装，正在安装..."
    apt-get install -y git 2>&1 | tee /tmp/git_install.log
    
    if ! command -v git &> /dev/null; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 警告：无法安装git"
        cat /tmp/git_install.log
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Git安装成功 (版本: $(git --version))"
    fi
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Git已安装 (版本: $(git --version))"
fi

# 配置git凭证存储（仅在git可用时）
if command -v git &> /dev/null; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 配置git凭证存储..."
    git config --global credential.helper store
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Git配置完成"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 跳过git配置，因为git不可用"
fi

# 显示网络信息
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 当前网络配置："
ifconfig || ip a

# 显示SSH服务状态
echo "[$(date '+%Y-%m-%d %H:%M:%S')] SSH服务状态："
if [ -d /run/systemd/system ]; then
    systemctl status ssh --no-pager 2>/dev/null || {
        echo "[WARNING] 无法使用systemctl检查状态，尝试其他方法..."
        /etc/init.d/ssh status 2>/dev/null || {
            echo "[INFO] 使用进程检查方式..."
            ps aux | grep -v grep | grep sshd
            netstat -tuln | grep ':22' || ss -tuln | grep ':22'
        }
    }
else
    if [ -f /etc/init.d/ssh ]; then
        /etc/init.d/ssh status 2>/dev/null || {
            echo "[INFO] 使用进程检查方式..."
            ps aux | grep -v grep | grep sshd
            netstat -tuln | grep ':22' || ss -tuln | grep ':22'
        }
    else
        echo "[INFO] 直接检查SSH进程和端口..."
        ps aux | grep -v grep | grep sshd
        netstat -tuln | grep ':22' || ss -tuln | grep ':22'
    fi
fi

# 获取容器IP地址
CONTAINER_IP=$(hostname -I | awk '{print $1}')
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 容器IP地址: $CONTAINER_IP"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 您可以使用以下命令从外部连接到容器:"
echo "ssh root@${CONTAINER_IP} -p $PORT"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 远程开发环境配置完成"
EOF

    log "生成远程配置脚本: $REMOTE_SETUP_SCRIPT"
    docker cp "$REMOTE_SETUP_SCRIPT" "$CONTAINER_NAME:/tmp/setup_ssh.sh"
    docker exec "$CONTAINER_NAME" chmod +x /tmp/setup_ssh.sh
    log "正在容器内执行远程配置..."
    docker exec -it "$CONTAINER_NAME" /tmp/setup_ssh.sh | tee -a $LOG_FILE
    rm -f "$REMOTE_SETUP_SCRIPT"

    log "远程开发环境配置完成"
}
```
</details>





## 6) 构建自己的镜像

- 编写Dockerfile

```bash
ARG BASE_IMAGE=artifact.cloudwalk.work/rd_docker_release/nvidia/tritonserver-dev:24.03-py3-base
FROM ${BASE_IMAGE}

# This image is intentionally "runtime-like": sPilot mounts /models from host and runs:
#   /models/engine.video_structure_v2/launcher ...
# launcher will start tritonserver + tisv1_adapter.

COPY opt/tritonserver /opt/tritonserver

# Compatibility libs (copied from shared disk into build context by scripts)
COPY compat/triton_compat /opt/tensorrtserver/lib
COPY compat/opencv32 /opencv32
COPY compat/opencv45 /opencv45
COPY compat/openjp2 /openjp2
COPY compat/trtcompat /trtcompat
COPY compat/jpeg /jpeg_compat
COPY compat/png /png_compat
COPY compat/mkl /mkl_compat
COPY compat/cuda /cuda_compat
COPY compat/tiff /tiff_compat
COPY compat/openexr /openexr_compat
COPY compat/webp /webp_compat
COPY compat/jbig /jbig_compat

ENV LD_LIBRARY_PATH=/opt/tensorrtserver/lib:/opt/tritonserver/lib:/opt/tritonserver/backends/cpppipe:/trtcompat:/opencv32:/opencv45:/openjp2:/jpeg_compat:/png_compat:/mkl_compat:/cuda_compat:/tiff_compat:/openexr_compat:/webp_compat:/jbig_compat
ENV LD_PRELOAD=/openjp2/libopenjp2.so.2.3.1
ENV LD_BIND_NOW=1

```


- 从 Dockerfile 构建镜像

当前目录已有 `Dockerfile.engine`，可参考：

```bash
docker build -f Dockerfile.engine \
  -t your_registry/engine:1.0.0 \
  .
```

- 给镜像打标签

```bash
docker tag your_registry/engine:1.0.0 your_registry/engine:latest
```

- 登录仓库并推送

```bash
docker login your_registry
docker push your_registry/engine:1.0.0
docker push your_registry/engine:latest
```

- 其他机器拉取并运行

```bash
docker pull your_registry/engine:1.0.0
docker run -d --name engine_service your_registry/engine:1.0.0
```

常见仓库：

- Docker Hub
- Harbor（企业私有仓库常用）
- 阿里云容器镜像服务 ACR





## 7) 多容器通信

推荐使用“自定义 bridge 网络 + 服务名互访”。

### 7.1 创建网络

```bash
docker network create dev_net
docker network ls
```

### 7.2 把多个容器放入同一网络

```bash
docker run -d --name redis --network dev_net redis:7
docker run -d --name app --network dev_net -p 18080:8080 my_app:latest
```

### 7.3 容器间通过“容器名”访问

在 `app` 容器里连接 Redis：

```bash
redis-cli -h redis -p 6379
```

注意点：

- 同一自定义网络内，Docker 自带 DNS，`redis` 会自动解析到对应容器 IP。
- 容器间通信不需要 `-p`，`-p` 是给“宿主机/外部访问容器”用的。

### 7.4 已启动容器补加网络

```bash
docker network connect dev_net code_dev
docker network inspect dev_net
```






## 8) 常见问题与排错

### 8.1 端口访问失败

- 检查容器是否在运行：`docker ps`
- 检查端口映射：`docker port <容器名>`
- 检查容器内服务是否真的监听目标端口：`ss(netstat) -tulnp | grep :<端口>`


### 8.2 容器里无法联网

- 检查 DNS：`cat /etc/resolv.conf`
- 检查网络：`docker network inspect bridge`
- 必要时换源后再 `apt update`。

### 8.3 文件改了但容器里看不到

- 检查挂载路径是否正确。
- 检查读写权限（宿主机目录权限、是否用了 `:ro`）。

### 8.4 镜像太大    

- 清理构建缓存：`docker builder prune`
- 尽量减少无用层，合并命令，及时清理包缓存。



## 9) 当前目录内可直接参考的文件

- `my_docker_300i.sh`：Ascend 容器快速拉起脚本样例。
- `start_docker_develop.sh`：启动开发环境脚本样例。
- `Dockerfile.engine`：业务镜像构建示例（包含兼容库与运行时环境变量）。


