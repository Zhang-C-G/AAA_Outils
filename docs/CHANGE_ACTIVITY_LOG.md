# 改动流水文档

最近同步：`2026-05-11`
状态：`active`

## 1. 文档定位

这份文档只记录“当前这一轮、连续 1-3 次改动”的内容。
满 3 次并完成 git checkpoint + push 后，更早历史统一交给 git 追溯。

## 2. 当前轮次

- 轮次标识：`2026-05-11-post-xunfei-live-voice-checkpoint`
- 当前连续改动次数：`1`
- 本轮目标：
  - 继续修复 E 模块 F3 讯飞语音 service 常驻待命路径，解决 `ready` 后无法稳定进入 `capturing / streaming`
- 上一个 git 检查点：`checkpoint: document xunfei live voice checkpoint`
- 历史追溯方式：`git log` / 远端提交记录

## 3. 上一轮已归档 checkpoint 摘要

上一轮在进入 checkpoint 前共完成 3 次改动：

### 第 1 次改动
- 时间：`2026-05-09`
- 内容：
  - 保留 F 模块公司投递表的颜色区分
  - 让下拉框恢复原本黑白风
  - 将颜色信息改为侧边色标承载
- 影响文件：
  - `webui/config/app-resume.js`
  - `webui/config/styles.css`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
  - `rg -n "resume-company-select-wrap|resume-company-select-indicator|syncCompanySelectTheme" webui/config/app-resume.js webui/config/styles.css`
- 测试结果：`通过`

### 第 2 次改动
- 时间：`2026-05-09`
- 内容：
  - F 模块公司投递表补充分页
  - 分页状态接入保存与草稿恢复
  - 公司名称输入框改为字段贴合宽度
  - 表格规则写入私人偏好，并建立第一个统一表格模板
- 影响文件：
  - `webui/config/app-common.js`
  - `webui/config/app-main.js`
  - `webui/config/app-resume.js`
  - `webui/config/index.html`
  - `webui/config/styles.css`
  - `docs/extension/global_preferences/components/18_表格与筛选器偏好.md`
  - `docs/templates/TABLE_STAGE1_TEMPLATE.md`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
  - `rg -n "resumeCompanyPagination|company_table_view|resume-company-name-input|TABLE_STAGE1_TEMPLATE" webui/config/app-resume.js webui/config/index.html webui/config/styles.css webui/config/app-main.js docs/templates/TABLE_STAGE1_TEMPLATE.md`
- 测试结果：`通过`

### 第 3 次改动
- 时间：`2026-05-09`
- 内容：
  - F 模块公司投递表的顶部筛选条支持多项同时展开
  - 多个 `筛` 按钮允许同时保持绿色激活
  - 顶部筛选区改为承载多个筛选块
  - 表头选择入口改为勾选框本体，去掉“全选”文字
  - 顶部筛选条增加结果统计
  - 删除额外的“收起筛选”入口，筛选展开与关闭只通过对应列表头圆点控制
  - 公司名称与链接地址输入框改为默认单行显示
  - 顶部筛选区压缩为更紧凑的工具条样式
  - 删除筛选卡片内重复字段名
  - 收窄公司名称列
  - 将表头勾选框调整为列内真正居中显示
- 影响文件：
  - `webui/config/app-resume.js`
  - `webui/config/styles.css`
  - `docs/extension/global_preferences/components/18_表格与筛选器偏好.md`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
  - `rg -n "resumeCompanyFilterBar|resume-company-filter-summary|resume-filter-dot.active|resume-company-select-head" webui/config/app-resume.js webui/config.index.html webui/config/styles.css`
- 测试结果：`通过`
- 是否触发 git：`是，已形成 checkpoint`

## 4. 当前 1-3 次改动窗口

### 第 1 次改动
- 时间：`2026-05-11`
- 内容：
  - 修复 E 模块 F3 语音 service 的 Python live worker 启动方式
  - 改正 service 模式下参数拆分错误，避免设备名中的空格被错误切开，导致 Python 把整串参数当成脚本路径或把设备名截断
  - 为 service 启动补上工作目录、stdout/stderr 重定向与退出后的错误回传
  - 修正 service worker 退出码读取，避免正常停止后误写 `xunfei live worker failed with exit code`
- 影响文件：
  - `scripts/assistant_voice_input.ps1`
  - `docs/modules/changelog/E_截图问答_修改过程.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - service 脚本级冒烟：启动 `assistant_voice_input.ps1 -Mode service -Provider xunfei_websocket_asr`，发送 `start` 后确认状态可从 `starting` 推进到 `capturing`
  - service 停止回归：发送 `stop` 后确认状态最终回到 `ready`，`ErrorPath` 保持为空
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/restart_main_ahk.ps1`
- 测试结果：`通过`
- 是否触发 git：`否`
