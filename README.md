# REDLINE · 公路狂徒

Godot 4 制作的 3D 公路摩托竞速与近战格斗游戏。当前版本 v0.5，已支持手机 / 平板触控。

**[直接在浏览器游玩](https://vorojar.github.io/redline-road-rash/)** · **[源码仓库](https://github.com/vorojar/redline-road-rash)**

## 怎么玩

同一个地址会自动识别设备：手机和 iPad 使用横屏触控，电脑使用键盘。进入网页后点击「进入游戏 · 开启声音」，等待资源载入，再选择赛事。浏览器需要支持 WebGL 2 和 WebAssembly；首次载入资源较大，后续可使用浏览器缓存。

| 操作 | 按键 |
| --- | --- |
| 油门 / 刹车 / 转向 | WASD 或方向键 |
| 拳击 / 踢击 / 持械攻击 | J / K / L |
| 格挡 / 闪避 / 夺械 | U / I / O |
| 蓄力冲刺 | 按住 Shift，蓄满松开 |
| 定速 / 暂停 | Space / Esc |

进度保存在当前浏览器中；清除网站数据会删除该浏览器的存档。在「驾驶设置 → 操作」可手动切换自动识别、触屏、键盘 / 手柄；触屏支持左右手布局。

触屏按钮采用圆形图标：摇杆转向、拳头攻击、圆盘刹车、盾牌格挡、闪电蓄力、双竖线暂停。触屏默认自动油门。滑动转向区控制方向，按住刹车减速，松开后继续加速；右手点击攻击、按住格挡或蓄力，蓄满后松手冲刺。攻击随当前武器自动变化；近身对手蓄力或硬直时会出现夺械按钮。切后台或旋转到竖屏会暂停，回到横屏后点击继续。

## 当前内容

- 三款不同外形和性能的摩托，以及可旋转、缩放的 3D 车库。
- 松岭公路、海岸断崖两条赛道，包含连续左右弯和起伏；车头默认随道路弯曲，左右输入用于变道和贴近对手，松手后自动回正并沿当前车道行驶；高速过弯只减速、不自动扣稳定值。短暂压路肩不直接摔车，碰撞和受击仍会失衡。
- 转向采用柔和的小幅响应、高速抑制和渐进起转；松手快速收回变道角度，减少持续横移。
- 5 名对手、车流和警方追击；AI 使用各自车型、冲刺和弯道速度规则。玩家领先时加速追赶、落后时减速等待，追赶仍受弯道与车流限制。附近最多两人主动挑战玩家，其余彼此交战；AI 互殴包含伤害、格挡、闪避和击倒。并排交手可被冲刺或车流打断。
- 最近对手体力与出手预警；较低、较近的跟车镜头和不同颜色的骑手，方便辨认近身攻防。
- 拳脚、木棒、钢管、格挡、闪避和夺械；物理摔车与起身扶车。
- 随速度伏低的骑姿、IK 肘膝、分阶段挥击与受击反馈。
- 真实摩托录音、摇滚配乐和分层 Foley，可单独调整音乐音量。

人物和动画为风格化原创实现，仍有写实度和手感上的迭代空间。网页采用单线程 Compatibility/WebGL 2 导出，性能与原生版本有差异。

## 本地开发与导出

需要 **Godot 4.7.2** 标准版。用编辑器打开 `project.godot`，运行主场景 `game/main.tscn`。命令行可将 `godot` 加入 PATH，或将 macOS Godot 放在 `.tools/Godot.app`。

```bash
./scripts/verify.sh           # 规则检查与两条赛道整场回归
./scripts/export_web.sh       # 导出到 outputs/web
./scripts/export_windows.sh   # Windows x64 ZIP
./scripts/export_macos.sh     # macOS ZIP
```

导出预设使用 `.tools/export_templates/` 下对应的官方 Godot 4.7.2 模板：

- Web：`web_nothreads_release.zip`、`web_nothreads_debug.zip`
- Windows：`windows_release_x86_64.exe`、`windows_debug_x86_64.exe`
- macOS：`macos.zip`

从 [Godot 官方发行页](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable)下载 export templates，将 `.tpz` 作为 ZIP 解压，复制相应文件。引擎、模板和构建产物不提交到主分支。

本地预览网页：

```bash
python3 -m http.server 5033 --directory outputs/web
# 浏览器访问 http://localhost:5033/
```

网页发布文件保存在 `gh-pages` 分支，由 GitHub Pages 提供 HTTPS。`main` 分支保存源代码和资源。

## 项目结构

| 路径 | 内容 |
| --- | --- |
| `game/race.gd` | 比赛、摄像机、攻击流程与结算 |
| `game/bike_state.gd` | 驾驶、抓地、伤害状态 |
| `game/vehicles/` | 模型、骨骼姿态、物理摔车与恢复 |
| `game/systems/` | AI、车流、格斗、声音、输入与生涯 |
| `game/world/` | 道路 spline、地形和景物 |
| `data/` | 车型、难度、赛事与赛道配置 |
| `assets/models/source/` | 可编辑 Blender 源文件 |
| `web/` | 网页入口、加载状态和授权页 |
| `tests/` | 隔离存档的规则和整场回归 |

Blender 模型可由 `scripts/build_models.py`、`build_bike_variants.py`、`build_traffic.py` 重建。音频脚本 `scripts/build_audio.py` 需要 numpy 和 ffmpeg，原始音乐文件可从授权页下载；日常运行无需重新生成资源。

## 素材与授权

完整说明见 [assets/licenses/ASSETS.md](assets/licenses/ASSETS.md) 和 [AUDIO.md](assets/licenses/AUDIO.md)。

- 音乐：Umplix — Super Wreck Roadway（CC0）。
- 摩托录音及其循环剪辑：dklon（CC-BY-SA 3.0）；这些改编音频保持同一许可证。
- 地面纹理：ambientCG（CC0）。
- Noto Sans SC：SIL OFL 1.1。
- Godot Engine：MIT。
- 图标与树木图像由 AI 生成；车辆、车手、程序动画与其余 Foley 为本项目制作。

本项目与 Electronic Arts 或 Road Rash 官方无关联。

### Web 资源精简

Web 仅导出运行时需要的资源；模型、使用中的贴图、音频及渲染设置保持不变。完整 Noto Sans SC 字体保留在源码里，网页使用按当前代码和数据文字生成的 Redline UI 子集。

`export_web.sh` 使用 `uv run scripts/build_web_font.py` 重建字体，需安装 [uv](https://docs.astral.sh/uv/)；fontTools 版本由脚本固定。构建会检查字符覆盖及现有字形轮廓和字宽。新增动态加载的资产时，也需加入 Web 导出预设的资源列表。
