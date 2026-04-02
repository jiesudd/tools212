
**OpenClaw 本地部署完整整理文档**

### 前置准备
1. 创建日志目录并给权限（必须执行，请替换为自己的实际路径）：
   ```bash
   mkdir -p /data/<USERNAME_REDACTED>/openclaw/log 
   chmod 777 /data/<USERNAME_REDACTED>/openclaw/log
   ```

2. **容器启动命令**（请自行修改容器名称及镜像地址）：
   ```bash
   docker run -d \
     --name openclaw \                  # ← 改成你喜欢的名称（如 openclaw-custom）
     --network host \
     -v /data/<USERNAME_REDACTED>/openclaw/log:/home/node/.openclaw \
     -e NODE_OPTIONS="--max-old-space-size=4096" \
     <DOCKER_IMAGE_URL>                 # ← 替换为实际的镜像地址，如 alpine/openclaw:main
   ```

### 步骤 1：配置 Control UI（必须先配置才能用网页管理）
进入挂载目录编辑配置文件：
```bash
cd /data/<USERNAME_REDACTED>/openclaw/log
vim openclaw.js
```

在 `gateway` 对象里**添加或修改**为以下内容（端口 18789 可自行改成不冲突的端口）：

```javascript
gateway: {
  controlUi: { // 添加这个字段
    enabled: true,
    allowedOrigins: [
      'http://<VPN_IP_REDACTED>:18789',      // VPN地址（跳板机）
      'http://127.0.0.1:18789',
      'http://localhost:18789',
    ],
    allowInsecureAuth: true,
  },
  auth: {
    mode: 'token',
    token: '__OPENCLAW_REDACTED__',   // 这个是你自己的 token
  },
},
```

保存后**重启容器**：
```bash
docker restart openclaw
```

### 步骤 2：设置 Token + 通过 VPN 连接网页
1. 再次编辑（一般会自动生成可以跳过这一步就行了） `/data/<USERNAME_REDACTED>/openclaw/log/openclaw.js`，把上面的 `token` 改成你自己想要的（建议复杂一点）：
   ```javascript
   token: '<YOUR_SECURE_TOKEN_HERE>',
   ```

2. 重启容器（同上）。

3. 通过 **VPN** 访问网页控制台：
   ```text
   http://<VPN_IP_REDACTED>:18789
   ```
   （注意：必须走 VPN，否则连不上）

4. 浏览器打开后点击 **Connect**。

5. 如果浏览器提示不安全/证书问题/或者进不了：
   - 谷歌浏览器输入 `chrome://flags/#unsafely-treat-insecure-origin-as-secure`
   - 找到 Insecure origins treated as secure 这一项
   - 在下方的文本框中，填入你的 OpenClaw 地址。例如: `http://<VPN_IP_REDACTED>:18789`, `http://127.0.0.1:18789` (多个地址用逗号隔开)
   - 然后再去访问 `http://<VPN_IP_REDACTED>:18789`
   - 将 `openclaw.js` 文件的 token 输入浏览器 openclaw 的控制界面连接到后端，会显示手动配对。

### 步骤 3：授权浏览器设备
进入容器执行命令：
```bash
docker exec -it openclaw sh
```

在容器内运行：
```bash
openclaw devices list          # 查看待授权设备
openclaw devices approve <id>  # 把 id 替换成 list 里显示的 ID
```

返回浏览器刷新，应该显示 **Connected** ✅

### 步骤 4：添加本地模型（以 Qwen3.5 为例）
继续编辑 `/data/<USERNAME_REDACTED>/openclaw/log/openclaw.js`，在文件最外层添加以下配置（和 gateway 同级）：

```javascript
models: {
  providers: {
    "custom-1": {
      baseUrl: "http://127.0.0.1:8000/v1",
      apiKey: "EMPTY",
      auth: "api-key",
      api: "openai-completions",
      authHeader: false,
      models: [
        {
          id: "qwen3.5",
          name: "Qwen3.5-35B",
          api: "openai-completions",
          reasoning: true,
          input: ["text"],
          cost: {
            input: 0,
            output: 0,
            cacheRead: 0,
            cacheWrite: 0
          },
          contextWindow: 32768,
          maxTokens: 8192,
          compat: {
            maxTokensField: "max_tokens",
            thinkingFormat: "qwen"
          }
        }
      ]
    }
  }
},

agents: {
  defaults: {
    model: "custom-1/qwen3.5"
  }
},
```

保存后**重启容器**：
```bash
docker restart openclaw
```

### 完成验证
- 网页控制台显示 Connected
- 在 OpenClaw 里能看到模型 `custom-1/qwen3.5` 并可直接使用

**小贴士**：
- 所有配置都在 `/data/<USERNAME_REDACTED>/openclaw/log/openclaw.js` 一个文件里，改完记得重启容器。
- 跳板机只开放 VPN 端口，外部无法直连，安全性更高。
- 需要改端口、路径、模型名称时，直接对应修改即可。