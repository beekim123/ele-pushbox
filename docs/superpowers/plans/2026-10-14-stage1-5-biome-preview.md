# 阶段 1.5 美术模块与地图预览执行计划

执行人：本 Codex 会话；按用户授权单 worker 顺序执行，不派发并行任务。

**目标**：封存第一阶段，完成零像素回归美术拆分及六大风格实机预览，停在用户美术验收。

**设计依据**：`docs/art-architecture-and-biome-design.md` 第 0、2–6 节及本轮四步指令。

**架构**：基线矩阵按业务域原样搬迁；ArtRegistry 分离基线与主题缓存；ThemeSpec 提供语义色板、周期背景与机关皮肤；展示数据使用 SDK cell 编码接入同一个 world Shader，展示器不创建物理 Session。普通游戏仍使用 320×180；展示器使用 640×360 原生画布及整数缩放。

**约束**：68 张基线 SHA256 不变、缓存引用恒等；默认主题兼容；禁止扫描词保持缺席；机械闸门按两格循环采样，能量门保留基座；箱体与虚影均按 kind；主题背景按需缓存；不改 SDK、board/session/rules 或原关卡；不实现第二阶段机关结算。

- [x] Step 0：重跑 18/18（含性能），保存失败与通过证据；提交 `feaa6ba`；工作区干净。
- [x] Step 1：新增 `tests/art_modules.gd`，先验证缺少注册表的失败；建立第 2.1 节完整目录；兼容壳转发 Registry.image/names；Style.texture/themed_texture 分轨；测试像素 SHA、引用、回退、懒加载及主题背景裁剪。
- [x] Step 1 验证：`python3 tools/run_tests.py --only art_modules`、`--only procedural_art`，再完整 `--performance`；保留模块拆分证据。
- [x] Step 2：新增 `tests/biome_showcase.gd`，先验证缺少展示器的失败；添加六份固定格宽地图及独立摆件坐标；实现 ThemeShaderBinder.apply(material, theme_id, ids)，升级同一地形 Shader 并修正 BoardView 双轨与闸门协议。
- [x] Step 2 UI：大厅鼠标入口/B 快捷键；展示器左右键/鼠标翻页、六个主题直接选择、Esc 返回；离开与直接 select_level 均恢复普通布局。
- [x] Step 2 验证：真实 macOS Godot 窗口渲染六张图，检查地形像素、3px 草皮/云底、2px 条纹、新材质、透明占位、缓存与输入；导出 640×360 和整数 ×3 的 1920×1080 至 `artifacts/biome-preview/captures/`，逐张视觉检查。
- [x] Step 3：完整 `python3 tools/run_tests.py --performance`（20 个脚本）；原 18 脚本零改，T8 <=4ms / <=100ms；复核冻结文件 SHA、禁词、git diff；记录技术审核结果。
- [x] Step 3 交接：更新 `docs/v2/status.md` 和预览报告，状态明确为技术候选通过、用户美术待验收、本地改动未正式发布；停止第二阶段开发；下一步由用户双击 Run Demo.command → 地图风格预览。
