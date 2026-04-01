## 快速上手VsCode

***\*VsCode下载链接\****：https://code.visualstudio.com/

根据当前系统选择Windows或Linux版本

 

### 首次打开 & 界面认识

- 按 Win + R 输入 code 回车，或桌面搜索“Visual Studio Code”启动。
- 第一次会显示欢迎页，点击 **Get Started** 或直接按 Ctrl + Shift + P 打开命令面板。
- **打开文件夹**：File → Open Folder...（或 Ctrl + K Ctrl + O），建议新建一个测试文件夹（如 C:\vscode-test）。

### 下载完成后注意初始配置：

![image-20260401114325638](C:\Users\洁苏\AppData\Roaming\Typora\typora-user-images\image-20260401114325638.png)

下载后，ctrl+shift+P打开搜索栏，输入Configure Display language，在语言栏换成简体中文再重启VsCode，即可从英文切换成中文

 



#### 其次，还需下载以下拓展：（其它辅助工具如：Codex可按需添加）

![img](file:///C:\Users\洁苏\AppData\Local\Temp\ksohtml45960\wps4.jpg) 

 

### 下载 anaconda 或者 miniconda 环境：

这里给的链接是国内的清华源，可以往下拖，下载Latest版本，带有python后缀只是有个初始的python环境，可下可不下

conda环境： https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/

下载完成后注意在anaconda Prompt中输入conda init powershell与conda init cmd.exe，激活系统环境。

熟悉conda命令符，如：虚拟环境配置，查看当前系统中已有的虚拟环境

当配置环境时，发现无法下载，可能是镜像源的问题，可添加清华源，配置后记得tos接收

此时，再无法下载，就可能是权限问题，用管理员身份打开即可

### 个性化设置（两步搞定）

按 Ctrl + , 打开设置：

- 搜索 “auto save” → 开启 **Auto Save**（防手抖）。
- 搜索 “font” → 调大字体/行高（推荐 Consolas 或 Fira Code）。
- 搜索 “theme” → 换成 Dark+（默认暗黑主题很舒服）。
- 搜索 “language” → 确认已切换中文。

所有设置支持 User（全局）和 Workspace（项目专属）。

###  小贴士 & 常见问题

- **自动更新**：默认开启，启动时会提示更新，保持最新版。
- **远程开发**：安装 **Remote - SSH** 扩展，可直接连 Linux 服务器编辑代码。
- **添加 Git / Node.js 等**：VS Code 会提示安装，跟着走即可。
- **端口/权限问题**：终端里直接用 code . 打开文件夹最稳。

### 常用快捷键（Windows 专属，效率翻倍）

| 操作          | 快捷键                                | 作用         |
| ------------- | ------------------------------------- | ------------ |
| 命令面板      | Ctrl + Shift + P                      | 万能搜索     |
| 快速打开文件  | Ctrl + P                              | 秒找文件     |
| 切换标签页    | Ctrl + Tab                            | 快速切换     |
| 跳转到定义    | F12                                   | 查看函数定义 |
| 重命名符号    | F2                                    | 全项目改名   |
| 打开终端      | Ctrl + `                              | 内置命令行   |
| 折叠/展开代码 | Ctrl + K Ctrl + 0 / Ctrl + K Ctrl + J | 清理视图     |
| 新建文件      | Ctrl + N                              | 快速新建     |
| 保存          | Ctrl + S                              | 保存当前文件 |