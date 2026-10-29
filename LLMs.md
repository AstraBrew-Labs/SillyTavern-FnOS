# 飞牛 fnOS 应用开发参考（LLMs.md）

> 面向 AI 编码助手的单文件索引与规范摘要。内容索引自飞牛应用开放平台官方文档，
> 用于在本仓库内快速生成符合规范的 fnOS 应用包。

- **文档来源**：<https://developer.fnnas.com/docs/guide/> · <https://developer.fnnas.com/docs/core-concepts/framework/>
- **机器可读索引**：<https://developer.fnnas.com/llms.txt> · **全文快照**：<https://developer.fnnas.com/llms-full.txt>
- **快照时间**：2026-10-28（对应文档更新日志最新条目 2026-07-31，开放 API 第一期）
- **适用范围**：第三方应用（`source=thirdparty`），应用包格式 `.fpk`

---

## 0. 使用方式（给 AI 的建议阅读顺序）

1. 先读 §2 核心模型，确定应用形态（Native / Docker）与访问模型（端口 / CGI / 网关）。
2. 读 §3 包结构，再读 §4 manifest、§5 权限、§6 资源——这三个文件决定包能否通过 `fnpack` 校验。
3. 有后台进程必须读 §7 生命周期脚本与 §8 环境变量；否则服务无法被系统正确启停与判定状态。
4. 需要桌面图标或文件打开方式读 §9；需要复用 NAS 域名 / WebSocket / 登录态读 §10。
5. 需要读写用户文件、打开系统页面、跟随主题语言，读 §16 开放 API。

**硬性约束（违反即无法安装或运行）**

- 包根目录必须同时存在 `manifest`、`config/privilege`、`config/resource`、`ICON.PNG`、`ICON_256.PNG`，以及 `app/`、`cmd/`、`wizard/` 三个目录。
- 脚本内禁止硬编码安装路径，必须使用 `TRIM_APPDEST` / `TRIM_PKGETC` / `TRIM_PKGVAR` 等环境变量。
- 生命周期脚本必须具备可重复执行能力（安装、升级、配置流程可能被重跑）。
- 自定义向导字段与环境变量不得使用 `TRIM_` 前缀（系统保留）。
- 不要信任客户端传入的用户 ID；统一网关场景必须使用转发 Header。

---

## 1. 上游文档索引

| 主题 | 地址 | 内容要点 |
| --- | --- | --- |
| 欢迎 / 学习路径 | `/docs/guide` | 平台定位、开发流程总览 |
| 更新日志 | `/docs/update-log` | 字段废弃、工具版本、开放 API 上线时间线 |
| 准备工作 | `/docs/quick-started/prerequisites` | 测试设备、开发机、管理员权限、CLI 准备 |
| 创建应用 | `/docs/quick-started/create-application` | 最小包：静态页 + CGI 入口 |
| 测试应用 | `/docs/quick-started/test-application` | 应用中心手动安装 / `appcenter-cli install-fpk` |
| 上架应用 | `/docs/quick-started/publish-application` | 发布材料、发布前测试项 |
| 应用框架 | `/docs/core-concepts/framework` | 安装后目录、生命周期、退出码 |
| Manifest | `/docs/core-concepts/manifest` | 全部字段语义 |
| 环境变量 | `/docs/core-concepts/environment-variables` | `TRIM_*` 全量表 |
| 应用权限 | `/docs/core-concepts/privilege` | 包用户 / 附加组 / root 模式 |
| 应用资源 | `/docs/core-concepts/resource` | `data-share`、`usr-local-linker`、`docker-project` |
| 应用入口 | `/docs/core-concepts/app-entry` | `app/ui/config` 字段、文件打开方式 |
| index.cgi | `/docs/core-concepts/index-cgi` | CGI 轻量入口、静态文件映射范例 |
| 统一网关 | `/docs/core-concepts/gateway-registration` | `gatewayPrefix`/`gatewaySocket`、用户 Header、WebSocket |
| 用户向导 | `/docs/core-concepts/wizard` | 四类向导、字段类型、校验规则 |
| 应用依赖 | `/docs/core-concepts/dependency` | `install_dep_apps` 顺序与版本 |
| 中间件服务 | `/docs/core-concepts/middleware` | Redis / MinIO / RabbitMQ |
| 运行时环境 | `/docs/core-concepts/runtime` | `python312`、`nodejs_v22`、`java-21-openjdk` |
| 图标 | `/docs/core-concepts/icon` | 尺寸、色彩空间、圆角规范 |
| Native 案例 | `/docs/examples/native` | Node + React + 统一网关完整落地 |
| Docker 案例 | `/docs/examples/docker` | Compose + 端口入口完整落地 |
| appcenter-cli | `/docs/cli/appcentercli` | 安装、启停、默认安装位置 |
| fnpack | `/docs/cli/fnpack` | 创建模板、打包、校验清单 |
| 开放 API 概述 | `/api/overview` | 能力边界与阅读顺序 |
| 调用方式 | `/api/calling` | `api-scope`、JS SDK、后端 API 统一调用 |
| 平台配置 | `/api/platform-config` | 语言 / 主题 / 系统版本 |
| 授权与文件概览 | `/api/authorization/overview` | ACL 授权模型、两种授权路线 |
| 应用共享授权 | `/api/authorization/shared-access` | `pickSharedFile`（仅管理员） |
| 用户个人授权 | `/api/authorization/user-access` | `pickUserFile` / `authorizeUserFile` |
| 文件权限检查 | `/api/authorization/file-acl` | `trim.file.checkUserACL` |
| 路径转换 | `/api/authorization/path-convert` | `trim.file.convertPath` |
| 页面路由 | `/api/page/routing` | `openFile` / `showFileDetails` / `openFileManager` |
| 页面交互 | `/api/page/ui` | `setTitle` / `$on` / `setExitPageTips` / `close` |
| 错误码 | `/api/error-codes` | JSSDK 与后端 API 错误码 |

---

## 2. 核心模型

### 2.1 应用包的三个组成部分

