# Resume Autofill Browser Extension

这是 `ZCG-Raccourci Control` 的第一版浏览器插件骨架。

## 当前能力

- 从本地服务读取 `http://127.0.0.1:8798/api/resume/profile`
- 获取简历 `profile` 与 `flat_map`
- 对当前网页的 `input / textarea / select` 做启发式字段匹配并尝试填值

## 使用方式

1. 在主程序里打开 Web 配置页，进入“简历自动填写”模块并保存资料。
2. 在浏览器扩展管理页加载本目录为“已解压的扩展程序”。
3. 打开目标招聘表单页面。
4. 点击插件图标，先点“读取本地简历”，再点“自动填写当前页”。

## 说明

- 这是第一版通用骨架，当前采用“字段名 / 别名 / placeholder / label / name”启发式匹配。
- 后续如果某个招聘网站需要更高命中率，可以继续增加站点专用规则。
