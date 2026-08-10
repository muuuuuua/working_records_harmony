# 工时账本（HarmonyOS）

一个使用 ArkTS 和 HarmonyOS 原生关系型数据库 RDB 实现的钟点工工时、工资记录应用。

## 已实现

- 新增、编辑、删除每日工时记录
- 记录日期、起止时间、休息分钟、时薪和备注
- 自动计算跨午夜班次的有效工时及工资
- 按月份查看和切换记录
- 统计出勤天数、总工时、总工资、平均时薪和平均日薪
- 使用 `@kit.ArkData` 的 `relationalStore` 持久化，数据保存在设备本地

## 运行

1. 使用 DevEco Studio 打开本目录。
2. 等待 OHPM/Hvigor 同步完成。
3. 选择已配置签名的模拟器或真机运行 `entry` 模块。

工程目标 SDK 为 HarmonyOS 5.0.0（API 12）。若本机只安装了更新版本的 SDK，可在根目录 `build-profile.json5` 中调整 `compatibleSdkVersion`。

## 数据库

数据库名为 `hourly_work.db`，核心表为 `work_record`。工资和有效分钟数在保存时一并固化，便于历史统计保持一致。
