# 实施前规格冲突记录（2026-10-13）

## 依据及处理状态

**已裁决：** 用户随后明确回复“两条以模板为准”，继续 M0–M5，单 worker，T2 的 4/8 线程项列为未执行。下文保留初次核对记录；C01/C02 不再阻塞实施。

用户提供的入口：`/Users/key_/Desktop/CURRGO/newdesign/prompts/pushbox-demo-prompt.md`。
该文件第 15 行明确要求：**“它和模板矛盾时，停下来记录问题，不要自己选。”**

本次只做输入核对和环境检查，发现以下两处模板与 C++ 参考实现的行为差异。尚未裁决、修改模板、修改参考代码或开始游戏实现；没有运行 SDK 模拟，以下反例是静态规则分析，不是 D1–D5 测试结果。

## C01：SAND 分类是否累计 solid

- 模板：`docs/demo-template.md:40` 及 `:281`，先判 SOLID，随后只以 `#loose` 的 cell 数与阈值比较。
- C++：`docs/pushbox_sim.cpp:78`，随后以 `c.s + c.l >= g_threshold` 判断 SAND。
- 静态反例：阈值 152，一格含 144 个 solid、8 个 loose、104 个 empty。模板判 OPEN，C++ 判 SAND。144 个 solid 没有低于模板的固定崩落阈值 128；分类阈值 152 是 T3 要求的扰动值。
- 实际影响：分类会进一步影响移动、登台阶、挖沙、箱子支撑和预演。本次没有证明 D1–D5 中会出现该输入，不把这个反例报告为作者解法失败。
- 建议供用户裁决：游戏层按模板的单 tag 分类实现；C++ 的累计分类仅记录为参考实现偏差。模板材料与 profile JSON 保持原样。

## C02：崩落是否每轮扫描全图

- 模板：第 2.4 节每轮先崩落，第 2.7 节要求每轮清除剩余 1–127 个 breakable 的格；第 8.1 节明确依靠此规则支持酸蚀岩。入口提示词“必须做对”第 7 条也明确要求每轮执行。
- C++：`docs/pushbox_sim.cpp:159` 只有 `crumble_pending` 为真才扫描；第 160 行立即清除此标志；第 161 行扫描范围仅限本次爆炸包围框。`act()` 中只有 BOMB 动作设置此标志。
- 静态反例：非爆炸轮输入中，一格剩 64 个 breakable。模板要求清掉；C++ 在 `crumble_pending == false` 时保留。
- 实际影响：两者对非爆炸导致的破坏、已有残余和可配置规则的行为不同。本次没有证明现有五关作者解法因此失败。
- 建议供用户裁决：游戏层按模板每轮扫描全图执行崩落；C++ 的单次爆炸检查仅记录为参考实现偏差。不要修改 SDK。

## R01：T2 的线程要求与本机资源上限

- 模板 `docs/demo-template.md:641` 要求线程数 1、4、8 分别回放 T1。
- 用户本轮 AGENTS.md 要求整台电脑最多 2 个计算 worker，未经明确同意不能突破。
- 用户资源限制优先。当前默认 1 个 worker；4/8 线程测试不得直接执行，现阶段标为未执行，不能据此声明 T2 全量通过。SDK 构建脚本默认 `--jobs=4`，实际启动时必须显式改为 `--jobs 1`。
- 这项记录不要求用户现在放宽资源限制；恢复实施后，可先完成允许范围内的测试，并保留 4/8 线程验收缺口。

## 输入与环境核对

- 当前仓库只有设计输入，分支 `master`，初始提交 `d886417`。没有 `project.godot` 或游戏脚本。
- 项目中的模板与 `/Users/key_/Desktop/CURRGO/newdesign/pushbox/demo-template.md` 逐字节相同（`cmp` 退出码 0）。
- 项目中的 C++ 参考与 `/Users/key_/Desktop/CURRGO/newdesign/_work/measure/pushbox_sim.cpp` 逐字节相同（`cmp` 退出码 0）。两处差异不是本地副本过时导致。
- 本机 Godot 可执行文件：`/Users/key_/Desktop/CURRGO/ele-proj/zips/Godot.app/Contents/MacOS/Godot`；`--version` 实际输出 `4.7.2.stable.official.ed1daf0bf`。
- 可读 SDK 仓库：`/Users/key_/Desktop/CURRGO/ele-proj/ele-base-c++`；当前 HEAD `0e6b5dd8`，与要求的 `dacb93e` 不同。`dacb93e` 对象存在，读取其 `VERSION` 得到 `1.2.0`。恢复实施后需要在可写项目目录准备固定版本的独立 SDK 副本；现有 dylib 未核验来源，不能作为 M0 已通过的证据。
- 已检查全机计算进程和内存；本次未启动编译、模拟或长时间计算，无需清理计算任务。

输入 SHA-256：

```text
3d9f3c471090ee6989da316c0bf5575e9970dd55a7e06d0d4c6ae818933a70d0  docs/demo-template.md
78513a1da7b1affd29571ad6d8ee82a30f6d04ba1f7f5b7421a8c3b452309966  docs/pushbox_sim.cpp
f9613221df6dff0bd4b5390bbaf73316def63d4152455fa36d40843b12d025f1  docs/common.hpp
4913fd9c72e48e4fbec580028511b1439e66a48afdfc8c4ccdad0756ac9f0f5d  docs/sdk-capability-map.md
f0d619150d8918eb2bf2483bb107dbf697a802ff29685b29bb514aac943d0714  docs/RESULTS.md
```

## 最近可执行的一步与交接

执行人：用户，在当前聊天裁决 C01、C02。建议直接发送：

> 按模板实现这两条，C++ 仅作其余规则与实测对照；本机保持 1 个 worker，T2 的 4/8 线程项列为未执行，继续 M0–M5。

收到裁决后执行人：当前 Codex 会话。先记录裁决和实施计划，再准备 `dacb93e` 独立 SDK 副本、单 worker 编译与 M0 验证；随后按 M1→M5 实现和实测。最终逐项报告通过、失败和未执行项，不把已有设计方测量结果写成 demo 自己通过的结果。
