# 模块 11：简历自动填写

## 模块目标

- 在主界面内按分区维护简历资料。
- 为浏览器插件提供统一的本地简历 Profile。
- 让插件能对招聘网站表单执行第一版自动填写。

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
- 每个 section：`id` / `title` / `description` / `rows`
- 每个 row：`id` / `label` / `value` / `aliases` / `type`

说明：
- `aliases` 用于浏览器插件匹配招聘网站上的不同字段叫法。
- `type` 当前支持：`text` / `textarea` / `date` / `select`
- Web 编辑表格已移除 `说明/notes` 列，简历数据中不再保存该字段。

## 接口

- `GET /api/resume/state`：Web 端读取简历状态
- `POST /api/resume/save`：Web 端保存简历 Profile
- `GET /api/resume/profile`：浏览器插件读取 `profile + flat_map`

## 当前自动填写策略

- 插件会扫描当前页面的 `input / textarea / select`
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
- 后续若要提升命中率，优先增加“站点专用规则”，而不是把通用规则写得越来越脆弱。
