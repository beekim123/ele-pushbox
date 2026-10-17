# DLV-04b 济州海女村：6 间机关房，济州进开局抽签

状态：**制作完成，自动验收未全过；人工试玩未完成，待技术复验与合并**（未合并；遗留见「交付」）。
基线：`claude/inspiring-ride-zfnn4s`（已包含 DLV-04a）→ 分支：`ui/DLV-04b`（按用户本轮指令；**不要**从 `main` 开）
预计：3–4 小时；超过 5 小时还没做完就停下，把进度写进「交付」交回。

**开工**（照抄）：
```bash
git fetch origin
git checkout -b ui/DLV-04b origin/claude/inspiring-ride-zfnn4s
```
**交回**（二选一）：
- 能推送：`git push -u origin ui/DLV-04b`
- 不能推送：`git bundle create DLV-04b.bundle origin/claude/inspiring-ride-zfnn4s..ui/DLV-04b`，把 `DLV-04b.bundle` 交给用户

只往 `ui/DLV-04b` 提交；不往别的分支推送，也不合并别的分支。

## 目标
做出济州的 6 间机关房：`jeju_neolttwigi`、`jeju_baramgil`、`jeju_pier`、`jeju_terrace`、`jeju_doldam`、`jeju_dodaebul`，全部通过 `check-rooms2`；然后把济州（`jeju_1`）放进正式地图和开局抽签。做完后工作台「配送」菜单会自动出现「海女村」。

## 要读的（只读这些）
- [DLV-04.md](DLV-04.md) 的「每间房的要求」表和「要做」第 2、3、6 条
- [delivery-jeju.md](../design/delivery-jeju.md) 第 4 节（这 6 间的想法）
- [DLV-05.md](DLV-05.md) 的「交付」：跷跷板、阵风在 v2 里怎么写；`tests/rooms2.test.mjs` 里 DLV-05 加的 4 间测试房间就是现成的写法样板
- 关卡 G09、G10、F08、E06 的规格（装置参数照抄）

## 要做的
1. 6 间房写进 `content/rooms/jeju/<id>.json`，装置照 DLV-04 第 3 条。阵风只用验证过的那一种配置；F08 余量很小，作者解要多试几种走法确认没有捷径。
2. 房名、提示文字加进 `content/i18n-rooms2/` 两张表，再跑 `python3 tools/build-font.py --ext rooms2`。
3. 13 间都通过以后，按 DLV-04 第 6 条：
   - `jeju_1` 从 `slices.json` 顶层 `planned` 移进 `entries`（放在 `diyu_1` 后面），删掉 `todo` 字段；`planned` 空了就删掉；
   - `delivery_pool.pool.maps` 加 `{"slice": "jeju_1", "weight": 1}`；
   - 看 300 个种子的统计，需要时调 `jeju_1.layout` 的 `cols` / `rows`；
   - 更新 `delivery-puzzle-rules.md` 第 6 节的地图表和统计、`delivery-jeju.md` 开头的状态。
4. 放进 `entries` 后，内容检查里"jeju_1 规划中"的警告会消失；声音目录 `content/catalog/audio.json` 的 `pending_references` 里登记的 `slice:jeju_1` 这时变成正常引用，**不用改**。

## 可改的文件
- 新建：`content/rooms/jeju/` 下这 6 个文件
- `content/i18n-rooms2/zh-Hans.json`、`en.json`：只加这 6 间的键
- `content/catalog/slices.json`：只动 `jeju_1`、`planned`、`delivery_pool`
- `docs/design/delivery-puzzle-rules.md`（只改第 6 节地图表和统计）、`docs/design/delivery-jeju.md`（状态、第 4 节"和设计不同的地方"）
- 测试里写死"只有两张地图"的两处预期，加上济州（交付里写明）：
  - `tests/rooms2.test.mjs` 约第 185 行 `["diyu_1", "dungeon_2"]` → 加 `"jeju_1"`；
  - `tests/workbench.e2e.cjs` 的 `wantMenu`：「配送」组 `"石牢","地府"` 后面加 `"海女村"`。
  其他测试不改。
- 生成文件：用工具生成后提交，不手改

验收和这个清单冲突时，以清单为准，把做不到的写进交付，不要想办法绕过。

