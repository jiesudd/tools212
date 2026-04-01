
***

# 模型微调与部署完整步骤

## 1. 下载模型

首先，安装 ModelScope 用于下载大语言模型：

```bash
pip install modelscope
```

创建保存模型的文件夹（在调试环境下可以赋予 777 权限）：

```bash
sudo mkdir -p Meta-Llama-3.1-8B-Instruct-AWQ-INT4
sudo chmod -R 777 Meta-Llama-3.1-8B-Instruct-AWQ-INT4
```

下载目标大模型 `Meta-Llama-3.1-8B-Instruct-AWQ-INT4`：

```bash
modelscope download --model LLM-Research/Meta-Llama-3.1-8B-Instruct-AWQ-INT4 --local_dir ./Meta-Llama-3.1-8B-Instruct-AWQ-INT4
```

---

## 2. 拉起开发容器

> **前提条件**：在拉取容器前，请确保本地已有 `cuda-12.2` 的开发容器环境（非 CUDA 开发容器也可，后期可通过 Conda 管理），并已配置好 NVIDIA 的容器工具（NVIDIA Container Toolkit）。

将下方代码保存为 `auto_setup_container.sh` 脚本，然后通过以下指令一键拉起开发容器：

```bash
# 脚本启动指令 (使用对应的镜像)
bash auto_setup_container.sh docker.m.daocloud.io/nvidia/cuda:12.2.0-devel-ubuntu22.04
```

**`auto_setup_container.sh` 完整脚本如下：**

```bash
#!/bin/bash
# 功能：拉起容器、配置网络源、配置SSH远程开发环境，只支持22的系统
# 使用方法：./auto_setup_container.sh [镜像ID或名称]

set -e  # 遇到错误立即退出
set -o pipefail  # 管道命令中任意错误都会导致整个管道失败

IMAGE=$1
CONTAINER_NAME="llamafactory_demo"
PORT=1925
IMAGES_PATH="/data"
LOG_FILE="/tmp/container_setup_$(date +%Y%m%d_%H%M%S).log"

# 日志函数
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

# 检查Docker服务状态
check_docker() {
    log "检查Docker服务状态..."
    if ! systemctl is-active --quiet docker; then
        log "错误：Docker服务未运行，正在尝试启动..."
        sudo systemctl start docker || {
            log "严重错误：无法启动Docker服务"
            exit 1
        }
    fi
    log "Docker服务运行正常"
}

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
      --gpus all \
      -p $PORT:22 \
      --privileged \
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
    check_docker
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

---

## 3. 环境配置与 LLaMA-Factory 准备

1. 使用 VSCode 连接到容器。
2. 进入容器后，找到合适的工作路径，拉取 `LLaMA-Factory` 的源码（可能需要挂全局代理或 VPN）。
3. 激活 Conda 环境，配置 Pip 清华源，并在终端内依次执行：

```bash
# 建立 Conda 环境
conda create -n llamafctory_demo

# 激活环境并安装 Python (建议 3.11 或 3.12 以上版本)
conda activate llamafctory_demo
conda install python==3.12

# 配置 Pip 清华源
pip config set global.index-url https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple

# 克隆源码并安装依赖
git clone --depth 1 https://github.com/hiyouga/LLaMA-Factory.git
cd LLaMA-Factory
pip install -e .
pip install -r requirements/metrics.txt

# 安装量化支持包
pip install autoawq --no-build-isolation
pip install gptqmodel==5.6.0
```

4. **量化工具兼容性修复**：
   运行以下命令替换底层包中的不兼容函数引用：
```bash
sed -i 's/PytorchGELUTanh/GELUActivation/g' /root/miniconda3/envs/llamafctory_demo/lib/python3.12/site-packages/awq/quantize/scale.py
```

5. **检查安装是否成功**：
```bash
llamafactory-cli version 
```

---

## 4. 启动模型微调

目标模型是量化模型，在此我们采用量化的 LoRA 配置文件，参考路径如下：
`LLaMA-Factory/examples/train_qlora/llama3_lora_sft_awq.yaml`

启动训练指令（**注意**：需在 `LLaMA-Factory` 根目录下执行）：

```bash
llamafactory-cli train examples/train_qlora/llama3_lora_sft_awq.yaml \
    learning_rate=1e-4 \
    logging_steps=1