| 组成 | 位置 | 作用 |
| --- | --- | --- |
| 元数据与配置 | `manifest`、`config/privilege`、`config/resource` | 系统识别、兼容性校验、运行用户、资源与 Scope 声明 |
| 生命周期脚本 | `cmd/*` | 安装 / 升级 / 卸载 / 配置 / 启停 / 状态 |
| 运行与 UI 资源 | `app/**`、`wizard/*`、`ICON*.PNG` | 程序与静态文件、桌面入口、表单、图标 |

安装后落盘于 `/var/apps/{appname}`，`target` / `etc` / `var` / `tmp` / `home` 均为指向 `/vol{n}/@app*` 的软链。

### 2.2 三种访问模型（关键选型）

| 能力 | 端口服务 | `index.cgi` | 统一网关 |
| --- | --- | --- | --- |
| 入口路径 | `http://host:{service_port}/` | `/cgi/ThirdParty/{appname}/index.cgi/` | `/app/{appname}` |
| 常驻服务 | 适合 | 不推荐 | 适合 |
| WebSocket | 支持 | **不支持** | 支持 |
| NAS 登录态 | 不参与（与登录态无关） | CGI 调用前校验 | 转发前校验 + 用户 Header |
| 性能 | 直连服务 | 每请求启动 CGI 进程 | 转发到长期运行服务 |
| 域名 | 独立端口 | 复用系统访问域名 | 复用系统访问域名 |
| 适配成本 | 最低 | 静态页最低 | 服务需适配前缀与 Socket |

**选型规则**

- 纯静态页 / 兼容老包 → `index.cgi`。
- 独立服务、无需 NAS 身份 → 端口服务（`service_port` + `port` 入口）。
- 需要复用域名、需要当前登录用户身份、需要 WebSocket → 统一网关（推荐用于正式产品）。
- 使用统一网关时，国内版需在 `manifest` 声明足够高的 `os_min_version`（官方示例：`os_min_version=1.1.3100`），且不需要 `service_port`。

### 2.3 Native 与 Docker

| 维度 | Native | Docker |
| --- | --- | --- |
| 交付物 | 可执行二进制 / 脚本 + 打包运行时 | 镜像 + `docker-compose.yaml` |
| 创建命令 | `fnpack create <appname>` | `fnpack create <appname> --template docker` |
| 资源声明 | 可选 `data-share` | 必须 `docker-project` |
| 启停控制 | `cmd/main` 自己管理进程与 PID | 系统按 Compose 管理，`main` 只需 `status` |
| `platform` | 含架构二进制时必须精确（`x86`/`arm`） | 可 `all`，但镜像必须支持目标架构 |
| `config/privilege` | 决定进程身份，必须认真配置 | 不决定容器内身份，保留默认即可 |

---

## 3. 包结构与目录

### 3.1 开发期目录（`fnpack` 生成）

```text
myapp/
├── app/
│   ├── ui/
│   │   ├── config                 # 桌面入口 / 文件打开方式
│   │   ├── images/icon_64.png
│   │   ├── images/icon_256.png
│   │   └── index.cgi              # 仅 CGI 模型需要
│   ├── server/                    # 后端程序（Native，自定义）
│   ├── www/                       # 静态文件（CGI 模型）
│   └── docker/docker-compose.yaml # 仅 Docker 模板
├── cmd/
│   ├── main                       # start / stop / status
│   ├── install_init
│   ├── install_callback
│   ├── upgrade_init
│   ├── upgrade_callback
│   ├── uninstall_init
│   ├── uninstall_callback
│   ├── config_init
│   └── config_callback
├── config/
│   ├── privilege
│   └── resource
├── wizard/                        # install / upgrade / uninstall / config（可空）
├── manifest
├── ICON.PNG                       # 64 x 64
└── ICON_256.PNG                   # 256 x 256
```

### 3.2 安装后目录

```text
/var/apps/{appname}
├── cmd/                 # 生命周期脚本
├── config/{privilege,resource}
├── manifest
├── ICON.PNG / ICON_256.PNG
├── target  -> /vol{n}/@appcenter/{appname}   # 应用文件与运行资源
├── etc     -> /vol{n}/@appconf/{appname}     # 配置
├── var     -> /vol{n}/@appdata/{appname}     # 需持久化的运行数据（日志、PID、DB）
├── tmp     -> /vol{n}/@apptemp/{appname}     # 临时文件
├── home    -> /vol{n}/@apphome/{appname}     # 应用用户数据
├── meta
├── shares/              # config/resource 中声明的共享目录
└── wizard/
```

**目录职责判定**：程序文件 → `target`；用户配置 → `etc`；运行态数据（日志、PID、SQLite） → `var`；可丢弃缓存 → `tmp`；需要用户在文件管理器中看到的内容 → `shares`（`data-share`）。

### 3.3 `fnpack build` 的校验清单

| 路径 | 类型 | 要求 |
| --- | --- | --- |
| `manifest` | 文件 | 存在且含必要字段 |
| `config/privilege` | 文件 | 存在，合法 JSON |
| `config/resource` | 文件 | 存在，合法 JSON |
| `ICON.PNG` / `ICON_256.PNG` | 文件 | 存在 |
| `app/`、`cmd/`、`wizard/` | 目录 | 存在（`wizard/` 可为空目录） |
| `app/{desktop_uidir}/` | 目录 | 声明 `desktop_uidir` 时必须存在 |

---

## 4. `manifest` 全字段

无扩展名，INI 风格 `key=value`，位于包根目录。

