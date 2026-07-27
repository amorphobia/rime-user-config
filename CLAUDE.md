# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

RIME 输入法用户配置仓库，使用 GitHub Actions 自动集成生成各平台 RIME 配置包。主方案为[星空键道](https://github.com/amorphobia/rime-jiandao)，辅以袖珍简化字拼音、日本語、蜀拼-重慶。

## Commands

```bash
make sort          # 排序 opencc/tofu.txt
make check         # 运行字典校验（排序检查 + 去重校验）
bash scripts/sanity_check.sh  # 字典文件校验（cizu_append/delete/modify、danzi_append、tofu 的排序和去重检查）
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

### 键道6 编码规则

键道6 的编码体系中，单字全码为 6 个字母：**前 2 码音码，后 4 码形码**。同一字的形码固定不变，多音字则有不同音码。词组全码也为 6 码：

| 字数 | 全码 | 说明 |
|---|---|---|
| 二字 | 4音码 + 2形码 | 两字音码各取 2 码 + 两字形码各取第 1 码 |
| 三字 | 3音码 + 2形码 | 三字音码各取首码 + 前两字形码首码 |
| 四字及以上 | 4音码 + 2形码 | 第 1、2、末字音码首码(3码) + 又取第1字音码首码(1码) + 前两字形码首码 |

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
