# PaperBloodRogue

纸片人血萌 Roguelike（单人 + AI 协作开发）项目骨架。  
目标是先跑通垂直切片，再逐步扩展到双线发行版本。

## 已落地范围
- Godot 4 项目骨架（核心循环、战斗原型、元进度、地区化血腥开关）。
- 数据驱动配置（武器/敌人/房间/任务/地区设置）。
- 自动化测试入口（单元与生成测试）。
- 双线发行资产草案（Steam + 国内渠道文案与发布清单）。

## 环境要求
- Godot `4.3+`
- Git（可选）
- 推荐系统：Windows 11（主开发），macOS（辅助）

## 本地运行
1. 用 Godot 打开项目根目录。
2. 直接运行主场景（`res://scenes/main.tscn`）。
3. 默认使用 Global 表现；可通过环境变量切换：
   - `GAME_REGION=global`
   - `GAME_REGION=cn`

## 命令行测试
```bash
godot --headless --script res://tests/test_runner.gd
```

## 双线构建
```bash
bash scripts/build/build_variants.sh
```

## 目录结构
- `docs/`：产品支柱、风格、发行与运营文档。
- `data/`：内容配置（JSON）。
- `scenes/`：Godot 场景入口。
- `scripts/`：核心玩法、构建与工具脚本。
- `tests/`：自动化测试脚本。
- `.github/workflows/`：CI 配置。
