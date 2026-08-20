# DeepSeek Harness Linux 离线安装器

这是由社区维护的 DeepSeek Harness 无 sudo 离线安装器和私有兼容运行时，当前首个预发行版
仅支持 GNU/Linux ARM64。

> [!IMPORTANT]
> 本项目不是 DeepSeek 官方项目，与 DeepSeek AI 不存在隶属、赞助或背书关系。

## 当前范围

- upstream `@deepseek-ai/dsh@0.1.0-rc.7`，不修改业务代码或 engines
- Node.js `22.23.2`
- Debian 10 ARM64 glibc 2.28 私有运行时
- Conda libstdc++/libgcc 与离线 native addon 工具链
- 目标机不联网、不使用 sudo、不设置全局 `LD_LIBRARY_PATH`
- 默认安装到 `~/.local/share/dsh-kylin`

安装器要求 Linux `aarch64`、系统 glibc `>= 2.17`、kernel `>= 4.4`。Node 官方 ARM64
支持基线为 kernel `>= 4.18`、glibc `>= 2.28`；本包解决 glibc 问题，但 kernel 4.4–4.17
仍属于必须实机验证的兼容模式。

适用目标包括 ARM64 版银河麒麟、统信 UOS、openEuler、Debian、Ubuntu、RHEL、Rocky、
AlmaLinux 和 Anolis OS。当前不支持 x86_64、LoongArch、RISC-V、ARM32 或 Alpine/musl。

## 从 Release 安装

下载对应预发行版的离线包和 `SHA256SUMS`：

```bash
sha256sum -c SHA256SUMS
tar -xzf dsh-linux-arm64-offline-0.1.0-rc.7-stellaria.1.tar.gz
cd dsh-linux-arm64-offline-0.1.0-rc.7-stellaria.1
bash install.sh
```

安装后：

```bash
$HOME/.local/bin/dsh-diagnose
$HOME/.local/bin/dsh-configure-key
$HOME/.local/bin/dsh-web
```

Web UI 只监听 `127.0.0.1:3080`。API Key 不写入 Release、桌面文件、shell 历史或公开日志。

## 安全边界

安装器不会修改 `/lib`、`/usr/lib`、`/etc/ld.so.conf*` 或 shell 启动文件。Node 和 native
addon 的 PT_INTERP/RPATH 在用户版本目录中修补；安装验收失败会恢复旧版本。

Git 仓库只保存脚本、锁文件、ELF 审计、许可证和构建元数据；数百 MiB 的二进制只作为
GitHub Release Asset 发布。详情见英文 [README](README.md)、
[第三方声明](THIRD_PARTY_NOTICES.md)、[源码获取说明](SOURCE_AVAILABILITY.md)
和 [免责声明](DISCLAIMER.md)。
