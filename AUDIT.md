# DYPlus V1.0 审查记录

## 1.1.2 导出闪退修复候选（2026-10-15）

用户反馈1.1.1点击停止并导出后立即退出，未出现分享面板，尚未取得设备崩溃日志。代码中全进程扫描把Class值存入NSMutableDictionary；macOS回归夹具复现 `legacyClassContainerInitialized=YES`，而新读取器的“不触发目标初始化”断言通过。这证实旧扫描存在意外执行类初始化的缺陷，但尚不能单独证明该手机崩溃的全部原因。

修复移除全进程扫描、Class容器、关联展开、导出点击时的实时视图遍历及自动分享；先保存快照，逐类检查并原子保存检查点和活动阶段。增加独立系统文件保存器、轻量快照模式及复制阶段入口。对目标数、元数据条数、报告体积和处理时间设置明确限制并标注。

源码 `6e80bd57b21989d3f761f2c72a3bbebad6f42291` 通过 [CI编译与三组测试](https://github.com/hang2251641767-sketch/dyplus/actions/runs/38676613147)。安全测试覆盖目标不初始化、缺失/Swift类处理、快照跨实例恢复、无效JSON与超限报告不破坏旧检查点、损坏阶段文件回退。产物SHA256：`eaec7f17ba1149d20d3a73853c9f3ea59e40b86c12f64a8e36a3dd7259511fba`。

本版手机端生成、保存和崩溃是否消除尚待复测；自动发消息及实际隐藏仍未接入。

## 1.1.1 定向诊断补充（2026-10-15）

诊断 schema 升至2：已知目标与实测列表类型优先导出，完整记录其方法/属性/成员声明；辅助类型按优先级确定性选择，输出相关类名索引和缺失目标状态。用户可手动启动3分钟页面类型采集，进入后台自动停止，可手动停止/清空；不读取聊天或联系人内容，不执行发送接口。

源码 `b1e469d85755e77bd24d780ddf2f593525230b0c` 已通过 [CI 构建](https://github.com/hang2251641767-sketch/dyplus/actions/runs/38674810834)、配置测试和定向选择测试。回归用例覆盖12,000个无Objective-C方法的噪声类型、目标去重、缺失目标保留、补充预算独立以及输入顺序不影响结果。产物SHA256：`6f027b5054007d3bff79621bc789f68ddd124bebba1321e0afbb305d0835456e`。

这是编译和逻辑测试证据，未验证真机页面采集效果，也不表示续火花发送或密友隐藏完成。参考二进制仅在本地静态分析，其文件和诊断原件均未上传仓库。

## 1.1 预览版补充（2026-10-15）

抖音内显示名称改为“抖音助手PLUS”。增加本地续火花计划/好友名单、密友名单与手动接口元数据导出；实际火花检测、一键导入、自动发送、四处列表隐藏仍未接入，执行开关禁用。[源码提交](https://github.com/hang2251641767-sketch/dyplus/commit/688fb574b29b47d10449c8430397870d4cdcd21a) 已通过 [CI 编译、配置测试、签名与导出](https://github.com/hang2251641767-sketch/dyplus/actions/runs/38672369613)。

用户反馈上一版原有功能可用；本版新增配置和诊断页面尚未获得真机验证。继续接入需要目标应用导出的接口诊断文件，操作见 `ASSISTANT-ADAPTATION.md`。

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

2026-10-15 云端构建结果：源码提交 `184dc2213469ce10884be08f982e8c4a1ca96f57` 已在 macOS CI 运行 `make clean` 和 `make all ARCHS=arm64 SCHEME= FINALPACKAGE=1 INSTALL=0`，编译、链接、签名及导出成功。[构建记录](https://github.com/hang2251641767-sketch/dyplus/actions/runs/38670031403)

产物 SHA256：`a39f1b95301b8c66c9070014910c376880e1de7ec4c38d582f089f3cdd9a6e18`。仅发现系统加载依赖；`otool -L` 首项的 `/Library/MobileSubstrate/DynamicLibraries/DYPlus.dylib` 是动态库自身的安装标识，不是外部 Substrate 依赖。没有进行真机注入测试。

- 当前本地环境为 Windows，没有本地编译成功结论；上述成功证据来自 GitHub Actions 的 `make all`，未验证 deb 打包。
- 未拥有 iPhone 14 Pro / iOS 16.5.1 + 抖音 40.3.0 + TrollFools 注入测试链路，不能声称真机适配或功能兼容。
- 新模块开关尚未接管历史 DYYY Hook，当前为模块化设置骨架；旧 Hook 仍可能执行。新模块回退不是全插件安全模式。

## 建议验证顺序

1. 在 macOS CI 下载 dylib artifact，核对源码提交、架构、依赖和校验值。
2. 在测试设备备份抖音数据后，通过 TrollFools 仅注入 DYPlus，先保持总开关关闭。
3. 测试启动、Feed、设置页、评论和媒体流程；出现异常时撤销 TrollFools 注入。模块迁移完成后再逐项验证开关与回退。
