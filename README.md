# Soga 二进制发行包

Linux amd64 · Xiaov2board WebAPI · VLESS / AnyTLS · 本地签名许可证

本仓库提供运行二进制、部署脚本和使用文档。核心源码不在此仓库中；二进制从 [Releases](https://github.com/kiksok/soga-binaries/releases) 下载。当前版本：`2.16.4-local2`。

- [详细 Xiaov2board 对接文档](docs/XIAOV2BOARD.md)：面板每项怎么填、TLS / WS / AnyTLS 示例、服务管理及排错。
- [部署脚本](install.sh)：下载固定版本、校验摘要、生成配置、检查本地许可证、安装 systemd 服务。
- [示例配置](examples/)：修改示例值后使用。

## 快速开始

需要 Linux x86_64、Bash、curl、Python 3、coreutils；安装服务需要 systemd 和 root。TLS证书检查另需 OpenSSL。有效许可证须单独取得，不在公开包中；当前程序只信任固定签发公钥，不能自行换一把钥匙后直接使用。

```bash
curl -fL https://raw.githubusercontent.com/kiksok/soga-binaries/v2.16.4-local2/install.sh -o install.sh
sudo bash install.sh --license /secure/license.json
```

按提示填写：协议、面板根地址、该协议的节点ID、后端通讯密钥。AnyTLS还需证书和私钥。已有节点目录会被拒绝覆盖。

没有许可证时可先取得目标机器指纹，不安装服务：

```bash
bash install.sh --fingerprint
```

## 下载文件

发行包 `soga-local2-2.16.4-linux-amd64.zip` 内只有三个二进制、示例配置、说明和校验文件。SHA-256：

```text
8f11a8b66f981e215c500dd1e4bae25515ee9fc756b80afbb63f417549cbd2bc
```

公开发布内容不含部署许可证、签发私钥、机器指纹、个人目录、核心源码或内部分析资料。可执行文件保留运行所需的内嵌数据和正常 Go 编译元数据。

本版本为测试发行。已验证 VLESS / AnyTLS 的账户初始加载、刷新增删、许可限额和进程生命周期；实际面板、证书及复杂传输模式需按部署环境验收。授权校验使用本地签名；面板读取、流量/在线数据上报和代理出站仍正常联网。