| 分组 | 字段 | 取值 / 说明 |
| --- | --- | --- |
| 基础 | `appname` | 应用唯一标识，同时决定 `/var/apps/{appname}` |
| 基础 | `version` | 如 `1.0.0`、`2.1.3-beta` |
| 基础 | `display_name` | 应用中心、设置、UI 中显示名 |
| 基础 | `desc` | 描述，必要时可含 HTML |
| 基础 | `source` | 第三方固定 `thirdparty` |
| 平台 | `platform` | `x86` / `arm` / `all`；`all` 仅当包内无架构相关二进制（原 `arch` 字段已废弃） |
| 开发者 | `maintainer` / `maintainer_url` | 开发者名称 / 站点 |
| 开发者 | `distributor` / `distributor_url` | 发布者（与开发者不同时填写） |
| 兼容 | `os_min_version` | 最低系统版本，按实测值填写 |
| 兼容 | `os_max_version` | 最高系统版本，有明确上限时填写 |
| 运行控制 | `ctl_stop` | `true` 显示启停与状态；`false` 隐藏（静态页 / 配置型应用） |
| 安装 | `install_type` | 空 = 用户选存储位置；`root` = 系统分区 |
| 安装 | `install_dep_apps` | 依赖应用，`:` 分隔，`>` 声明最低版本，如 `database>2.2.2:cache` |
| 桌面 | `desktop_uidir` | UI 目录，默认 `ui` |
| 桌面 | `desktop_applaunchname` | 应用卡片打开的入口 ID，须与 `{desktop_uidir}/config` 中一致 |
| 端口 | `service_port` | 服务端口；不监听固定端口可省略 |
| 端口 | `checkport` | 启动前是否检查端口，默认 `true` |
| 授权 | `disable_authorization_path` | `true` 隐藏应用设置中的授权目录设置（仅在完全不需要用户选目录时） |
| 更新 | `changelog` | 更新说明，面向用户、简洁 |
| 开放 API | `micro_app` | 需要调用前端 JS SDK 时必须为 `true`，否则微应用环境不加载 |

### 示例

```ini
appname=astrabrew-launcher
version=1.0.0
display_name=AstraBrew Launcher
desc=星酿启动器
source=thirdparty
platform=x86

maintainer=AstraBrew Labs
maintainer_url=https://astrabrew.cn

os_min_version=1.1.3100

desktop_uidir=ui
desktop_applaunchname=astrabrew-launcher.Application

ctl_stop=true
checkport=false
```

**注意**：`install_dep_apps` 的多个依赖是**从右到左**安装与启用（`a:b` → 先 `b` 后 `a`）；依赖检查**不递归**，需要间接依赖时必须在当前应用显式声明。

---

## 5. `config/privilege`

```json
{
  "defaults": { "run-as": "package" },
  "username": "myapp_user",
  "groupname": "myapp_group",
  "join-groups": ["video", "render"]
}
```

| 字段 | 说明 |
| --- | --- |
| `run-as` | `package`（专用应用用户，默认推荐）或 `root` |
| `username` / `groupname` | 省略时按 `manifest.appname` 自动生成 |
| `join-groups` | 追加系统用户组，如 `video`、`render`（GPU / 硬件转码） |

**规则**

- 默认 `run-as=package`；每增加一个 `join-groups` 条目都会扩大可访问资源面，只加必需的。
- 长期对外提供访问的进程禁止以 root 运行。确需 root 做特权准备时，用 `runuser -u "$TRIM_USERNAME" -- ...` 降权后再启动服务。
- 应用默认**不**拥有用户文件访问权；访问用户数据必须通过「用户在设置中授权目录」或「`config/resource` 声明 `data-share`」。

---

## 6. `config/resource`

只声明实际使用的资源。四个顶层键：`data-share`、`usr-local-linker`、`docker-project`、`api-scope`。

### 6.1 `data-share`（共享数据目录）

```json
{
  "data-share": {
    "shares": [
      { "name": "myapp/documents" },
      {
        "name": "myapp/backups",
        "permission": { "rw": ["other_app_user"], "ro": ["report_reader"] }
      }
    ]
  }
}
```

- 安装时自动创建，使用 **Windows ACL** 模型（非 POSIX ACL），系统自动为应用运行用户授予所需 ACL。
- 路径获取：`TRIM_DATA_SHARE_PATHS`（`:` 分隔）或软链 `/var/apps/{appname}/share/{子目录}`。
- 命名建议：统一以 `appname` 为顶级目录，再按用途分 `myapp/documents`、`myapp/backups`，避免与其他应用冲突。
- `permission` 仅在需要授权其他应用/用户访问时填写。

### 6.2 `usr-local-linker`（系统链接）

```json
{
  "usr-local-linker": {
    "bin": ["bin/myapp-cli"],
    "lib": ["lib/mylib.so"],
    "etc": ["etc/myapp.conf"]
  }
}
```

分别链接到 `/usr/local/bin`、`/usr/local/lib`、`/usr/local/etc`。可执行文件避免 `cli` / `server` / `tool` 这类通用名，使用 `{appname}-cli`。

### 6.3 `docker-project`

```json
{
  "docker-project": {
    "projects": [{ "name": "myapp-stack", "path": "docker" }]
  }
}
```

`path` 相对于 `app/`，该目录必须包含 `docker-compose.yaml`。

### 6.4 `api-scope`（开放 API 能力声明）

```json
{
  "api-scope": [
    "trim.file.userAccess",
    "trim.file.userAcl",
    "trim.file.path"
  ]
}
```

| Scope | 对应能力 |
| --- | --- |
| `trim.file.sharedAccess` | 管理员为应用授权目录；查询/删除共享授权目录 |
| `trim.file.userAccess` | 当前用户授权自己的目录/文件；查询/删除用户授权目录 |
| `trim.file.userAcl` | 检查指定用户对路径的读/写/删除权限 |
| `trim.file.path` | 内部路径 `/vol1/...` → 语义化展示路径 |
| `trim.system.getPlatformConfig` | 后端读取系统语言与版本 |

声明 Scope 只是接入前提，实际可访问范围仍取决于用户授权、管理员设置与 token 校验。**不要写满全部 Scope。**

---

## 7. 生命周期脚本（`cmd/`）

| 脚本 | 触发时机 |
| --- | --- |
| `install_init` | 安装文件写入**前** |
| `install_callback` | 安装文件写入**后**（首启前初始化放这里） |
| `main` | 接收 `start` / `stop` / `status` |
| `upgrade_init` / `upgrade_callback` | 升级新包写入前 / 后（数据与配置迁移） |
| `uninstall_init` / `uninstall_callback` | 移除文件前 / 清理后 |
| `config_init` / `config_callback` | 配置变更前 / 后（重写配置文件、重启服务） |

### 7.1 退出码

| 码 | 含义 |
| --- | --- |
| `0` | 成功；`status` 中表示正在运行 |
| `1` | 失败 |
| `3` | `status` 中表示未运行 |

`cmd/main` **必须**只接受 `start` / `stop` / `status`，其他参数返回 1 并写入错误日志。`ctl_stop=false` 的应用可只实现 `status`（或全空实现）以隐藏启停按钮。

