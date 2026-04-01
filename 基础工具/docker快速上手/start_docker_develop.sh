#!/bin/bash

# 功能：拉起容器、配置网络源、配置SSH远程开发环境
# 使用方法：./auto_setup_container.sh [镜像ID或名称]

set -e  # 遇到错误立即退出
set -o pipefail  # 管道命令中任意错误都会导致整个管道失败

IMAGE=$1
CONTAINER_NAME="develop_container"
PORT=19521
IMAGES_PATH="/data"
LOG_FILE="/tmp/container_setup_$(date +%Y%m%d_%H%M%S).log"

# 日志函数
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

# 检查Docker服务状态
# check_docker() {
#     log "检查Docker服务状态..."
#     if ! systemctl is-active --quiet docker; then
#         log "错误：Docker服务未运行，正在尝试启动..."
#         sudo systemctl start docker || {
#             log "严重错误：无法启动Docker服务"
#             exit 1
#         }
#     fi
#     log "Docker服务运行正常"
# }

# 验证镜像是否存在
validate_image() {
    log "验证镜像 $IMAGE 是否存在..."
    if ! docker image inspect $IMAGE &> /dev/null; then
        log "错误：指定的镜像 $IMAGE 不存在"
        exit 1
    fi
    log "镜像 $IMAGE 验证通过"
}

# 检查容器是否已存在
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

# 拉起容器
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

# 配置容器内网络源
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

# 配置远程开发环境
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

# 主执行流程
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
