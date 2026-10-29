#!/bin/bash
# 本地冒烟测试：假 server.js + 假 TRIM_* 环境，覆盖安装、启动期配置同步、设置变更与生命周期
# 不联网、不触碰真实 fnOS 目录，全部在 .workbuddy/simtest 下进行

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SIM="${ROOT}/.workbuddy/simtest"
rm -rf "${SIM}"
mkdir -p "${SIM}/var" "${SIM}/etc" "${SIM}/target/server" "${SIM}/share/sillytavern/data" "${SIM}/home" "${SIM}/tmp"

export TRIM_APPNAME="sillytavern"
export TRIM_APPVER="1.4.0-test"
export TRIM_PKGVAR="${SIM}/var"
export TRIM_PKGETC="${SIM}/etc"
export TRIM_PKGTMP="${SIM}/tmp"
export TRIM_PKGHOME="${SIM}/home"
export TRIM_APPDEST="${SIM}/target"
export TRIM_DATA_SHARE_PATHS="${SIM}/share/sillytavern"
export TRIM_TEMP_LOGFILE="${SIM}/err.txt"
export TRIM_UID="$(id -u)"
export TRIM_GID="$(id -g)"

cp "${ROOT}/app/server/patch-config.js" "${SIM}/target/server/patch-config.js"

ST_VERSION="$(awk -F'"' '/^ST_VERSION=/{print $2; exit}' "${ROOT}/cmd/install_callback")"
ST_VERSION="$(awk -F'"' '/^ST_VERSION=/{print $2; exit}' "${ROOT}/cmd/install_callback")"
ST_HOME="${SIM}/var/sillytavern"
CFG="${ST_HOME}/config.yaml"
PATCHER="${SIM}/target/server/patch-config.js"
mkdir -p "${ST_HOME}/node_modules" "${ST_HOME}/default"
printf '{"name":"sillytavern","version":"1.99.0-test"}\n' > "${ST_HOME}/package.json"

# 复刻 SillyTavern 的安全门槛：listen=true 且无白名单/鉴权/override 时 process.exit(1)
cat > "${ST_HOME}/server.js" <<'JS'
const fs = require('fs');
const http = require('http');
const cfg = fs.readFileSync('./config.yaml', 'utf8');
const val = (k) => {
  const m = cfg.match(new RegExp('^' + k + ':\\s*(\\S+)', 'm'));
  return m ? m[1].replace(/['"]/g, '') : '';
};
const listen = val('listen') === 'true';
const secure = val('whitelistMode') === 'true' || val('basicAuthMode') === 'true' || val('securityOverride') === 'true';
if (listen && !secure) {
  console.error('Your current SillyTavern configuration is insecure (listening to non-localhost).');
  process.exit(1);
}
const portArg = process.argv.indexOf('--port');
const port = portArg > -1 ? Number(process.argv[portArg + 1]) : 8000;
http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end('sillytavern-fake-ok');
}).listen(port, '127.0.0.1', () => console.log(`fake server on ${port}`));
JS

# 与上游 default/config.yaml 结构一致：默认 8000、仅本机白名单、IPv6 关闭
cat > "${ST_HOME}/default/config.yaml" <<'YAML'
dataRoot: ./data
port: 8000
listen: false
listenAddress:
  ipv4: 0.0.0.0
  ipv6: '[::]'
protocol:
  ipv4: true
  ipv6: false
browserLaunch:
  enabled: true
  browser: 'default'
whitelistMode: true
whitelist:
  - ::1
  - 127.0.0.1
whitelistDockerHosts: true
basicAuthMode: false
basicAuthUser:
  username: user
  password: password
YAML

FAILED=0
pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; FAILED=1; }
expect_eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1（期望 $3，实际 $2）"; fi }
probe_ok() { curl -fsS --max-time 4 "http://127.0.0.1:$1/" 2>/dev/null | grep -q "sillytavern-fake-ok"; }
probe_down() { ! curl -fsS --max-time 2 "http://127.0.0.1:$1/" >/dev/null 2>&1; }
block_value() { awk -v b="$1" -v k="$2" '$0 ~ "^"b":" {f=1;next} f&&/^[^[:space:]]/{exit} f&&$0 ~ "^[[:space:]]+"k":" {print $2; exit}' "${CFG}" | tr -d "'\""; }

echo "=== A. 安装：不带任何参数，全部走默认值 ==="
bash "${ROOT}/cmd/install_callback" >/dev/null 2>&1
expect_eq "install_callback 退出码" "$?" "0"