### 7.2 用户可见错误

失败前把简明、可执行的错误写入 `TRIM_TEMP_LOGFILE`，系统会在安装 / 启动 / 升级 / 配置流程中展示给用户。

```bash
if [ ! -f "$TRIM_PKGETC/config.conf" ]; then
  echo "Missing configuration file." > "$TRIM_TEMP_LOGFILE"
  exit 1
fi
```

### 7.3 `cmd/main` 标准骨架（含 PID 与优雅停止）

```bash
#!/bin/bash

LOG_FILE="${TRIM_PKGVAR}/app.log"
PID_FILE="${TRIM_PKGVAR}/app.pid"
APP_DIR="${TRIM_APPDEST}/server"

log_msg() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"; }
alive()   { kill -0 "$1" 2>/dev/null; }

status_app() {
  [ -f "$PID_FILE" ] || return 1
  local pid; pid="$(head -n 1 "$PID_FILE" | tr -d '[:space:]')"
  [ -n "$pid" ] && alive "$pid" && return 0
  rm -f "$PID_FILE"; return 1
}

start_app() {
  status_app && return 0
  log_msg "Starting ${TRIM_APPNAME} ${TRIM_APPVER}"
  cd "$APP_DIR" || exit 1
  ./myapp --port "$TRIM_SERVICE_PORT" >> "$LOG_FILE" 2>&1 &
  echo "$!" > "$PID_FILE"
}

stop_app() {
  [ -f "$PID_FILE" ] || return 0
  local pid; pid="$(head -n 1 "$PID_FILE" | tr -d '[:space:]')"
  if [ -n "$pid" ] && alive "$pid"; then
    kill -TERM "$pid" 2>> "$LOG_FILE" || true
    local i=0
    while alive "$pid" && [ "$i" -lt 10 ]; do sleep 1; i=$((i+1)); done
    alive "$pid" && kill -KILL "$pid" 2>> "$LOG_FILE" || true
  fi
  rm -f "$PID_FILE"
}

case "$1" in
  start)  start_app ;;
  stop)   stop_app ;;
  status) status_app && exit 0; exit 3 ;;
  *)      echo "Unknown command: $1" > "$TRIM_TEMP_LOGFILE"; exit 1 ;;
esac
```

---

## 8. 环境变量

### 8.1 应用信息

| 变量 | 含义 |
| --- | --- |
| `TRIM_APPNAME` | `manifest.appname` |
| `TRIM_APPVER` | 当前版本 |
| `TRIM_OLD_APPVER` | 升级前的旧版本 |
| `TRIM_APP_STATUS` | 当前操作：`INSTALL` / `START` / `UPGRADE` / `UNINSTALL` / `STOP` / `CONFIG` |

### 8.2 路径

| 变量 | 对应目录 |
| --- | --- |
| `TRIM_APPDEST` | `target`（已安装应用文件） |
| `TRIM_PKGETC` | `etc`（配置） |
| `TRIM_PKGVAR` | `var`（需保留的运行数据） |
| `TRIM_PKGTMP` | `tmp` |
| `TRIM_PKGHOME` | `home` |
| `TRIM_PKGMETA` | `meta` |
| `TRIM_APPDEST_VOL` | 应用所在存储空间根路径 |

### 8.3 用户与权限

`TRIM_USERNAME`、`TRIM_GROUPNAME`、`TRIM_UID`、`TRIM_GID`（应用身份）；`TRIM_RUN_USERNAME`、`TRIM_RUN_GROUPNAME`、`TRIM_RUN_UID`、`TRIM_RUN_GID`（当前脚本执行身份，特权操作时可能不同）。

### 8.4 网络与资源

| 变量 | 含义 |
| --- | --- |
| `TRIM_SERVICE_PORT` | `manifest.service_port` |
| `TRIM_DATA_SHARE_PATHS` | `data-share` 声明的共享路径，`:` 分隔 |
| `TRIM_DATA_ACCESSIBLE_PATHS` | 用户授权的可访问路径，`:` 分隔 |
| `TRIM_API_TOKEN` | 后端调用开放 API 的 Bearer token |

### 8.5 日志与临时目录

`TRIM_TEMP_LOGFILE`（用户可见错误）、`TRIM_TEMP_UPGRADE_FOLDER`、`TRIM_PKGINST_TEMP_DIR`、`TRIM_TEMP_TPKFILE`。

### 8.6 系统上下文

`TRIM_SYS_VERSION`、`TRIM_SYS_VERSION_MAJOR`、`TRIM_SYS_VERSION_MINOR`、`TRIM_SYS_VERSION_BUILD`、`TRIM_SYS_ARCH`、`TRIM_KERNEL_VERSION`、`TRIM_SYS_MACHINE_ID`、`TRIM_SYS_LANGUAGE`。

### 8.7 向导变量

向导字段名直接成为环境变量名，**不带** `TRIM_` 前缀（如 `wizard_port` → `$wizard_port`）。字段名一旦发布应保持稳定。

---

## 9. 应用入口 `app/ui/config`

根对象为 `.url`；入口 ID 建议以 `appname` 为前缀（如 `astrabrew-launcher.main`），并与 `desktop_applaunchname` 一致。

| 字段 | 说明 |
| --- | --- |
| `title` | 入口显示名 |
| `icon` | 相对 UI 目录的图标，`{0}` 表示尺寸占位（`images/icon_{0}.png`） |
| `type` | `iframe`（桌面窗口内） / `url`（浏览器标签或外部 WebView） |
| `protocol` | `http` / `https` / 空字符串（由系统自适应；统一网关与 CGI 忽略此字段） |
| `port` | 服务端口；可用 `${wizard_port}` 引用向导值 |
| `url` | 打开路径；可用 `${wizard_path}` 引用向导值 |
| `allUsers` | 是否对所有用户可见 |
| `fileTypes` | 文件打开方式的扩展名数组 |
| `noDisplay` | 在桌面隐藏入口，仅保留文件操作入口 |
| `control.accessPerm` | `editable` / `readonly` / `hidden`（应用设置中该入口设置的可见性） |
| `gatewayPrefix` | 统一网关公开前缀 `/app/{appname}[/{path}]` |
| `gatewaySocket` | 仅文件名，如 `app.sock`，位于 `target` 下 |

