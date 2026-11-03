# Mistbound · 雾区回收队

Godot 4 的 2D 俯视合作刷宝框架。玩家不是冒险者，而是进入危险雾区的回收员，从废弃设施里把异常物品带回前哨。结构为**共享前哨／雾区 + 可重复的废弃设施任务 + 回收员长期成长**。面向个人开发的可运行起点，使用 GDScript 和 Godot 原生节点，无第三方依赖。

> 画面采用像素风：世界以 1/3 分辨率渲染后放大，雾气按区域浓度漂移，靠近自己、灯光和队友的地方会变薄。内部 ID（`camp`、`wilds`、`mine`、`crypt`、`traveler_blade`、`ember_relic`、`equipped_relic` 等）保持不变，以兼容存档和联机协议；代码里的 relic 即游戏中的“异常物”。

## 打开与运行

使用 Godot 4 导入本目录的 `project.godot`，按 **F5**。本项目已在 **Godot 4.7.2 / Windows** 验证，使用 Compatibility 渲染器。

也可以在本目录运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run.ps1
# 打开编辑器
powershell -ExecutionPolicy Bypass -File .\tools\run.ps1 -Editor
```

脚本会尝试 PATH、环境变量 `MISTBOUND_GODOT` 和各盘常用 Steam 库路径。未找到时显式传入 `-Godot 'C:\path\Godot.exe'`。项目目录可以移动，不依赖本机绝对路径。

## 现在可以玩什么

- 从雾线前哨进入外环雾区，再进入 7 号采样井或回声声学实验室；各区域有碰撞、入口和独立视觉。
- WASD 移动，鼠标瞄准，按住左键攻击，空格闪避，Q 切换撬棍与射钉枪；敌人会追击并预警攻击。
- 破拆撬棍进行近身扇形攻击；射钉枪发射有飞行时间的钢钉，钢钉命中首个敌人或地形后消失。两把武器都随初始角色提供。
- 击败普通敌人与守卫者获得经验和个人掉落；靠近按 E 回收报酬和异常物。
- 采样井守卫者掉落“不熄的打火机”，实验室守卫者掉落“跳闸电容”。I / Esc 打开装备箱，武器与异常物各占一个独立槽位，可自由组合或卸下异常物。
- 不熄的打火机让武器命中使目标自燃 3 秒，每 0.5 秒造成 4 点伤害；再次命中刷新时长，不叠加层数。
- 跳闸电容每累计 3 次武器命中放电连锁，主目标及最多两个邻近目标各受到 12 点额外伤害。燃烧和放电不会递归触发异常物。
- 守卫者交替使用冲锋与范围重击：冲锋先锁定方向显示走廊，重击先显示圆形范围；闪避可穿过伤害窗口，过热（恢复）阶段适合输出。
- 每 40 经验提升一级，最多 20 级；提升基础伤害与生命。倒下扣除最多 5 报酬，在本区域入口被救回，装备保留。
- 返回前哨恢复生命。离开再进入设施会刷新敌人；切换区域会清除尚未拾取的掉落。
- 单人行动、创建好友房间、通过 IP/端口加入；设计上限 4 人。

操作：**WASD 移动 / 左键攻击 / 空格闪避 / Q 切换武器 / E 交互 / I 或 Esc 装备箱**。界面右上角可保存、离开。

前哨里的收容仓库、维修间等目前是视觉占位。两种武器与两种异常物效果已经实现；更多技能、随机词条、任务、前哨升级、自由建造等留作后续内容。

## 联机规则

公共地图指**当前房间内共享的地图**。房主的进程负责模拟战斗、验证拾取和切换区域，其他人发送操作。入口由房主靠近后按 E，全队一起进入。支持游戏开始后加入；断线后可从主菜单重新加入。

1. 房主点击“创建好友房间”，默认 UDP 端口为 `24570`。
2. 同一局域网的朋友填写房主的局域网 IP，点击“加入房间”。同一台电脑测试可填 `127.0.0.1`。
3. 公网直连需要可达的公网地址、UDP 端口映射和相应防火墙规则；运营商 CGNAT 下不能只靠路由器端口映射。当前没有 Steam 邀请、自动 NAT 穿透或网络中继。

房主退出会结束房间，客人回到主菜单并保存已确认的角色进度。没有房主迁移。客户端目前使用位置插值，尚未实现本地预测，高延迟下操作会有延迟。

本机双开应使用**不同存档目录**，避免两个进程写入同一份角色：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run.ps1 -Mode host -SaveDir 'D:\Code\mistbound\test-results\host'
powershell -ExecutionPolicy Bypass -File .\tools\run.ps1 -Mode join -Address 127.0.0.1 -SaveDir 'D:\Code\mistbound\test-results\guest'
```

## 存档

默认目录为 Godot 的 `user://saves`；在编辑器中通过“项目 → 打开用户数据文件夹”定位。设置绝对路径环境变量 `MISTBOUND_SAVE_DIR` 可覆盖它。

