#!/usr/bin/env bash
set -Eeuo pipefail
set +x
umask 077

readonly VERSION='2.17.0-local2'
readonly INSTALLER_REVISION='5'
readonly ARCHIVE_NAME='soga-local2-2.17.0-linux-amd64.zip'
readonly ARCHIVE_URL="https://github.com/kiksok/soga-binaries/releases/download/v${VERSION}/${ARCHIVE_NAME}"
readonly ARCHIVE_SHA256='48c94ecd32b02dc3d7ea8b62a8d706aa8786e23962fff9bc9ac38771ddd33611'
protocol='anytls' sub_type='' panel_url='' node_ids='' auth_code='local' token_file='' cert_file='' key_file=''
listen_address='0.0.0.0' service_name='soga-217-local2' destination='' archive_file=''
prepare_only=0 no_start=0 check_panel=0 interactive=0 work=''
cert_mode='' cert_domain='' cert_email='' dns_provider='' dns_env_file='' acme_archive=''
skip_deps=0

die() { printf '错误：%s\n' "$*" >&2; exit 1; }
cleanup() { if [[ -n "$work" && -d "$work" ]]; then rm -rf -- "$work"; fi; }
trap cleanup EXIT
trap 'printf "操作失败，请检查上方错误；已有部署不会被覆盖；新建目录可能已保留，请按错误提示处理。\n" >&2' ERR
usage() {
  cat <<'USAGE'
Soga 2.17.0 local-2 / Xiaov2board 对接安装器 r5（Linux x86_64）

用法：bash install.sh [选项]
  --auth-code TEXT     本地启用文本，默认local，不再询问，不联网验码
  --protocol TYPE      默认 anytls，不再询问；需要VLESS时填写 --protocol vless
  --sub-type TYPE      预留参数；本发行安装器尚未启用 v2node，填写会报错
  --panel-url URL      面板根地址，如 https://panel.example.com/
  --node-id IDS        对应协议节点ID；同协议多节点用逗号分隔
  --token-file FILE    仅保存后端通讯密钥的文本文件；省略则隐藏输入
  --cert-mode MODE     默认auto：读取面板SNI并HTTP自动签发；另支持dns/file/none
  --cert-domain DOMAIN 可选覆盖证书域名，默认读取面板节点SNI
  --cert-email EMAIL   可选ACME联系邮箱，省略不询问
  --dns-provider NAME  DNS插件，如 dns_cf、dns_ali
  --dns-env FILE       DNS API凭据文件，KEY=value格式，不执行shell展开
  --acme-archive FILE  使用已下载的acme.sh 3.1.6源码包，仍核对固定摘要
  --skip-deps          不自动安装系统依赖（prepare-only默认不安装）
  --cert FILE          手动TLS证书的绝对路径（fullchain）
  --key FILE           对应私钥的绝对路径
  --listen ADDRESS     监听IP，默认 0.0.0.0
  --name NAME          服务名称，默认 soga-217-local2；只允许小写字母数字和短横线
  --dest DIRECTORY     安装目录，默认 /project/服务名称；必须是不存在的绝对路径
  --archive FILE       使用已下载的固定版本ZIP，仍核对内置SHA-256
  --check-panel        额外读取面板config/user接口，仅输出摘要
  --no-start           安装文件与服务定义，但不启用或启动服务
  --prepare-only       只准备目录并做本地检查；不要求root、不改systemd、不启动
  -h, --help           显示帮助

默认仅询问面板网址、节点ID和通讯密钥；AnyTLS节点必须在面板填写有效SNI。
本版不需要许可证文件、签名、机器指纹或有效期。
正式安装会按需安装依赖；http/dns模式使用acme.sh及systemd定时续期。
--prepare-only / --no-start不签发证书；不修改防火墙或覆盖已有部署。
USAGE
}
value() { [[ $# -ge 2 && -n "$2" ]] || die "$1 需要一个值"; }
while (($#)); do
  case "$1" in
    --auth-code) value "$@"; auth_code=$2; shift 2;;
    --protocol) value "$@"; protocol=$2; shift 2;;
    --sub-type) value "$@"; sub_type=$2; shift 2;;
    --panel-url) value "$@"; panel_url=$2; shift 2;;
    --node-id) value "$@"; node_ids=$2; shift 2;;
    --token-file) value "$@"; token_file=$2; shift 2;;
    --cert-mode) value "$@"; cert_mode=$2; shift 2;;
    --cert-domain) value "$@"; cert_domain=$2; shift 2;;
    --cert-email) value "$@"; cert_email=$2; shift 2;;
    --dns-provider) value "$@"; dns_provider=$2; shift 2;;
    --dns-env) value "$@"; dns_env_file=$2; shift 2;;
    --acme-archive) value "$@"; acme_archive=$2; shift 2;;
    --skip-deps) skip_deps=1; shift;;
    --cert) value "$@"; cert_file=$2; shift 2;;
    --key) value "$@"; key_file=$2; shift 2;;
    --listen) value "$@"; listen_address=$2; shift 2;;
    --name) value "$@"; service_name=$2; shift 2;;
    --dest) value "$@"; destination=$2; shift 2;;
    --archive) value "$@"; archive_file=$2; shift 2;;
    --prepare-only) prepare_only=1; shift;;
    --no-start) no_start=1; shift;;
    --check-panel) check_panel=1; shift;;
    -h|--help) usage; exit 0;;
    *) die "未知参数 $1（使用 --help 查看）";;
  esac
