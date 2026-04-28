# 改动流水文档

最近同步：`2026-04-27`  
状态：`active`

## 1. 文档定位

这份文档只记录“当前这一轮、连续 1-3 次改动”的内容。  
满 3 次并完成 git checkpoint + push 后，更早历史统一交给 git 追溯。

## 2. 当前轮次

- 轮次标识：`2026-04-27-post-lazy-load-checkpoint`
- 当前连续改动次数：`3`
- 本轮目标：
  - 收掉设置面板里不符合全局偏好的保存式交互
  - 改为修改后即时生效、自动保存
  - 把这条偏好升级为文档硬规则，前置约束第一阶段与第二阶段
  - 启动 B 模块第一阶段重构，给几十万字量级笔记预留稳定壳层
- 上一个 git 检查点：`checkpoint: lazy-load config modules`
- 历史追溯方式：`git log` / 远端提交记录

## 3. 当前 1-3 次改动窗口

### 第1次改动
- 时间：`2026-04-27`
- 内容：
  - 删除主界面设置面板中的 `只预览` 与 `保存主题` 按钮
  - 主题预设、模式切换、色轮选择改为修改后即时应用
  - 主界面新增轻量自动保存节流，避免拖动色轮时频繁请求后端
  - 保留关闭按钮，面板关闭不再承担“确认保存”的职责
- 影响文件：
  - `webui/config/theme-picker.js`
  - `webui/config/app-main.js`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - `node --check --experimental-default-type=module webui/config/theme-picker.js`
  - `node --check --experimental-default-type=module webui/config/app-main.js`
  - `rg -n "shell-theme-apply|shell-theme-save|onSave" webui/config/theme-picker.js webui/config/app-main.js`
  - `scripts/restart_main_ahk.ps1`
  - 重启后确认当前仅存在 `1` 个 `AutoHotkey64.exe`
- 测试结果：`通过`
- 是否触发 git：`否`

### 第2次改动
- 时间：`2026-04-27`
- 内容：
  - 将“个性化设置类面板默认即时生效、默认自动保存、默认禁止保存/应用/预览按钮”写成全局硬规则
  - 将该硬规则同时写入：
    - 通用偏好结论
    - 自动保存与保存按钮偏好
    - 第一阶段文档模板
    - 第二阶段能力说明模板
  - 明确禁止先按通用组件习惯设计保存式交互，再留到后续修正
- 影响文件：
  - `docs/extension/global_preferences/00_通用偏好结论.md`
  - `docs/extension/global_preferences/04_自动保存与保存按钮偏好.md`
  - `docs/templates/STAGE1_DOC_TEMPLATE.md`
  - `docs/templates/STAGE2_CAPABILITY_TEMPLATE.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - `rg -n "个性化设置类面板|默认即时生效|默认自动保存|默认禁止|保存.*应用.*预览|通用组件默认交互" ...`
  - `scripts/restart_main_ahk.ps1`
  - 重启后确认当前仅存在 `1` 个 `AutoHotkey64.exe`
- 测试结果：`通过`
- 是否触发 git：`否`

### 第3次改动
- 时间：`2026-04-28`
- 内容：
  - 启动 B 模块第一阶段重构
  - B 模块页面由“笔记列表 + 正文编辑”双栏改为“笔记列表 + 结构目录/模块筛选 + 正文编辑”三栏
  - 新增第一阶段说明条、目录复制按钮、模块筛选壳层、目录列表壳层
  - 从当前 Markdown 正文中前端抽取标题目录，为后续“只显示某模块”闭环预留结构
  - 新建 B 模块第一阶段文档，明确重型私人笔记的结构策略与第二阶段待补项
- 影响文件：
  - `webui/config/index.html`
  - `webui/config/styles.css`
  - `webui/config/app-notes.js`
  - `docs/modules/04B_stage1_重型笔记重构.md`
  - `docs/modules/changelog/B_笔记_修改过程.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-notes.js`
  - `rg -n "copyNoteOutlineBtn|notesModuleChips|notesOutlineList|renderNoteStructure|parseNoteStructure" webui/config/index.html webui/config/app-notes.js`
  - `scripts/restart_main_ahk.ps1`
  - 重启后确认当前仅存在 `1` 个 `AutoHotkey64.exe`
- 测试结果：`通过`
- 是否触发 git：`是，已达到 3/3 checkpoint 阈值`
