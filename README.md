# REDLINE · 公路狂徒

Godot 4 制作的 3D 公路摩托竞速与近战格斗游戏。当前版本 v0.5，已支持手机 / 平板触控。

**[直接在浏览器游玩](https://vorojar.github.io/redline-road-rash/)** · **[源码仓库](https://github.com/vorojar/redline-road-rash)**

- 地图首次切换分帧加载并显示进度；本次游戏已加载的地图直接复用，缓存地图移出场景树，避免旧地图碰撞干扰。

## 怎么玩

同一个地址会自动识别设备：手机和 iPad 使用横屏触控，电脑使用键盘。进入网页后点击「进入游戏 · 开启声音」，等待资源载入，再选择赛事。浏览器需要支持 WebGL 2 和 WebAssembly；首次载入资源较大，后续可使用浏览器缓存。

| 操作 | 按键 |
| --- | --- |
| 油门 / 刹车 / 转向 | WASD 或方向键 |
| 自动攻击 / 伺机夺械 | 鼠标左键 |
| 拳击 / 踢击 / 持械攻击 | J / K / L |
| 格挡 / 闪避 / 夺械 | U / I / O |
| 蓄力冲刺 | 按住 Shift，蓄满松开 |
| 定速 / 暂停 | Space / Esc |

电脑左键点击游戏画面：有武器就挥击；空手时，近身对手露出夺械破绽就抢武器，否则交替拳击、踢击。每次点击出手一次，受正常冷却限制。

进度保存在当前浏览器中；清除网站数据会删除该浏览器的存档。在「驾驶设置 → 操作」可手动切换自动识别、触屏、键盘 / 手柄；触屏支持左右手布局。

触屏按钮采用圆形图标：摇杆转向、拳头攻击、圆盘刹车、盾牌格挡、闪电蓄力、双竖线暂停。触屏默认自动油门。滑动转向区控制方向，按住刹车减速，松开后继续加速；右手点击攻击、按住格挡或蓄力，蓄满后松手冲刺。攻击随当前武器自动变化；近身对手蓄力或硬直时会出现夺械按钮。切后台或旋转到竖屏会暂停，回到横屏后点击继续。

在「驾驶设置 → 画质」切换流畅、均衡、精细，设置自动保存。默认均衡使用原生 3D 分辨率、2× 抗锯齿和近景阴影；精细使用 4× 抗锯齿；流畅降低分辨率并关闭抗锯齿、实时阴影，供较慢设备使用。

## 当前内容

- 三款不同外形和性能的摩托，以及可旋转、缩放的 3D 车库。赛车服与车身采用原创 UV 贴图、法线和粗糙度；骑手使用带封闭镜片的成熟全盔素材，六种花纹分别配合骑手服装颜色，涂装换色保留白色标识，车损与车库共用漆面材质。
- 松岭公路（3 km）、海岸断崖（3.6 km）和跨郡耐力赛（12 km）三条赛道，包含连续左右弯和起伏；弯道需要主动按对应方向，持续按住时限制转向幅度，松手不再自动随弯；直道左右输入柔和变道并在松手后回正；高速过弯只减速、不自动扣稳定值。短暂压路肩不直接摔车，碰撞和受击仍会失衡。
- 摩托与汽车、摩托之间具备实体阻挡，免伤不允许穿车；追尾减速并产生前倾回弹，重撞可摔车。比赛中的浮动通知、快捷键说明和摔车文字已移除，保留仪表与教学。
- 转向采用柔和的小幅响应、高速抑制和渐进起转；松手快速收回变道角度，减少持续横移。
- 5 名对手、车流和警方追击；AI 使用各自车型、冲刺和弯道速度规则。玩家领先时加速追赶、落后时减速等待，追赶仍受弯道与车流限制。附近最多两人主动挑战玩家，其余彼此交战；AI 互殴包含伤害、格挡、闪避和击倒。并排交手可被冲刺或车流打断。
- 最近对手体力与出手预警；较低、较近的跟车镜头和不同颜色的骑手，方便辨认近身攻防。
- 拳脚、木棒、钢管、格挡、闪避和夺械；拳击短促、踢击推开、棍击重硬直，配合分级音效、停顿和定向受击动作。物理摔车与起身扶车。
- AXEL 记仇追击、NOVA 打完就撤、ROOK 踢向车流、JINX 持械强攻、VIPER 伺机夺械；重伤对手会短暂退避再参战，不会因此回血。对手栏显示当前战术。
- 随速度伏低的骑姿、IK 肘膝、分阶段挥击与受击反馈。
- 跨郡耐力赛在海岸进入前三后解锁，九阶段覆盖山脊、货运走廊、跨谷高架、警方追截和终点争夺；两处维修站靠右停车 2 秒可各补充一次体力与车况。
- 交通车辆先打灯再平滑变道，遇到玩家或前车会让行、刹车；高热度出现侧翼增援，耐力赛封锁一侧时始终保留另一侧通路。
- 挥棒固定右手握持、左手扶把，左右分别使用正手/反手，肩部随动作转动，AI 蓄力到命中连续。车损产生漆面划痕和凹痕、重损冒烟并适度降低动力；重新比赛恢复车辆。
- 三车分别采用运动双缸、巡航 V 双缸、高转四缸声浪；授权实录纹理与排气脉冲分层制作，怠速、加速、收油平滑切换，高转收油有受间隔限制的回火。摇滚配乐可单独调音量。
- 冲线先减速过渡，再揭晓名次和奖金；冠军举手庆祝、展示缓慢旋转、带金属反射和铭牌的 3D 金色奖杯并播放短庆祝音效，之后开放再赛按钮。

人物以 MakeHuman CC0 成熟人体拓扑为基础，适配赛车服、头盔和游戏骨骼；程序动画为项目实现，仍有写实度和手感上的迭代空间。网页采用单线程 Compatibility/WebGL 2 导出，性能与原生版本有差异。

## 本地开发与导出

需要 **Godot 4.7.2** 标准版。用编辑器打开 `project.godot`，运行主场景 `game/main.tscn`。命令行可将 `godot` 加入 PATH，或将 macOS Godot 放在 `.tools/Godot.app`。

```bash
./scripts/verify.sh           # 规则检查与三条赛道整场回归
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

网页首页使用原创封面图，加载进度直接显示在开始按钮内。`scripts/finalize_web.py` 为游戏包、引擎及封面生成内容指纹；`web/cache-worker.js` 只持久缓存这些不可变资源，首页 HTML 保持联网更新。刷新后相同版本从本地缓存读取，更新游戏包不会重新下载未变的引擎；资源缓存保留每类最近两版，不操作生涯存档。缓存不可用或被浏览器清理时会重新下载，仍可正常启动。

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

先用 `python3 scripts/build_surface_maps.py`（需要 Pillow）生成原创车辆 / 赛车服贴图。RATCHET 使用 Silas6 的 CC-BY 4.0 街车模型，由 `scripts/import_street_bike.py` 从保留的源 GLB 重建；前后轮独立滚动和悬挂、贴图最高 1K，骑姿按实际握把适配。其他 Blender 模型可由 `scripts/build_models.py`、`build_bike_variants.py`、`build_traffic.py` 重建；`scripts/build_rider.py` 从 MakeHuman 人体和 djengala 全盔（CC BY 4.0）源素材单独重建骑手。贴图、GLB 与 `.blend` 均已入库，日常运行不需要 Blender。音频脚本 `scripts/build_audio.py` 需要 numpy 和 ffmpeg，原始音乐文件可从授权页下载；日常运行无需重新生成资源。

道路与地面使用共享的宏观颜色/磨损材质，远景贴图启用 mipmaps；180 米外使用渐进深度雾，在手机远裁剪前隐藏远处场景边界。植被采用近景交叉面、远景 billboard 和分区 MultiMesh；手机减少近景层次及电缆。轿车与独立箱式货车由 `scripts/build_traffic.py` 重建；不透明深色车窗与上沿遮阳带遮住简化车厢，后视镜使用独立镜面，车漆与灯具分别处理。骑手软领口与长手套袖口沿用身体蒙皮，遮住装备接缝。护栏、反光柱、碎石灌木与电线杆由 `game/world/roadside_details.gd` 按赛道生成。

## 素材与授权

完整说明见 [assets/licenses/ASSETS.md](assets/licenses/ASSETS.md) 和 [AUDIO.md](assets/licenses/AUDIO.md)。

- 音乐：Umplix — Super Wreck Roadway（CC0）。
- 摩托录音及其循环剪辑：dklon（CC-BY-SA 3.0）；这些改编音频保持同一许可证。
- 地面纹理：ambientCG（CC0）。
- Noto Sans SC：SIL OFL 1.1。
- Godot Engine：MIT。
- RATCHET 摩托模型及基础贴图：Silas6 — Motorcycle（CC BY 4.0），经尺寸、轮组、贴图分辨率及运行材质适配。
- 图标与树木图像由 AI 生成；人体基础网格和蒙皮权重来自 MakeHuman（CC0）；全盔来自 djengala（CC BY 4.0）；其余车辆、其余车手装备与原创涂装、程序动画及其余 Foley 为本项目制作。

本项目与 Electronic Arts 或 Road Rash 官方无关联。

### Web 资源精简

Web 仅导出运行时需要的资源；模型、使用中的贴图、音频及渲染设置保持不变。完整 Noto Sans SC 字体保留在源码里，网页使用按当前代码和数据文字生成的 Redline UI 子集。

`export_web.sh` 使用 `uv run scripts/build_web_font.py` 重建字体，需安装 [uv](https://docs.astral.sh/uv/)；fontTools 版本由脚本固定。构建会检查字符覆盖及现有字形轮廓和字宽。新增动态加载的资产时，也需加入 Web 导出预设的资源列表。