### 9.1 端口服务入口

```json
{
  ".url": {
    "astrabrew-launcher.main": {
      "title": "AstraBrew Launcher",
      "icon": "images/icon_{0}.png",
      "type": "iframe",
      "protocol": "http",
      "port": "8080",
      "url": "/",
      "allUsers": true
    }
  }
}
```

### 9.2 文件打开方式

```json
{
  ".url": {
    "astrabrew-launcher.editor": {
      "title": "AstraBrew Editor",
      "icon": "images/icon_{0}.png",
      "type": "iframe",
      "protocol": "http",
      "port": "8080",
      "url": "/edit",
      "allUsers": true,
      "fileTypes": ["txt", "md", "json"],
      "noDisplay": true
    }
  }
}
```

系统会在 URL 后追加 `path` 查询参数：`http://localhost:8080/edit?path=/vol1/Users/admin/Documents/example.txt`。**该 path 是用户输入**，读取前必须校验。

---

## 10. 统一网关（推荐正式应用使用）

### 10.1 注册

```json
{
  ".url": {
    "astrabrew-launcher.main": {
      "title": "AstraBrew Launcher",
      "icon": "images/icon_{0}.png",
      "type": "iframe",
      "protocol": "",
      "gatewayPrefix": "/app/astrabrew-launcher",
      "gatewaySocket": "app.sock",
      "url": "/app/astrabrew-launcher",
      "allUsers": true
    }
  }
}
```

流程：请求 `/app/astrabrew-launcher` → 系统校验会话 → 转发到 `/var/apps/astrabrew-launcher/target/app.sock` → 应用从 Header 读取用户上下文。

### 10.2 转发 Header

| Header | 说明 | 示例 |
| --- | --- | --- |
| `X-Trim-Userid` | 当前用户 UID | `1000` |
| `X-Trim-Isadmin` | 是否管理员 | `true` / `false` |
| `X-Trim-Username` | 当前用户名 | `admin` |

```js
function getGatewayUser(req) {
  return {
    uid: req.headers["x-trim-userid"],
    isAdmin: req.headers["x-trim-isadmin"] === "true",
    username: req.headers["x-trim-username"],
  };
}
```

### 10.3 应用侧要求

- 服务必须监听 `gatewaySocket` 指定的 Unix Socket，路径为 `${TRIM_APPDEST}/app.sock`；启动前先 `rm -f` 残留 Socket。
- 所有 HTTP 与 WebSocket 路由保持在 `gatewayPrefix` 之下（前端构建 `base` 也要设为该前缀）。
- Docker 应用：把 `${TRIM_APPDEST}` 挂载进容器，让容器内服务在该目录创建 Socket。
- 网关**只校验登录态，不做业务鉴权**。用户只能访问自己的数据；管理接口需 `isAdmin`；文件类接口必须做路径校验（拒绝 `..`、限定目录）。

### 10.4 WebSocket

```js
const wsProtocol = window.location.protocol === "https:" ? "wss:" : "ws:";
const socket = new WebSocket(`${wsProtocol}//${window.location.host}/app/myapp/ws`);
```

连接建立时同样会带上身份 Header，之后应把连接绑定到 `X-Trim-Userid`，不要信任消息体中的用户 ID。

---

## 11. `index.cgi`（轻量入口）

- 位置：`app/ui/index.cgi`（打包工具会处理可执行权限）。
- 入口路径固定为 `/cgi/ThirdParty/{appname}/index.cgi/`，`protocol` 与 `port` 被忽略。
- 不支持 WebSocket、流式响应与长连接；每次请求启动一个 CGI 进程。
- 系统在调用 CGI 前校验 NAS 登录态。

最小静态映射脚本见下（务必保留目录穿越防护）：

```bash
#!/bin/bash
BASE_PATH="/var/apps/{appname}/target/www"
URI_NO_QUERY="${REQUEST_URI%%\?*}"
REL_PATH="/"

case "$URI_NO_QUERY" in
  *index.cgi*) REL_PATH="${URI_NO_QUERY#*index.cgi}" ;;
esac

[ -z "$REL_PATH" ] || [ "$REL_PATH" = "/" ] && REL_PATH="/index.html"

TARGET_FILE="${BASE_PATH}${REL_PATH}"

if echo "$TARGET_FILE" | grep -q '\.\.'; then
  echo "Status: 400 Bad Request"; echo "Content-Type: text/plain; charset=utf-8"
  echo ""; echo "Bad Request"; exit 0
fi

if [ ! -f "$TARGET_FILE" ]; then
  echo "Status: 404 Not Found"; echo "Content-Type: text/plain; charset=utf-8"
  echo ""; echo "404 Not Found"; exit 0
fi

case "${TARGET_FILE##*.}" in
  html|htm) mime="text/html; charset=utf-8" ;;
  css) mime="text/css; charset=utf-8" ;;
  js) mime="application/javascript; charset=utf-8" ;;
  png) mime="image/png" ;;
  jpg|jpeg) mime="image/jpeg" ;;
  svg) mime="image/svg+xml" ;;
  *) mime="application/octet-stream" ;;
esac

