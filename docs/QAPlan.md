# QA & Automation Plan

## 测试层次
- 单元测试：战斗公式、成长解锁阈值、房间有效性校验。
- 生成测试：固定 seed 构造 run，确保最终 Boss 房可达。
- 输入回放校验：保证回放事件时序合法，可用于后续手感回归。

## 执行方式
- 本地：`godot --headless --script res://tests/test_runner.gd`
- CI：`.github/workflows/ci.yml` 在每次提交自动执行。

## 质量门禁
- 任意测试失败时禁止发布构建。
- 新增战斗或成长逻辑必须补对应测试。
- 每次平衡改动后至少执行一次完整回归。
