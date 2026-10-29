# SillyTavern · 飞牛 fnOS 版

把 **SillyTavern 官方原版**打包成飞牛 OS 的应用，装完即可用，不需要 SSH、不懂命令行也能跑起来。

- 上游项目：<https://github.com/SillyTavern/SillyTavern>（AGPL-3.0）
- 本包版本：`1.19.0-2`，对应上游 **1.19.0**
- 应用标识：`sillytavern`

> 版本号规则：`1.19.0-2` 中 `1.19.0` 跟随上游官方版本，`-2` 是本封装包的修订号。上游升版会变成 `1.20.0-1`，本包自身修复则递增后缀（`1.19.0-3`）。源码按上游 **tag** 拉取，声明的版本与实际部署的代码始终一致。

---

## 它做了什么

官方 SillyTavern 需要自己装 Node.js、clone 仓库、`npm install`、改 `config.yaml`、处理进程守护。本包把这一整套收进 fnOS 的应用生命周期里：

| 你原本要手动做的 | 本包的处理 |
| --- | --- |
| 安装 Node.js 22 | 声明为依赖，安装应用时自动装上 `nodejs_v22` |
| 安装 Git | 声明为依赖，自动安装；同时注入到服务进程环境，供「安装扩展」使用 |
| `git clone` 上游源码 | 安装时自动拉取指定 tag（含国内镜像回退） |
| `npm install` | 自动执行，走 npmmirror 优先 |
| 改端口 / 监听地址 / 白名单 | 自动写入 `config.yaml`，端口在安装向导里填 |
| 进程守护、开机自启 | 由应用中心托管，有启停按钮与运行状态 |
| 聊天记录备份 | 数据落在共享目录，文件管理器里直接可见 |

---

## 环境要求

| 项 | 要求 |
| --- | --- |
| 系统 | fnOS ≥ **1.1.3100** |
| 架构 | x86 / ARM 均可（包内无架构相关二进制，依赖在目标机安装） |
| 磁盘 | 预留 ≥ 1.5 GB（源码 + `node_modules`） |
| 网络 | 安装时 NAS 需能访问 GitHub 与 npm 源 |

`nodejs_v22` 与 `git` 会作为依赖自动安装，**不需要你手动准备**。

---

## 安装方式

### 方式一：应用中心手动安装（推荐，小白用这个）

1. 获取安装包 `sillytavern.fpk`：从发布页下载，或在仓库根目录执行 `fnpack build` 自行生成
2. 打开飞牛 OS → **应用中心** → 右上角 **手动安装**（或「+」→ 安装本地应用）
3. 选择 `sillytavern.fpk`
4. 向导里只填一项：**服务端口**（默认 `11451`，被占用时改成 5000-65535 之间其它值）
5. 等待安装完成 —— 首次会拉取源码并安装依赖，视网络约 3-10 分钟
6. 安装完成后点击桌面图标，浏览器打开 `http://NAS地址:11451`

安装过程若有问题，应用中心会弹出具体原因（本包会把日志尾部一并回显）。

### 方式二：SSH 命令行安装

适合想看详细日志、或图形界面安装失败的场景。

```bash
# 1. 把 fpk 传到 NAS，例如 /vol1/1000/
# 2. 安装
appcenter-cli install-fpk /vol1/1000/sillytavern.fpk

# 3. 查看状态 / 启动
appcenter-cli list
appcenter-cli start sillytavern
```

命令行会输出具体校验项，比图形界面的「安装失败」更好定位问题。

### 方式三：从源码目录直接安装（开发者）

适用于改完本包脚本后立刻验证，不必先打包：

```bash
git clone <本仓库地址> sillytavern
cd sillytavern
fnpack build                  # 可选，生成 fpk
appcenter-cli install-local   # 直接在设备上打包并安装
```

> `fnpack` 与 `appcenter-cli` 说明见 <https://developer.fnnas.com/docs/cli/fnpack>。前者在开发机上用，后者在飞牛设备上用。

---

## 安装后

### 访问

浏览器打开 `http://NAS地址:11451`（端口以你安装时填的为准）。桌面图标走的是同一个地址。

### 数据在哪

| 内容 | 路径 |
| --- | --- |
| 聊天记录、角色卡、预设、世界书 | `/vol1/@appshare/sillytavern/data/` |
| 程序源码与依赖 | `/vol1/@appdata/sillytavern/sillytavern/` |
| 运行配置 `config.yaml` | `/vol1/@appdata/sillytavern/sillytavern/config.yaml` |
| 运行日志 | `/vol1/@appdata/sillytavern/logs/app.log` |
| 安装日志 | `/vol1/@appdata/sillytavern/logs/install.log` |

共享目录里的 `data/` 就是 SillyTavern 的 `data` 目录，可以直接用文件管理器拖入角色卡（PNG 角色卡放 `data/default-user/characters/`）。

### 修改端口

应用中心 → SillyTavern → **应用设置** → 服务端口。保存后服务自动重启，旧端口立即释放。

### 升级

