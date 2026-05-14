# 用户文档系统使用说明

最近同步：`2026-05-14`
状态：`active`

## 1. 这份文档怎么用

这份文档不是给开发者讲实现细节的，而是给用户、协作者、接手者看的。

最适合的使用方法不是从头一直读到尾，而是按下面顺序使用：

1. 先看“我现在属于哪种情况”
2. 再按树状分支找到该看的文档
3. 再看对应案例，确认这条路径到底怎么跑

## 2. 一句话先讲清楚

这套文档系统的作用，是把一次任务变成一条可追踪的链路：

`你提出任务 -> AI 读取规则和上下文 -> AI 实施修改 -> AI 测试 -> AI 补文档 -> AI 显式汇报状态 -> 达到条件时 git checkpoint`

所以它不是“资料库”，而是“操作导航系统”。

## 3. 先判断：你现在属于哪种情况

先看这张树状判断图。

```text
你现在想做什么？
|
+-- A. 我只想知道“这个项目现在是什么状态”
|   |
|   +-- 先看：docs/AI_HANDOFF.md
|   +-- 再看：docs/COMPONENTS.md
|
+-- B. 我只想知道“这套文档系统怎么分层”
|   |
|   +-- 先看：docs/DOC_SYSTEM.md
|   +-- 再看：docs/USER_DOC_SYSTEM_GUIDE.md
|
+-- C. 我要让 AI 开始处理一个任务
|   |
|   +-- 这个任务是否涉及具体模块？
|       |
|       +-- 否
|       |   |
|       |   +-- 先看：AI_DEVELOPMENT_PLAYBOOK.md
|       |   +-- 再看：AI_HANDOFF.md
|       |   +-- 再看：CHANGE_CHECKPOINT_RULE.md
|       |   +-- 再看：CHANGE_ACTIVITY_LOG.md
|       |
|       +-- 是
|           |
|           +-- 先看上面四份
|           +-- 再看：对应 docs/modules/*.md
|           +-- 再看：对应 docs/modules/changelog/*.md
|
+-- D. 我想知道“这个模块过去改过什么”
|   |
|   +-- 先看：对应 docs/modules/*.md
|   +-- 再看：对应 docs/modules/changelog/*.md
|
+-- E. 我想检查“这次有没有按流程收尾”
    |
    +-- 先看：docs/UPDATE_CHECKLIST.md
    +-- 再看：docs/ACTION_LOG.md
    +-- 再看：docs/DOC_CHANGELOG.md
    +-- 再看：docs/CHANGE_ACTIVITY_LOG.md
    +-- 再看：docs/CHANGE_CHECKPOINT_RULE.md
```

## 4. 所有路径的共同骨架

虽然你会走不同分支，但它们共同遵守的骨架其实是一样的：

```text
提出问题
  -> 判断任务类型
    -> 读取规则文档
      -> 如命中模块，再读取模块文档
        -> 实施修改或讨论
          -> 做测试或校对
            -> 更新文档
              -> 回复状态
                -> 如达到阈值则 git checkpoint
```

也就是说，分支不同，但骨架不变。

## 5. 用户输入是什么，AI 输出是什么

这一节也用树状拆开讲。

### 5.1 你的输入

```text
你的输入
|
+-- 任务输入
|   +-- 你直接提出的需求、问题、修改目标
|
+-- 规则输入
|   +-- 当前文档系统对 AI 的执行约束
|
+-- 上下文输入
    +-- 当前代码、文档、截图、报错、git 状态、工作区状态
```

具体例子：

- 任务输入：
  - “修复插件目录识别问题”
  - “把教育经历改成多条可新增、可删除、可修改”
  - “先讨论文档输出规范”
- 规则输入：
  - 必须先读哪些文档
  - 必须更新哪些记录文档
  - 每次回复必须显示哪些状态
- 上下文输入：
  - 当前代码
  - 当前 JSON
  - 当前截图
  - 当前 git/worktree 状态

### 5.2 AI 的输出

