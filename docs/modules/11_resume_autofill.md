# 模块 11：简历自动填写

最近同步：`2026-05-09`

## 模块目标

- 在 Web 主界面中按分区维护本地简历资料。
- 为浏览器插件提供统一的本地 `profile + flat_map` 数据。
- 前端编辑聚焦“字段名 / 值”，别名和匹配规则改由后端默认字段表维护。
- 在简历字段维护之外，提供一块稳定的“公司投递维护表”，用于管理目标公司、投递进度与跳转链接。

## 核心主功能

- 核心一：本地简历资料可稳定维护，插件可稳定读取并完成自动填写。
- 核心二：公司投递信息可集中维护，支持筛选、分页、批量勾选与批量跳转。
- 任何前端精简、字段展示调整、说明文案删减，都不能以牺牲资料可用性和插件填表能力为代价。

## 当前分区

1. 基本信息
2. 求职期望
3. 教育经历
4. 实习经历
5. 项目经历
6. 在校职务
7. 校园活动
8. 家庭成员
9. 获奖经历
10. 英语能力
11. 证书信息
12. 自我介绍

## 当前工作区结构

F 模块当前分成两块工作区：

1. `简历字段维护`
2. `公司投递维护`

其中：

- 左侧仍为简历分区导航。
- 右侧主区可在“简历字段维护 / 公司投递维护”之间切换。
- 简历字段维护仍以字段表为主。
- 公司投递维护已经升级为表格型维护工作区。

## 主要文件

- `webui/config/app-resume.js`
- `webui/config/index.html`
- `webui/config/styles.css`
- `webui/config/server-resume.ps1`
- `browser_extension/resume_autofill/manifest.json`
- `browser_extension/resume_autofill/popup.js`
- `browser_extension/resume_autofill/content.js`
- `resume_profile.json`

## 数据结构

- 本地简历文件：`resume_profile.json`
- 顶层结构：`version` / `updated_at` / `sections` / `company_links` / `editor_mode`
- 每个 section：`id` / `title` / `rows`
- 每个 row：`id` / `label` / `value` / `aliases` / `type`
- 每个 company row：`id` / `company` / `url` / `company_type` / `company_scale` / `job_type` / `progress`

补充说明：

- 前端字段区现在只编辑 `字段名 (label)` 与 `值 (value)`。
- `aliases` 不再放在前端 UI 中维护，而是优先走后端默认字段表。
- `type` 不再放在前端 UI 中维护，但后端结构仍保留该字段，供插件和默认表使用。
- `editor_mode` 用于恢复上次停留在“字段维护”还是“公司投递维护”。
- 公司投递表还会持久化保存表格视图状态，例如当前页和每页条数。

## Web 页面口径

### 简历字段维护

- 左侧为分区导航，右侧为当前分区字段表。
- 字段表只保留三列：
  - 字段名
  - 值
  - 操作
- 已移除：
  - `匹配别名`
  - `类型`
  - `复制 JSON`
  - `当前 Profile JSON 预览`

### 公司投递维护表

- 当前列结构：
  - 勾选列
  - 公司名称
  - 公司类型
  - 公司规模
  - 岗位类型
  - 投递进度
  - 链接地址
  - 操作
- 列头通过圆点按钮展开顶部筛选条。
- 顶部筛选条支持多项同时展开。
- 顶部筛选条显示当前命中的公司总数。
- 表格底部带分页区。
- 表头批量勾选框仅保留勾选框本体，不保留“全选”文字。
- 公司名称与链接地址默认以单行输入外观呈现。

## 当前交互结论

- F 模块默认自动保存，不保留手动保存按钮。
- 公司投递表默认遵循“筛选器 + 分页 + 表格”组合。
- 筛选条只通过列头圆点开关，不再提供第二套收起按钮。
- 状态型下拉不直接整体染色，颜色信息交给左侧细色标承担。
- 批量投递通过勾选若干公司后统一打开链接完成。

## 接口

- `GET /api/resume/state`：Web 端读取简历状态
- `POST /api/resume/save`：Web 端保存简历资料
- `GET /api/resume/profile`：浏览器插件读取 `profile + flat_map`

## 后端映射策略

- 默认字段表仍在 `server-resume.ps1` 中维护。
- 当 row 的 `id` 命中默认字段定义时：
  - `aliases` 默认取后端字段表
  - `type` 默认取后端字段表
- 这样前端即使不展示别名与类型，插件侧的匹配与填表能力仍能保留。

## 当前边界

- 这是第一版通用启发式自动填写，不保证所有招聘网站一次命中。
- 后续若要提高命中率，优先增加站点专用规则，而不是继续扩大前端编辑复杂度。
- 公司投递维护表当前仍以“手动维护 + 手动跳转”为主，不负责自动抓取官网投递进度。

## 相关文档

- 全局表格偏好：`docs/extension/global_preferences/components/18_表格与筛选器偏好.md`
- 第一阶段表格模版：`docs/templates/TABLE_STAGE1_TEMPLATE.md`
- 模块修改过程：`docs/modules/changelog/F_简历自动填写_修改过程.md`
