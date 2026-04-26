# 模块修改过程记录：F 简历自动填写

最近同步：`2026-04-26`
状态：`active`

## 1. 当前状态

- 核心范围：资料字段、映射、自动填写入口
- 当前重点：字段稳定与映射一致性

## 2. 修改记录

### 2026-04-26 / 初始建档
- 改动内容：
  - 建立模块修改过程文档，后续独立记录 F 模块演进
- 测试：
  - 文档创建校验
- 测试结果：`通过`

### 2026-04-26 / 删除保存按钮并切到自动保存
- 改动内容：
  - 删除 Web 端 F 模块“保存简历资料”按钮
  - 删除 AHK 配置界面 F 模块“Save Resume Config”按钮
  - F 模块改为字段变更后自动保存，符合“不喜欢保存按钮”的个人偏好
- 测试：
  - 代码校验：确认 `resumeSaveBtn` 已从 `index.html` 与 `app-resume.js` 移除
  - 代码校验：确认 AHK F 模块已改为 `OnResumeFieldChanged -> ScheduleResumeSettingsAutoSave`
  - 启动校验：通过 `scripts/restart_main_ahk.ps1` 重启原有 `main.ahk` 实例
- 测试结果：`通过`

### 2026-04-26 / 公司链接维护界面第一阶段 UI
- 改动内容：
  - F 模块头部新增一行“进入公司链接界面”提示条
  - 点击后，主编辑区切换为“公司 / 链接地址 / 允许填充”维护表
  - 当前只做 UI，不接后端自动填充逻辑
- 测试：
  - 代码校验：确认 F 模块新增 `resumeCompanyPanel` 与切换按钮
  - 代码校验：确认 `app-resume.js` 已新增 `editor_mode` 与公司链接表渲染
  - 启动校验：通过 `scripts/restart_main_ahk.ps1` 重启原有 `main.ahk` 实例
- 测试结果：`待执行`