```text
AI 的输出
|
+-- 实现输出
|   +-- 代码、配置、数据、前端、脚本修改
|
+-- 文档输出
|   +-- 模块文档、模块过程文档、动作记录、改动计数
|
+-- 测试输出
|   +-- 做了什么测试、有没有通过
|
+-- 状态输出
    +-- 已做事项 / 未做事项 / 文档状态 / 测试状态 / git状态 / checkpoint状态
```

## 6. 分支案例 1：我只是想知道“项目现在是什么”

### 触发条件

- 你不准备立刻开发
- 你只是想知道当前项目状态
- 你想知道哪个模块已经稳定、哪个风险高

### 走哪条分支

```text
目标：只看当前状态
  -> docs/AI_HANDOFF.md
  -> docs/COMPONENTS.md
```

### 这条分支会得到什么

- 项目当前核心定位
- 当前稳定结论
- 不能回退的约束
- 下一步最安全接手路径

### 例子

比如你刚打开项目，只想知道：

- F3 语音链路是不是已经稳定
- 简历自动填写现在做到哪一步
- 后续接手应该优先看什么

这时不用先读模块细节，先读：

1. `docs/AI_HANDOFF.md`
2. `docs/COMPONENTS.md`

## 7. 分支案例 2：我要让 AI 开始做一个任务

### 触发条件

- 你准备让 AI 真正开始处理任务
- 这个任务可能是开发、修复、补文档、规则讨论

### 先判断：是否涉及具体模块

```text
我要让 AI 开始做任务
|
+-- 不涉及具体模块
|   |
|   +-- 读 AI_DEVELOPMENT_PLAYBOOK.md
|   +-- 读 AI_HANDOFF.md
|   +-- 读 CHANGE_CHECKPOINT_RULE.md
|   +-- 读 CHANGE_ACTIVITY_LOG.md
|
+-- 涉及具体模块
    |
    +-- 先读上面四份
    +-- 再读对应 docs/modules/*.md
    +-- 再读对应 docs/modules/changelog/*.md
```

### 例子 A：这是模块任务

你说：

- “把教育经历改成多条可新增、删除、修改”

这就是“涉及具体模块”的任务，因为它命中了 F 模块“简历自动填写”。

所以路径是：

1. `docs/extension/AI_DEVELOPMENT_PLAYBOOK.md`
2. `docs/AI_HANDOFF.md`
3. `docs/CHANGE_CHECKPOINT_RULE.md`
4. `docs/CHANGE_ACTIVITY_LOG.md`
5. `docs/modules/11_resume_autofill.md`
6. `docs/modules/changelog/F_简历自动填写_修改过程.md`

然后 AI 再去读代码和数据，例如：

- `resume_profile.json`
- `webui/config/app-resume.js`
- `webui/config/server-resume.ps1`
- `browser_extension/resume_autofill/site-strategies.js`

### 例子 B：这是规则任务

你说：

- “我们现在讨论每次回复必须显示哪些状态”

这不是模块功能任务，而是规则对齐任务。

所以路径是：

1. `docs/extension/AI_DEVELOPMENT_PLAYBOOK.md`
2. `docs/AI_HANDOFF.md`
3. `docs/CHANGE_CHECKPOINT_RULE.md`
4. `docs/CHANGE_ACTIVITY_LOG.md`
5. 如需要，再看 `docs/UPDATE_CHECKLIST.md`

这时一般不会先读某个模块主文档，因为焦点是规则体系。

## 8. 分支案例 3：我想查“这个模块以前怎么改过”

### 触发条件

- 你已经知道目标模块
- 你想看它的长期演进，而不是只看当前实现

### 走哪条分支

```text
目标：追历史
  -> 对应 docs/modules/*.md
  -> 对应 docs/modules/changelog/*.md
```

### 例子

比如你想知道简历自动填写模块为什么会增加站点分析、为什么教育经历改成多条结构。

你就去看：

1. `docs/modules/11_resume_autofill.md`
2. `docs/modules/changelog/F_简历自动填写_修改过程.md`

第一个文档告诉你“现在它是什么”，第二个文档告诉你“它是怎么一步步变成现在这样的”。

## 9. 分支案例 4：我想检查这次改动有没有按流程收尾

### 触发条件

- 你怀疑 AI 只改了代码，没补文档
- 你怀疑这次回复没有把状态说清楚
- 你想知道当前是不是该 git checkpoint 了

