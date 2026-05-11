# 改动流水文档

最近同步：`2026-05-11`
状态：`active`

## 1. 文档定位

这份文档只记录“当前这一轮、连续 1-3 次改动”的内容。
满 3 次并完成 git checkpoint + push 后，更早历史统一交给 git 追溯。

## 2. 当前轮次

- 轮次标识：`2026-05-11-post-xunfei-auth-failure-checkpoint`
- 当前连续改动次数：`3`
- 本轮目标：
  - 完成 E 模块 F3 讯飞语音识别的低延迟、流式转写、状态可视化与常驻待命优化
- 上一个 git 检查点：`checkpoint: trace xunfei voice auth failure`
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
  - E 模块 F3 从“识别后直接调用模型”切为“纯语音识别回填”，便于单独验证语音准确率
  - 修复讯飞识别结果的中文编码链路，改为 Python UTF-8 文件落地后再由 PowerShell / AHK 读取，避免悬浮窗出现乱码
  - 去掉讯飞上传中的实时节流，先将“整段上传后再识别”的额外等待压短
- 影响文件：
  - `scripts/assistant_voice_input.ps1`
  - `scripts/xunfei_asr.py`
  - `src/assistant_overlay.ahk`
  - `docs/modules/changelog/E_截图问答_修改过程.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - `python scripts/xunfei_asr.py --audio <probe_pcm> --output <temp> --error-output <temp>`：确认输出为正常中文，不再乱码
  - transcript 初始化文件检查：确认空文件长度为 `0`，无 UTF-8 BOM
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/restart_main_ahk.ps1`
- 测试结果：`通过`
- 是否触发 git：`否`

### 第 2 次改动
- 时间：`2026-05-11`
- 内容：
  - E 模块 F3 改为 live 讯飞链路：边采集、边上传、边实时写 transcript
  - 悬浮窗 transcript watcher 刷新间隔从 `180ms` 收紧到 `70ms`
  - 悬浮窗文案改为“实时转写”，让用户明确知道当前展示的是流式中间结果
- 影响文件：
  - `scripts/xunfei_asr.py`
  - `scripts/assistant_voice_input.ps1`
  - `src/storage/assistant.ahk`
  - `src/assistant_overlay.ahk`
  - `docs/modules/changelog/E_截图问答_修改过程.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - script 级 live 回归：启动 `assistant_voice_input.ps1 -Mode listen -Provider xunfei_websocket_asr`，确认 transcript 文件可被持续更新
  - `python scripts/xunfei_asr.py --audio <probe_pcm>`：确认识别结果稳定输出到 UTF-8 文件
- 测试结果：`通过`
- 是否触发 git：`否`

### 第 3 次改动
- 时间：`2026-05-11`
- 内容：
  - E 模块为 F3 增加语音阶段状态显示：`启动中 / 已连接服务 / 正在监听 / 实时转写 / 收尾 / 完成`
  - 新增语音阶段耗时埋点日志，确认旧链路中 `F3 -> listening` 约 `641ms`、`F3 -> capturing` 约 `1344ms`
  - 按“悬浮窗已打开时预拉起语音底层”的思路，接入语音 service 常驻待命尝试；当前 service 能稳定进入 `ready`，但 `start` 后未稳定推进到 `capturing`，因此已先接入超时 fallback 保护，避免完全无结果
- 影响文件：
  - `scripts/assistant_voice_input.ps1`
  - `scripts/xunfei_asr.py`
  - `src/storage/assistant.ahk`
  - `src/assistant_overlay.ahk`
  - `docs/modules/changelog/E_截图问答_修改过程.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - 日志校验：`action.log` 中已出现 `assistant_voice_stage` 与 `assistant_voice_first_text` 埋点
  - service 模式脚本测试：确认 `assistant_voice_input.ps1 -Mode service` 可稳定进入 `stage=ready`
  - service `start` 测试：确认可拉起 Python 子进程，但当前状态仍停留在 `ready`，说明常驻待命链路尚未完全打通
- 测试结果：`部分通过：状态/埋点/ready 正常，service start 后采集链路仍需继续修复`
- 是否触发 git：`是，达到 3/3，需执行 checkpoint`
