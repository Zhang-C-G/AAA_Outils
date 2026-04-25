# 文档系统总图

最近同步：`2026-04-25`

## 1. 目标

这份文档用于回答两个问题：

1. 当前文档体系按什么层级组织
2. 某一类信息应该写到哪里

目标不是堆更多文档，而是让后续开发和排障时能快速找到正确入口。

## 2. 当前结构

当前文档体系按五层组织：

1. 根入口层
2. 业务模块层
3. 共享契约层
4. 系统实现层
5. 开发规范层

## 3. 各层职责

### 3.1 根入口层

位于 `docs/` 根目录。

用于放：

- 总览入口
- AI 交接入口
- 更新与维护清单
- 动作日志
- 术语、编码、样式总规范

当前核心入口文件：

- `docs/COMPONENTS.md`
- `docs/AI_HANDOFF.md`
- `docs/UPDATE_CHECKLIST.md`
- `docs/ACTION_LOG.md`

### 3.2 业务模块层

位于 `docs/modules/`。

用于放真正的业务能力说明，例如：

- 快捷字段
- 笔记
- 截图发手机
- 截图问答
- 简历自动填写
- 笔记显示

判断标准：

- 用户能感知这是一个独立功能
- 它有自己的核心主功能
- 它不是单纯的底层支撑层

注意：

- `docs/modules/` 当前除了业务模块，也暂时保留了一部分系统实现说明文档
- 这是历史遗留结构，不代表最终理想边界

### 3.3 共享契约层

位于 `docs/shared/`。

用于放跨多个模块复用的规则和契约，例如：

- 全局热键
- 状态与模式
- 存储契约
- 日志契约
- UI token 契约

判断标准：

- 被多个模块复用
- 不属于某一个单独模块
- 改动后会同时影响多处

### 3.4 系统实现层

主要位于 `docs/components/`，补充在 `docs/architecture/`、`docs/config/`。

用于放：

- 运行流程
- UI 与 modes 结构
- 数据与文件落盘
- Web API
- 配置 schema
- 依赖图

判断标准：

- 面向实现结构，不面向单一业务功能
- 更接近“系统怎么搭起来”，而不是“用户看到什么”

### 3.5 开发规范层

位于 `docs/extension/`。

用于放“如何开发新东西”的规范，而不是某个业务模块本身。

当前包括：

- `AI_DEVELOPMENT_PLAYBOOK.md`
- `OVERLAY_STAGE2_GUIDE.md`
- `NEW_MODE_CHECKLIST.md`

## 4. 目前的结构边界

当前最需要明确的一点是：

- `docs/modules/` 不完全等于“纯业务模块”
- 其中 `07_web_config_frontend.md`、`08_web_config_backend.md`、`09_storage_and_files.md`、`10_runtime_and_state.md` 更接近系统实现层

因此，当前可按下面方式理解：

### 4.1 纯业务模块

- `02_field_prompt_quickfield.md`
- `04_notes.md`
- `05_capture_to_phone.md`
- `06_assistant_capture_qa.md`
- `11_resume_autofill.md`
- `12_notes_display.md`

### 4.2 业务相关的入口或壳层

- `01_hotkey_panel.md`
- `03_hotkey_settings.md`

### 4.3 历史保留的系统说明文档

- `07_web_config_frontend.md`
- `08_web_config_backend.md`
- `09_storage_and_files.md`
- `10_runtime_and_state.md`

结论：

- 现在可以继续使用这套编号
- 但后续新增文档时，不应再把新的系统实现文档继续塞进 `docs/modules/`

## 5. 新文档该放哪里

### 5.1 放进 `docs/modules/`

当它满足下面任一条件：

- 是一个用户可感知的独立功能
- 有明确的模块核心主功能
- 会单独被开发、测试、排障

### 5.2 放进 `docs/shared/`

当它满足下面任一条件：

- 跨多个模块复用
- 是契约、命名规范、共享规则
- 修改后会影响多个模块

### 5.3 放进 `docs/components/` 或 `docs/architecture/`

当它满足下面任一条件：

- 面向系统实现，而不是单个功能
- 解释运行链路、状态流、接口、依赖关系
- 更像技术结构图，而不是模块说明

建议：

- 常规系统实现放 `docs/components/`
- 偏结构视角、关系图、拓扑图放 `docs/architecture/`

### 5.4 放进 `docs/extension/`

当它满足下面任一条件：

- 是开发规范
- 是新增功能时的步骤指南
- 是某一类实现的验收清单

## 6. 推荐阅读顺序

### 6.1 日常开发

1. `docs/COMPONENTS.md`
2. `docs/extension/AI_DEVELOPMENT_PLAYBOOK.md`
3. 如涉及悬浮窗，读 `docs/extension/OVERLAY_STAGE2_GUIDE.md`
4. 目标模块文档 `docs/modules/*.md`
5. 如涉及共享能力，再读 `docs/shared/*.md`
6. 如涉及系统实现，再读 `docs/components/*.md`

### 6.2 接手恢复

1. `docs/AI_HANDOFF.md`
2. `docs/COMPONENTS.md`
3. `docs/extension/AI_DEVELOPMENT_PLAYBOOK.md`
4. 目标模块文档

## 7. 后续整理方向

当前结构已经可用，但仍有两个后续优化方向：

1. 逐步把 `docs/modules/07~10` 这类系统说明迁移到更合适的系统层目录
2. 继续减少根目录入口数量，避免首次阅读时入口过多

