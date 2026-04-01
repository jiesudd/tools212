
***

# 在 Ubuntu 上安装 Docker (配置清华源)

本文档整理了在 Ubuntu 系统上完整安装 Docker CE 的步骤，并配置了清华大学开源软件镜像站以加速下载。

## 1. 卸载旧版本

如果你的系统中曾经安装过旧版本的 Docker（如 `docker`, `docker-engine`, `docker.io` 等），请先卸载它们以避免冲突。

```bash
sudo apt-get remove docker docker-engine docker.io containerd runc
```

## 2. 安装必要依赖

更新 `apt` 包索引并安装相关的依赖包，以允许 `apt` 通过 HTTPS 使用存储库。

```bash
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg lsb-release
```

## 3. 添加 Docker 官方 GPG 密钥

创建存放密钥的目录，并下载 Docker 的官方 GPG 密钥进行安全验证。

```bash
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
```

## 4. 设置软件存储库 (切换至清华源)

为了提高在国内的下载速度，我们先将官方源配置写入，然后将其备份，并替换为清华大学的 Docker CE 镜像源。

**步骤 4.1：写入官方源**
```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

**步骤 4.2：备份官方源**
```bash
sudo mv /etc/apt/sources.list.d/docker.list /etc/apt/sources.list.d/docker.list.backup
```

**步骤 4.3：添加清华源**
```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

## 5. 安装 Docker

最后，再次更新 `apt` 索引，并安装最新版本的 Docker 引擎、CLI、containerd 以及 Compose 插件。

```bash
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

**提示**：安装完成后，你可以通过运行 `sudo docker version` 或 `sudo docker run hello-world` 来验证 Docker 是否安装成功。