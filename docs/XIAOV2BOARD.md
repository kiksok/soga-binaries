# Xiaov2board 对接使用文档

适用：Soga `2.17.0-local2`、安装器 r5、Linux amd64、传统 AnyTLS/VLESS 节点。默认 AnyTLS，仅询问面板网址、节点 ID、通讯密钥；VLESS 使用 `--protocol vless`。接口为 `/api/v1/server/UniProxy`，暂不支持非空 `sub_type` 或 v2node 分类。

## 1. 本地启用文本与面板密钥

本版不要求 `license.json`、签名、机器指纹、有效期或授权用户/节点额度检查。安装器默认使用本地启用文本 local，不再询问。需要改文字时可用 `--auth-code 测试`；手动配置写 `soga_key=local`。空白、换行、NUL 和超过 8192 字节的文本被拒绝。

文本只作为本地启动标记，不传给原版核心。原版授权 HTTP 发送流程继续停用；正常面板接口、在线/流量上报和代理出站仍联网。核心文件仍须与发行版匹配并通过完整性检查。

**`webapi_key` 必须填写 Xiaov2board 实际的后端通讯密钥 `server_token`，不能任意填写。** 它不是面板登录密码、用户 UUID、订阅 token 或本地启用文本。AnyTLS 客户端密码使用面板用户 UUID。

## 2. 准备的信息

| 信息 | 填写方法 |
| --- | --- |
| 面板根网址 | 如 `https://panel.example.com/`，保留真实子目录，不拼 API 端点或后台登录路径 |
| 后端通讯密钥 | 后台的服务器/节点通讯密钥 `server_token` |
| 协议 | 默认 `anytls`；VLESS 显式添加 `--protocol vless` |
| 节点 ID | 对应协议分类下的真实 ID，多节点用 `52,53`，不加空格 |
| 本地启用文本 | 自动填 local，不需要输入 |
| 节点地址 | 指向节点公网 IP 的域名或实际接入地址 |
| TLS 证书 | 默认从面板 SNI 自动签发，无需输入证书信息 |

同号 ID 在 AnyTLS 与 VLESS 分类中可能属于不同节点。同实例多节点须为同一协议，各监听端口不能冲突。启动器不施加授权用户/节点额度；实际面板权限、剩余流量、设备限制和套餐有效期仍执行。

## 3. 面板节点怎么填

### 3.1 AnyTLS

| 面板字段 | 示例与说明 |
| --- | --- |
| 名称 | `AnyTLS-01` |
| 地址 `host` | `anytls.example.com`，指向节点服务器 |
| 连接端口 `port` | `8443`，也可选其他可用端口 |
| 服务端口 `server_port` | 直连同为 `8443`；转发/NAT 按实际映射填写 |
| TLS 域名 `server_name` | `anytls.example.com`，匹配证书和客户端 SNI |
| 跳过验证 `insecure` | 关闭，使用可信、匹配的证书 |
| `padding_scheme` | 初次留空，使用默认值 |
| 权限组 | 与测试用户套餐的权限组匹配 |
| 倍率、显示 | 初测倍率 1，开启显示 |

AnyTLS 使用 TLS，不能选 `none`。标准 Cloudflare 橙云不代理原始 AnyTLS TCP，直连域名使用 DNS-only。面板域名与节点证书域名可以不同。只在面板填写 SNI 不会完成域名验证或生成证书。

AnyTLS 与 VLESS 都不强制监听 443。同 IP 的两个独立监听通常不能同时占用同一 TCP 端口，可分别用 443 和 8443。证书验证端口与代理监听端口是不同设置。

### 3.2 VLESS TCP + TLS

| 面板字段 | 示例与说明 |
| --- | --- |
| 名称/地址 | `VLESS-TLS-01` / `vless.example.com` |
| 连接/服务端口 | 直连可同为 `443`，也可使用其他可用端口 |
| 传输 `network` | `tcp` |
| TLS `tls` | 普通 TLS 为 1，无 TLS 为 0，Reality 为 2 |
| TLS 域名/SNI | `vless.example.com`，与证书匹配 |
| Flow | 普通 TCP/TLS 先留空 |
| `encryption` | 留空/null，不手填字符串 `none` |
| 权限组、倍率、显示 | 与测试套餐匹配、倍率 1、开启 |
| 父节点 | 初次独立部署留空 |

服务端口、TLS、网络传输和高级密钥由面板下发，本地配置不另加同名字段强行覆盖。

### 3.3 WS、Reality、Vision、MLKEM 与 v2node

WS 设 `network=ws`，路径（例如 `/soga-ws`）与客户端/反代一致，按需填 WS Host。非 TCP 不设置 Vision flow。Soga 直接处理 WSS 时 TLS 设 1 并配置证书；前置反代终止 TLS、向 Soga 转发明文 WS 时设 0。反代需正确转发 Upgrade 和路径。同机反代可让 Soga 监听 `127.0.0.1:10000`、公网入口用 443；反代在其他机器时不填回环地址。

