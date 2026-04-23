# Resolved Incident: 字段/快捷字段加载丢失

状态: RESOLVED
关闭日期: 2026-04-21

## 问题摘要

- 用户在新增字段后刷新，内容显示丢失。
- 期间出现“保存成功但未真实入库”的感知问题。

## 根因汇总

1. 运行中的 Web 服务进程与最新代码版本不一致。
2. 请求体在部分编码场景下 JSON 解析失败风险高。
3. 快捷字段读写映射历史不一致（`quick_fields` section 对齐问题）。
4. 前端存在过期脚本缓存风险与早期脚本语法错误历史。

## 修复要点

- 对齐 `quick_fields -> [QuickFields]` 读写。
- `/api/save` 增加 payload 必填校验。
- 增加保存诊断日志：`config_save_payload` 与 `config_save_result`。
- `Read-BodyJson` 优先 UTF-8 解码并回退 ContentEncoding。
- 静态资源加 no-cache 响应头。
- 快捷字段页改为自动保存；删除栏目改为单次确认。
- 快捷键页改为全宽多列布局。

## 复测结论

- 新增/删除后刷新可保持一致。
- `config.ini` 落盘与 `/api/state` 返回一致。
- 日志可追踪提交行数与落盘行数，便于后续定位。
