# Soga 二进制发行包

Linux amd64 · Xiaov2board WebAPI · VLESS / AnyTLS · 本地签名许可证

本仓库提供运行二进制、部署脚本和使用文档。核心源码不在此仓库中；二进制从 [Releases](https://github.com/kiksok/soga-binaries/releases/tag/v2.17.0-local1) 下载。当前版本：`2.17.0-local1`。

- [详细 Xiaov2board 对接文档](docs/XIAOV2BOARD.md)：面板每项怎么填、TLS / WS / AnyTLS 示例、服务管理及排错。
- [部署脚本](install.sh)：下载固定版本、校验摘要、生成配置、检查本地许可证、安装 systemd 服务。
- [示例配置](examples/)：修改示例值后使用。

## 快速开始

需要 Linux x86_64、Bash、curl、Python 3、coreutils；安装服务需要 systemd 和 root。TLS证书检查另需 OpenSSL。有效许可证须单独取得，不在公开包中；当前程序只信任固定签发公钥，不能自行换一把钥匙后直接使用。

```bash
curl -fL https://raw.githubusercontent.com/kiksok/soga-binaries/v2.17.0-local1/install.sh -o install.sh
sudo bash install.sh --license /secure/license.json
```

按提示填写：协议、面板根地址、该协议的节点ID、后端通讯密钥。AnyTLS还需证书和私钥。默认安装为独立的 `soga-217-local1` 服务，已有节点目录会被拒绝覆盖。升级用户先按[保留旧版的升级步骤](docs/XIAOV2BOARD.md#71-从2164升级并保留回退)安装，避免新旧服务同时占用端口。

没有许可证时可先取得目标机器指纹，不安装服务：

```bash
bash install.sh --fingerprint
```

## 下载文件

发行包 `soga-local1-2.17.0-linux-amd64.zip` 内只有三个二进制、示例配置、说明和校验文件。SHA-256：

```text
d355f7c9ac52818704ca3a3c57391c113d01bd333737c7613713eea6e617274b
```

公开发布内容不含部署许可证、签发私钥、机器指纹、个人目录、核心源码或内部分析资料。可执行文件保留运行所需的内嵌数据和正常 Go 编译元数据。

本版本为测试发行，实际面板、证书及复杂传输模式需按部署环境验收。授权校验使用本地签名；面板读取、流量/在线数据上报和代理出站仍正常联网。本发行支持传统 VLESS / AnyTLS 节点，启动器拒绝非空 `sub_type`，暂不支持 v2node 节点。