## 不能碰的文件
- DLV-04a 做的 7 间房（有问题写进交付）
- `rooms2.js`、`mapgen2.js`、`tilemodel*.js`、`mech/*.js`：规则不够用就写进交付，不自己改
- 冻结区（AGENTS.md 2a）、`docs/status.md`、`game/**`

## 检查
边做边跑（只跑这些）：
```bash
node tools/check-rooms2.mjs --only <房间id>
```
最后跑一次：
```bash
node tools/check-rooms2.mjs --write     # 0 失败；300 个种子三张地图都抽到、都能生成
node tools/content.mjs check            # 0 错误、0 警告
node --test tests/*.test.mjs
node tools/art.mjs build                # 0 bumped
node tests/workbench.e2e.cjs
```
不要做的：逐个算文件哈希、复制仓库做试验、为写交付补跑命令（process.md 第 10 节）。

## 验收
- 13 间济州房每种翻转 × 每条路线都通过；开局抽签 300 个种子里三张地图都有。
- 工作台「配送」菜单出现「海女村」；点开能看到 13 间房；试玩一间机关房，跷跷板、阵风能用，按 `H` 喂零食有提示气泡。

## 交付（制作方填写，不超过 40 行）
- 跳板场：先扳开净空门，从上方绕到铁箱右侧推箱落井；弹起的木箱压住出口门。
- 风口：走动让阵风把墙角木箱吹进两格深坑，踩木箱过坑。
- 码头：从下方绕到铁箱右侧，推铁箱沉到水底跳板；沿下方返回，踩弹起的木箱上栈道。
- 橘园台地：挖出净空处的土，绕到右岸压板向左倒沙，弹起木箱开门，再爬到上屏。
- 石墙风口：沿下方到右侧入口压板放风，立即左推铁箱落右坑，挡住木箱使它停在左压板。
- 石灯台：下到跳板右端按上扳杆，风吹木箱落左井，把人物弹上石灯台。
- 300 种子：石牢 100 / 地府 107 / 济州 93，全部生成；7/8/9/10 房分别 29/129/118/24 局，8–16 屏；保留济州 16×2。
- `check-rooms2 --write`：36 间房、300 种子全部通过；济州 13 间每条路线及翻转通过，新六房 44 条路线均有作者解。
- `content.mjs check`：退出 1，2 error(s)、0 warning(s)：`content/i18n-delivery2`、`content/i18n-result` 缺 `zh-Hans.json`。
- `node --test --test-concurrency=1 tests/*.test.mjs`：213 项，198 通过、15 失败；失败均由上述两项文字表错误引起，房间及 DLV-05 测试通过。
- `art.mjs build`：156 assets、0 bumped、94 reference renders、6 approval records；资产生成完成，总退出 1 原因为同两项 content 错误。
- `workbench.e2e.cjs`：使用流程指定 Mac 浏览器路径，113 项通过、3 项失败；详情见下。
- 测试预期只改两处：`rooms2.test.mjs` 的地图集合加入济州；`workbench.e2e.cjs` 的配送菜单加入海女村，适配济州正式入池。
- E2E 遗留：总览内容检查受缺文字表阻塞；第 211 行仍断言地图数量为 2，第 556 行仍要求声音页出现「地图待 DSN-01」。后两处不在可改清单内，未改断言或产品行为绕过。
- 文字表遗留目录未由本包创建，也不在基线 Git 文件清单与本包可改范围内，未补表或删除目录。
- 石墙风口已试四条正常作者路线和放风后迟推的反例；迟推在原图和镜像均失败，正常路线及冻结检查通过。
- 页面验收：E2E 已看到菜单「海女村」，三地图页面各自房间列表无异常；人工查看 13 房、试玩机关和按 H 气泡未完成。
- 人工试玩原因：浏览器工具安全策略禁止打开 `file://`；用户明确选择「作为交付遗留，记录人工试玩未完成」。
- 具体几何差异已记 `delivery-jeju.md` 第 4 节；未改规则实现、原七房、确认记录或冻结美术，无新增美术确认。
- 当前阶段：制作交回，技术验收未全过、人工验收未完成，尚未合并或正式入库。
- 下一步（整理合并方）：处理两项范围外文字表问题、修正上述两处未授权测试预期后，复跑失败及受影响检查，再按流程审核合并。
- 下一步（用户，已选择后续再验）：打开本地工作台 `#rooms2/map/jeju_1` 查看 13 房，试玩石灯台并确认阵风、跳板和 H 气泡；本轮无需即时操作。
