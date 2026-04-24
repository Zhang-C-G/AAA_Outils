# 模块 11：简历自动填写

## 模块目标

- 在 Web 主界面中按分区维护本地简历资料。
- 为浏览器插件提供统一的本地 `profile + flat_map` 数据。
- 前端编辑聚焦“字段名 / 值”，别名和匹配规则改由后端默认表维护。

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

## 主要文件

- `webui/config/app-resume.js`
- `webui/config/server-resume.ps1`
- `webui/config/index.html`
- `browser_extension/resume_autofill/manifest.json`
- `browser_extension/resume_autofill/popup.js`
- `browser_extension/resume_autofill/content.js`
- `resume_profile.json`

## 数据结构

- 本地简历文件：`resume_profile.json`
- 顶层结构：`version` / `updated_at` / `sections`
- 每个 section：`id` / `title` / `rows`
- 每个 row：`id` / `label` / `value` / `aliases` / `type`

说明：

- 前端主 UI 现在只编辑 `字段名(label)` 与 `值(value)`。
- 分区说明小字已从前端主 UI 移除，页面只保留分区标题与字段表。
- `aliases` 不再放在前端主 UI 中维护，而是优先走后端默认字段表。
- `type` 不再放在前端主 UI 中维护，但后端结构仍保留该字段，供插件和默认表使用。

## Web 页面口径

- 左侧仍为分区导航，右侧为当前分区字段表。
- 字段表只保留三列：
  - 字段名
  - 值
  - 操作
- 已移除：
  - `匹配别名`
  - `类型`
  - `复制 JSON`
  - `当前 Profile JSON 预览`

## 接口

- `GET /api/resume/state`：Web 端读取简历状态
- `POST /api/resume/save`：Web 端保存简历 Profile
- `GET /api/resume/profile`：浏览器插件读取 `profile + flat_map`

## 后端映射策略

- 默认字段表仍在 `server-resume.ps1` 中维护。
- 当 row 的 `id` 命中默认字段定义时：
  - `aliases` 默认取后端字段表
  - `type` 默认取后端字段表
- 这样前端即使不展示别名与类型，插件侧的匹配与填表能力仍能保留。

## 当前自动填写策略

- 插件扫描当前页面的 `input / textarea / select`
- 从以下信息中提取候选匹配名：
  - `label[for]`
  - `aria-label`
  - `placeholder`
  - `name`
  - `id`
  - 常见表单容器文本
- 再用这些候选名去匹配本地 `字段名 + 别名`

## 当前边界

- 这是第一版通用启发式自动填写，不保证所有招聘网站一次命中。
- 后续若要提高命中率，优先增加站点专用规则，而不是继续扩大前端编辑复杂度。
