# DLV-04b 济州海女村：6 间机关房，济州进开局抽签

状态：**等 DLV-04a 合并后再派**（DLV-04 按 process.md 2.1 拆出的后一半；两包都改文字表，不能同时做）
基线：`claude/inspiring-ride-zfnn4s`（已包含 DLV-04a）→ 分支：`dlv/DLV-04b`（**不要**从 `main` 开）
预计：3–4 小时；超过 5 小时还没做完就停下，把进度写进「交付」交回。

**开工**（照抄）：
```bash
git fetch origin
git checkout -b dlv/DLV-04b origin/claude/inspiring-ride-zfnn4s
```
**交回**（二选一）：
- 能推送：`git push -u origin dlv/DLV-04b`
- 不能推送：`git bundle create DLV-04b.bundle origin/claude/inspiring-ride-zfnn4s..dlv/DLV-04b`，把 `DLV-04b.bundle` 交给用户

只往 `dlv/DLV-04b` 提交；不往别的分支推送，也不合并别的分支。

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
- 每间房一句：谜题怎么解
- 300 个种子的统计一行
- 上面「最后跑一次」各一行结果
- 改了哪条测试的预期、为什么（没有写"无"）
- 遗留问题（没有写"无"）
（分支名、提交号、`git diff --stat` 贴在给用户的回复里，不写进这个文件）
