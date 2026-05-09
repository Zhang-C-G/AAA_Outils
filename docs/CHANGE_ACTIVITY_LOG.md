# 改动流水文档

最近同步：`2026-05-09`
状态：`active`

## 1. 文档定位

这份文档只记录“当前这一轮、连续 1-3 次改动”的内容。  
满 3 次并完成 git checkpoint + push 后，更早历史统一交给 git 追溯。

## 2. 当前轮次

- 轮次标识：`2026-05-09-post-resume-filter-checkpoint`
- 当前连续改动次数：`0`
- 本轮目标：
  - 已完成上一轮 checkpoint，当前计数已清零
  - 下一轮改动开始后，再继续记录新的 1-3 次改动窗口
- 上一个 git 检查点：`checkpoint: refine resume table filtering`
- 历史追溯方式：`git log` / 远端提交记录

## 3. 上一轮已归档 checkpoint 摘要

上一轮在进入 checkpoint 前共完成 3 次改动：

### 第1次改动
- 时间：`2026-05-09`
- 内容：
  - 删除 F 模块公司投递表顶部整排筛选器
  - 改为“列标题右侧圆点按钮 -> 点击后展开对应筛选”的筛选方式
  - 链接地址列改为“单一可编辑输入框 + 单独跳转按钮”
- 影响文件：
  - `webui/config/index.html`
  - `webui/config/app-resume.js`
  - `webui/config/styles.css`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
  - `rg -n "resumeCompanyFilterKeyword|resume-company-filters|url-preview|resume-company-url-link|resume-filter-dot|resumeCompanyFilterCompany|open-url" webui/config/app-resume.js webui/config/index.html webui/config/styles.css`
- 测试结果：`通过`

### 第2次改动
- 时间：`2026-05-09`
- 内容：
  - 为 F 模块公司类型、公司规模、岗位类型、投递进度增加按值着色
  - 让不同选择结果在表格里更容易快速区分
- 影响文件：
  - `webui/config/app-resume.js`
  - `webui/config/styles.css`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
  - `rg -n "syncCompanySelectTheme|data-role=|data-value=|resume-company-select\\[data-role" webui/config/app-resume.js webui/config/styles.css`
- 测试结果：`通过`

### 第3次改动
- 时间：`2026-05-09`
- 内容：
  - 将 F 模块公司投递表的筛选交互从悬浮筛选改为顶部筛选条
  - 点击列头 `筛` 后，按钮变绿，表格上方出现对应筛选框
- 影响文件：
  - `webui/config/index.html`
  - `webui/config/app-resume.js`
  - `webui/config/styles.css`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
  - `rg -n "resumeCompanyFilterBar|resume-filter-popover|resumeCompanyFilterCompanyPanel|resume-company-filter-bar|resume-filter-dot.active" webui/config/app-resume.js webui/config/index.html webui/config/styles.css`
- 测试结果：`通过`
- 是否触发 git：`是，已完成 checkpoint commit 并 push`

## 4. 当前 1-3 次改动窗口

当前为空，等待下一轮改动开始记录。
