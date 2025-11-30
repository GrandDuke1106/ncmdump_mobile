# ncmdump-mobile

这是一个基于 Flutter 开发的安卓应用，为 [ncmdump-go](https://git.taurusxin.com/taurusxin/ncmdump-go) 提供了现代化的移动端图形界面。

非手机端也可以使用[ncmdump-gui](https://git.taurusxin.com/taurusxin/ncmdump-gui)。

它可以帮助你在 Android 设备上直接将网易云音乐的 `.ncm` 文件转换为普通的 `.mp3` 或 `.flac` 格式，并自动补全专辑封面等元数据。

## ✨ 功能特性

* **批量转换**：支持添加单个文件或扫描整个目录下的 `.ncm` 文件。
* **元数据修复**：转换同时自动下载并修复歌曲的专辑封面、歌手、专辑名等信息。
* **智能分组**：自动按目录分组显示文件，清晰直观。
* **目录历史**：记住你添加过的目录，支持下拉刷新，一键重新扫描所有历史目录。

## 🚀 编译指南

如果你想自己编译这个项目，请按照以下步骤操作。

### 1. 环境准备

确保你已经安装了以下环境：
* Flutter SDK
* Go 1.18+
* Android Studio & Android SDK
* `gomobile` 工具:
    ```bash
    cd exc
    go install golang.org/x/mobile/cmd/gomobile@latest
    gomobile init
    ```

### 2. 编译 Go 核心库 (.aar)

本项目依赖 `ncmdump-go` 的核心逻辑。你需要先将 Go 代码编译为 Android, Windows 或者 Linux 的 `.aar`, `dll` 或者 `so` 库。

在项目根目录执行：

```bash
# 确保你已经编写了 mobile/bridge.go 桥接文件，当然mobile有一个现成的
# 如果遇到 javac 报错，请检查 JAVA_HOME 环境变量
cd exc
gomobile bind -target=android -androidapi 21 -o ../ncmdump_mobile/android/app/libs/ncmdump.aar ./mobile
go build -buildmode=c-shared -o ../ncmdump_mobile/windows/runner/ncmdump.dll export.go ./desktop
go build -buildmode=c-shared -o ../ncmdump_mobile/linux/libncmdump.so export.go ./desktop
````

> **注意**：生成的 `ncmdump.aar` 文件必须放置在 `ncmdump_mobile/android/app/libs/` 目录下。

### 3. 安装 Flutter 依赖

```bash
cd ncmdump_mobile
flutter pub get
```

### 4. 运行或打包

连接你的 Android 设备或模拟器：

```bash
# 调试运行
flutter run

# 打包 APK
flutter build apk --release
```

## 📦 主要依赖库

  * `file_picker`: 文件与目录选择
  * `permission_handler`: Android 存储权限管理
  * `provider`: 状态管理
  * `shared_preferences`: 本地历史记录存储
  * `device_info_plus`: 获取 Android 版本信息

## ⚖️ 免责声明

本项目基于[MIT](LICENSE)开源，不提供担保。

本项目仅供学习和技术研究使用。请勿将本软件用于任何商业用途或侵犯第三方版权的行为。使用本软件产生的任何法律后果由使用者自行承担。

## 🙏 致谢

后端来自于：[ncmdump-go](https://git.taurusxin.com/taurusxin/ncmdump-go)
