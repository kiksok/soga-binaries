# Soga 二进制发行包

Linux amd64 · Xiaov2board · 2.17.0-local2 · 默认 AnyTLS

安装器 r5 默认使用 `anytls`，只询问面板网址、节点 ID、通讯密钥。读取面板节点的 SNI 后自动申请和续期证书，不询问证书方式、域名、路径、邮箱或本地启用文本。需要 VLESS 时传入 `--protocol vless`。

本版使用本地启用文本，填写任意非空内容即可，例如 `local`、`123` 或中文。无需 `license.json`、签名、机器绑定或到期检查。本地文本不传给原版核心，原版授权 HTTP 发送流程继续停用。正常面板接口、流量和在线上报、代理出站及证书签发仍按业务需要联网。

- [下载二进制](https://github.com/kiksok/soga-binaries/releases/tag/v2.17.0-local2)
- [详细 Xiaov2board 对接文档](docs/XIAOV2BOARD.md)
- [安装脚本](install.sh)

## 安装

Linux x86_64 服务器上，以 root 执行：

```bash
mkdir -p /project
cd /project
bash <(curl -fsSL https://raw.githubusercontent.com/kiksok/soga-binaries/installer-2.17.0-local2-r5/install.sh)
```

只填写面板根网址、AnyTLS 节点 ID、真实后端通讯密钥。**密钥必须是 Xiaov2board 实际的 `server_token`。** 本地启用文本默认设为 local，无需输入。

先在 Xiaov2board 节点编辑页填写 TLS 域名/SNI，让域名指向节点服务器，保持公网 TCP 80 可达且本机 80 空闲。脚本自动从配置接口读取域名，使用固定校验的 acme.sh 3.1.6 与 Let’s Encrypt 签发证书，systemd 每日续期检查，更新成功后校验并重启实例。面板没有有效 SNI 时直接提示修正面板，不重复询问证书信息。自动读取不能代替公网域名验证。

80 不可用时可显式选择 `--cert-mode dns` 并提供 DNS API 凭据；已有证书用 `--cert-mode file --cert 路径 --key 路径`。`--cert-email` 是可选参数。VLESS 默认从面板 TLS 字段判断是否需要普通证书。

默认目录为 `/project/soga-217-local2`，服务名为 `soga-217-local2`。脚本按需安装依赖，不覆盖已有目录或服务。`--prepare-only` 只生成文件并检查；`--no-start` 安装服务定义但暂缓签发和启动。

## 包内容与升级

ZIP 内只有 `soga-offline`、`soga.core`、`soga.conf`、`README.md`、`SHA256SUMS`。仓库只发布二进制、脚本、示例和使用文档，不包含核心源码、内部分析资料、签发私钥或机器绑定信息。

旧版 2.17.0-local1 保留用于回退。升级使用新目录和服务名，不需要转换或签发许可证。先停止占用同一端口的旧服务，再启动新版，按文档验证客户端、用户增删及面板上报。

本版支持传统 Xiaov2board AnyTLS/VLESS，暂不支持非空 `sub_type` 或 v2node。程序仍检查二进制版本完整性，面板用户权限、流量和设备等业务限制仍正常执行。