echo "Content-Type: $mime"
echo ""
cat "$TARGET_FILE"
```

---

## 12. 用户向导（`wizard/`）

四个文件，均为「步骤数组」：`install`、`upgrade`、`uninstall`、`config`。

```json
[
  {
    "stepTitle": "Setup",
    "items": [
      {
        "type": "text",
        "field": "wizard_port",
        "label": "Service port",
        "initValue": "8080",
        "rules": [
          { "required": true, "message": "Enter a port" },
          { "pattern": "^[0-9]+$", "message": "Use numbers only" }
        ]
      }
    ]
  }
]
```

| 类型 | 用途 |
| --- | --- |
| `text` | 短文本、端口、路径、用户名 |
| `password` | 密钥 / Token |
| `radio` | 少量互斥选项 |
| `checkbox` | 多选 |
| `select` | 较长互斥列表（`options: [{label, value}]`） |
| `switch` | 布尔 |
| `tips` | 只读提示（`helpText`） |

校验规则键：`required`、`min` / `max`、`len`、`pattern`（均支持配套 `message`）。

**打包器校验实测（fnpack 1.2.3，文档未写明）**

失败时的报错为 `File "<向导文件名>" is not valid due to JSON format or content validation failure.`，不指出具体字段，需按下列约束逐项排查：

| 写法 | 结果 |
| --- | --- |
| `[]`（空数组） | 通过 |
| `[{ "stepTitle": "...", "items": [] }]` | **失败**，`items` 不能为空 |
| `"initValue": true`（布尔） | **失败**，`initValue` 必须是字符串 |
| `"initValue": "true"` | 通过 |
| 省略 `initValue` | 通过 |
| `switch` + `helpText` | 通过 |
| `tips` 仅 `helpText`、无 `field` | 通过 |

结论：所有字段值按字符串书写，布尔语义用 `"true"` / `"false"` 表达；`field` 对 `tips` 可省略。

**约定**：自定义字段用 `wizard_` 前缀；不得用 `TRIM_`；值按字符串处理并在脚本内二次校验；密钥不进日志。

---

## 13. 依赖、中间件与运行时

| 类型 | `install_dep_apps` 值 | 说明 |
| --- | --- | --- |
| Redis | `redis` | `127.0.0.1:6379`，建议独立 db 号或 key 前缀 |
| MinIO | `minio` | `127.0.0.1:9000`，凭据不得硬编码进包 |
| RabbitMQ | `rabbitmq` | `127.0.0.1:5672`，使用应用专属队列/交换机 |
| Python | `python312` | `export PATH=/var/apps/python312/target/bin:$PATH` |
| Node.js | `nodejs_v22` | `export PATH=/var/apps/nodejs_v22/target/bin:$PATH` |
| Java | `java-21-openjdk` | `export PATH=/var/apps/java-21-openjdk/target/bin:$PATH` |

调用运行时命令前必须先注入 `bin` 目录到 `PATH`（写在 `cmd/main` 与安装脚本里）。

---

## 14. 图标

| 文件 | 尺寸 | 用途 |
| --- | --- | --- |
| `ICON.PNG` | 64×64 | 包图标、应用中心 |
| `ICON_256.PNG` | 256×256 | 包图标高清 |
| `app/ui/images/icon_64.png`、`icon_256.png` | 同上 | 桌面入口 / 文件打开方式 |

要求：PNG 或 JPG、sRGB、≤ 1024 KB、正方形画布、**主体使用圆角矩形风格**（不要直角满铺），64 px 下主体仍清晰，重要内容不贴边。

---

## 15. CLI

### 15.1 `fnpack`（v1.2.3）

```bash
fnpack create <appname>                              # 普通应用
fnpack create <appname> --without-ui true            # 无桌面入口的服务
fnpack create <appname> --template docker            # Docker 应用
fnpack build                                         # 当前目录打包
fnpack build --directory <path>                      # 指定包目录打包
```

下载页签名版本：`fnpack-1.2.3-{windows-amd64, linux-amd64, linux-arm64, darwin-amd64, darwin-arm64}`，来源 `https://static2.fnnas.com/fnpack/`。

### 15.2 `appcenter-cli`（设备上）

```bash
appcenter-cli install-fpk myapp.fpk
appcenter-cli install-fpk myapp.fpk --env config.env   # 预填向导值
appcenter-cli install-local                            # 从设备上的项目目录打包并安装
appcenter-cli list
appcenter-cli start myapp
appcenter-cli stop myapp
appcenter-cli default-volume        # 查看默认安装位置
appcenter-cli default-volume 1      # 设置默认安装位置
```

`config.env` 形如 `wizard_port=8080`，含密码/Token 的文件不得入库。

---

## 16. 开放 API

**版本门槛**：系统 `1.2.0401+`，App `1.34.0+`。前端调用需 `manifest` 中 `micro_app=true`。

### 16.1 两类接口

| 类型 | 调用位置 | 用途 |
| --- | --- | --- |
| 前端 JS SDK | 应用页面内（`@trimjs/web-app`） | 打开授权/文件选择器、打开系统页面、读平台配置、监听主题语言 |
| 后端 API | 应用服务端，经 Unix Socket | 查授权路径、检查文件 ACL、转换路径、读系统语言版本 |

```bash
npm install @trimjs/web-app
```

```js
import { TrimApp } from '@trimjs/web-app';
const sdk = new TrimApp();
```

**环境判定**：`sdk.isWeb`（是否 Web 运行环境）、`sdk.isStandaloneWeb`（是否独立浏览器页，`true` 表示不在宿主内）。
文件选择/授权类能力：宿主内（`isStandaloneWeb === false`）直接调 `pickUserFile` / `pickSharedFile`；独立浏览器（`true`）走 `openAppAuth` + `redirectUri` 回调。

**授权回调**：`openAppAuth` 默认 `target: '_blank'`；建议配合统一网关，使应用页与回调页同域，回调页用 `parseAppAuthCallback` 解析、校验 `state`、`window.opener.postMessage` 通知原页面并 `window.close()`。原页面必须保留「刷新授权状态」按钮作为兜底（移动端可能无 `opener`）。

### 16.2 后端 API 统一调用

```http
POST /api/v1/trimapp
Unix Socket: /var/run/trim_open_gateway_apiscope.socket
Content-Type: application/json
Authorization: Bearer <TRIM_API_TOKEN>
```

```json
{ "reqId": "1", "req": "trim.system.getPlatformConfig", "appName": "your-app", "data": {} }
```

响应：`{ "reqId": "...", "code": 0, "msg": "", "data": {} }`，`code=0` 为成功。

`TRIM_API_TOKEN` 由系统注入到脚本环境；**每次调用时从环境变量读取**，不得持久化到 DB/文件/前端，重装或重注册后会变化。

### 16.3 JS SDK 方法

