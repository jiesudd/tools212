## ***\*如何在本地和服务器使用Clash科学上网\****

### 本地下载网址

[下载安装 - Clash Verge](https://clash-vergec.com.cn/download.html)

![img](file:///C:\Users\洁苏\AppData\Local\Temp\ksohtml45960\wps8.jpg) 

下载完成后，于订阅处导入订阅文件链接即可，具体机场订阅，可以参考以下：

魔戒：https://mojie.app/register?aff=Tuq1IWk0

囡囡喵：https://xn--i2r10aa.com/#/register?code=r9oBQT9m

### 服务器使用方法

- Linux 服务器 手动启动 Clash + 开启 WireGuard VPN  

  1. **快速手动启动**  
  2. **推荐 systemd 方式**（稳定，结合 WireGuard）  

  #### 1. 快速手动启动 

  先 cd 到 Clash 配置目录（或放 clash 二进制的目录）：

  ```bash
  # 示例：用系统级配置目录（推荐）
  cd /etc/clash
  
  # 如果你把 clash 二进制和 config.yaml 都放在同一个自定义目录（如 ~/clash）
  cd ~/clash
  ```

  然后启动 Clash：
  ```bash
  # 你记忆的命令（当前目录有 clash 可执行文件时）
  ./clash -d .
  
  # 或者用全局安装的版本（最常用）
  clash -d /etc/clash
  ```

  **想后台运行（不占用终端）**：
  ```bash
  # 推荐：用 nohup 后台 + 日志
  nohup clash -d /etc/clash > clash.log 2>&1 &
  
  # 查看进程
  ps aux | grep clash
  ```

  **测试 Clash 是否正常**：
  ```bash
  curl -x http://127.0.0.1:7890 https://www.google.com
  ```

  #### 2. 同时开启 WireGuard VPN（服务器 VPN）
  WireGuard安装包：[Installation - WireGuard](https://www.wireguard.com/install/)

  （同样适用于外部连接内部服务器，作为一个IP地址的转发）

  WireGuard 用 systemd 管理，比手动更快：

  ```bash
  # 1. 启动 VPN（wg0 是默认接口）
  sudo systemctl start wg-quick@wg0
  
  # 2. 设置开机自启（推荐）
  sudo systemctl enable wg-quick@wg0
  
  # 3. 查看状态（看到 interface: wg0 就成功）
  sudo wg
  
  # 4. 查看日志（有问题时看这里）
  journalctl -u wg-quick@wg0 -e
  ```

  **停止/重启 VPN**：
  ```bash
  sudo systemctl stop wg-quick@wg0
  sudo systemctl restart wg-quick@wg0
  ```

  #### 3. 推荐：把 Clash 也改成 systemd 自启动（和 VPN 一起）
  如果你不想每次手动 `./clash -d .`，直接用之前我给的 service 文件（已适配）：

  ```bash
  # 如果还没创建 service，再执行一次（复制粘贴）
  sudo tee /etc/systemd/system/clash.service > /dev/null <<EOF
  [Unit]
  Description=Clash daemon
  After=network-online.target wg-quick@wg0.service
  Wants=network-online.target wg-quick@wg0.service
  
  [Service]
  Type=simple
  Restart=always
  ExecStart=/usr/local/bin/clash -d /etc/clash
  
  [Install]
  WantedBy=multi-user.target
  EOF
  
  sudo systemctl daemon-reload
  sudo systemctl enable --now clash
  ```

  这样**重启服务器后 Clash 和 WireGuard 会自动一起启动**，顺序是 VPN 先启动，再 Clash（避免网络冲突）。

  #### 4. 常用检查命令（一目了然）
  ```bash
  # Clash 状态
  sudo systemctl status clash
  journalctl -u clash -f   # 实时日志
  
  # VPN 状态
  sudo systemctl status wg-quick@wg0
  sudo wg show
  
  # 端口占用检查（7890 / 51820）
  ss -tlnp | grep -E '7890|51820'
  ```

  **Clash + WireGuard 共存小贴士**：  
  - WireGuard 是全隧道 VPN（客户端连上来后流量走服务器公网）。  
  - Clash 是本地代理（127.0.0.1:7890）。两者互不冲突。  
  - 如果你想让服务器**所有流量走 Clash 代理**，可以把 Clash 配置的 `tun` 模式打开（需额外权限）。  
  - 想让 WireGuard 客户端只走部分流量 → 修改客户端 config 的 `AllowedIPs`。

  
