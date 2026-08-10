# 工时账本（HarmonyOS）

一个使用 ArkTS 和 HarmonyOS 原生关系型数据库 RDB 实现的钟点工工时、工资记录应用。

## 已实现

- 新增、编辑、删除每日工时记录
- 使用带星期栏的系统月历选择工作日期
- 记录上午/下午、工作小时数、时薪和备注
- 工时保留一位小数，上下箭头按 0.5 小时向上或向下对齐
- 新增记录时自动沿用上次新增的时段、工时和时薪
- 自动按工时和时薪计算工资
- 按月份查看和切换记录
- 统计出勤天数、总工时、总工资、平均时薪和平均日薪
- 使用 `@kit.ArkData` 的 `relationalStore` 持久化，数据保存在设备本地

## 运行

1. 使用 DevEco Studio 打开本目录。
2. 等待 OHPM/Hvigor 同步完成。
3. 选择已配置签名的模拟器或真机运行 `entry` 模块。

工程最低兼容版本和目标 SDK 均为 HarmonyOS 6.1.0（API 23）。请使用配套 HarmonyOS 6.1 SDK 的 DevEco Studio 打开并同步工程；编译 SDK 由 DevEco Studio 自动选择其配套版本。

## 数据库

数据库名为 `hourly_work_v2.db`，核心表为 `work_record`。新 Schema 直接保存日期、上午/下午、小时数、时薪、备注和工资。