| 文件 | 保存内容 | 保存者 |
| --- | --- | --- |
| `character.json` | 名称、经验、金币、物品数量、武器槽和遗物槽 | 各玩家保存自己的角色 |
| `world.json` | 到访区域、累计首领击杀次数 | 单人或房主 |

关键进度变化和退出时保存；另有每 5 秒检查。文件采用临时写入与有效旧档备份，损坏主档可回退 `.bak`。世界现场敌人、地面掉落、玩家坐标未持久化，重新开始从前哨出发。

本地角色文件可编辑，入房时只做结构和范围校验。这是好友合作的信任模型，尚不适合可信交易经济、排行榜或公共 MMO。

角色存档已升级为 v2。旧版单槽 `equipped` 会按物品类型自动迁入武器槽或遗物槽，并补齐初始撬棍与射钉枪；金币、经验和已有物品保留。首次迁移保存保留原始 v1 备份。世界存档仍为 v1。未知未来版本会拒绝覆盖；新版联机协议为 v2，队友需使用相同版本项目。

## 项目结构与扩展

```text
scenes/main.tscn                 项目入口
scripts/main.gd                 输入、模块组装、驱动像素舞台
scripts/systems/game_session.gd  ENet / RPC / 房间生命周期
scripts/systems/world_simulation.gd  战斗、掉落、区域实例、快照
scripts/systems/combat_rules.gd  武器命中、箭矢、灼烧、连锁闪电
scripts/systems/enemy_brain.gd   敌人追击与首领招式状态机
scripts/systems/save_store.gd    角色 / 世界存档
scripts/systems/item_*.gd        物品 Resource 与注册表
scripts/world/zone_view.gd       四片地图、碰撞、入口、出生点与动态灯光
scripts/world/zone_art.gd        把各区域地面与建筑烘焙成一张像素图
scripts/world/pixel_stage.gd     低分辨率渲染、平滑镜头、雾气、全分辨率文字
scripts/art/                    调色板、像素绘制工具、文本像素图精灵
scripts/actors/                 玩家、敌人、掉落、弹体与战斗特效
scripts/ui/                    主菜单、HUD、装备箱；像素面板与主菜单背景
data/items/                    可在 Godot 编辑器调整的 .tres
tests/                         存档、玩法、像素资源、真实双进程联机、截图
tools/                         启动、引擎定位、截图
```

具体数据协议和扩展方式见 [docs/architecture.md](docs/architecture.md)。下一步可打磨双人战斗平衡、地图探索奖励和副本目标；增加真实公共服务器、多区域并行或跨服角色需要单独扩展架构。

## 验证

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\run_tests.ps1
# 指定引擎和日志目录
powershell -ExecutionPolicy Bypass -File .\tests\run_tests.ps1 -Godot 'C:\path\Godot.exe' -ResultsPath 'D:\Code\mistbound\test-results'
```

测试使用各自隔离的存档目录，不修改真实游戏存档。包含 Godot 导入、旧档迁移与存档完整性、玩法权限与快照排序、武器/遗物判定、像素图与区域烘焙、首领招式，以及两个独立进程通过 ENet 验证加入、移动、战斗、拾取、切图、重连和断线保存。

界面截图：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\capture.ps1            # 默认写入 test-results\capture
powershell -ExecutionPolicy Bypass -File .\tools\capture.ps1 -Phase1     # 武器、异常物、守卫者预警的受控展示
```

它包装了 `tests/capture_preview.gd`，自动设置隔离的 `MISTBOUND_CAPTURE_DIR` 与 `MISTBOUND_SAVE_DIR`，并在 `test-results` 放置 `.gdignore`，避免 Godot 导入截图。

## 像素美术

没有外部美术素材，全部由代码生成，但都按真实像素资源组织：

- 角色、敌人、掉落和手持工具是 `scripts/art/pixel_art.gd` 里的文本像素图，每个字符对应调色板中的一种颜色；数字 `1–3` 是可染色层（玩家队伍色、异常物颜色）。
- 区域地面和建筑由 `scripts/world/zone_art.gd` 程序化绘制并缓存，建筑正好覆盖碰撞矩形；灯光、信标、指示灯等动画由 `zone_view.gd` 逐帧叠加。
- 想换成手绘素材时，把 PNG 放到 `res://assets/sprites/<名称>.png`（染色层为 `<名称>_tint.png`，白闪剪影为 `<名称>_flash.png`）即可覆盖同名精灵，1 像素对应 3 个世界单位。
- 中文文字（地名、玩家名、首领状态）在全分辨率叠加层绘制，伤害数字使用 3×5 像素字体留在像素层。
- 界面与地图文字使用[融合像素字体](https://github.com/TakWolf/fusion-pixel-font)（12px 比例宽度，简体中文版，v2026.10.25），关闭抗锯齿，字号只取 12 的整数倍以保持像素清晰；缺字时回退到系统字体。字体以 SIL OFL 1.1 授权，许可证随字体放在 `assets/fonts/fusion-pixel/`。