done
[[ -z "$sub_type" ]] || die '此安装器尚未启用 sub_type/v2node；请使用已验收的传统 VLESS/AnyTLS 节点'
[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || die '仅支持 Linux x86_64 / amd64'
install_base() {
  local missing=0 tool
  for tool in curl python3 sha256sum mktemp install tar openssl socat; do
    command -v "$tool" >/dev/null || missing=1
  done
  ((missing)) || return 0
  [[ $EUID -eq 0 ]] || die '自动安装依赖需要root；自行安装后可使用 --skip-deps'
  printf '安装缺少的运行/自动证书依赖…\n'
  if command -v apt-get >/dev/null; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y curl ca-certificates python3 openssl coreutils tar socat
  elif command -v dnf >/dev/null; then
    dnf install -y curl ca-certificates python3 openssl coreutils tar socat
  elif command -v yum >/dev/null; then
    yum install -y curl ca-certificates python3 openssl coreutils tar socat
  else
    die '未找到apt-get/dnf/yum，请自行安装依赖并使用 --skip-deps'
  fi
}
if ((!prepare_only && !skip_deps)); then install_base; fi
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
names = {'README.md', 'SHA256SUMS', 'soga-offline', 'soga.conf', 'soga.core'}
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
chmod 755 "$work/bundle/soga-offline" "$work/bundle/soga.core"

ask() {
  local variable=$1 prompt=$2 input
  interactive=1
  [[ -r /dev/tty ]] || die '非交互执行时请通过参数提供全部必要信息'
  read -r -p "$prompt" input </dev/tty || die '输入中断'
  printf -v "$variable" '%s' "$input"
}
[[ -n "$panel_url" ]] || ask panel_url '面板根地址（如 https://panel.example.com/）：'
[[ -n "$node_ids" ]] || ask node_ids '该协议节点ID（多节点用逗号分隔）：'
[[ "$protocol" == vless || "$protocol" == anytls ]] || die '协议必须是 vless 或 anytls'
[[ "$service_name" =~ ^[a-z][a-z0-9-]{0,39}$ ]] || die '服务名不合法'
destination=${destination:-/project/$service_name}
[[ "$destination" =~ ^/[A-Za-z0-9._/-]+$ && "$destination" != *'/../'* && "$destination" != */.. ]] || die '安装目录须为不含空格或父目录跳转的绝对路径'
case "$destination" in /|/opt|/etc|/usr|/usr/bin|/bin|/sbin|/tmp|/var) die '请指定专用子目录';; esac
[[ ! -e "$destination" && ! -L "$destination" ]] || die '安装目录已存在；为避免覆盖，改用新目录或按文档更新'
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
if [[ -z "$cert_mode" ]]; then
  if [[ -n "$cert_file" || -n "$key_file" ]]; then cert_mode=file
  else cert_mode=auto; fi
