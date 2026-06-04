# AppCloner (macOS 应用程序多开/分身生成器)

AppCloner 是一个专为 macOS 设计的通用应用程序双开/多开分身管理工具。它通过动态链接库注入（dylib interposition）技术拦截底层 POSIX 和 Cocoa 目录查找 API，让任意 App 都能在完全隔离的沙盒数据目录中运行，实现真正的多实例同时运行（如在同一台 Mac 上同时登录两个不同的 Bambu Studio 账号）。

## 🌟 主要功能

- **通用双开/多开**：拖入任意 `.app` 到窗口内即可立即创建一个独立分身。
- **完全沙盒数据隔离**：每个分身都拥有独立的 `HOME`、`Library/Application Support` 和 `Caches` 目录。
- **APFS 瞬间克隆**：基于 APFS 的写时复制（Copy-on-Write）技术，瞬间完成克隆且不占用双倍磁盘空间。
- **内置自动签名**：自动执行 Ad-hoc 签名以绕过 macOS Hardened Runtime 限制，确保注入库能正常加载。
- **全架构通用支持**：二进制文件及注入库（dylib）均编译为 Universal Binary (同时支持 Apple Silicon M1/M2/M3 和 Intel 处理器)。
- **美观易用**：基于 SwiftUI 设计，提供半透明磨砂质感界面，支持拖拽创建，以及在 Finder 中一键打开沙盒数据目录。

---

## 📂 项目结构

```
AppCloner-for-mac/
├── AppCloner.swift       # Swift / SwiftUI 应用主逻辑

├── libredirect.m         # 核心 Hook 注入动态链接库源码 (Objective-C)
├── Info.plist            # App Bundle 配置模板
├── AppIcon.icns          # 应用程序图标文件
├── build.sh              # 自动编译与打包打包工具脚本 (可执行)
└── README.md             # 项目说明文档
```

---

## 🛠️ 如何编译与打包

在终端中进入当前目录，然后直接执行编译脚本：

```bash
chmod +x build.sh
./build.sh
```

### 编译脚本所做的工作：
1. **清理缓存**：删除先前的 `build` 文件夹和旧的 `.dmg`。
2. **编译 Universal Dylib**：使用 `clang` 编译出兼容 Intel (`x86_64`) 与 M系列芯片 (`arm64`) 的 `libredirect.dylib`。
3. **编译 AppCloner 客户端**：分别编译 Swift 源码至 `arm64` 和 `x86_64` 目标，并使用 `lipo` 合并为通用二进制文件。
4. **组装 App Bundle**：按照 macOS 规范组装为 `AppCloner.app`。
5. **代码签名**：对打包好的 App 进行 ad-hoc 重签名 (`codesign --force --deep --sign -`)。
6. **制作 DMG 安装包**：使用 `hdiutil` 自动将 App 打包为高压缩的 `AppCloner.dmg`，便于分发。

---

## 🚀 分发到其他 Mac 电脑上运行（避坑指南）

由于该软件是自行编译且未通过苹果官方公证（Notarization），在将打包好的 `AppCloner.dmg` 发送到其他 Mac 电脑安装时，通常会遇到 **“打不开，因为 Apple 无法检查其是否包含恶意软件”** 或 **“已损坏，无法打开”** 的 Gatekeeper 拦截警告。

请按以下方式处理以正常运行：

1. **拖入 Applications**：将 `AppCloner.app` 从 DMG 拖入目标电脑的 `/Applications` (应用程序) 文件夹中。
2. **解除 Gatekeeper 隔离**：
   打开 **终端 (Terminal.app)**，运行以下命令清除下载隔离属性：
   ```bash
   xattr -cr /Applications/AppCloner.app
   ```
3. **正常双击打开**：此时即可双击正常运行 AppCloner。

---

## 🔬 核心隔离原理

AppCloner 能够实现独立分身的底层核心逻辑如下：

1. **环境重定向**：
   在启动分身 App 时，AppCloner 为子进程设置了自定义的环境变量：
   - `HOME` 指向隔离的沙盒数据目录（如 `~/AppClones/Data/App_Clone1`）。
   - `CUSTOM_HOME` 也指向该沙盒目录。
   - `DYLD_INSERT_LIBRARIES` 注入了 `libredirect.dylib`。
   - `DYLD_FORCE_FLAT_NAMESPACE` 设为 `1`。

2. **Dylib 动态拦截 (libredirect.dylib)**：
   利用 macOS 的 `__interpose` 机制，在子进程启动时替换以下四个核心 API：
   - `NSHomeDirectory()` (Cocoa 获取 Home 路径)
   - `NSSearchPathForDirectoriesInDomains(...)` (Cocoa 检索 Application Support / Library 等路径)
   - `getpwuid(...)` (POSIX 系统级用户结构查询)
   - `getpwuid_r(...)` (线程安全的 POSIX 用户结构查询)

   当子进程的二进制代码调用这些 API 访问主电脑的配置时，会被强制重定向到我们自定义的 `CUSTOM_HOME` 沙盒目录，从而实现完全独立的数据保存与读取，不会污染原版 App 的数据。