| 方法 | 说明 |
| --- | --- |
| `getPlatformConfig()` | 返回 `{theme, language, systemLanguage, appVersion, systemVersion, format:{date,time}}` |
| `pickSharedFile(params?)` | 目录选择器（**仅管理员**），返回授权目录数组 |
| `authorizeSharedFile(path)` | 对已知目录重新申请授权（仅管理员） |
| `pickUserFile(params?)` | 用户选择目录（`directory:true`，单选）或文件（`directory:false`，可 `multiple`、`accept`） |
| `authorizeUserFile(path)` | 对已知用户路径重新申请授权 |
| `openAppAuth(method, params, opts)` | 独立浏览器环境下打开授权页（`target`、`features`、`state`、`redirectUri`） |
| `parseAppAuthCallback(url)` | 回调页解析授权结果 |
| `openFile(path)` | 用宿主能力打开文件 |
| `showFileDetails(paths, opts?)` | 打开文件详情（可调权限） |
| `openFileManager(path)` | 打开文件管理器并定位 |
| `openAppSetting()` | 打开当前应用设置页 |
| `openURL(url, target?, features?)` | 打开外部地址 |
| `setTitle(title)` | 设置窗口标题 |
| `$on('os/theme' \| 'os/language', cb)` | 监听主题/语言，**仅** `isWeb === true && isStandaloneWeb === false` |
| `setExitPageTips({title?, content?}?)` | 设置/清除离开页面提示 |
| `close()` | 关闭当前应用页 |

`FilePickerParams`：`multiple`、`directory`、`accept`（如 `['.png']`）、`sidebarGroup`、`title`、`okText`、`creatable`、`disabledPaths`。
`sidebarGroup` 枚举：`myFiles`、`otherShare`、`external`、`remote`、`favorites`、`team`。

### 16.4 后端 API 能力

| `req` | Scope | 关键参数 | 说明 |
| --- | --- | --- | --- |
| `trim.system.getPlatformConfig` | `trim.system.getPlatformConfig` | `{}` | 返回 `systemLanguage`、`systemVersion` |
| `trim.file.getSharedAccessibleFolders` | `trim.file.sharedAccess` | `{}` | 返回 `data.paths` |
| `trim.file.delSharedAccessibleFolder` | `trim.file.sharedAccess` | `{path}` | 返回 `data.suc` |
| `trim.file.getUserAccessibleFolders` | `trim.file.userAccess` | `{uid}` | 仅目录授权，返回 `data.paths` |
| `trim.file.delUserAccessibleFolder` | `trim.file.userAccess` | `{uid, path}` | 返回 `data.suc` |
| `trim.file.checkUserACL` | `trim.file.userAcl` | `{uid, path \| path[]}` | 返回 `[{path, readable, writable, deletable}]` |
| `trim.file.convertPath` | `trim.file.path` | `{path \| path[], language}` | 返回 `{status, result:[{path, semanticPath}]}` |

**授权模型要点**

- 应用以独立应用用户运行，访问用户文件需系统先把目标路径 ACL 授予该用户；**拿到授权路径 ≠ 绕过当前用户权限**。
- 目录授权可查询（`getUserAccessibleFolders`）；**文件授权不进入该列表**，只能使用选择器/回调返回的路径。
- 共享授权仅支持目录且仅管理员可操作；普通用户调用会得到 `code: 1 / "仅管理员可进行此操作"` 或回调 `status:"error", error:"access_denied"`。
- 返回文件列表前用 `checkUserACL` 按当前 `uid` 校验；路径不存在时三项权限均为 `false`。
- 页面展示路径用 `convertPath`，`language` 必传，不要直接显示 `/vol1/...`。

### 16.5 错误码

JSSDK：`0` 成功；`1000000` 服务/内部异常；`1000001` 登录或认证失败；`1000002` 管理员权限或 Scope 不足；`1000030` 请求不合法/路径不支持；`1000300` 未找到已安装应用；`1000701` 路径不存在；`1003103` 应用权限校验失败（尝试重装）；`1003201` 管理员已关闭该应用的普通用户授权能力。

后端 API：`200001 Invalid Params`（HTTP 200/400）、`200004 Unauthorized`（401，token 无效）、`200003 Forbidden`（403，Scope 未声明）、`200005 Not Found`（404，`req` 写错或版本不支持）、`200006 Internal Error`（200/500）。

---

## 17. 最小可用 Native 应用（统一网关版）

**必要文件清单**

1. `manifest`：`ctl_stop=true`、`desktop_uidir=ui`、`desktop_applaunchname={appname}.main`、`os_min_version` 满足网关要求、按需 `install_dep_apps`。
2. `config/privilege`：`run-as=package` + 应用专属 username/groupname。
3. `config/resource`：按需 `data-share`，加 `api-scope`。
4. `cmd/main`：`export PATH`（运行时）→ 以 `${TRIM_APPDEST}/app.sock` 启动服务 → PID 文件 → `status` 返回 0/3。
5. `app/ui/config`：`gatewayPrefix` + `gatewaySocket` + `url`，`protocol` 留空。
6. `app/server/*`：服务端监听 Unix Socket，同时兼容 `PORT` 用于本地开发；HTTP 与静态资源路由挂在 `GATEWAY_PREFIX` 下。
7. 前端构建 `base` 设为 `/app/{appname}/`，接口用相对/同前缀路径。
8. `ICON.PNG`、`ICON_256.PNG`、`app/ui/images/icon_{0}.png` 对应文件。

**构建脚本尾部**：`fnpack build --directory <packDir>`，产物为 `{appname}.fpk`。

**本地联调**：服务端无 `SOCKET_PATH` 时监听 `PORT`，前端 `vite.proxy` 把 `/app/{appname}` 代理到本地端口，确保本地与安装后路径一致。

---

## 18. 检查清单与常见陷阱

**发布前自检**

- [ ] `fnpack build` 通过（§3.3 全部路径存在）
- [ ] `manifest` 的 `platform` 与包内二进制/镜像架构一致
- [ ] `ctl_stop=false` 仅用于确实无后台进程的应用
- [ ] 脚本全部使用 `TRIM_*` 变量，无硬编码 `/var/apps/...`
- [ ] `cmd/main status` 在服务已停止时确实返回 3
- [ ] 服务启动前清理残留 `app.sock` 与 PID 文件
- [ ] 日志写入 `TRIM_PKGVAR`，不写 `target`
- [ ] 卸载流程尊重用户数据（`wizard/uninstall` 收集「保留或删除」）
- [ ] 网关场景：所有路由在 `gatewayPrefix` 下，`X-Trim-*` 为唯一身份来源
- [ ] 文件接口拒绝 `..`、限定目录、按 `uid` 做 ACL 校验
- [ ] `api-scope` 与实际调用一致，未声明多余 Scope
- [ ] 密钥不进包、不进日志、不进前端