fi
case "$cert_mode" in auto|http|dns|file|none) ;; *) die '证书方式必须是 auto、http、dns、file 或 none';; esac
if [[ "$cert_mode" == auto ]] || { [[ "$cert_mode" == http || "$cert_mode" == dns ]] && [[ -z "$cert_domain" ]]; }; then
  python3 - "$panel_url" "$node_ids" "$token_file" "$protocol" "$cert_mode" "$cert_domain" "$work/certificate-detection.json" <<'PANEL_CERT'
import json, pathlib, re, sys, urllib.error, urllib.parse, urllib.request
url, node_ids, token_file, protocol, mode, domain_override, output = sys.argv[1:]
if any(c in value for value in (url, node_ids, domain_override) for c in ('\n', '\r', '\x00')):
    raise SystemExit('面板输入包含无效字符')
try:
    parsed = urllib.parse.urlsplit(url)
    parsed.port
except ValueError:
    raise SystemExit('面板根网址格式不正确')
if parsed.scheme not in ('http', 'https') or not parsed.hostname or parsed.username is not None or parsed.password is not None or parsed.query or parsed.fragment:
    raise SystemExit('填写无凭据、query或fragment的HTTP(S)面板根网址')
if '/api/v1/server' in parsed.path or parsed.path.rstrip('/').endswith(('/config', '/user')):
    raise SystemExit('填写面板根网址，不填写API端点')
ids = node_ids.split(',')
if any(not re.fullmatch(r'[1-9][0-9]*', n) or int(n) > 9223372036854775807 for n in ids) or len(set(ids)) != len(ids):
    raise SystemExit('节点ID须是不重复的正整数，逗号分隔不加空格')
token = pathlib.Path(token_file).read_text().strip()
if not token or len(token) > 8192 or any(c in token for c in ('\n', '\r', '\x00')):
    raise SystemExit('通讯密钥为空、过长或包含无效字符')
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs): return None
opener = urllib.request.build_opener(NoRedirect())
detected = []
for node in ids:
    query = urllib.parse.urlencode({'node_id': node, 'node_type': protocol, 'token': token})
    endpoint = url.rstrip('/') + '/api/v1/server/UniProxy/config?' + query
    try:
        with opener.open(urllib.request.Request(endpoint, headers={'Accept': 'application/json', 'User-Agent': 'Go-http-client/1.1'}), timeout=15) as response:
            raw = response.read(8 * 1024 * 1024 + 1)
        if len(raw) > 8 * 1024 * 1024: raise ValueError()
        data = json.loads(raw)
        port = int(data['server_port'])
        if not 1 <= port <= 65535: raise ValueError()
        if protocol == 'anytls':
            tls = 1
            sni = data.get('server_name')
        else:
            tls = int(data['tls'])
            if tls not in (0, 1, 2): raise ValueError()
            settings = data.get('tls_settings') or {}
            if isinstance(settings, str): settings = json.loads(settings)
            if not isinstance(settings, dict): raise ValueError()
            sni = settings.get('server_name')
    except urllib.error.HTTPError as error:
        raise SystemExit(f'读取面板配置失败：节点{node} HTTP {error.code}，请核对节点ID、通讯密钥和面板根网址（不跟随重定向）')
    except Exception:
        raise SystemExit(f'读取面板配置失败：节点{node}，请核对面板DNS/证书/接口和网络')
    selected_mode = ('http' if tls == 1 else 'none') if mode == 'auto' else mode
    domain = domain_override or sni or ''
    if selected_mode in ('http', 'dns'):
        if not isinstance(domain, str) or not re.fullmatch(r'(?=.{1,253}$)(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,63}', domain):
            raise SystemExit(f'节点{node}的面板SNI缺失或不是有效域名；请先在面板填写TLS域名/SNI，再运行安装器')
        domain = domain.lower()
        if selected_mode == 'http' and port == 80:
            raise SystemExit(f'节点{node}代理监听80，HTTP验证无法持续续期；请改用DNS证书方式或更换节点监听端口')
    else: domain = ''
    detected.append((selected_mode, domain))
if len(set(detected)) != 1:
    raise SystemExit('多节点的TLS模式或证书域名不同，请分别安装实例，或明确指定一致的证书配置')
