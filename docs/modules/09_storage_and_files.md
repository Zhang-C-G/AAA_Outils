# 模块 09：存储层与文件格式

## 模块目标

- 统一管理配置读写、使用频率、笔记、截图与速率限制文件。
- 保证“除非手动删除，否则长期保留”的持久化原则。

## 主要文件

- `src/storage.ahk`
- `src/storage/data_load.ahk`
- `src/storage/data_save.ahk`
- `src/storage/usage.ahk`
- `src/storage/notes.ahk`
- `src/storage/capture_file_ops.ahk`
- `src/storage/capture_bridge.ahk`
- `src/storage/assistant.ahk`

## 核心数据文件

- `config.ini`
- `usage.ini`
- `config.snapshot.ini`
- `assistant_rate.ini`
- `notes/*.md`
- `captures/*.png`

## 改动后必查

1. 保存后重启进程，数据仍存在。
2. `config.ini` 分区结构保持完整。
3. 版本恢复能回到最近保存快照。