[ -L "${ST_HOME}/data" ] && pass "data 软链已建立" || fail "data 软链缺失"
[ -f "${CFG}" ] && pass "config.yaml 生成于 etc" || fail "config.yaml 缺失"
grep -qx "port: 11451" "${CFG}" && pass "默认端口 11451" || fail "默认端口不是 11451"
grep -qx "listen: true" "${CFG}" && pass "已启用监听（局域网可访问）" || fail "listen 未开启"
expect_eq "监听地址 ipv4" "$(block_value listenAddress ipv4)" "0.0.0.0"
expect_eq "监听地址 ipv6" "$(block_value listenAddress ipv6)" "[::]"
expect_eq "协议 ipv4" "$(block_value protocol ipv4)" "true"
EXPECT_V6=$([ -s /proc/net/if_inet6 ] && printf true || printf false)
expect_eq "协议 ipv6（随内核栈自动判定）" "$(block_value protocol ipv6)" "${EXPECT_V6}"
grep -qx "whitelistMode: true" "${CFG}" && pass "白名单常开（满足上游安全门槛）" || fail "白名单未开启"
grep -qx "  - 0.0.0.0/0" "${CFG}" && pass "IPv4 全放行 0.0.0.0/0" || fail "缺少 0.0.0.0/0"
grep -qx "  - '::/0'" "${CFG}" && pass "IPv6 全放行 ::/0" || fail "缺少 ::/0"
grep -qx "basicAuthMode: false" "${CFG}" && pass "账号鉴权已关闭" || fail "账号鉴权未关闭"
grep -q "^securityOverride" "${CFG}" && fail "不应再依赖 securityOverride" || pass "未依赖 securityOverride 豁免"
grep -qx "${ST_VERSION}" "${SIM}/var/sillytavern.version" && pass "版本号记录为上游 ${ST_VERSION}" || fail "版本号未按上游记录"
grep -qx "${ST_VERSION}" "${SIM}/var/sillytavern.version" && pass "版本号记录为上游 ${ST_VERSION}" || fail "版本号未按上游记录"
grep -q "^  enabled: false" "${CFG}" && pass "browserLaunch 已关闭" || fail "browserLaunch 未关闭"

bash "${ROOT}/cmd/main" start >/dev/null 2>&1
expect_eq "main start 退出码" "$?" "0"
probe_ok 11451 && pass "11451 端口可访问" || fail "11451 端口不可访问"
grep -q "git: /" "${SIM}/var/logs/app.log" && pass "启动日志记录了 git 与 exec-path" || fail "未记录 git 环境"

echo
echo "=== A2. 回归：config 残留上游默认 8000 时，启动应自愈为 11451 ==="
node "${PATCHER}" "${CFG}" "port=!8000" >/dev/null 2>&1
grep -qx "port: 8000" "${CFG}" && pass "已构造 8000 残留" || fail "构造残留失败"
bash "${ROOT}/cmd/main" stop >/dev/null 2>&1
bash "${ROOT}/cmd/main" start >/dev/null 2>&1
probe_ok 11451 && pass "启动后落在 11451" || fail "启动后未落在 11451"
grep -qx "port: 11451" "${CFG}" && pass "config 已被改回 11451" || fail "config 仍是 8000"

echo
echo "=== A3. 旧版软链配置迁移为实体文件 ==="
bash "${ROOT}/cmd/main" stop >/dev/null 2>&1
cp "${CFG}" "${SIM}/etc/legacy-config.yaml"
node "${PATCHER}" "${SIM}/etc/legacy-config.yaml" "port=!7777" >/dev/null 2>&1
rm -f "${CFG}"
ln -sfn "${SIM}/etc/legacy-config.yaml" "${CFG}"
bash "${ROOT}/cmd/main" start >/dev/null 2>&1
[ ! -L "${CFG}" ] && pass "软链已替换为实体文件" || fail "软链未被替换"
grep -qx "port: 7777" "${CFG}" && pass "迁移后沿用旧端口 7777" || fail "迁移后端口丢失"
probe_ok 7777 && pass "7777 端口可访问" || fail "7777 端口不可访问"