### 走哪条分支

```text
目标：检查收尾
  -> docs/UPDATE_CHECKLIST.md
  -> docs/ACTION_LOG.md
  -> docs/DOC_CHANGELOG.md
  -> docs/CHANGE_ACTIVITY_LOG.md
  -> docs/CHANGE_CHECKPOINT_RULE.md
```

### 你重点检查什么

看下面这张树：

```text
一次任务结束后，你要检查什么？
|
+-- 有没有更新文档？
|   +-- 看 ACTION_LOG / DOC_CHANGELOG / 模块文档
|
+-- 有没有记录本轮改动？
|   +-- 看 CHANGE_ACTIVITY_LOG
|
+-- 有没有更新当前计数？
|   +-- 看 CHANGE_CHECKPOINT_RULE
|
+-- 有没有说明测试？
|   +-- 看回复里的测试状态
|
+-- 有没有说明 git / checkpoint？
    +-- 看回复里的 git 状态 / checkpoint 状态
```

## 10. 一个完整的真实案例

下面用“教育经历改成多条维护”把整条链跑一遍。

### 第一步：用户输入

你提出的任务是：

- 教育经历不是一条，而是多条
- 需要支持新增、删除、修改

### 第二步：系统判断

```text
这是开发任务吗？ -> 是
这是模块任务吗？ -> 是
命中的模块是什么？ -> 简历自动填写
```

### 第三步：AI 读取文档

AI 先读：

1. `docs/extension/AI_DEVELOPMENT_PLAYBOOK.md`
2. `docs/AI_HANDOFF.md`
3. `docs/CHANGE_CHECKPOINT_RULE.md`
4. `docs/CHANGE_ACTIVITY_LOG.md`

因为它命中模块，所以继续读：

5. `docs/modules/11_resume_autofill.md`
6. `docs/modules/changelog/F_简历自动填写_修改过程.md`

### 第四步：AI 再读取现场上下文

例如：

- `resume_profile.json`
- `webui/config/app-resume.js`
- `webui/config/server-resume.ps1`
- `browser_extension/resume_autofill/site-strategies.js`

### 第五步：AI 实施修改

例如：

- 教育经历改成多条 `education_entry_*`
- 编辑器支持新增和删除教育条目
- 扩展侧解析支持新的教育日期口径

### 第六步：AI 更新文档

例如：

- `docs/modules/11_resume_autofill.md`
- `docs/modules/changelog/F_简历自动填写_修改过程.md`
- `docs/ACTION_LOG.md`
- `docs/DOC_CHANGELOG.md`
- `docs/CHANGE_ACTIVITY_LOG.md`
- `docs/CHANGE_CHECKPOINT_RULE.md`

### 第七步：AI 回复状态

至少要显式说明：

1. 已做事项
2. 未做事项
3. 文档状态
4. 测试状态
5. git 状态
6. checkpoint 状态

### 第八步：如达到阈值则 checkpoint

如果这是本轮第 `3 / 3` 次有效改动，并且测试通过，就执行：

- `git commit`
- `git push`

然后把改动计数清零，开启新一轮。

## 11. 最后记住这一张总图就够了

```text
你提出任务
  -> 系统判断任务类型
    -> 读取总规则
      -> 如命中模块，再读取模块文档
        -> 读取代码/截图/报错等现场上下文
          -> 实施修改或继续讨论
            -> 测试或静态校对
              -> 更新文档
                -> 回复状态
                  -> 达到条件则 checkpoint
```

## 12. 最短使用路径

如果你只想最短理解这套系统，记住下面 5 条就够了：

1. 想知道项目当前状态，看 `docs/AI_HANDOFF.md`
2. 想知道文档怎么分层，看 `docs/DOC_SYSTEM.md`
3. 想让 AI 开始干活，看 `docs/extension/AI_DEVELOPMENT_PLAYBOOK.md`
4. 想追某个模块怎么演进，看 `docs/modules/*.md` 和 `docs/modules/changelog/*.md`
5. 想知道这轮改动与 checkpoint 走到哪里，看 `docs/CHANGE_ACTIVITY_LOG.md` 和 `docs/CHANGE_CHECKPOINT_RULE.md`
