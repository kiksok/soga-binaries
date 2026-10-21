#!/usr/bin/env bash
set -Eeuo pipefail
set +x
umask 077

readonly VERSION='2.17.0-local1'
readonly ARCHIVE_NAME='soga-local1-2.17.0-linux-amd64.zip'
readonly ARCHIVE_URL="https://github.com/kiksok/soga-binaries/releases/download/v${VERSION}/${ARCHIVE_NAME}"
readonly ARCHIVE_SHA256='d355f7c9ac52818704ca3a3c57391c113d01bd333737c7613713eea6e617274b'
protocol='' sub_type='' panel_url='' node_ids='' license_file='' token_file='' cert_file='' key_file=''
listen_address='0.0.0.0' service_name='soga-217-local1' destination='' archive_file=''
prepare_only=0 no_start=0 check_panel=0 fingerprint_only=0 interactive=0 work=''

die() { printf '错误：%s\n' "$*" >&2; exit 1; }
cleanup() { if [[ -n "$work" && -d "$work" ]]; then rm -rf -- "$work"; fi; }
trap cleanup EXIT
trap 'printf "操作失败，请检查上方错误；已有部署不会被此脚本覆盖。\n" >&2' ERR
usage() {
  cat <<'USAGE'
Soga 2.17.0 local-1 / Xiaov2board 对接安装器（Linux x86_64）

用法：bash install.sh [选项]
  --license FILE       单独提供的有效 license.json
  --protocol TYPE      vless 或 anytls
  --sub-type TYPE      预留参数；本发行安装器尚未启用 v2node，填写会报错
  --panel-url URL      面板根地址，如 https://panel.example.com/
  --node-id IDS        对应协议节点ID；同协议多节点用逗号分隔
  --token-file FILE    仅保存后端通讯密钥的文本文件；省略则隐藏输入
  --cert FILE          手动TLS证书的绝对路径（fullchain）
  --key FILE           对应私钥的绝对路径
  --listen ADDRESS     监听IP，默认 0.0.0.0
  --name NAME          服务名称，默认 soga-217-local1；只允许小写字母数字和短横线
  --dest DIRECTORY     安装目录，默认 /opt/服务名称；必须是不存在的绝对路径
  --archive FILE       使用已下载的固定版本ZIP，仍核对内置SHA-256
  --check-panel        额外读取面板config/user接口，仅输出摘要
  --no-start           安装文件与服务定义，但不启用或启动服务
  --prepare-only       只准备目录并做本地检查；不要求root、不改systemd、不启动
  --fingerprint        下载/校验程序后仅打印本机指纹，不安装、不要求许可证
  -h, --help           显示帮助

缺少的必要信息会从终端交互读取。公开下载包不含许可证和签发私钥。
脚本不会安装系统依赖、申请证书、修改防火墙或覆盖已有部署。
USAGE
}
value() { [[ $# -ge 2 && -n "$2" ]] || die "$1 需要一个值"; }
while (($#)); do
  case "$1" in
    --license) value "$@"; license_file=$2; shift 2;;
    --protocol) value "$@"; protocol=$2; shift 2;;
    --sub-type) value "$@"; sub_type=$2; shift 2;;
    --panel-url) value "$@"; panel_url=$2; shift 2;;
    --node-id) value "$@"; node_ids=$2; shift 2;;
    --token-file) value "$@"; token_file=$2; shift 2;;
    --cert) value "$@"; cert_file=$2; shift 2;;
    --key) value "$@"; key_file=$2; shift 2;;
    --listen) value "$@"; listen_address=$2; shift 2;;
    --name) value "$@"; service_name=$2; shift 2;;
    --dest) value "$@"; destination=$2; shift 2;;
    --archive) value "$@"; archive_file=$2; shift 2;;
    --prepare-only) prepare_only=1; shift;;
    --no-start) no_start=1; shift;;
    --check-panel) check_panel=1; shift;;
    --fingerprint) fingerprint_only=1; shift;;
    -h|--help) usage; exit 0;;
    *) die "未知参数 $1（使用 --help 查看）";;
  esac
