# 开发环境搭建

## 设备建议
- 主机：Windows 11 / 32GB RAM / RTX 4060 / 1TB SSD。
- 副机：macOS（用于文档、素材管理、AI 协作）。

## 工具链
- 引擎：Godot 4.3+
- IDE：Cursor
- 版本控制：Git + GitHub
- 美术：Aseprite 或 Krita

## 初始化步骤
1. 安装 Godot 4.3（确认命令行为 `godot` 或 `godot4`）。
2. 打开项目根目录并让 Godot 生成 `.godot/` 缓存。
3. 执行测试：`bash scripts/ci/run_tests.sh`。
4. 执行双线构建：`bash scripts/build/build_variants.sh`。

## AI 协作约束
- 核心战斗与成长逻辑必须人工审查。
- 所有 AI 资产必须登记到素材台账。
- 每次大改后必须跑回归测试。
