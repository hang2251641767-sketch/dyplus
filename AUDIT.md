# DYPlus V1.0 审查记录

审查对象：`https://github.com/huami1314/DYYY`（本地快照 `upstream-DYYY/`）

## 已核对

- 上游仓库公开标注 MIT License；本分支保留原 `LICENSE`，新增代码沿用同一许可证。
- 上游采用 Theos/Logos；入口为 `DYYY.xm`、`DYYYSettings.xm`，依赖集中在 `AwemeHeaders.h`。
- 上游 `Makefile` 产出 tweak 包，CI 使用 macOS、Theos action，并尝试普通/rootless/roothide 三种方案。
- 上游 README 的明确测试声明是抖音 36.5.0；没有发现可证明 40.3.0 真机适配的声明。

## DYPlus V1.0 改动

- 包名/产物名切换为 `DYPlus`，保留原始 DYYY 源码与 Hook 范围，不引入其他插件。
- 新增 `DYPlusFeatureRegistry`：目标版本精确匹配 40.3.0；总开关或版本不匹配时，新模块返回关闭状态。
- 新增中文“兼容性控制”页面：总开关、模块开关、恢复安全默认值；设置页右上角可进入。
- CI 直接编译 arm64 `DYPlus.dylib`，检查架构与系统依赖，上传动态库、构建日志和 SHA256；CI 成功仅表示编译与静态检查成功。

## 未完成/不能虚报

- 当前环境为 Windows，未执行 Theos/macOS `make package`，因此没有本地编译成功结论。
- 未拥有 iPhone 14 Pro / iOS 16.5.1 + 抖音 40.3.0 + TrollFools 注入测试链路，不能声称真机适配或功能兼容。
- 新模块开关尚未接管历史 DYYY Hook，当前为模块化设置骨架；旧 Hook 仍可能执行。新模块回退不是全插件安全模式。

## 建议验证顺序

1. 在 macOS CI 下载 dylib artifact，核对源码提交、架构、依赖和校验值。
2. 在测试设备备份抖音数据后，通过 TrollFools 仅注入 DYPlus，先保持总开关关闭。
3. 测试启动、Feed、设置页、评论和媒体流程；出现异常时撤销 TrollFools 注入。模块迁移完成后再逐项验证开关与回退。