**高频陷阱**

| 现象 | 根因 |
| --- | --- |
| 入口打不开 | `service_port`、Compose 端口映射、入口 `port` 三者不一致 |
| 状态一直「未运行」 | `CONTAINER_NAME` 与 Compose `container_name` 不一致；或 `status` 未按 PID 判断 |
| 网关 502 / 无法转发 | 服务未监听 `${TRIM_APPDEST}/app.sock`，或 Socket 文件名与 `gatewaySocket` 不符 |
| 前端资源 404 | 构建 `base` 未设为 `gatewayPrefix` |
| 前端 `fetch` 报 `Unexpected token 'N', "Not Found" is not valid JSON` | 页面以 `/app/{appname}`（**无结尾斜杠**）打开，相对路径 `./api/` 被当作文档相对解析成 `/app/api/`，命中网关自身的纯文本 404。应按 `location.pathname` 中匹配到的 `/app/{appname}` 前缀拼接绝对 API 路径，并在 `res.json()` 前校验 `Content-Type` |
| JS SDK 调用无响应 | `manifest` 缺少 `micro_app=true`，页面未按微应用环境加载 |
| 后端 API 403 | `config/resource` 未声明对应 `api-scope` |
| 后端 API 401 | 未从当前进程读取 `TRIM_API_TOKEN`（用了旧值或未注入） |
| `$on` 不生效 | 不在 Web 宿主环境（移动端内嵌或独立浏览器） |
| 依赖装不上 | `install_dep_apps` 顺序写反（依赖按右到左启用）或未声明间接依赖 |
| 图标审核不通过 | 直角满铺方形、64 px 不可辨、超过 1024 KB |

---

## 19. 本仓库结构（astrabrew-launcher）

按官方 Native 案例组织：源码工程与应用包同根，前端 React 源码经 Vite 构建后写入 `app/www`，后端为 `app/server/server.js`（零第三方依赖，无需编译）。

```text
astrabrew-launcher/
├── frontend/                 # React 源码（Vite）
│   ├── index.html
│   ├── vite.config.mjs       # base = /app/astrabrew-launcher/，outDir = ../app/www
│   └── src/{main.jsx,App.jsx,api.js,styles.css}
├── scripts/
│   ├── build.js              # 装依赖 → vite build → fnpack build
│   └── dev.js                # 并行启动后端(5001) 与 Vite(5173)
├── app/
│   ├── server/               # 后端（CommonJS，零依赖）
│   ├── ui/                   # 入口配置 + 图标
│   └── www/                  # Vite 构建产物（index.html + assets/）
├── cmd/                      # 9 个生命周期脚本
├── config/{privilege,resource}
├── wizard/uninstall
├── manifest
├── ICON.PNG / ICON_256.PNG
└── package.json              # npm run dev / build
```

| 命令 | 作用 |
| --- | --- |
| `npm run dev` | 后端 + Vite 同启，页面 `http://127.0.0.1:5173/app/astrabrew-launcher/` |
| `npm run build` | 构建前端并打包，产出 `astrabrew-launcher.fpk` |
| `npm run build:ui` | 仅构建前端到 `app/www` |
| `fnpack build` | 仅打包（复用已有 `app/www`，不会重新构建前端） |

**注意**：`app/www` 是构建产物，修改前端后必须重新 `npm run build` 才能进入 FPK。仓库保留已构建的 `app/www`，使 `fnpack build` 可独立执行。

**前端技术栈**：React 19 + HeroUI v3（`@heroui/react` 3.2.x）+ Tailwind CSS v4（`@tailwindcss/vite`）。

- 样式入口 `src/styles.css` 只写 `@import "@heroui/styles";`——该包内部已 `@import "tailwindcss"`，再显式引入一次会重复注入 preflight。
- HeroUI v3 **没有 Provider**，组件使用复合结构（`Card.Header` / `Card.Title` / `Card.Content` / `Card.Footer`），事件用 `onPress` 而非 `onClick`。
- **UI 采用飞牛 fnOS 系统设置风格，固定浅色**：`main.jsx` 写死 `data-theme="light"`，不再跟随系统深浅色。取值来自 fnOS 1.2.0800 设置界面截图取样——内容区白底 `#ffffff`、明细卡片 `#f5f5f5`、概览卡片 `#deecfe`、主色 `#0066fe`、次级文字 `#6e7887`、正文 `#101114`、卡片圆角 8px、卡片间距 10px、卡片内边距 20/18px。
- HeroUI 的语义 token（`--background` / `--surface` / `--accent` / `--muted` / `--radius` 等）在 `styles.css` 中整体覆盖为上述取值，`Chip` / `Spinner` 自动跟随官方配色；卡片与字段版式用 Tailwind 手写，便于精确对齐官方间距（官方卡片标题 13px、标签 12px、值 14px、概览数值 26px semibold）。
- 长路径用 `<wbr>` 在 `/` 处断行，避免 `break-all` 把单词从中间劈开；网格项加 `min-w-0` 防止长路径把轨道撑宽。
- 构建体积：CSS ≈ 424 KB（gzip 40 KB）、JS ≈ 273 KB（gzip 86 KB）。CSS 偏大是因为整包 72 个组件的样式全量引入，需要瘦身时可改为按 `@heroui/styles/components/*.css` 分片引入并自行补齐 `base` / `themes` / `utilities` / `variants`。
- 构建时会出现若干 `Unexpected ")"` CSS 警告，来源是 HeroUI 组件内部 `:is()` / `:not(:is())` 选择器在 Tailwind v4.3 下的编译结果，仅影响 checkbox / radio 的 `transition-property` 规则，不影响本项目使用的组件。

| 实现项 | 取值 |
| --- | --- |
| 访问模型 | 统一网关 `/app/astrabrew-launcher`，Socket `app.sock` |
| 运行时依赖 | `install_dep_apps=nodejs_v22`，`platform=all` |
| 权限 | `run-as=package`，用户/组同为 `astrabrew-launcher` |
| 共享目录 | 单一 `astrabrew-launcher` |
| 卸载 | `wizard/uninstall` 的 `wizard_keep_data`（字符串 `"true"`）控制是否清数据 |
