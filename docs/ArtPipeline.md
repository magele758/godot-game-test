# AI 美术资产生成工作流

## 推荐工具（按优先级）
1. **ComfyUI + Stable Diffusion XL**（本地，免费，完全控制）
2. **Midjourney**（质量高，月费 $10 起，商用可）
3. **DALL-E 3 / ChatGPT**（快速原型，商用可）
4. **Krita + AI 插件**（精修 + 局部重绘）

## 纸片人风格提示词模板

### 角色（透明背景）
```
paper cutout character, flat 2D, cartoon style, thick black outline,
white paper texture, chibi proportions, [角色描述],
transparent background, game sprite, clean edges
--style raw --ar 1:1
```

### 敌人
```
paper cutout monster, dark cardboard texture, menacing cute,
flat 2D, thick outline, [敌人描述],
transparent background, game sprite
--style raw --ar 1:1
```

### 场景/地板
```
top-down paper craft room, pastel colors, notebook paper texture,
doodle decorations, flat 2D game background, tileable,
[场景描述]
--style raw --ar 16:9
```

### 特效（击杀/血液）
```
paper confetti explosion, red paper scraps flying,
flat 2D, cartoon gore, paper cutout style,
transparent background, sprite sheet
--style raw
```

## 处理流程
1. 生成原始图 → 保存为 PNG
2. 去背景（rembg / remove.bg / Krita 魔棒）
3. 统一尺寸（角色 64x64 或 128x128，场景 1280x720）
4. 放入 `res://assets/sprites/` 目录
5. 在 Godot 中用 Sprite2D 替换 Polygon2D 占位图

## Godot 导入设置
- Filter: `Nearest`（保持像素感）或 `Linear`（平滑）
- Compression: `Lossless`
- 勾选 `Fix Alpha Border`

## 需要生成的最小资产清单
| 资产 | 尺寸 | 数量 | 说明 |
|------|------|------|------|
| 主角idle | 128x128 | 1 | 白色纸片人站姿 |
| 主角攻击 | 128x128 | 3 | 三段连击 |
| 主角闪避 | 128x128 | 1 | 冲刺姿态 |
| 喽啰 | 96x96 | 1 | 纸板敌人 |
| 墨犬 | 96x96 | 1 | 快速小型敌人 |
| 订书骑士 | 128x128 | 1 | 大型敌人 |
| Boss | 192x192 | 1 | 彩纸守卫 |
| 场地背景 | 1280x720 | 2 | 两个主题区域 |
| 击杀粒子 | 32x32 | 3 | 纸屑/血色纸片 |
| 挥砍弧光 | 128x64 | 1 | 半透明弧形 |

## 素材命名规范
```
assets/sprites/player/player_idle.png
assets/sprites/player/player_attack_1.png
assets/sprites/enemies/grunt_idle.png
assets/sprites/environments/room_toy_hall.png
assets/sprites/fx/slash_arc.png
assets/sprites/fx/defeat_confetti.png
```

## 版权记录
每张生成图必须登记到 `docs/Operations/ai_asset_ledger_template.csv`：
- 使用的模型（SD XL / MJ v6 等）
- 完整提示词
- 生成时间
- 是否有后期修改
