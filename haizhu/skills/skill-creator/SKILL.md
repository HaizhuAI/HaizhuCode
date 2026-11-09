---
name: haizhu-skill-creator
description: 新建或更新 Agent Skill。当用户要把一段工作流、提示词或指令集做成可复用技能，或改进 ~/.config/opencode/skill 或 ~/.haizhu/skills 下的现有技能时使用。
---

# HaizhuCode 技能工匠

技能 = 一个目录，内含 `SKILL.md`（YAML frontmatter + Markdown 指令）+ 可选支撑文件。启用后仅 `name`/`description` 常驻上下文，正文按需加载。

## 技能落点

- OC2：`$OC2_CONFIG/skill/<name>/`（`hz seed` 把 `haizhu/skills/*` 链接到此处）。
- 通用：`$HOME/.agents/skills/<name>/`；Claude 路径：`$HOME/claude/skills/<name>/`。
- 同名用户技能覆盖内置；改内置技能先复制到用户目录再改。
- 新技能在 App 的技能列表里出现但默认禁用——提醒用户去启用。

## 流程

1. **弄清用例**：技能做什么、何时触发、好输出长什么样。对话里已展示的工作流直接抽取，少问。
2. **规划内容**：`SKILL.md` 写什么、哪些细节进 `references/`、哪些重复易错工作写成 `scripts/`。
3. **查冲突**：先 `ls` 目标 skills 目录；同名已存在则先读再与用户确认覆盖。
4. **写文件**。
5. **按下表验证**：每个脚本至少真跑一遍。
6. **汇报**：列出文件、提醒启用、给一句试用提示。

## SKILL.md 格式

```markdown
---
name: my-skill
description: 这个技能做什么、什么时候用。
---

# My Skill

指令正文……
```

- `---` 必须在第 1 行并以 `---` 闭合；值里有 `: ` 或 `#` 或以特殊字符开头就加引号或 `>-` 折叠块。
- `name`（必填）：与目录名完全一致；小写字母/数字/短横线，≤64 字符，不以 `.` 开头。
- `description`（必填）：≤1024 字符——这是模型加载前唯一可见的部分，写清"做什么+何时用+触发关键词"，第三人称。
- `compatibility`（可选）：环境要求，如 `Requires python3`。
- 正文用祈使句，≤500 行；细节放 references。

## 支撑文件布局

```
<skills>/my-skill/
├── SKILL.md
├── references/   # 详细文档，按需加载
├── scripts/      # 可执行辅助
└── assets/       # 模板等产物素材
```

- **references**：在 `SKILL.md` 里用相对链接 `[名](references/x.md)` 挂出，并说明何时读；一层深，不链式引用。
- **scripts**：shebang 开头 + `chmod +x`；`SKILL.md` 里写绝对路径引用与参数/输出说明；不假设解释器存在，先 `command -v` 探测并在 `compatibility` 声明。手机内置 Linux 是 proot，工具链以 busybox + python3 为准。
- 别放 README/CHANGELOG 等对任务无用的文件。

## 写作要点

- 只放模型本来不知道的东西：领域规则、约定、精确格式、坑。
- 格式敏感时给输入/输出对示例，胜过抽象规则。
- 易错流程给编号清单或脚本；开放任务给方向让模型自己定。
- 固定结构的产出给输出模板。

## 校验清单

- [ ] 目录名 == `name` 字段
- [ ] frontmatter 从第 1 行起、以 `---` 闭合、特殊字符已引号
- [ ] `description` 说明做什么+何时用，≤1024 字符
- [ ] `SKILL.md` 链接的每个文件都真实存在于该相对路径
- [ ] 每个脚本可执行、至少跑通过一次、要求已写进 `compatibility`
- [ ] 不与现有技能重复或冲突
