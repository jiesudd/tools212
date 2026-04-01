

```bash
docker network create teleport-net

#nginx_set.sh 脚本配置参考
#拉取Teleport镜像并生成配置文件
docker pull public.ecr.aws/gravitational/teleport:14.3.36-amd64

# 生成Teleport配置文件模板
docker run --rm \
  --entrypoint=/usr/local/bin/teleport \
  -v $PWD/config:/etc/teleport \
  public.ecr.aws/gravitational/teleport:14.3.36-amd64  \
  configure \
  --cluster-name=school-cluster \
  --roles=auth,proxy \
  > config/teleport.yaml
```

### 配置模板文件：`config/teleport.yaml`

```yaml
version: v3
teleport:
  nodename: teleport-proxy-auth
  data_dir: /var/lib/teleport
  log:
    output: stderr
    severity: INFO
  ca_pin: ""

auth_service:
  enabled: "yes"
  listen_addr: 0.0.0.0:3025
  cluster_name: school-cluster
  proxy_listener_mode: separate

# 关键修改：让Teleport监听内部端口（比如3080），Nginx监听443
proxy_service:
  enabled: "yes"
  # 改为监听内部端口，不与Nginx冲突
  web_listen_addr: 0.0.0.0:3080
  tunnel_listen_addr: 0.0.0.0:3024
  public_addr: "xxxxx:443"
  # 不直接使用SSL证书，由Nginx处理SSL
  https_key_file: ""
  https_cert_file: ""
  # 禁用ACME，由Nginx处理SSL
  acme:
    enabled: no

ssh_service:
  enabled: "no"
```

### 运行 Teleport 主容器及后续配置

```bash
# 运行Teleport主容器
docker run -d \
  --name teleport \
  --restart unless-stopped \
  --entrypoint=/usr/local/bin/teleport \
  --hostname teleport \
  --network teleport-net \
  --network-alias teleport \
  -v ~/teleport/config/teleport.yaml:/etc/teleport/teleport.yaml \
  -v ~/teleport/data:/var/lib/teleport \
  -p 3025:3025 \
  -p 3024:3024 \
  public.ecr.aws/gravitational/teleport:14.3.36-amd64 \
  start -c /etc/teleport/teleport.yaml

curl -k https://xxxxx:443/webapi/ping

# 设置账户
docker exec -it teleport tctl users add admin --roles=editor,access

#然后登录到https://xxxxx:443，使用刚创建的admin账户登录
```

若无法以 root 登录节点，需确保 access 角色配置正确：
操作路径：Web UI -> Management -> Roles -> access
关键配置（注意 YAML 列表格式）：

```yaml
allow:
  logins:
    - "{{internal.logins}}"
    - "root"
    - "xxxxx" 
```

### 设置节点 Token 及运行节点容器

```bash
# 设置节点token
docker exec -it teleport tctl tokens add --type=node --ttl=1h

# 运行Teleport节点容器
# docker stop teleport-node
# docker rm teleport-node
# 域名不对应更换为节点所在服务器的公网IP或域名（校园网，域名不在白名单中）
docker logs -f teleport-node
docker run -d \
  --name teleport-node \
  --restart unless-stopped \
  --entrypoint=/usr/local/bin/teleport \
  --gpus all \
  -v /data:/data \
  --privileged \
  --shm-size 48g \
  -v ~/teleport-node/data:/var/lib/teleport \
  public.ecr.aws/gravitational/teleport:14.3.36-amd64 \
  start \
  --roles=node \
  --token=xxxxx \
  --auth-server=xxxxx:3024 \
  --nodename=campus-node-1 \
  --labels=env=campus,location=school \
  --advertise-ip=auto \
  --insecure

nohup teleport start \
  --config=/dev/null \
  --roles=node \
  --token=xxxxx \
  --auth-server=xxxxx:3024 \
  --nodename=campus-node-master \
  --labels=env=campus_master,location=school_master \
  --advertise-ip=auto \
  --insecure \
  > /var/log/teleport-node.log 2>&1 &
```

### 写入到系统 (Systemd 配置文件)

```ini
# [Unit]
# Description=Teleport Node Service (Campus Master)
# After=network.target

# [Service]
# Type=simple
# # 自动重启设置：如果进程退出，5秒后自动重启
# Restart=always
# RestartSec=5

# # 启动命令（去掉了 nohup 和 &，Systemd 会自动处理后台运行）
# ExecStart=/usr/local/bin/teleport start \
#   --config=/dev/null \
#   --roles=node \
#   --auth-server=xxxxx:3024 \
#   --nodename=campus-node-master \
#   --labels=env=campus_master,location=school_master \
#   --advertise-ip=auto \
#   --insecure

# # 日志重定向
# StandardOutput=append:/var/log/teleport-node.log
# StandardError=append:/var/log/teleport-node.log

# [Install]
# WantedBy=multi-user.target
```

