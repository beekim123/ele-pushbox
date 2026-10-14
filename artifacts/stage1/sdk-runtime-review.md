# SDK 运行产物与临时源码清理核对

日期：2026-10-14（Asia/Shanghai）。范围：第一阶段期间，按用户补充授权核对并清理本地 `vendor/ele-base-cpp`；不开发第二阶段、不重编 SDK、不启动 Godot/Python/构建测试。主会话统一维护计划及 `docs/v2/status.md`，并执行全部测试。

## 结果与边界

- 已仅删除 `/Users/key_/Desktop/CURRGO/pushbox-demo/vendor/ele-base-cpp`。
- 保留 `vendor/.gdignore`（0 字节）、`vendor/.DS_Store`、全部 `bin/` 产物/许可证和根目录 `ele.gdextension`。
- 清理前后，7 个 `bin/` 文件及 `ele.gdextension` 的 SHA-256 全部相同。校验清单见 [清理前](sdk-bin-before.sha256) 与 [清理后](sdk-bin-after.sha256)。`shasum -a 256 -c artifacts/stage1/sdk-bin-before.sha256` 返回 8 项 `OK`；`cmp` 返回 0。
- 本子任务不声明游戏或全量测试通过；动态启动与第一阶段全量回归由主会话顺序执行并留痕。

## 运行、测试及打包路径

1. `ele.gdextension` 的 `macos.arm64` 指向 `res://bin/libele_godot.dylib`。文件为 Mach-O arm64 动态库，大小 **1,284,512 字节**（约 1.2 MiB）。SHA-256：

   ```text
   b084eb5ffad07cc4b790285156de1bf3ef1c33fd69a8bb7fd2d7c599f6c088c4
   ```

   此值与 `bin/build-metadata.json` 的记录一致；锁定 SDK commit 为 `dacb93e6dc898ac8d1dfa95f6bc15686a183cf18`，SDK 版本 1.2.0，release/godot，构建 jobs=1。

2. `otool -L bin/libele_godot.dylib` 显示系统依赖仅 `/usr/lib/libc++.1.dylib`、`/usr/lib/libSystem.B.dylib`。其自身 install name 为 `build/godot/release/libele_godot.dylib`，不构成对 `vendor/` 的外部动态库依赖。

3. `tools/run_demo.sh` 只检查 `bin/libele_godot.dylib` 存在并通过 `ele.gdextension` 启动。`project.godot`、`pushbox/`、`tests/`、测试运行器、启动脚本及打包校验脚本的路径检索未发现运行时读取 `vendor/`。

4. `tools/run_tests.py` 创建的临时测试工程只接入 `bin/`、`tests/`、`tools/`、`artifacts/` 和 `ele.gdextension`，复制 `pushbox/`；不包含 `vendor/`，也不调用 `tools/prepare_sdk.sh`。因此测试的静态运行依赖由 `bin/` 提供；实际执行结果由主会话补充。

5. `vendor/.gdignore` 是空文件，屏蔽 Godot 的目录扫描。`.gitignore:3` 的 `vendor/` 规则排除该临时目录；`git check-ignore -v` 已确认命中，主仓库 `git ls-files vendor` 没有条目。`bin/libele_godot.dylib` 则通过显式例外规则纳入版本管理。

6. `tools/package_demo.py` 使用明确的目录白名单，其中包含 `bin/`，不含 `vendor/`；`tools/verify_package.py` 从解压工程启动扩展，不要求临时源码目录。本次没有重新打包旧候选 ZIP。

## 删除前的数据检查

- SDK 工作树处于 detached HEAD `dacb93e6dc898ac8d1dfa95f6bc15686a183cf18`；`git diff --stat`、`git diff --cached --stat` 均为空。
- SDK 的唯一非忽略未跟踪项是 `.venv` 符号链接，目标为 `/Users/key_/Desktop/CURRGO/ele-proj/ele-base-c++/.venv`。删除整个临时目录只移除链接本身；清理后通过 `test -d` 确认外部目标仍存在。
- `vendor/box2d` 与 `vendor/godot-cpp` 两份依赖仓库的完整未跟踪/修改状态均为空；SDK 及两份依赖的 HEAD 和本地分支相对本地已存远端引用没有独有提交。
- 忽略内容为构建目录、下载的上述第三方依赖、Python/系统缓存、示例安装产物，以及 `.local/config.json`。配置仅包含现有 Godot 可执行路径，示例 `adapter_config.txt` 均为 `release`。未发现需要保留的修改源码、用户工作或补丁。
- 清理命令为 `rm -rf -- vendor/ele-base-cpp`，没有尾随斜杠，也没有跟随 `.venv` 链接。未删除 `vendor/` 本身或其他目录。

## 空间与产物核验

以 `du -sk` 的磁盘分配量为准：

| 对象 | 清理前 KiB | 清理后 KiB |
| --- | ---: | ---: |
| `vendor/ele-base-cpp` | 454,664 | 目录不存在 |
| `vendor/` 合计 | 454,672 | 8 |
| `bin/` 合计 | 1,280 | 1,280 |

释放约 **444 MiB**（454,664 KiB）。上述 8 项哈希校验及保留文件/外部链接目标检查均返回 0；`git status --short -- bin ele.gdextension tools/prepare_sdk.sh` 无输出，运行产物及构建脚本未修改。

## 后续接入建议与交接

`tools/prepare_sdk.sh` 的现有机制是 clone SDK 至 `vendor/ele-base-cpp`，固定 `dacb93e`，在临时源码目录执行单 worker 的 release/godot 构建，再复制动态库、扩展配置、调色板和许可证到当前项目。只有未来主动重编 SDK 时，该脚本才会重建临时目录。

第二阶段若在 SDK 主仓库完成开发和编译，可直接将对应 `libele_godot.dylib` 安装到本项目 `bin/`，并将配套 `ele.gdextension` 安装到项目根目录，确认其中的库路径仍为 `res://bin/libele_godot.dylib`。按实际新版本同步许可证/第三方声明及 `bin/build-metadata.json` 的 commit、版本、构建配置和 SHA-256，再由当时开发会话按用户范围执行回归；不需要复制整份 SDK 源码到本项目。本次未执行此后续接入或任何第二阶段工作。

当前阶段：SDK 临时源码清理已完成，第一阶段开发/验证仍由主会话处理。下一步及执行人：主会话运行并核对第一阶段全量回归，在项目状态文档中同步本核对结论，然后按用户要求停在第一阶段审核。当前无需用户操作；本清理子任务已结束，无需后续操作。
