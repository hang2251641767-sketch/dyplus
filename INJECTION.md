# 抖音助手PLUS 1.1 适配预览：构建与注入说明

## 获取文件

在 GitHub 仓库的 Actions 页面选择 `Build DYPlus dylib`，打开成功的运行记录，下载 `DouyinAssistantPLUS-V1.1-preview-arm64-TrollFools`。解压后选取 `DYPlus.dylib`，无需解开 deb。二进制名保留 DYPlus，抖音内名称为“抖音助手PLUS”。

也可以从 Actions 的 Run workflow 手动触发。上传源码时必须保留 `.github/workflows/build.yml`、`scripts/` 等子目录。

## 构建检查范围

工作流使用 Theos 编译 arm64 动态库，并检查架构和加载依赖。如果产物依赖系统目录以外的库，会停止导出。包内包含源码提交号、Theos 提交号、依赖清单和 SHA256 校验值。

工作流成功代表编译和这些静态检查通过；不能证明抖音私有接口、设置入口或其他功能在 40.3.0 正常运行。

## 在目标设备测试

目标测试环境：iPhone 14 Pro，iOS 16.5.1，抖音 40.3.0，TrollFools。用户已反馈 V1.0 原有功能可用；本次扩展配置与诊断导出仍需真机测试。

1. 保存现有抖音数据，并确保可在 TrollFools 中撤销注入。
2. 在 TrollFools 选择抖音，导入解压得到的 `DYPlus.dylib`，完成注入后重新启动抖音。
3. 检查“抖音助手PLUS”设置入口，通过“续火花与密友（适配中）”进入扩展页面。双指长按界面使用“助手功能”按钮进入。
4. 如出现闪退，先在 TrollFools 撤销 DYPlus 注入。仅关闭设置开关不能卸载已经安装的 Hook。

不要同时注入原 DYYY 或另一个 DYPlus 构建，它们含同名类和相同 Hook。

## 已知限制

本版的自动续火花和密友隐藏为待适配项目，只能保存计划及名单。要继续接入，需要导出 `DouyinAssistantPLUS-interfaces.json`；操作见 `ASSISTANT-ADAPTATION.md`。

DYPlus 新模块控制目前是重构骨架，模块开关尚未连接历史 DYYY 功能。历史 Hook 仍可能执行；“恢复安全默认值”只关闭新模块设置，不是整个插件的安全模式。彻底回退需撤销注入。