```

**对应的 `llama3_lora_sft_awq.yaml` 配置文件参考：**

```yaml
### model
model_name_or_path: TechxGenus/Meta-Llama-3-8B-Instruct-AWQ
trust_remote_code: true

### method
stage: sft
do_train: true
finetuning_type: lora
lora_rank: 8
lora_target: all

### dataset
dataset: identity,alpaca_en_demo
template: llama3
cutoff_len: 2048
max_samples: 1000
preprocessing_num_workers: 16
dataloader_num_workers: 4

### output
output_dir: saves/llama3-8b/lora/sft
logging_steps: 10
save_steps: 500
plot_loss: true
overwrite_output_dir: true
save_only_model: false
report_to: none  # choices: [none, wandb, tensorboard, swanlab, mlflow]

### train
per_device_train_batch_size: 1
gradient_accumulation_steps: 8
learning_rate: 1.0e-4
num_train_epochs: 3.0
lr_scheduler_type: cosine
warmup_ratio: 0.1
bf16: true
ddp_timeout: 180000000

### eval
# val_size: 0.1
# per_device_eval_batch_size: 1
# eval_strategy: steps
# eval_steps: 500
```

---

## 5. 模型推理服务部署 (vLLM)

我们通过 vLLM 进行模型推理。演示服务器中已经拉取了最新的 vLLM 镜像，通过 Docker 运行推理服务：

```bash
docker run -d --runtime nvidia --gpus all \
    --name vllm_llama3_lora \
    --ipc=host \
    -p 8000:8000 \
    -v /data/lx:/data/lx \
    91g4yzlo8rrzsyhevr.xuanyuan.run/vllm/vllm-openai:latest \
    --model /data/lx/llm_models/Meta-Llama-3.1-8B-Instruct-AWQ-INT4 \
    --quantization awq \
    --enable-lora \
    --lora-modules my_finetuned_model=/data/lx/LLaMA-Factory/saves/Meta-Llama-3.1-8B-Instruct-AWQ-INT4/lora/sft \
    --max-lora-rank 16 \
    --max-cpu-loras 8 \
    --max-model-len 30000 \
    --enable-auto-tool-choice \
    --tool-call-parser llama3_json
```

**查看 vLLM 的运行日志：**

```bash
docker logs -f vllm_llama3_lora
```

**测试模型推理接口**：

使用 Curl 发送请求测试微调后的模型是否生效：

```bash
curl http://localhost:8000/v1/chat/completions \
 -H "Content-Type: application/json" \
 -d '{
   "model": "my_finetuned_model",
   "messages": [
     {"role": "user", "content": "Who created you?"}
   ],
   "temperature": 0.0
 }'
```

**预期输出（响应示例）**：
输出符合训练数据预期的格式，证明微调加载成功：

```json
{
  "id": "chatcmpl-b4c40454a7416cb8",
  "object": "chat.completion",
  "created": 1774956082,
  "model": "my_finetuned_model",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "Hi there, I'm {{name}}, an AI assistant developed by {{author}}. How can I assist you today?",
        "refusal": null,
        "annotations": null,
        "audio": null,
        "function_call": null,
        "tool_calls": [],
        "reasoning": null
      },
      "logprobs": null,
      "finish_reason": "stop",
      "stop_reason": null,
      "token_ids": null
    }
  ],
  "service_tier": null,
  "system_fingerprint": null,
  "usage": {
    "prompt_tokens": 36,
    "total_tokens": 61,
    "completion_tokens": 25
  }
}
```

---

## 6. 内网穿透与 Agent 快速开发准备

> **注意**：跳板机必须配置好 VPN 和 IP 白名单。若是生产环境，建议使用 Nginx 进行反向代理。

如果需要进行 Agent 的快速开发与本地联调，可通过以下命令将大模型所在服务器的 `8000` 端口安全映射到跳板机（实现内网穿透）：

```bash
AUTOSSH_GATETIME=0 autossh -M 0 -fN \
  -o "ServerAliveInterval 30" \
  -o "ServerAliveCountMax 3" \
  -o "ExitOnForwardFailure yes" \
  -o "StrictHostKeyChecking no" \
  -R 0.0.0.0:18088:0.0.0.0:8000 \
  root@xxxxxx
```