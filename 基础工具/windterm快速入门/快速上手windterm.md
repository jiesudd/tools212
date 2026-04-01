## 快速上手windterm

***\*WindTerm的下载链接：\****

https://github.com/kingToolbox/WindTerm/releases/tag/2.7.0

 

### 下载与启动

解压到任意目录（如 D:\Tools\WindTerm），双击 **WindTerm.exe** 即可运行。 **无需管理员权限，无残留**，直接可用。

**升级/迁移提示**（重要）：

- 第一次启动会让你选择 **Profiles 目录**（存放会话配置）。推荐选 **Home 目录**（如 C:\Users\你的用户名），这样以后升级只需替换 .wind 文件夹即可保留所有会话





### 首次打开 & 界面认识

启动后界面干净现代（类似 VS Code 的标签页 + 侧边栏）：

- **左侧**：会话树（Session Tree）——所有保存的服务器一目了然。
- **顶部**：标签页 + 工具栏（新建会话、SFTP、同步输入等）。
- **中间**：终端主窗口（支持分屏、透明度、主题）。
- **底部/右侧**：可打开 Explorer（文件管理）、Shell Pane、Command Palette（Alt+B）。

第一次建议：

- 点击左上角 **New Session**（或 Ctrl+Shift+N）→ 快速新建 SSH。
- 界面支持中文（设置里切换 Language → Chinese）。



### 核心操作：快速连接 Linux 服务器

1. 点击 **New Session** → 选择 **SSH**。
2. 填写：
   - Host：你的服务器 IP 或域名
   - Port：22（默认）
   - Username：root 或你的用户
   - **OneKey**（强烈推荐）：点右侧小钥匙图标 → 新建 OneKey，填密码/私钥，一键自动登录（支持公钥、Expect 方式）。
3. 点击 **Connect**，连上后右键标签页 → **Save Session** 保存（下次直接双击会话树即可连）。
4. 测试：输入 whoami 或 curl -x http://127.0.0.1:7890 https://www.google.com（配合你之前的 Clash 代理）。

**SFTP 文件传输**（超级好用）：

- 连上后点击顶部 **SFTP** 图标 → 自动打开文件浏览器，双向拖拽上传/下载



### 可视化介绍

打开 会话——>新建会话

![img](file:///C:\Users\洁苏\AppData\Local\Temp\ksohtml45960\wps5.jpg) 

进入下面的界面

![img](file:///C:\Users\洁苏\AppData\Local\Temp\ksohtml45960\wps6.jpg) 

主机填写远程主机的Ip地址

标签、分组只是为了方便管理，随意填写即可

如果有涉及代码《可视化》，需改动代理人和X11实现弹窗转发

内置X显示 填写本地IP地址，在命令行窗口输入：ipconfig

![image-20260401114908427](C:\Users\洁苏\AppData\Roaming\Typora\typora-user-images\image-20260401114908427.png)

![image-20260401114925163](C:\Users\洁苏\AppData\Roaming\Typora\typora-user-images\image-20260401114925163.png)

![image-20260401114936668](C:\Users\洁苏\AppData\Roaming\Typora\typora-user-images\image-20260401114936668.png)

其次就是ssh的config文件的存储位置：
默认为（绿色部分为自己的用户名称）

![image-20260401115020688](C:\Users\洁苏\AppData\Roaming\Typora\typora-user-images\image-20260401115020688.png)



### 个性化 & 小贴士

- **设置**：顶部菜单 → Settings → 调字体、主题、自动保存、代理（支持 HTTP/SOCKS5，正好配 Clash）。

- **会话备份**：直接复制 .wind 文件夹即可跨电脑迁移。

- **性能**：内存占用极低，支持 WSL、X11 转发、端口转发。

- **安全提醒**：私钥用 Agent Forwarding（2.7 新增），不用把密钥传到服务器。

- 常见问题

  ：

  - 中文乱码 → Settings → Encoding 选 UTF-8。
  - 首次 Profiles 目录选错 → 退出后删除 .wind 重新启动。
  - 想连 Windows 本机 PowerShell → 新建 Shell 会话即可。

### 常用快捷键

| 操作          | 快捷键           | 作用             |
| ------------- | ---------------- | ---------------- |
| 新建会话      | Ctrl + Shift + N | 快速连服务器     |
| 命令面板      | Alt + B          | 万能搜索         |
| 打开 SFTP     | Ctrl + Shift + F | 文件传输         |
| 同步输入      | Ctrl + Shift + S | 多标签同时发命令 |
| 切换标签      | Ctrl + Tab       | 快速切换         |
| Tmux 放大窗格 | Alt + Z          | 专注模式         |
| 搜索终端内容  | Ctrl + F         | 带预览的高亮搜索 |
| 锁定屏幕      | Ctrl + L         | 防偷看           |