# .agents 兼容规则入口

本项目主规则文件为 `AGENTS.md`。
如果当前工具同时支持读取 `AGENTS.md` 与 `.agents/rules.md`，以 `AGENTS.md` 为准。

默认使用简体中文与用户沟通。
除非用户明确要求英文，或代码、命令、报错、协议字段必须保留原文，否则回复、解释、计划、审查意见均使用简体中文。

本项目已安装 `superpowers-zh` 技能框架，相关 skills 位于 `.agents/skills/` 目录。

开始任务前，优先阅读 `AGENTS.md`。
当任务匹配某个 skill 时，读取对应的 `.agents/skills/<skill-name>/SKILL.md` 并严格遵循其流程。
