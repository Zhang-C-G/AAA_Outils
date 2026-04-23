# Shared 03：存储契约（Storage Contract）

## 定义

各模块共享的数据落盘规则与文件契约。

## 核心文件

- `config.ini`
- `usage.ini`
- `config.snapshot.ini`
- `assistant_rate.ini`

## 约束

1. 默认长期保留，除非用户手动删除。
2. 保存逻辑不能破坏内置分类和默认热键。
3. 新增分区需同步读取、写入和默认回填逻辑。
4. 文档必须同步说明新分区用途与格式。