done
[[ -z "$sub_type" ]] || die '此安装器尚未启用 sub_type/v2node；请使用已验收的传统 VLESS/AnyTLS 节点'
[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || die '仅支持 Linux x86_64 / amd64'
for tool in python3 sha256sum mktemp install; do command -v "$tool" >/dev/null || die "缺少依赖：$tool"; done
work=$(mktemp -d -t soga-install.XXXXXXXX)

if [[ -n "$archive_file" ]]; then
  [[ -f "$archive_file" ]] || die '指定的ZIP文件不存在'
  cp -- "$archive_file" "$work/package.zip"
else
  command -v curl >/dev/null || die '缺少 curl'
  printf '下载固定版本 %s…\n' "$VERSION"
  curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
    --retry 3 --connect-timeout 15 --max-time 300 "$ARCHIVE_URL" -o "$work/package.zip"
fi
printf '%s  %s\n' "$ARCHIVE_SHA256" "$work/package.zip" | sha256sum --check --status || die 'ZIP校验失败；未安装任何文件'
python3 - "$work/package.zip" "$work/bundle" <<'PY'
import hashlib, pathlib, sys, zipfile
archive, dest = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
names = {'README.md', 'SHA256SUMS', 'soga-license', 'soga-offline', 'soga.conf', 'soga.core'}
with zipfile.ZipFile(archive) as z:
    if set(z.namelist()) != names or len(z.namelist()) != len(names):
        raise SystemExit('ZIP文件清单不符合固定版本')
    if sum(i.file_size for i in z.infolist()) > 110_000_000:
        raise SystemExit('ZIP解压大小超出范围')
    dest.mkdir(mode=0o700)
    for i in z.infolist():
        if i.filename not in names or (i.external_attr >> 16) & 0o170000 == 0o120000:
            raise SystemExit('ZIP包含不允许的路径或链接')
        (dest / i.filename).write_bytes(z.read(i))
    expected_names = names - {'SHA256SUMS'}
    seen = set()
    for line in (dest / 'SHA256SUMS').read_text().splitlines():
        digest, name = line.split('  ', 1)
        if name not in expected_names or name in seen:
            raise SystemExit('文件校验清单包含非预期条目')
        seen.add(name)
        if hashlib.sha256((dest / name).read_bytes()).hexdigest() != digest:
            raise SystemExit('解压文件摘要不一致')
    if seen != expected_names:
        raise SystemExit('文件校验清单不完整')
PY
chmod 755 "$work/bundle/soga-offline" "$work/bundle/soga-license" "$work/bundle/soga.core"
if ((fingerprint_only)); then "$work/bundle/soga-offline" --fingerprint; exit 0; fi

ask() {
  local variable=$1 prompt=$2 input
  interactive=1
  [[ -r /dev/tty ]] || die '非交互执行时请通过参数提供全部必要信息'
  read -r -p "$prompt" input </dev/tty || die '输入中断'
  printf -v "$variable" '%s' "$input"
}
[[ -n "$protocol" ]] || ask protocol '协议（vless / anytls）：'
[[ -n "$panel_url" ]] || ask panel_url '面板根地址（如 https://panel.example.com/）：'
[[ -n "$node_ids" ]] || ask node_ids '该协议节点ID（多节点用逗号分隔）：'
[[ -n "$license_file" ]] || ask license_file '本机有效许可证文件路径：'
[[ "$protocol" == vless || "$protocol" == anytls ]] || die '协议必须是 vless 或 anytls'
[[ "$service_name" =~ ^[a-z][a-z0-9-]{0,39}$ ]] || die '服务名不合法'
destination=${destination:-/opt/$service_name}
[[ "$destination" =~ ^/[A-Za-z0-9._/-]+$ && "$destination" != *'/../'* && "$destination" != */.. ]] || die '安装目录须为不含空格或父目录跳转的绝对路径'
case "$destination" in /|/opt|/etc|/usr|/usr/bin|/bin|/sbin|/tmp|/var) die '请指定专用子目录';; esac
[[ ! -e "$destination" && ! -L "$destination" ]] || die '安装目录已存在；为避免覆盖，改用新目录或按文档更新'
[[ -f "$license_file" && -r "$license_file" ]] || die '许可证文件不可读'
if [[ -z "$token_file" ]]; then
  interactive=1
  [[ -r /dev/tty ]] || die '非交互执行必须提供 --token-file'
  read -r -s -p '后端通讯密钥（隐藏输入）：' token </dev/tty || die '输入中断'
  printf '\n' >/dev/tty
  printf '%s' "$token" >"$work/panel-token"
  unset token
  token_file="$work/panel-token"
