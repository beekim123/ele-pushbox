# INT-01 合并第 1 批的两个分支

状态：第 2 批开头 · 待做（执行者：GPT；几分钟，做完第 2 批其余包才开始）

## 目标
把第 1 批在另开会话里完成的两个分支合并进集成分支 `codex/portitor-stage1`：`origin/claude/ui-01-research`（UI-01 调研报告）、`origin/claude/lv-01-model`（LV-01 设计模型插件接口）。

## 要做的事
1. `git pull`，然后依次 `git merge origin/claude/ui-01-research`、`git merge origin/claude/lv-01-model`（合并提交，不要 rebase、不要强推）。
2. 冲突：生成文件按 README 共同规则第 2 条重新生成；`docs/packages/UI-01.md`、`LV-01.md` 以对应分支的为准（里面有「交付」）。
3. 重新生成：`node tools/check-levels.mjs --write`、`node tools/art.mjs build`。

## 不能碰的文件
- 只做合并和重新生成，不改任何内容。

## 验收标准
- `node tools/art.mjs build` → `0 bumped`；`node tools/art.mjs verify` → `verify ok`；`node tools/content.mjs check` → 0 error
- `node --test tests/*.test.mjs` 全部通过；Godot 测试全部通过
- `docs/research/2026-10-ui-style.md` 和 LV-01 的插件文件都在集成分支上；推回集成分支

## 交付（执行者填写）
