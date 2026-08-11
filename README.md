# AppCloner (macOS 应用程序多开/分身生成器)

AppCloner 是一个专为 macOS 设计的通用应用程序双开/多开分身管理工具。它通过动态链接库注入（dylib interposition）技术拦截底层 POSIX 和 Cocoa 目录查找 API，让任意 App 都能在完全隔离的沙盒数据目录中运行，实现真正的多实例同时运行。

## 🌟 主要功能

- **通用双开/多开**：拖入任意 `.app` 到窗口内即可立即创建一个独立分身。
- **完全沙盒数据隔离**：每个分身都拥有独立的 `HOME`、`Library/Application Support` 和 `Caches` 目录。
- **APFS 瞬间克隆**：基于 APFS 的写时复制（Copy-on-Write）技术，瞬间完成克隆且不占用双倍磁盘空间。


通常会遇到 **“打不开，需要解除隔离

   xattr -cr /Applications/AppCloner.app
