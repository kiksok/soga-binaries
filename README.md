# Soga 二进制发行包

Linux amd64 · Xiaov2board · 2.17.0-local2 · 默认 AnyTLS

安装器默认使用 `anytls`，不询问协议。需要 VLESS 时传入 `--protocol vless`。

本版使用本地启用文本，填写任意非空内容即可，例如 `local`、`123` 或中文。无需 `license.json`、签名、机器绑定或到期检查。本地文本不传给原版核心，原版授权 HTTP 发送流程继续停用。正常面板接口、流量和在线上报、代理出站及证书签发仍按业务需要联网。

- [下载二进制](https://github.com/kiksok/soga-binaries/releases/tag/v2.17.0-local2)
- [详细 Xiaov2board 对接文档](docs/XIAOV2BOARD.md)
- [安装脚本](install.sh)

## 安装

Linux x86_64 服务器上，以 root 执行：

```bash
mkdir -p /project
cd /project
bash <(curl -fsSL https://raw.githubusercontent.com/kiksok/soga-binaries/v2.17.0-local2/install.sh)
```

填写面板根网址、AnyTLS 节点 ID、本地启用文本、真实后端通讯密钥及证书方式。**面板通讯密钥必须是 Xiaov2board 实际的 `server_token`，只有本地启用文本可任意填写。** 用 `--auth-code local` 可预先指定启用文本。

证书方式可选 `http` 自动签发（域名指向本机，TCP 80 空闲且公网可达）、`dns` 自动签发（需要 DNS API 凭据）、`file` 已有证书。AnyTLS 必须使用证书，VLESS 明文或 Reality 可选 `none`。自动模式使用固定校验的 acme.sh 3.1.6 与 Let’s Encrypt，systemd 每日检查续期，证书更新成功后校验并重启对应实例。公网 CA 签发须完成实际域名验证。

默认目录为 `/project/soga-217-local2`，服务名为 `soga-217-local2`。脚本按需安装依赖，不覆盖已有目录或服务。`--prepare-only` 只生成文件并检查；`--no-start` 安装服务定义但暂缓签发和启动。

## 包内容与升级

ZIP 内只有 `soga-offline`、`soga.core`、`soga.conf`、`README.md`、`SHA256SUMS`。仓库只发布二进制、脚本、示例和使用文档，不包含核心源码、内部分析资料、签发私钥或机器绑定信息。

旧版 2.17.0-local1 保留用于回退。升级使用新目录和服务名，不需要转换或签发许可证。先停止占用同一端口的旧服务，再启动新版，按文档验证客户端、用户增删及面板上报。

本版支持传统 Xiaov2board AnyTLS/VLESS，暂不支持非空 `sub_type` 或 v2node。程序仍检查二进制版本完整性，面板用户权限、流量和设备等业务限制仍正常执行。
