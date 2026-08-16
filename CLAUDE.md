# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

RIME 输入法用户配置仓库，使用 GitHub Actions 自动集成生成各平台 RIME 配置包。主方案为[星空键道](https://github.com/amorphobia/rime-jiandao)，辅以袖珍简化字拼音、日本語、蜀拼-重慶。

## Commands

```bash
make sort          # 排序 opencc/tofu.txt
make check         # 运行字典校验（排序检查 + 去重校验）
bash scripts/sanity_check.sh  # 字典文件校验（cizu_append/delete/modify、danzi_append、tofu 的排序和去重检查）
bash scripts/calc_encoding.sh <词组> [权重]  # 计算词组编码，输出待插入行
bash scripts/find_position.sh <file> [音码 [形码 [权重 [次要权重]]]]  # 定位插入行号（支持 stdin 批量）
bash scripts/insert_entries.sh <file>  # 批量插入（stdin: after_line<TAB>词<TAB>音码<TAB>形码<TAB>权重）
```

## Architecture

### Directory Structure

```
dicts/              # 自定义字典数据（修改源方案词典的增量文件）
  cizu_append.txt   # 词缀追加 (~19.6k 行, tab 分隔: 词	音码	形码	权重)
  cizu_delete.txt   # 词缀删除
  cizu_modify.txt   # 词缀修改（如调权重）
  danzi_append.txt  # 单字追加
  buchong_append.txt# 补充追加
lua/                # RIME Lua 脚本（所有平台共享）
opencc/             # OpenCC 转换数据（emoji、简繁、绘文字加、焱暒妏）
  tofu.txt          # tofu 过滤列表（需要排序）
scripts/
  fetch.sh          # 构建脚本：clone 上游方案仓库，应用 dicts/ 补丁，生成 schemas/ 目录
  sanity_check.sh   # 字典校验：检查排序和去重
  calc_encoding.sh  # 计算词组编码（需上游 rime-jiandao 仓库）
  find_position.sh  # 定位插入行号（单条参数模式 / stdin 批量模式）
  insert_entries.sh # 批量插入（按 after_line 降序处理，同基线按输入顺序）
  installer.ps1     # 小狼毫一键安装脚本
weasel/             # 小狼毫 (Windows) — weasel.custom.yaml, default.custom.yaml 等
rabbit/             # 玉兔毫 (Windows, AutoHotkey) — rabbit.custom.yaml 等
squirrel/           # 鼠须管 (macOS)
hamster/            # 仓输入法 (iOS)
irime/              # iRime (iOS)
```

### How It Works

1. **字典层** (`dicts/`): 存放增量修改文件，在构建时通过 `fetch.sh` 应用到上游方案（星空键道）的词典中。`cizu_append.txt` 是核心文件，格式为 `词\t音码\t形码\t权重`。

2. **方案层** (`*.schema.yaml`, `*.dict.yaml`): 构建时由 `fetch.sh` 从各上游仓库 clone 生成，不直接入库。

3. **平台配置层** (`weasel/`, `rabbit/`, etc.): 存放各平台的 `.custom.yaml` 文件，覆盖外观、快捷键、应用级 ascii_mode 等。

### Build Pipeline (GitHub Actions)

每条提交/标签触发 `Build Rime Configs` workflow：
1. **sanity-check** — 运行 `sanity_check.sh` 校验字典
2. **prepare-schemas** — 安装 opencc，运行 `fetch.sh` 拉取上游方案并应用补丁
3. **build-package** — 矩阵构建各平台（weasel/hamster/irime/squirrel/rabbit）配置包，上传为 Release Artifact

### Deweight 机制

`fetch.sh` 中调用 `make_dicts.sh` 时传入 `--deweight` 参数，作用是将 `06.630.txt` 中的 630 个高频短语的**权重强制设为 10**。

这 630 个短语已在 `04.buchong.txt` 中被赋予了专用的简码（如「不能」= `ba`、「必须」= `bu`），因此不应在词组编码树中抢占短码位置。

**流程位置**（在 `make_dicts.sh` 中的顺序）：

```
追加 append 条目 → 去重 → ★ deweight（630 词 → weight=10） → 删除 → 调权 → 排序 → 生成编码树
```

**效果**：
- 排序 (`sort -k4,4nr`)：weight=10 远低于常规权重（897–1050），630 短语沉到同音码组的末尾
- 生成编码树 (`convert_raw_dict.py`)：因权重极低，630 短语被推入深层子节点，得到的长码不会被用户实际打到
- 相当于在编码树中为这 630 词「占位但不竞争」，确保常规词组拿到更短的编码

### 键道6 编码规则

键道6 的编码体系中，单字全码为 6 个字母：**前 2 码音码，后 4 码形码**。同一字的形码固定不变，多音字则有不同音码。词组全码也为 6 码：

| 字数 | 全码 | 说明 |
|---|---|---|
| 二字 | 4音码 + 2形码 | 两字音码各取 2 码 + 两字形码各取第 1 码 |
| 三字 | 3音码 + 3形码 | 三字音码各取首码 + 三字形码各取首码 |
| 四字及以上 | 4音码 + 2形码 | 第 1、2、3、末字音码首码(4码) + 前两字形码首码 |

### 飞键（Alt Code）

飞键指同一发音对应多个合法音码键位。键道中涉及三组：

| 飞键 | 键位 | 适用范围 |
|---|---|---|
| `zh` | F / Q | 声母为 zh，韵母为 ai、ao、e 时（其余韵母已强制飞键固定） |
| `ch` | J / W | 声母为 ch，韵母为 ao、e 时（其余韵母已强制飞键固定） |
| `uang` | M / X | 韵母为 uang，声母为 ch、g、h、k、sh、zh 时 |

飞键与多音字的区别：
- **飞键**：同一读音，多个合法编码。添加词组时**所有飞键音码都要添加**，权重保持一致。
- **多音字**：不同读音，不同编码。只添加词组实际读音对应的编码。

`calc_encoding.sh` 会自动列出所有音码组合，stderr 以 `可能 zh 飞键 F/Q`、`可能多音字` 等标签提示。用户需自行判断哪些行应添加：飞键的全部保留，多音字的只保留符合读音的。

### 新增词组流程

向 `cizu_append.txt` 添加新词的标准步骤：

1. **查上游** — 在 `rime-jiandao/dicts/cizu_raw.txt` 中确认该词是否已存在，避免重复
2. **计算编码** — 使用辅助脚本自动计算：
   ```bash
   bash scripts/calc_encoding.sh <词组> [权重]
   # 示例：
   bash scripts/calc_encoding.sh 胜在           # 输出：胜在	erzh	uv	850
   bash scripts/calc_encoding.sh 子模块 980      # 输出：子模块	zmk	avv	980
   bash scripts/calc_encoding.sh --check 找全    # 同时检查是否已存在
   ```
   脚本需上游 `rime-jiandao` 仓库在同级目录，或设置 `JIANDOO_DIR` 环境变量指向其路径。
   若输出多行，注意 stderr 的提示：标记为飞键的行全部添加，标记为多音字的行只取符合读音的。**脚本的「可能 XX 飞键」提示是启发式的，不检查韵母条件，必须对照上方飞键规则表的适用范围列确认后再决定。**
3. **确定权重（必须从分支排序反推，禁止使用默认值）** — 不设默认权重。新词的权重必须根据它在该音码的形码分支中应处的位置**反推**得出。

   具体步骤（与步骤 4 联动）：

   - 在 `--context` 输出中，按形码逐字符追踪新词在编码树中的路径。
   - 对与新词**共享形码前缀**（到首次分叉为止）的每一层节点，列出该节点内所有权重档的条目。
   - 根据词频判断新词应排在哪些词之后、哪些词之前，由此确定权重区间。
   - 常见权重档位：1050 / 980 / 950 / 900 / 850 / 798 / 750 / 700 / 650。选择区间内合适的整数，相邻词之间留出间隔。
   - **必须双向比对**：不仅往上比高权重词，也要往下看完所有低权重词，确认新词确实比它们更常用才可排在其前。
   - **不确定时先询问用户**，不要猜测。

4. **形码分支权重检查（必须执行，不可跳过）** — 编码树按形码**逐字符**分叉，权重只决定**同一节点内**的排序。判断两个词是否在同一分支竞争，必须逐字符比较形码，直到它们**首次出现不同字符**为止——该层之前共享同一前缀、该层起分道扬镳。只共享首字符但在第二字符就分叉的，不在同一子节点竞争，权重高低不影响编码长度。

   例如 `风暴潮` 形码 `uoa` 在 `fbj` 的 `u` 支下，首字符 `u` 与 制表键(`uvi`) 共享，需两码形码；但第二字符 `o` vs `v` 已分叉，与 直播间(`uio`) 在 `i` 处分叉——三者在同一首字符节点但不共享第二字符，权重高低互不影响编码长度。反例：`第一方`(`uvo`) 和 第一种(`uvu`) 共享前两字符 `uv`，在第三字符才分叉，权重排序会直接影响编码。`大吗`(`vo`) 和 大麻(`vo`) 形码完全相同，权重必须拉开。

5. **插入文件** — 按排序规则（音码 → 权重降序 → 形码）放到正确位置。**定位与插入分两步**：

   先定位（`find_position.sh` 一次运行给出精确行号，无需手工试探边界）：
   ```bash
   # 单条定位（输出 after_line + 前后行/组内成员供核对）
   bash scripts/find_position.sh dicts/cizu_append.txt <音码> <形码> <权重>
   # 批量定位（stdin: 词<TAB>音码<TAB>形码<TAB>权重，输出可直接喂 insert_entries.sh 的行）
   printf '词\t音码\t形码\t权重\n...' | bash scripts/find_position.sh dicts/cizu_append.txt
   ```
   再插入（**≥2 条必须用脚本**，单条也可用管道）：
   ```bash
   # 格式：after_line<TAB>词<TAB>音码<TAB>形码<TAB>权重
   echo '3169	手敲	edqc	io	850
   6721	河南人	hnr	aui	850
   6721	湖南人	hnr	aui	850' | bash scripts/insert_entries.sh dicts/cizu_append.txt
   # 完整流水线（定位 → 插入一步到位）：
   printf '手敲\tedqc\tio\t850\n' | bash scripts/find_position.sh dicts/cizu_append.txt \
     | bash scripts/insert_entries.sh dicts/cizu_append.txt
   ```
   脚本按行号降序处理（从下到上插入），确保未插入词的行号不受先前插入影响。同一条插入基线（after_line 相同）的多条词按脚本输入顺序排列；after_line 为 0 表示插到文件开头。组内定位按 权重降序 → 次要权重降序 → 形码升序，与文件排序规则一致。**注意核对 find_position.sh 输出的 after_line 与上下文，避免定位偏差（曾出现形码误输入未被 sanity 拦截的先例）。**
6. **校验** — 运行 `bash scripts/sanity_check.sh` 确认排序和去重通过

### Dictionary Validation Rules

原始 dict 文件列含义：`词	音码	形码	权重	次要权重	注释`

- `cizu_append.txt`: 按音码、权重降序、次要权重降序、形码排序，(词, 音码) 唯一
- `cizu_delete.txt`: 按音码排序，(词, 音码) 唯一
- `cizu_modify.txt`: 按音码排序，(词, 音码) 唯一
- `danzi_append.txt`: 按第 2 列（tab 分隔）排序
- `opencc/tofu.txt`: 排序后去重

## Key Design Decisions

- 字典权重调整通过在 `cizu_modify.txt` 中覆盖词条实现（非直接修改上游词典）
- 不同平台共享同一套字典补丁和 Lua 脚本，只在 `.custom.yaml` 中差异化配置
- 版本通过 git tag 管理，格式 `vYYYYMMDD`（如 `v20260726`）
- 平台配置中统一使用 `LXGW WenKai Mono GB` 和 `Plangothic P2` 字体
