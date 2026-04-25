# Architecture Docs

最近同步：`2026-04-25`

## 1. 目标

`docs/architecture/` 用于放系统结构视角的文档。

这里关注的是：

- 模块之间如何依赖
- 系统如何分层
- 哪些地方是高耦合点
- 改动一个点可能影响哪里

## 2. 与 `docs/components/` 的区别

- `docs/components/` 更偏实现说明和系统分解
- `docs/architecture/` 更偏结构关系、依赖关系、拓扑视角

简单理解：

- 想看“系统由哪些部分组成”，先看 `docs/components/`
- 想看“这些部分之间怎么互相影响”，再看 `docs/architecture/`

## 3. 当前文档

1. `DEPENDENCY_MAP.md`
   说明：主要代码和模块之间的依赖关系

## 4. 相关入口

- 总览入口：`docs/COMPONENTS.md`
- 文档系统总图：`docs/DOC_SYSTEM.md`
- 系统实现层：`docs/components/`