selected_mode, domain = detected[0]
pathlib.Path(output).write_text(json.dumps({'mode': selected_mode, 'domain': domain}))
print('面板配置已读取：' + ('使用SNI ' + domain + ' 自动签发证书' if domain else '此VLESS传输无需普通TLS证书'))
PANEL_CERT
  cert_mode=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["mode"])' "$work/certificate-detection.json")
  cert_domain=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["domain"])' "$work/certificate-detection.json")
fi
[[ "$protocol" != anytls || "$cert_mode" != none ]] || die 'AnyTLS使用TLS，不能选择none'
if [[ "$cert_mode" == http || "$cert_mode" == dns ]]; then
  [[ -z "$cert_file" && -z "$key_file" ]] || die '自动模式不能同时提供 --cert / --key'
  [[ -n "$cert_domain" ]] || die '面板未返回有效证书域名，请在面板填写TLS域名/SNI'
  if [[ "$cert_mode" == dns ]]; then
    [[ -n "$dns_provider" ]] || ask dns_provider 'DNS插件名称（如 dns_cf / dns_ali）：'
    [[ -n "$dns_env_file" ]] || ask dns_env_file 'DNS API凭据文件绝对路径（KEY=value）：'
    [[ "$dns_env_file" == /* && -f "$dns_env_file" && -r "$dns_env_file" ]] || die 'DNS凭据须是可读文件的绝对路径'
  else
    [[ -z "$dns_provider" && -z "$dns_env_file" ]] || die 'HTTP模式不使用DNS插件或凭据'
  fi
  cert_file="$destination/certs/fullchain.pem"; key_file="$destination/certs/privkey.pem"
else
  [[ -z "$cert_domain" && -z "$cert_email" && -z "$dns_provider" && -z "$dns_env_file" && -z "$acme_archive" ]] || die '自动证书参数需要 --cert-mode http 或 dns'
  if [[ "$cert_mode" == file ]]; then
    [[ -n "$cert_file" ]] || ask cert_file '完整证书链的绝对路径：'
    [[ -n "$key_file" ]] || ask key_file '对应私钥的绝对路径：'
  else [[ -z "$cert_file" && -z "$key_file" ]] || die 'none模式不能同时提供证书文件'; fi
fi
if [[ "$cert_mode" == file ]]; then
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
  if [[ "$cert_mode" == http || "$cert_mode" == dns ]]; then
    for unit in "$service_name-cert-renew.service" "$service_name-cert-renew.timer"; do
      [[ ! -e "/etc/systemd/system/$unit" && ! -L "/etc/systemd/system/$unit" ]] || die "续期unit已存在：$unit"
      if systemctl cat "$unit" >/dev/null 2>&1; then die "续期unit已存在：$unit"; fi
    done
  fi
  [[ ! -e "/etc/systemd/system/$service_name.service" && ! -L "/etc/systemd/system/$service_name.service" ]] || die '同名服务文件已存在'
  if systemctl cat "$service_name.service" >/dev/null 2>&1; then die '同名systemd服务已存在；请使用全新 --name'; fi
fi

python3 - "$cert_mode" "$cert_domain" "$cert_email" "$dns_provider" "$dns_env_file" <<'PY'
import pathlib, re, sys
mode, domain, email, provider, env_file = sys.argv[1:]
if mode not in ('http', 'dns'): raise SystemExit(0)
if not re.fullmatch(r'(?=.{1,253}$)(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,63}', domain):
    raise SystemExit('证书域名须为普通完整域名，不含协议、路径、端口、IP或通配符')
if email and not re.fullmatch(r'[A-Za-z0-9.!#$%&*+/=?^_{}|~-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,63}', email):
    raise SystemExit('ACME联系邮箱格式不正确')
if mode == 'dns':
    if not re.fullmatch(r'dns_[a-zA-Z0-9_]+', provider): raise SystemExit('DNS插件名称不合法，如 dns_cf / dns_ali')
    count = 0
    for line in pathlib.Path(env_file).read_text().splitlines():
        line = line.strip()
        if not line or line.startswith('#'): continue
        key, sep, value = line.partition('=')
        if not sep or not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', key) or not value or '\x00' in value:
            raise SystemExit('DNS凭据须为非空KEY=value，不使用export或shell命令')
        if key in {'HOME', 'CODEX_HOME', 'PATH', 'ENV', 'BASH_ENV', 'SHELLOPTS', 'SHELL', 'IFS', 'PWD', 'TMPDIR'} or key.startswith(('LD_', 'PYTHON', 'BASH_FUNC_')):
            raise SystemExit('DNS凭据包含不允许的进程环境变量')
        count += 1
    if not count: raise SystemExit('DNS凭据文件为空')
PY
if [[ -n "$acme_archive" ]]; then
  [[ -f "$acme_archive" && -r "$acme_archive" ]] || die 'acme.sh源码包不可读'
  printf '%s  %s\n' '0d3f9000ac44a6331314742a88c475f79134e24fc991997883652adc59efc486' "$acme_archive" | sha256sum --check --status || die 'acme.sh源码包摘要不匹配'
fi

python3 - "$work/bundle/soga.conf" "$panel_url" "$node_ids" "$token_file" "$protocol" "$listen_address" "$cert_file" "$key_file" "$auth_code" <<'PY'
import ipaddress, pathlib, re, sys, urllib.parse
target, url, ids, token_file, protocol, listen, cert, key, auth_code = sys.argv[1:]
token = pathlib.Path(token_file).read_text().strip()
for value in (url, ids, token, protocol, listen, cert, key, auth_code):
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
if not auth_code.strip() or len(auth_code.encode()) > 8192:
    raise SystemExit('本地授权码须为非空文本，最多8192字节')
text = f'type=xiaov2board\nserver_type={protocol}\napi=webapi\nnode_id={ids}\nwebapi_url={url.rstrip("/")}/\nwebapi_key={token}\nsoga_key={auth_code}\nlisten={listen}\ncheck_interval=60\nsubmit_interval=60\ntcp_timeout=120\nudp_timeout=2\nforbidden_bit_torrent=false\n'
if cert:
    text += f'cert_mode=file\ncert_file={cert}\nkey_file={key}\n'
pathlib.Path(target).write_text(text)
PY
if [[ "$cert_mode" == http || "$cert_mode" == dns ]]; then
  if [[ "$cert_mode" == dns ]]; then install -m 600 "$dns_env_file" "$work/bundle/acme-dns.env"; fi
  if [[ -n "$acme_archive" ]]; then install -m 600 "$acme_archive" "$work/bundle/acme-source.tar.gz"; fi
  {
    printf '#!/usr/bin/env bash\nset -Eeuo pipefail\nset +x\numask 077\n'
    printf 'base=%q\nmode=%q\ndomain=%q\nemail=%q\nprovider=%q\nservice=%q\n' "$destination" "$cert_mode" "$cert_domain" "$cert_email" "$dns_provider" "$service_name"
    cat <<'CERT_SCRIPT'
# Embedded by the installer after its instance-specific, shell-quoted variables.
die() { printf '证书操作失败：%s\n' "$*" >&2; exit 1; }
acme="$base/acme/acme.sh"
check_certificate() {
  local a b
  openssl x509 -in "$base/certs/fullchain.pem" -noout -checkend 0 >/dev/null || die '证书不存在、无效或已过期'
  openssl x509 -in "$base/certs/fullchain.pem" -noout -checkhost "$domain" >/dev/null || die '证书域名不匹配'
  a=$(openssl x509 -in "$base/certs/fullchain.pem" -pubkey -noout)
  b=$(openssl pkey -in "$base/certs/privkey.pem" -passin pass: -pubout 2>/dev/null) || die '私钥无效'
  [[ "$a" == "$b" ]] || die '证书与私钥不匹配'
}
bootstrap() {
  local temporary
  for tool in curl tar python3 sha256sum openssl; do command -v "$tool" >/dev/null || die "缺少依赖 $tool"; done
  if [[ ! -f "$acme" ]]; then
    temporary=$(mktemp -d "$base/acme-bootstrap.XXXXXXXX")
    if [[ -f "$base/acme-source.tar.gz" ]]; then
      cp -- "$base/acme-source.tar.gz" "$temporary/acme.tar.gz"
    else
      curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 --retry 3 --connect-timeout 15 --max-time 180 \
        'https://codeload.github.com/acmesh-official/acme.sh/tar.gz/refs/tags/3.1.6' -o "$temporary/acme.tar.gz"
    fi
    printf '%s  %s\n' '0d3f9000ac44a6331314742a88c475f79134e24fc991997883652adc59efc486' "$temporary/acme.tar.gz" | sha256sum --check --status || die 'acme.sh源码包校验失败'
    mkdir "$temporary/source"
    tar -xzf "$temporary/acme.tar.gz" --strip-components=1 -C "$temporary/source"
    local -a account_options=()
    if [[ -n "$email" ]]; then account_options=(--accountemail "$email"); fi
    (cd "$temporary/source" && bash ./acme.sh --install --home "$base/acme" --config-home "$base/acme-data" --cert-home "$base/acme-data/certs" --no-cron --no-profile "${account_options[@]}")
    rm -rf -- "$temporary"
  fi
  [[ $(bash "$acme" --version | tail -n 1) == v3.1.6 ]] || die '仅支持已固定校验的acme.sh 3.1.6'
  run_acme --set-default-ca --server letsencrypt
}
run_acme() {
  python3 - "$base" "$mode" "$@" <<'ACME_PY'
import base64, os, pathlib, re, subprocess, sys, urllib.parse
base, mode, *arguments = sys.argv[1:]
env = os.environ.copy(); secrets = []
if mode == 'dns':
    for line in pathlib.Path(base, 'acme-dns.env').read_text().splitlines():
        line = line.strip()
        if not line or line.startswith('#'): continue
        key, sep, value = line.partition('=')
        if not sep or not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', key):
            raise SystemExit('DNS凭据文件格式不正确')
        if key in {'HOME', 'CODEX_HOME', 'PATH', 'ENV', 'BASH_ENV', 'SHELLOPTS', 'SHELL', 'IFS', 'PWD', 'TMPDIR'} or key.startswith(('LD_', 'PYTHON', 'BASH_FUNC_')):
            raise SystemExit('DNS凭据包含不允许的进程环境变量')
        if len(value) >= 2 and value[0] == value[-1] and value[0] in ('"', "'"): value = value[1:-1]
        if not value or '\x00' in value: raise SystemExit('DNS凭据为空或包含无效字符')
        env[key] = value
        secrets.extend((value, urllib.parse.quote(value, safe=''), base64.b64encode(value.encode()).decode()))
command = ['bash', str(pathlib.Path(base, 'acme/acme.sh')), '--home', str(pathlib.Path(base, 'acme')), '--config-home', str(pathlib.Path(base, 'acme-data')), '--cert-home', str(pathlib.Path(base, 'acme-data/certs')), *arguments]
result = subprocess.run(command, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
output = result.stdout
for secret in sorted(set(secrets), key=len, reverse=True): output = output.replace(secret, '[REDACTED]')
print(output, end='')
if result.returncode and not (result.returncode == 2 and '--issue' in arguments):
    raise SystemExit('acme.sh执行失败；未启动节点。请核对域名验证、DNS权限和网络后重试')
ACME_PY
}
case "${1:-}" in
  bootstrap) bootstrap;;
  issue)
    bootstrap
    install -d -m 700 "$base/certs"
    if [[ "$mode" == http ]]; then
      command -v socat >/dev/null || die 'HTTP验证缺少socat'
      python3 - <<'PORT_PY'
import socket
try:
    with socket.socket() as listener: listener.bind(('0.0.0.0', 80))
except OSError:
    raise SystemExit('HTTP验证需要本机TCP 80空闲；请改用DNS验证，或处理占用后重试')
PORT_PY
      run_acme --issue --server letsencrypt --keylength ec-256 -d "$domain" --standalone
    else
      [[ -f "$base/acme/dnsapi/$provider.sh" ]] || die '此版本acme.sh没有该DNS插件'
      run_acme --issue --server letsencrypt --keylength ec-256 -d "$domain" --dns "$provider"
    fi
    run_acme --install-cert -d "$domain" --ecc --fullchain-file "$base/certs/fullchain.pem" --key-file "$base/certs/privkey.pem" --reloadcmd "$base/certificate-reload.sh"
    chmod 600 "$base/certs/fullchain.pem" "$base/certs/privkey.pem"
    check_certificate
    ;;
  renew)
    [[ -f "$acme" ]] || die '请先运行 certificate.sh issue 完成首次签发'
    run_acme --cron
    check_certificate
    ;;
  check) check_certificate;;
  *) die '用法：certificate.sh bootstrap | issue | renew | check';;
esac
CERT_SCRIPT
  } >"$work/bundle/certificate.sh"
  chmod 700 "$work/bundle/certificate.sh"
  {
    printf '#!/usr/bin/env bash\nset -Eeuo pipefail\n'
    printf '%q check\n' "$destination/certificate.sh"
    printf 'if systemctl is-active --quiet %q; then\n  systemctl restart %q\nfi\n' "$service_name.service" "$service_name.service"
  } >"$work/bundle/certificate-reload.sh"
  chmod 700 "$work/bundle/certificate-reload.sh"
fi
printf '检查本地启用状态、程序完整性和配置…\n'
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
            with opener.open(urllib.request.Request(url, headers={'Accept': 'application/json', 'User-Agent': 'Go-http-client/1.1'}), timeout=10) as r:
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
(cd "$destination" && sha256sum soga-offline soga.core > SHA256SUMS)
if ((prepare_only)); then
  printf '文件已准备并通过本地检查：%s\n未修改systemd或启动服务。\n' "$destination"
  if [[ "$cert_mode" == http || "$cert_mode" == dns ]]; then
    printf '自动证书尚未签发，未安装续期timer。正式部署前运行：bash %s/certificate.sh issue\n' "$destination"
  fi
  exit 0
fi
install -d -m 755 /etc/soga
cat >"/etc/systemd/system/$service_name.service" <<UNIT
[Unit]
Description=Soga 2.17.0 local-2 Xiaov2board backend
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=60
StartLimitBurst=5

[Service]
Type=simple
User=root
WorkingDirectory=$destination
Environment=TMPDIR=$destination/tmp
ExecStart=$destination/soga-offline --config $destination/soga.conf --core $destination/soga.core
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
if [[ "$cert_mode" == http || "$cert_mode" == dns ]]; then
  sed -i "/^ExecStart=/i ExecStartPre=$destination/certificate.sh check" "/etc/systemd/system/$service_name.service"
  cat >"/etc/systemd/system/$service_name-cert-renew.service" <<UNIT
[Unit]
Description=Renew TLS certificate for $service_name
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
User=root
WorkingDirectory=$destination
ExecStart=$destination/certificate.sh renew
TimeoutStartSec=30min
UMask=0077
UNIT
  cat >"/etc/systemd/system/$service_name-cert-renew.timer" <<UNIT
[Unit]
Description=Daily TLS certificate renewal check for $service_name

[Timer]
OnCalendar=daily
RandomizedDelaySec=1h
Persistent=true
Unit=$service_name-cert-renew.service

[Install]
WantedBy=timers.target
UNIT
fi
systemctl daemon-reload
if ((no_start)); then
  if [[ "$cert_mode" == http || "$cert_mode" == dns ]]; then
    printf '已安装但未签发/启动。先执行：bash %s/certificate.sh issue\n再执行：systemctl enable --now %s %s-cert-renew.timer\n' "$destination" "$service_name" "$service_name"
  else
    printf '已安装但未启动。启动命令：systemctl enable --now %s\n' "$service_name"
  fi
else
  if [[ "$cert_mode" == http || "$cert_mode" == dns ]]; then "$destination/certificate.sh" issue; fi
  systemctl enable --now "$service_name.service"
  sleep 3
  systemctl is-active --quiet "$service_name.service" || die "服务尚未运行，请执行 journalctl -u $service_name -n 80"
  if [[ "$cert_mode" == http || "$cert_mode" == dns ]]; then systemctl enable --now "$service_name-cert-renew.timer"; fi
  printf '服务已启动：%s\n' "$service_name"
fi
printf '配置：%s/soga.conf\n日志：journalctl -u %s -f\n' "$destination" "$service_name"
