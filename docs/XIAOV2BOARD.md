# Xiaov2board 对接使用文档

适用版本：Soga `2.17.0-local1`，Linux amd64。本文的传统节点示例对应 Xiaov2board 的 `/api/v1/server/UniProxy` 接口，使用 `vless` 和 `anytls` 两种节点类型。从2.16.4升级请先阅读[保留旧版的升级步骤](#71-从2164升级并保留回退)。

## 1. 先准备哪些信息

| 信息 | 从哪里取得 | 示例 | 填写位置 |
| --- | --- | --- | --- |
| 面板根地址 | 你部署的 Xiaov2board 网站地址 | `https://panel.example.com/` | `webapi_url` / 脚本 `--panel-url` |
| 后端通讯密钥 | 后台系统配置中的节点/服务器通讯密钥，对应 `server_token` | 由管理员设置的随机长字符串 | `webapi_key`；脚本隐藏输入或 `--token-file` |
| 协议 | 后台新增节点选择的类型 | `vless` 或 `anytls` | `server_type` / `--protocol` |
| 节点ID | 保存节点后，节点列表或编辑请求中的实际ID | `37` | `node_id` / `--node-id` |
| 服务器地址 | 节点服务器公网IP或域名 | `node.example.com` | 面板节点的地址/`host` |
| 客户端连接端口 | 客户端访问的公网端口 | `443` | 面板节点的连接端口/`port` |
| 后端监听端口 | Soga在本机实际监听的端口 | `443` | 面板节点的服务端口/`server_port` |
| 有效本地许可证 | 对应此程序版本及目标机器的签名文件 | `license.json` | 脚本 `--license` |
| TLS证书和私钥 | 自行申请并部署的证书文件 | `/etc/ssl/soga/fullchain.pem`、`privkey.pem` | `cert_file` / `key_file` |

`server_token` 不是后台登录密码、用户订阅token、用户UUID，也不是 Soga 本地许可证。面板账户密码不需要填写到节点配置中。此版本不需要填写原厂 `soga_key`。

`node_id` 必须属于所选协议。例如VLESS节点37要配 `server_type=vless`；AnyTLS的同号节点是另一个节点。多节点只可填写同协议ID，如 `37,38`，不加空格。同机多个节点的实际监听端口必须不同。

## 2. 面板侧怎么填

后台界面名称可能随版本不同，下表同时给出实际配置字段。先建一个最简单的节点，连通后再加反代、CDN或高级加密。

### 2.1 普通 VLESS TCP + TLS

在后台新增VLESS节点：

| 项目 | 建议初始值 | 说明 |
| --- | --- | --- |
| 名称 | `VLESS-TLS-01` | 显示给用户的名称 |
| 地址 `host` | `node.example.com` | 指向节点服务器；与面板域名可以不同 |
| 连接端口 `port` | `443` | 用户客户端连接此端口 |
| 服务端口 `server_port` | `443` | 直连时与连接端口相同；NAT/反代时按实际映射填写 |
| 传输 `network` | `tcp` | 本例不用WS |
| TLS `tls` | `1` / 开启普通TLS | 该面板中0=不启用、1=TLS、2=Reality |
| TLS域名/SNI | `node.example.com` | 对应证书覆盖的域名，客户端也需一致 |
| Flow `flow` | 留空 | 普通VLESS先留空；Vision另行配置 |
| 加密 `encryption` | 留空/null | 本例不用额外VLESS加密；不要手填字符串 `none` |
| 权限组 `group_id` | 测试套餐所在权限组 | 决定哪些用户能下发到节点 |
| 倍率 `rate` | `1` | 按业务计费策略修改 |
| 显示 | 开启 | 决定是否出现在订阅；不替代权限组设置 |
| 父节点 | 留空 | 初次独立部署不设置父节点 |

保存后记下节点ID。服务端需要配置有效证书文件；仅在面板填写SNI不会自动生成本机证书。正式客户端保留证书验证，不使用跳过验证来掩盖证书错误。

如果只在受控环境测试无TLS TCP，面板设 `tls=0`，配置无需证书。公网日常使用建议启用TLS。

### 2.2 VLESS WS / WSS

沿用VLESS基本信息，修改下列项目：

| 项目 | 取值 |
| --- | --- |
| `network` | `ws` |
| WS路径 | `/soga-ws`，必须与客户端及反代一致 |
| WS Host | 使用实际接入域名；需要时在面板网络设置填写 |
| `flow` | 留空；非TCP场景不配置Vision |
| TLS | Soga直接处理WSS时设1并提供证书；TLS在前置反代终止、后端明文WS时设0 |

网络设置由面板以 `networkSettings` 下发。后端配置只填写面板和节点信息，不在本地新增 `network`、`tls`、WS路径来覆盖面板。

采用前置反代时，客户端连接端口可为443、Soga本地服务端口可为10000，监听地址设 `127.0.0.1`；反代需正确转发WebSocket Upgrade并使用同一路径。只在反代与Soga同机时使用本机回环地址。

### 2.3 AnyTLS

在后台新增AnyTLS节点：

| 项目 | 建议初始值 | 说明 |
| --- | --- | --- |
| 名称 | `AnyTLS-01` | 自定义 |
| `host` | `anytls.example.com` | 指向节点服务器 |
| `port` / `server_port` | `8443` / `8443` | 避免与同机VLESS的443冲突 |
| `server_name` | `anytls.example.com` | 对应客户端SNI及证书 |
| 跳过证书验证 `insecure` | `0` / 关闭 | 使用可信、匹配的证书 |
| `padding_scheme` | 留空使用默认 | 只在明确需要时按面板支持格式修改 |
| 权限组/倍率/显示 | 与测试套餐匹配、1、开启 | 与VLESS同理 |

对应的AnyTLS配置接口返回 `server_port`、`server_name` 和 `padding_scheme`，不需要自己添加VLESS的 `network/tls` 字段。AnyTLS本身使用TLS，节点服务器必须另配证书和私钥。客户端密码使用面板用户的UUID，不是通讯密钥。

### 2.4 Reality / Vision / MLKEM

这些设置由VLESS面板字段下发，当前包沿用核心中的相应实现。部署脚本负责面板、证书和服务管理，不自动生成Reality/MLKEM密钥，也不把复杂模式视为已验收。先完成普通TCP/TLS或WS对接，再按客户端兼容性配置。

Reality使用面板 `tls=2`、对应服务端私钥、目标地址/端口、允许SNI和short ID；客户端使用对应公钥。Vision使用TCP及匹配的 `xtls-rprx-vision`。不要把普通TLS的PEM证书、Reality密钥和MLKEM密钥混填。

### 2.5 新版的 sub_type 与 v2node 节点

原版2.17.0增加了用于 Xiaov2board v2node 节点的 `sub_type`。v2node 是面板中独立的节点分类，内部再选择协议；它的节点ID不等于传统VLESS或AnyTLS分类下的同号节点。不要仅因节点实际使用VLESS就把v2node节点ID填进本文的传统VLESS示例。

对应面板实现中，传统节点配置走 `/api/v1/server/UniProxy/config`；v2node配置走 `/api/v2/server/config`，响应包含 `protocol`、`network_settings` 等字段。v2node的配置获取、用户刷新、流量和在线数据上报需要一起核对。原版的新增参数不能代替这些接口的实际验收。

本发行暂不支持v2node节点，启动器拒绝非空 `sub_type`，安装器也会明确拒绝 `--sub-type`。已有传统VLESS、AnyTLS节点升级保持原来的节点类型和ID，不需要添加 `sub_type`。需要迁移节点分类时，先等待明确支持相应接口的发行版，再在独立测试节点验证账户增删、代理、流量和在线数据。

## 3. 准备许可证与服务器

公开下载包不含部署许可证，也不含签发私钥。许可证可绑定机器、有效期、协议及本地限额；当前程序固定信任已有签发公钥。用另一把自行生成的私钥签名，不会被此程序接受。

在目标服务器下载脚本并取得机器指纹：

```bash
curl -fL https://raw.githubusercontent.com/kiksok/soga-binaries/v2.17.0-local1/install.sh -o install.sh
bash install.sh --fingerprint
```

将输出指纹交给持有对应签发私钥的管理员，取得本机可用的 `license.json` 后，单独放到服务器，例如 `/secure/license.json`。许可证不能直接手改客户、日期或额度，修改后需要重新签名。迁移到另一台机器前确认机器绑定是否需要重签。

依赖示例：

```bash
# Debian / Ubuntu
sudo apt-get update
sudo apt-get install -y curl ca-certificates python3 openssl coreutils

# Rocky / AlmaLinux / 其他使用dnf的系统
sudo dnf install -y curl ca-certificates python3 openssl coreutils
```

脚本不会自动修改防火墙、安装依赖或申请证书。请在云安全组和本机防火墙放行面板 `server_port` 对应的入站TCP端口；使用其他转发模式时按实际需要配置。服务端必须能访问面板HTTPS地址及正常代理目的地址。

## 4. 使用脚本安装

### 4.1 交互式安装

```bash
sudo bash install.sh --license /secure/license.json
```

依次输入协议、面板根地址、节点ID和后端通讯密钥。密钥输入不回显。AnyTLS会继续询问证书和私钥路径；VLESS也会询问可选证书路径，普通TLS/WSS填写证书和私钥，明文TCP/WS或Reality留空。

默认服务名 `soga-217-local1`，安装目录 `/opt/soga-217-local1`。已有同名目录或服务不会被覆盖。脚本会校验固定版本ZIP和解压文件摘要、执行本地 `--check`，通过后安装并启用服务。升级时先增加 `--no-start`，按第7.1节手动切换，避免与正在运行的旧版占用相同端口。

### 4.2 明确参数：VLESS TLS

先将通讯密钥保存在只有自己可读的文件。使用下面方式输入可避免将真实密钥写入命令历史：

```bash
umask 077
read -r -s -p '后端通讯密钥: ' PANEL_SECRET; printf '\n'
printf '%s' "$PANEL_SECRET" > panel-token.txt
unset PANEL_SECRET
```

安装：

```bash
sudo bash install.sh \
  --license /secure/license.json \
  --protocol vless \
  --panel-url https://panel.example.com/ \
  --node-id 37 \
  --token-file ./panel-token.txt \
  --cert /etc/ssl/soga/fullchain.pem \
  --key /etc/ssl/soga/privkey.pem \
  --name soga-217-vless \
  --check-panel
```

`--check-panel` 会读取真实面板的config/user接口，只输出端口、传输及账户数量摘要，不输出通讯密钥、用户UUID或节点私钥；不会跟随HTTP重定向。它不证明客户端到节点的链路一定可用。

### 4.3 明确参数：AnyTLS

```bash
sudo bash install.sh \
  --license /secure/license.json \
  --protocol anytls \
  --panel-url https://panel.example.com/ \
  --node-id 52 \
  --token-file ./panel-token.txt \
  --cert /etc/ssl/soga-anytls/fullchain.pem \
  --key /etc/ssl/soga-anytls/privkey.pem \
  --name soga-217-anytls \
  --check-panel
```

两种协议同机部署时分别运行脚本，使用不同服务名、目录和面板服务端口。许可证必须允许所选协议。

### 4.4 只生成文件 / 暂不启动 / 本地ZIP

```bash
# 在专用目录准备文件并校验许可证，不修改systemd或启动核心
bash install.sh --prepare-only --dest /tmp/soga-217-preview \
  --license /secure/license.json --protocol vless \
  --panel-url https://panel.example.com/ --node-id 37 \
  --token-file ./panel-token.txt

# 已下载ZIP时增加 --archive 参数，仍校验脚本内固定摘要
sudo bash install.sh --archive ./soga-local1-2.17.0-linux-amd64.zip \
  --license /secure/license.json --no-start
```

`--no-start` 会安装systemd定义，但不启用或启动；准备好配置后执行 `systemctl enable --now 服务名`。无systemd环境用 `--prepare-only`，再按自己的进程管理器运行。先选不存在的专用目录，不要指向已有业务目录。

## 5. 不用脚本，手动填写配置

解压发行ZIP，在修改配置前运行 `sha256sum -c SHA256SUMS`。然后将许可证放到同目录，编辑 `soga.conf`：

```ini
type=xiaov2board
server_type=vless
api=webapi
node_id=37
webapi_url=https://panel.example.com/
webapi_key=replace-with-your-server-token
listen=0.0.0.0
check_interval=60
submit_interval=60
tcp_timeout=120
udp_timeout=2
forbidden_bit_torrent=false
cert_mode=file
cert_file=/etc/ssl/soga/fullchain.pem
key_file=/etc/ssl/soga/privkey.pem
```

| 本地字段 | 如何填写 |
| --- | --- |
| `type` | 固定 `xiaov2board` |
| `api` | 固定 `webapi` |
| `server_type` | 小写 `vless` / `anytls` |
| `node_id` | 该协议实际节点ID；同协议多ID用逗号分隔 |
| `webapi_url` | 面板根地址，保留真实子目录；不加 `/api/v1/server/UniProxy/config`，不填后台登录路径 |
| `webapi_key` | 面板后端通讯密钥 `server_token` |
| `listen` | 直连一般填 `0.0.0.0`；本机反代可填 `127.0.0.1` |
| `check_interval` / `submit_interval` | 初始填60秒；面板也返回 `base_config.pull_interval/push_interval`，须一并核对面板设置 |
| `cert_mode` | 手动证书填 `file` |
| `cert_file` / `key_file` | 完整证书链及匹配私钥的绝对路径；AnyTLS/普通TLS需要，明文TCP/WS不填 |

保持一行一个 `key=value`，不要写YAML、JSON或带 `[section]` 的INI；不要重复同一个字段。节点监听端口从面板 `server_port` 获取，无需另填本地端口。

运行：

```bash
chmod +x soga-offline soga-license soga.core
./soga-offline --check --config ./soga.conf
./soga-offline --config ./soga.conf
```

手动运行应准备原核心使用的 `/etc/soga` 数据目录及写权限；服务安装器会创建该目录。正式管理服务时通过启动器运行，不要直接运行 `soga.core`。

## 6. 如何确认对接成功

1. `--check` 成功：仅说明本地签名、机器、期限、协议、节点额度、原文件及配置通过检查，不会访问真实面板。
2. `--check-panel` 成功：接口返回正确配置及用户数组。用户数为0时检查用户是否在节点权限组、套餐是否有效、流量是否耗尽、账户是否被禁用。
3. 查看服务日志：确认节点已监听正确端口、加载用户且没有证书或端口冲突错误。
4. 从面板获取测试账户订阅，客户端连节点并访问网络，核对TLS域名、WS路径等参数。
5. 等待拉取/上报周期，在面板检查节点最近检查时间、流量和在线记录；再增删测试账户，确认后续刷新生效。

接口分工：

| 方法与路径 | 用途 |
| --- | --- |
| `GET /api/v1/server/UniProxy/config` | 取得节点服务端口、传输、TLS等配置 |
| `GET /api/v1/server/UniProxy/user` | 取得本节点可用账户 |
| `POST /api/v1/server/UniProxy/push` | 正常流量上报 |
| `POST /api/v1/server/UniProxy/alive` | 正常在线用户/IP上报 |

每次请求使用 `node_type`、`node_id` 和 `token`。本地许可证解决程序授权，用户是否能代理仍由面板下发的账户及其UUID决定。无需向公开仓库提交任何真实配置、token或许可证。

## 7. 服务、证书续期和更新

将下面 `soga-217-vless` 换成实际 `--name`；未指定名称的新安装默认是 `soga-217-local1`：

```bash
sudo systemctl status soga-217-vless --no-pager
sudo journalctl -u soga-217-vless -n 80 --no-pager
sudo journalctl -u soga-217-vless -f
sudo systemctl restart soga-217-vless
sudo systemctl stop soga-217-vless
sudo systemctl disable --now soga-217-vless
```

脚本的配置与许可证在 `/opt/服务名/` 下，均按受限权限保存；临时运行文件位于该目录的 `tmp/`。脚本安装后 `SHA256SUMS` 只记录三个不可变二进制，修改配置不影响二进制校验。

证书续期后核对链和私钥路径，并重启相应服务，不假设自动热加载。许可证到期、移除或变为无效时启动器会停止核心；许可证调整或迁机需由对应签发管理员处理。

### 7.1 从2.16.4升级并保留回退

新版本不自动覆盖旧目录、替换现有服务或升级现有许可证。许可证绑定的程序与清单摘要已变化，需要签发管理员为2.17.0准备对应许可证；保留旧版许可证用于回退。以下以旧服务 `soga-local2`、新服务 `soga-217-local1` 为例，实际名称可通过 `systemctl status` 确认。

1. 保留原安装目录及配置、许可证，另行安全备份。旧版 `license.json` 留在旧安装目录，新版许可证另存为 `/secure/license-2.17.0.json`，不要覆盖旧版许可证。记录旧服务名、节点类型/ID、面板地址、证书路径和实际端口；不要把真实配置提交到公开仓库。
2. 下载本版安装脚本，使用全新服务名和目录，添加 `--no-start`。与旧版使用同一节点/端口时，此时只准备新版，保持旧版继续服务。

```bash
curl -fL https://raw.githubusercontent.com/kiksok/soga-binaries/v2.17.0-local1/install.sh -o install-2.17.0.sh
sudo bash install-2.17.0.sh \
  --license /secure/license-2.17.0.json \
  --protocol vless \
  --panel-url https://panel.example.com/ \
  --node-id 37 \
  --token-file ./panel-token.txt \
  --cert /etc/ssl/soga/fullchain.pem \
  --key /etc/ssl/soga/privkey.pem \
  --name soga-217-local1 \
  --dest /opt/soga-217-local1 \
  --check-panel --no-start
```

上例是普通VLESS TLS；AnyTLS改为 `--protocol anytls` 及对应节点ID和证书，明文TCP/WS去掉 `--cert` / `--key`。有效的原有证书可继续使用原绝对路径，无需移动到新版安装目录。`panel-token.txt` 按第4.2节准备。安装器的本地检查和面板预检不启动代理监听；它们通过后仍须验证真实客户端。

3. 核对新目录的 `soga.conf`，然后切换。先停旧服务，释放同一端口，再启动新服务：

```bash
sudo systemctl stop soga-local2
sudo systemctl start soga-217-local1
sudo systemctl status soga-217-local1 --no-pager
sudo journalctl -u soga-217-local1 -n 80 --no-pager
```

4. 用实际客户端验证代理、用户增删、流量和在线上报。确认成功后再调整开机启动：

```bash
sudo systemctl enable soga-217-local1
sudo systemctl disable soga-local2
```

5. 若启动失败或对接异常，停止新版并启动保留的旧版。回退不需要覆盖文件或重新下载：

```bash
sudo systemctl disable --now soga-217-local1
sudo systemctl enable --now soga-local2
```

保留两套目录，直到新版按实际业务验收完成。不要同时运行同端口的两套服务，不要把新版二进制或许可证复制到旧版运行目录或 `tmp/` 中混用。

## 8. 常见问题

| 现象 | 优先检查 |
| --- | --- |
| `token is null` / `token is error` | `webapi_key` 是否为面板后端通讯密钥；是否粘贴错误或取错面板 |
| `server is not exist` | 节点ID与 `vless/anytls` 类型是否对应；节点是否已保存 |
| 301/302/404 / 面板检查重定向 | 填最终面板根地址；不要填后台入口或API全路径；核对面板子目录与Web重写 |
| 面板API返回HTML/登录页 | 核对WAF/CDN人机验证、API路由和反代配置 |
| 许可证machine mismatch / expired | 目标机器绑定、系统时间、期限及是否使用正确的签名许可证 |
| 许可证manifest/hash mismatch | 程序与许可证版本是否匹配；不要混用旧版许可证或替换其中一个二进制 |
| `address already in use` | 同机不同节点是否占用同一服务端口；用 `ss -lntp` 检查 |
| 客户端TLS错误 | 证书链、有效期、SNI、私钥匹配及系统时间；不要仅关闭客户端验证 |
| AnyTLS一直认证失败 | 客户端密码应为该用户UUID；节点应是AnyTLS类型且正确加载用户 |
| 用户数0或账户未下发 | 节点权限组与用户套餐权限组、到期时间、剩余流量、禁用状态 |
| 节点在线但流量不增长 | 是否实际产生新流量、上报周期、面板队列/Redis/统计任务是否正常 |
| `/etc/soga` 数据文件错误 | 数据目录存在且有写权限；按实际环境准备Geo/路由数据 |
| `Permission denied` 启动运行副本 | 安装目录/TMPDIR是否位于 `noexec` 挂载；将TMPDIR设到可执行专用目录 |
| 本地 `unknown error` 日志 | 此测试版部分停用路径返回本地错误；结合 `--check`、监听和实际代理结果判断，不据单行日志断言整个服务失败 |

对外提供日志前删除通讯密钥、订阅链接、用户UUID、节点密钥和个人路径。此公开仓库仅用于二进制发行及部署说明。
