# 改动流水文档

最近同步：`2026-05-09`
状态：`active`

## 1. 文档定位

这份文档只记录“当前这一轮、连续 1-3 次改动”的内容。  
满 3 次并完成 git checkpoint + push 后，更早历史统一交给 git 追溯。

## 2. 当前轮次

- 轮次标识：`2026-05-09-post-resume-module-library-checkpoint`
- 当前连续改动次数：`2`
- 当前连续改动次数：`3`
- 本轮目标：
  - 收紧 F 模块公司投递表筛选交互
  - 去掉顶部整排筛选器，改为列头圆点展开筛选
  - 收紧链接列，避免同一格内出现两个并列链接入口
  - 为不同选择值补颜色区分
  - 将筛选交互进一步改为“列头触发 + 表格顶部筛选条”
- 上一个 git 检查点：`checkpoint: sync resume table and module library`
- 历史追溯方式：`git log` / 远端提交记录

## 3. 上一轮已归档 checkpoint 摘要

上一轮在进入 checkpoint 前共完成 3 次改动：

### 第1次改动
- 时间：`2026-05-09`
- 内容：
  - F 模块公司维护表升级为公司投递面板
  - 增加公司类型、公司规模、岗位类型、投递进度
  - 增加批量投递入口与筛选器
  - 补入 50 家目标公司与链接
- 影响文件：
  - `webui/config/app-resume.js`
  - `webui/config/index.html`
  - `webui/config/styles.css`
  - `webui/config/server-resume.ps1`
  - `webui/config/app-main.js`
  - `webui/config/app-common.js`
  - `resume_profile.json`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
  - PowerShell 语法解析 `webui/config/server-resume.ps1`
  - `resume_profile.json | ConvertFrom-Json`
- 测试结果：`通过`

### 第2次改动
- 时间：`2026-05-09`
- 内容：
  - 补建“文档低耦合与拆分规则”
  - 建立“模块库总索引 / 模块母版清单”
  - 将新规则接入开发规范入口、总图、清单与总索引
  - 补齐 `18_表格与筛选器偏好.md` 索引，并加入分页偏好
- 影响文件：
  - `docs/extension/AI_DEVELOPMENT_PLAYBOOK.md`
  - `docs/extension/DOC_CREATION_GUIDE.md`
  - `docs/extension/NEW_MODE_CHECKLIST.md`
  - `docs/extension/README.md`
  - `docs/extension/全局私人偏好文档.md`
  - `docs/extension/文档体系总图.md`
  - `docs/extension/文档低耦合与拆分规则.md`
  - `docs/extension/模块库总索引.md`
  - `docs/extension/模块母版清单.md`
  - `docs/extension/global_preferences/00_通用偏好结论.md`
  - `docs/extension/global_preferences/components/18_表格与筛选器偏好.md`
- 测试：
  - `rg -n "文档低耦合与拆分规则|模块库总索引|模块母版清单|18_表格与筛选器偏好" docs/extension`
  - 文档交叉索引人工复查
- 测试结果：`通过`

### 第3次改动
- 时间：`2026-05-09`
- 内容：
  - F 模块链接地址列支持直接点击跳转
  - 保留原输入框继续编辑
  - 链接缺少协议头时自动补全为 `https://`
- 影响文件：
  - `webui/config/app-resume.js`
  - `webui/config/styles.css`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
  - `rg -n "resume-company-url|url-preview|normalizeExternalUrl" webui/config/app-resume.js webui/config/styles.css`
- 测试结果：`通过`

## 4. 当前 1-3 次改动窗口

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
- 是否触发 git：`否`

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
- 是否触发 git：`是，已达到 3/3 checkpoint 阈值`

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
- 是否触发 git：`否`