Reality 使用 `tls=2`，配置匹配的服务端私钥、目标地址/端口、允许 SNI 和 short ID，客户端填对应公钥。Vision 使用 TCP 和匹配的 `xtls-rprx-vision`。MLKEM 按核心/客户端兼容参数配置。普通 PEM 证书、Reality 密钥和 MLKEM 密钥不能混填。

这些能力沿用核心，复杂模式须在实际客户端验收；安装器不生成这些高级密钥。v2node 是单独面板分类、接口不同，本版拒绝非空 `sub_type`，不要把 v2node ID 填作传统节点 ID。

## 4. 下载与安装

Linux x86_64 上以 root 执行：

```bash
mkdir -p /project
cd /project
curl -fL https://raw.githubusercontent.com/kiksok/soga-binaries/installer-2.17.0-local2-r5/install.sh -o install.sh
bash install.sh
```

默认直接用 AnyTLS，只输入面板根网址、节点 ID、真实通讯密钥，密钥隐藏输入。安装器读取节点配置中的 `server_name`，自动使用 HTTP 验证申请证书，并配置续期。VLESS 使用 `bash install.sh --protocol vless`，普通 TLS 读取 `tls_settings.server_name`；明文及 Reality 自动跳过普通证书。

请先在面板填写节点的 TLS 域名/SNI，将该域名 A/AAAA 正确解析到节点，保持公网 TCP 80 可达且本机 80 空闲。域名缺失、域名不是有效 DNS 名、节点监听 80、多节点的 TLS/SNI 不一致或接口异常时，脚本明确报错，不重复询问证书信息。不同域名的节点分别安装。用户也可通过 `--cert-domain` 明确覆盖证书域名。

自动读取只获取证书域名，不会从面板下载私钥，也不能绕过 CA 的域名控制权验证。需要 DNS 验证或已有证书时，按下面高级参数配置。联系邮箱可用 `--cert-email` 指定，默认不询问。

脚本按需通过 apt-get/dnf/yum 安装 curl、CA 证书、Python 3、OpenSSL、coreutils、tar 和 socat，已有依赖可用 `--skip-deps`。正式安装需要 systemd 和 root，不修改防火墙或停止已有 Web 服务。

默认目录和服务名为 `/project/soga-217-local2` 和 `soga-217-local2`，不覆盖已有同名目录/服务。脚本固定版本下载并检查 ZIP、解压文件、本地启用状态和二进制完整性后准备证书与服务。

先保存真实通讯密钥，避免写入命令历史：

```bash
umask 077
read -r -s -p '后端通讯密钥: ' PANEL_SECRET; printf '\n'
printf '%s' "$PANEL_SECRET" > /project/panel-token.txt
unset PANEL_SECRET
```

### 4.1 HTTP 自动证书

域名 A/AAAA 须指向本节点，公网 TCP 80 可达且本机 80 空闲，IPv6 记录也须正确。代理可监听 443、8443 等其他端口。已有 Web 服务占用 80 或代理本身监听 80 时，选择 DNS 验证。

```bash
bash /project/install.sh \
  --panel-url https://panel.example.com/ \
  --node-id 52 --token-file /project/panel-token.txt --auth-code local \
  --cert-mode http --cert-domain anytls.example.com \
  --cert-email admin@example.com --name soga-217-anytls
```

VLESS 普通 TLS/WSS 使用相同证书参数，另加 `--protocol vless` 并更换 ID 和域名。域名须匹配 SNI 与客户端验证；每实例申请一个普通域名，不申请 IP 证书或通配符。

### 4.2 DNS 自动证书

Cloudflare `dns_cf` 的 Token 需目标区域的 DNS 编辑及区域读取权限：

```bash
umask 077
read -r -s -p 'Cloudflare DNS API Token: ' DNS_SECRET; printf '\n'
printf 'CF_Token=%s\n' "$DNS_SECRET" > /project/acme-dns.env
unset DNS_SECRET
bash /project/install.sh \
  --panel-url https://panel.example.com/ \
  --node-id 52 --token-file /project/panel-token.txt --auth-code local \
  --cert-mode dns --cert-domain anytls.example.com \
  --cert-email admin@example.com \
  --dns-provider dns_cf --dns-env /project/acme-dns.env \
  --name soga-217-anytls
```

其他服务商使用对应 acme.sh 插件和变量，例如 `dns_ali` 的 `Ali_Key`、`Ali_Secret`。凭据每行 `KEY=value`，不写 export，不执行 shell 替换。实例下的 `acme-dns.env` 权限 600；ACME 配置也可能保存凭据，这些文件不可公开。