echo
echo "=== A4. 启动前自愈：whitelistMode 被关闭时应被重新开启（否则上游 exit 1）==="
node "${PATCHER}" "${CFG}" "whitelistMode=!false" >/dev/null 2>&1
grep -qx "whitelistMode: false" "${CFG}" && pass "已构造 whitelistMode=false" || fail "构造失败"
bash "${ROOT}/cmd/main" stop >/dev/null 2>&1
bash "${ROOT}/cmd/main" start >/dev/null 2>&1
grep -qx "whitelistMode: true" "${CFG}" && pass "启动前已恢复白名单" || fail "白名单未被恢复"
probe_ok 7777 && pass "恢复后服务正常" || fail "恢复后服务异常"

echo
echo "=== B. 设置页：改端口为 8125 ==="
wizard_port="8125" bash "${ROOT}/cmd/config_callback" >/dev/null 2>&1
expect_eq "config_callback 退出码" "$?" "0"
grep -qx "port: 8125" "${CFG}" && pass "端口已改为 8125" || fail "端口未更新"
probe_ok 8125 && pass "8125 端口可访问" || fail "8125 端口不可访问"
probe_down 11451 && pass "旧端口 11451 已释放" || fail "旧端口仍占用"
bash "${ROOT}/cmd/main" status && pass "status=0" || fail "status 非 0"

echo
echo "=== C. 端口校验 ==="
wizard_port="80" bash "${ROOT}/cmd/config_init" >/dev/null 2>&1
[ $? -ne 0 ] && pass "端口 80 被拒绝" || fail "端口 80 未被拒绝"
wizard_port="70000" bash "${ROOT}/cmd/config_init" >/dev/null 2>&1
[ $? -ne 0 ] && pass "端口 70000 被拒绝" || fail "端口 70000 未被拒绝"
wizard_port="abc" bash "${ROOT}/cmd/config_init" >/dev/null 2>&1
[ $? -ne 0 ] && pass "非数字端口被拒绝" || fail "非数字端口未被拒绝"
wizard_port="11451" bash "${ROOT}/cmd/config_init" >/dev/null 2>&1
expect_eq "合法端口通过" "$?" "0"

echo
echo "=== D. 幂等、升级迁移与卸载 ==="
bash "${ROOT}/cmd/install_callback" >/dev/null 2>&1
expect_eq "重装（无向导变量）退出码" "$?" "0"
grep -qx "port: 8125" "${CFG}" && pass "重装未重置端口" || fail "重装重置了端口"
grep -qx "whitelistMode: true" "${CFG}" && pass "重装后白名单仍开启" || fail "重装后白名单被关闭"

node "${PATCHER}" "${CFG}" "basicAuthMode=!true" "whitelistMode=!false" "listen=!false" >/dev/null 2>&1
grep -qx "basicAuthMode: true" "${CFG}" && pass "已构造旧版配置" || fail "构造旧版配置失败"
printf '%s\n' "${ST_VERSION}" > "${SIM}/var/sillytavern.version"
# 不传任何向导变量：升级应完全无交互，且不得改动已设置的端口
bash "${ROOT}/cmd/upgrade_callback" >/dev/null 2>&1
expect_eq "upgrade_callback 退出码" "$?" "0"
grep -qx "basicAuthMode: false" "${CFG}" && pass "升级后关闭鉴权" || fail "升级未关闭鉴权"
grep -qx "whitelistMode: true" "${CFG}" && pass "升级后恢复白名单" || fail "升级未恢复白名单"
grep -qx "listen: true" "${CFG}" && pass "升级后恢复监听" || fail "升级未恢复监听"
grep -qx "port: 8125" "${CFG}" && pass "升级未覆盖用户端口 8125" || fail "升级覆盖了端口"

[ ! -f "${ROOT}/wizard/upgrade" ] && pass "升级无需向导" || fail "仍存在升级向导"
[ ! -f "${ROOT}/wizard/upgrade" ] && pass "升级无需向导" || fail "仍存在升级向导"
bash "${ROOT}/cmd/main" stop >/dev/null 2>&1
expect_eq "main stop 退出码" "$?" "0"
bash "${ROOT}/cmd/main" status; expect_eq "停止后 status" "$?" "3"
bash "${ROOT}/cmd/main" restart >/dev/null 2>&1
expect_eq "未知指令返回值" "$?" "1"

wizard_keep_data="true" bash "${ROOT}/cmd/uninstall_callback" >/dev/null 2>&1
[ ! -d "${ST_HOME}" ] && pass "卸载移除源码目录" || fail "源码目录残留"
[ -d "${SIM}/share/sillytavern/data" ] && pass "保留模式未删用户数据" || fail "保留模式误删数据"

echo
echo "=== 最终 config.yaml ==="
head -24 "${CFG}" 2>/dev/null
exit "${FAILED}"
