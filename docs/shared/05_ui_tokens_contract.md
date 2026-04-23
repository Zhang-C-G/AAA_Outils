# Shared 05：UI Token 契约

## 定义

跨页面共享的颜色、字体、按钮与关键文案规范。

## 主要来源

- `docs/UI_STYLE_TOKENS.md`
- `webui/config/styles.css`
- `src/theme.ahk`

## 约束

1. 样式改动先改 Token，再改页面实现。
2. 关键按钮文案保持全局一致（保存、恢复、删除、刷新）。
3. 新模块优先复用现有 Token，避免风格漂移。