使用固定校验的 acme.sh 3.1.6 和 Let’s Encrypt，工具、账户和证书分别在实例的 `acme/`、`acme-data/`、`certs/` 中，不修改 profile 或添加 acme cron。systemd timer 管理续期。核心读取 `cert_mode=file` 和固定 PEM 路径；CLI 的 auto/http/dns 是安装器选项。默认 auto 需要读取面板 config，即使 prepare-only 也会读取一次；显式指定证书模式及完整域名时可只做本地准备。

### 4.3 已有证书或暂不启动

```bash
bash /project/install.sh \
  --panel-url https://panel.example.com/ \
  --node-id 52 --token-file /project/panel-token.txt --auth-code hello \
  --cert-mode file --cert /project/certificates/fullchain.pem \
  --key /project/certificates/privkey.pem --name soga-217-anytls --check-panel
```

手动证书检查有效期和密钥匹配，域名/信任链仍需在实际客户端验证。VLESS 明文 TCP/WS 或 Reality 用 `--protocol vless --cert-mode none` 并去掉证书参数；AnyTLS 不能用 none。

`--prepare-only --dest /project/soga-preview` 只生成文件并检查，不安装依赖或 systemd、不签发。`--no-start` 写完整 unit 但不签发、启用或启动。已下载 ZIP 可用 `--archive /project/soga-local2-2.17.0-linux-amd64.zip`，仍检查固定摘要。

`--check-panel` 只读 config/user，只输出端口、网络和用户数量摘要，不输出 token、UUID 或节点私钥，不跟随重定向；不代表客户端链路已连通。

## 5. 手动配置与运行

解压后先运行 `sha256sum -c SHA256SUMS`，再编辑 `soga.conf`：

```ini
type=xiaov2board
server_type=anytls
api=webapi
node_id=52
webapi_url=https://panel.example.com/
webapi_key=replace-with-real-server-token
soga_key=local
listen=0.0.0.0
check_interval=60
submit_interval=60
forbidden_bit_torrent=false
cert_mode=file
cert_file=/project/certificates/fullchain.pem
key_file=/project/certificates/privkey.pem
```

每行一个 key=value，不写 section、YAML 或 JSON，不重复字段。VLESS 改对应协议/ID。端口由面板下发，同机反代可监听 127.0.0.1。

```bash
chmod +x soga-offline soga.core
./soga-offline --check --config ./soga.conf
./soga-offline --config ./soga.conf
```

`--check` 检查本地文本、配置和完整性，不访问面板或读许可证。手动运行须准备原核心使用的 `/etc/soga` 数据目录和权限，安装器会创建。通过 soga-offline 启动，不直接运行 soga.core。

## 6. 验证、续期和服务管理

1. 通过本地检查，按需做面板预检。
2. 日志确认监听正确端口并加载用户；用户为 0 时核对权限组、套餐、剩余流量和禁用状态。
3. 实际客户端验证域名、信任链、端口和传输。
4. 等待拉取/上报周期，检查在线和流量记录，增删用户验证刷新。

接口为 GET `/api/v1/server/UniProxy/config`、`user` 和 POST `push`、`alive`，使用真实 node_type、node_id 和 token。本地文本不改变用户 UUID 认证或面板业务限制。

```bash
systemctl status soga-217-anytls --no-pager
journalctl -u soga-217-anytls -n 80 --no-pager
systemctl restart soga-217-anytls
systemctl stop soga-217-anytls
systemctl list-timers soga-217-anytls-cert-renew.timer
journalctl -u soga-217-anytls-cert-renew.service -n 80 --no-pager
```

自动模式每日加随机延迟检查续期，未到期不重启；证书更新成功后校验并重启对应实例。手动模式自行管理续期。首次签发失败不启动主服务或启用 timer，目录和 unit 保留。修复域名、80 端口或 DNS 权限后执行：

```bash
/project/soga-217-anytls/certificate.sh issue
systemctl enable --now soga-217-anytls soga-217-anytls-cert-renew.timer
```

prepare-only 不创建 unit，验收后用新的正式目录重新安装。真实工具安装、合成签发/续期及失败处理已经检查；公网 CA 签发仍须完成实际域名验证。

## 7. 升级与回退

保留旧目录、配置和服务，以新目录/服务名加 `--no-start` 安装新版。不再使用旧 license.json，无需重签。已有有效证书可沿用原路径。

核对新配置，先停占用同一端口的旧服务，再启动新版。例如：

```bash
systemctl stop soga-217-local1
systemctl start soga-217-local2
systemctl status soga-217-local2 --no-pager
```

自动证书模式先完成首次签发，再启用 timer。验证客户端、用户增删和上报后启用新版开机启动、禁用旧版。回退时停新版及其 timer，启动保留的旧版，旧版仍用原有授权方式。避免两套服务占用同一端口或同时更新同一证书。

面板预检和SNI发现请求使用与Go后端一致的User-Agent，兼容拒绝Python默认请求标识的面板访问防护。