fi
[[ -f "$token_file" && -r "$token_file" ]] || die '通讯密钥文件不可读'
if [[ "$protocol" == anytls && -z "$cert_file" ]]; then ask cert_file 'AnyTLS完整证书链的绝对路径：'; fi
if [[ "$protocol" == anytls && -z "$key_file" ]]; then ask key_file 'AnyTLS私钥的绝对路径：'; fi
if [[ "$protocol" == vless && -z "$cert_file" && -z "$key_file" ]] && ((interactive)); then
  ask cert_file 'VLESS普通TLS/WSS证书绝对路径（明文/Reality留空）：'
  if [[ -n "$cert_file" ]]; then ask key_file '对应私钥的绝对路径：'; fi
fi
if [[ -n "$cert_file" || -n "$key_file" ]]; then
  [[ "$cert_file" == /* && "$key_file" == /* && -r "$cert_file" && -r "$key_file" ]] || die '证书和私钥必须成对提供可读的绝对路径'
  command -v openssl >/dev/null || die '校验证书需要 openssl'
  openssl x509 -in "$cert_file" -noout -checkend 0 >/dev/null || die '证书无效或已过期'
  openssl x509 -in "$cert_file" -pubkey -noout >"$work/cert-public.pem"
  openssl pkey -in "$key_file" -passin pass: -pubout >"$work/key-public.pem" 2>/dev/null || die '私钥不可解析；无人值守服务需要无口令私钥'
  cmp -s "$work/cert-public.pem" "$work/key-public.pem" || die '证书与私钥不匹配'
fi
if ((!prepare_only)); then
  [[ $EUID -eq 0 ]] || die '安装systemd服务需要root；仅生成文件请用 --prepare-only --dest 专用目录'
  command -v systemctl >/dev/null || die '缺少 systemctl'
  [[ -d /run/systemd/system ]] || die '系统未运行systemd；请使用 --prepare-only 后手动管理进程'
  [[ ! -e "/etc/systemd/system/$service_name.service" && ! -L "/etc/systemd/system/$service_name.service" ]] || die '同名服务文件已存在'
  if systemctl cat "$service_name.service" >/dev/null 2>&1; then die '同名systemd服务已存在；请使用全新 --name'; fi
fi

python3 - "$work/bundle/soga.conf" "$panel_url" "$node_ids" "$token_file" "$protocol" "$listen_address" "$cert_file" "$key_file" <<'PY'
import ipaddress, pathlib, re, sys, urllib.parse
target, url, ids, token_file, protocol, listen, cert, key = sys.argv[1:]
token = pathlib.Path(token_file).read_text().strip()
for value in (url, ids, token, protocol, listen, cert, key):
    if '\n' in value or '\r' in value or '\x00' in value:
        raise SystemExit('输入不能包含换行或NUL')
u = urllib.parse.urlsplit(url)
if u.scheme not in ('http', 'https') or not u.hostname or u.username is not None or u.password is not None or u.query or u.fragment:
    raise SystemExit('面板地址必须是无凭据、query和fragment的HTTP(S)根地址')
if '/api/v1/server' in u.path or u.path.rstrip('/').endswith(('/config', '/user')):
    raise SystemExit('填写面板根地址，不要填写完整API端点')
try:
    u.port
    ipaddress.ip_address(listen)
except ValueError:
    raise SystemExit('端口或监听IP格式不正确')
parts = ids.split(',')
if not parts or any(not re.fullmatch(r'[1-9][0-9]*', x) or int(x) > 9223372036854775807 for x in parts) or len(set(parts)) != len(parts):
    raise SystemExit('节点ID必须为不重复的正整数，多个节点用逗号分隔且不加空格')
if not token or len(token) > 8192:
    raise SystemExit('通讯密钥为空或过长')
text = f'type=xiaov2board\nserver_type={protocol}\napi=webapi\nnode_id={ids}\nwebapi_url={url.rstrip("/")}/\nwebapi_key={token}\nlisten={listen}\ncheck_interval=60\nsubmit_interval=60\ntcp_timeout=120\nudp_timeout=2\nforbidden_bit_torrent=false\n'
if cert:
    text += f'cert_mode=file\ncert_file={cert}\nkey_file={key}\n'
pathlib.Path(target).write_text(text)
PY
install -m 600 "$license_file" "$work/bundle/license.json"
printf '校验本地许可证、机器和配置…\n'
"$work/bundle/soga-offline" --check --config "$work/bundle/soga.conf"

if ((check_panel)); then
python3 - "$work/bundle/soga.conf" <<'PY'
import json, pathlib, sys, urllib.error, urllib.parse, urllib.request
values = dict(line.split('=', 1) for line in pathlib.Path(sys.argv[1]).read_text().splitlines() if '=' in line and not line.startswith('#'))
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None
opener = urllib.request.build_opener(NoRedirect())
for node in values['node_id'].split(','):
    for endpoint in ('config', 'user'):
        query = urllib.parse.urlencode({'node_id': node, 'node_type': values['server_type'], 'token': values['webapi_key']})
        url = values['webapi_url'].rstrip('/') + '/api/v1/server/UniProxy/' + endpoint + '?' + query
        try:
            with opener.open(urllib.request.Request(url, headers={'Accept': 'application/json'}), timeout=10) as r:
                raw = r.read(8 * 1024 * 1024 + 1)
                if len(raw) > 8 * 1024 * 1024:
                    raise ValueError('body too large')
                data = json.loads(raw)
            if endpoint == 'user':
                if not isinstance(data.get('users'), list):
                    raise ValueError('missing users array')
                summary = {'users': len(data['users'])}
            else:
                port = int(data['server_port'])
                if not 1 <= port <= 65535:
                    raise ValueError('invalid server_port')
                if values['server_type'] == 'vless' and int(data.get('tls') or 0) == 1 and not values.get('cert_file'):
                    raise SystemExit('面板节点启用普通TLS，请使用 --cert / --key 提供本机证书后再安装')
                summary = {'server_port': port, 'network': data.get('network'), 'tls': data.get('tls')}
            print(json.dumps({'node_id': node, 'endpoint': endpoint, 'ok': True, **summary}))
        except urllib.error.HTTPError as e:
            raise SystemExit(f'面板检查失败：node_id={node} endpoint={endpoint} HTTP {e.code}（不会跟随重定向）')
        except Exception:
            raise SystemExit(f'面板检查失败：node_id={node} endpoint={endpoint}，请检查DNS、证书、通讯密钥和节点配置')
PY
fi

mkdir -p -- "$(dirname -- "$destination")"
mv -T --no-clobber -- "$work/bundle" "$destination"
[[ ! -d "$work/bundle" ]] || die '安装目录在准备期间已出现；为避免覆盖，未移入文件'
install -d -m 700 "$destination/tmp"
(cd "$destination" && sha256sum soga-offline soga-license soga.core > SHA256SUMS)
if ((prepare_only)); then
  printf '文件已准备并通过本地检查：%s\n未修改systemd或启动服务。\n' "$destination"
  exit 0
fi
install -d -m 755 /etc/soga
cat >"/etc/systemd/system/$service_name.service" <<UNIT
[Unit]
Description=Soga 2.17.0 local-1 Xiaov2board backend
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=60
StartLimitBurst=5

[Service]
Type=simple
User=root
WorkingDirectory=$destination
Environment=TMPDIR=$destination/tmp
ExecStart=$destination/soga-offline --config $destination/soga.conf --license $destination/license.json --core $destination/soga.core
Restart=on-failure
RestartSec=5
TimeoutStopSec=10
KillMode=control-group
LimitNOFILE=1048576
UMask=0077
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
if ((no_start)); then
  printf '已安装但未启动。启动命令：systemctl enable --now %s\n' "$service_name"
else
  systemctl enable --now "$service_name.service"
  sleep 3
  systemctl is-active --quiet "$service_name.service" || die "服务尚未运行，请执行 journalctl -u $service_name -n 80"
  printf '服务已启动：%s\n' "$service_name"
fi
printf '配置：%s/soga.conf\n日志：journalctl -u %s -f\n' "$destination" "$service_name"