直接安装新版 `sillytavern.fpk` 覆盖即可：

- **不需要重新填端口**，升级流程没有任何向导
- 端口、`config.yaml`、聊天记录、角色卡全部保留
- 若新包对应的上游版本不同，会自动把源码替换到新版本并重装依赖

### 卸载

应用中心卸载时会询问 **是否保留聊天记录与角色卡**：

- 保留（默认）→ 只删程序，共享目录里的数据不动，重装后可继续用
- 删除 → 连同 `data/` 一起清除，不可恢复

---

## 内置的默认配置

本包会在**每次启动前**把 `config.yaml` 的这些键强制同步一次，避免历史配置或上游默认值把服务带偏：

```yaml
port: 11451            # 跟随安装向导 / 应用设置
listen: true           # 允许非本机访问
listenAddress:
  ipv4: '0.0.0.0'
  ipv6: '[::]'         # 内核启用 IPv6 时自动开启双栈
whitelistMode: true
whitelist:
  - 127.0.0.1
  - '::1'
  - 0.0.0.0/0          # 等效全放行
  - '::/0'
basicAuthMode: false
browserLaunch:
  enabled: false       # NAS 无图形环境，不尝试拉起浏览器
```

两点说明：

1. **白名单为什么要写 `0.0.0.0/0`**：SillyTavern 自身有个硬性检查——监听非 localhost 且白名单/鉴权全关时会直接 `process.exit(1)` 拒绝启动。所以白名单必须开启，而 `0.0.0.0/0` + `::/0` 让它在语义上等同于完全放开。`::/0` 不能省，否则 IPv6 客户端会被挡住。
2. **没有账号密码**：访问控制按需求关闭了。任何能连到该端口的人都能进入酒馆、读写全部角色卡与聊天记录。

> ⚠️ 因此**不建议把该端口直接映射到公网**。确需外网访问，请前置一层反向代理（带 Basic Auth）或走 VPN / FN Connect，不要裸奔。

---

## 常见问题

**安装很慢或卡在拉取源码**

首次安装要下载上游源码（含 npm 依赖）。源码拉取按「直连 GitHub → ghfast.top → gh-proxy.org → gt.astrabrew.cn」依次重试，npm 依赖按「npmmirror → 官方源」重试。全部失败会回显日志尾部，细节看 `logs/install.log`。

**应用显示「未运行」或启动失败**

看 `logs/app.log` 末尾。安装/启动失败时，应用中心弹窗也会带上这段日志。常见原因：

| 日志关键字 | 原因 | 处理 |
| --- | --- | --- |
| `EADDRINUSE` | 端口被占用 | 应用设置里换端口 |
| `EACCES` | 共享目录权限异常 | 重装应用（会重建权限） |
| `Could not resolve host` | NAS 无法访问外网 | 检查 DNS / 网络 |

**安装扩展时报 `Internal Server Error`**

SillyTavern 装扩展是调用系统 `git` 去 clone。本包已在启动时把 git 与其 `git-core` 注入服务进程环境，并写入 `safe.directory`。若仍报错，看 `logs/app.log`：

- `spawn git ENOENT` → Git 依赖没装好，应用中心确认 `git` 已安装启用
- `remote-https is not a git command` → exec-path 未生效，把 `git --exec-path` 输出反馈
- `unable to access` / `Could not resolve host` → NAS 到 GitHub 不通，属网络问题

**想改白名单 / 加访问密码**

当前版本刻意不做这些设置项。需要的话直接改 `config.yaml`（`whitelistMode`、`basicAuthMode` 等），但注意下次启动会被强制同步回默认值——若确实需要长期生效，请提需求，我把对应设置项加回应用设置页。

**升级后端口变了？**

不会。升级流程不写入端口。历史版本中有过一次「8000 视为未设置并迁移到 11451」的逻辑，已在 `1.19.0-1` 移除。

---

## 仓库结构

```text
sillytavern/
├── manifest                 # 应用元数据（版本、依赖、入口）
├── config/
│   ├── privilege            # 以独立应用用户运行
│   └── resource             # 声明共享目录
├── app/
│   ├── server/patch-config.js   # config.yaml 行级改写器（保留注释与未涉及键）
│   └── ui/{config,images}       # 桌面入口与图标
├── cmd/                     # 生命周期脚本
│   ├── main                 # start/stop/status：git 环境注入、配置同步、进程管理
│   ├── install_callback     # 拉源码、装依赖、生成配置、数据目录链接
│   ├── upgrade_callback     # 版本比对与源码替换（不动端口）
│   └── ...
├── wizard/{install,config,uninstall}
└── tests/simtest.sh         # 本地冒烟测试（54 项断言，无需真机）
```

本地校验：

```bash
bash tests/simtest.sh        # 生命周期与配置同步的全链路回归
fnpack build                 # 打包，产出 sillytavern.fpk
```

---

## 许可

本封装包仅为部署脚本与配置，SillyTavern 本体版权归其作者所有，遵循 **AGPL-3.0**。使用与分发请遵守上游许可。
