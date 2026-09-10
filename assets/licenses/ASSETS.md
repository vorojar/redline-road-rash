# Asset provenance

- `models/motorcycle.glb`, `models/sedan.glb`: Original geometry authored for this project by `scripts/build_models.py` and `scripts/build_traffic.py` using Blender 4.4.3. Editable sources in `models/source`; no original Road Rash assets used.
- `textures/roadside_pine.png`: Generated with the built-in imagegen tool on 2026-09-06. Prompt: “Photorealistic natural vegetation billboard, one isolated mature California roadside pine tree, full tree from roots to top, centered on transparent background, 1024x1536, irregular dark olive needles, textured brown trunk, realistic silhouette gaps, overcast neutral light, no text or ground.”
- `textures/asphalt/Asphalt010_*`: ambientCG Asphalt 010, CC0 1.0. Source: https://ambientcg.com/view?id=Asphalt010 ; download: https://ambientcg.com/get?file=Asphalt010_1K-JPG.zip
- `textures/ground/Ground037_*`: ambientCG Ground 037, CC0 1.0. Source: https://ambientcg.com/view?id=Ground037 ; download: https://ambientcg.com/get?file=Ground037_1K-JPG.zip
- ambientCG license: https://docs.ambientcg.com/license/ ; CC0 legal text: https://creativecommons.org/publicdomain/zero/1.0/
- Audio: dklon motorcycle field recordings and derived loops (CC-BY-SA 3.0), Umplix “Super Wreck Roadway” music (CC0), plus original layered Foley. Full source links, modifications and licenses: `AUDIO.md`.
- macOS keyboard UI uses system fonts. Windows and touch UI bundle Noto Sans SC under SIL OFL 1.1; the Web build uses a glyph subset described below.
- Godot Engine: MIT license, https://godotengine.org/license/ . The local runtime and export template are from the official Godot GitHub release 4.7.2-stable.

REDLINE is a working local project name. No affiliation with Electronic Arts or Road Rash is claimed. The project is published on GitHub Pages. Third-party store listings, code-signing with a distribution identity and notarization have not been performed.


v0.3：衣袖/裤腿轮廓、衣物缝线、手套/靴子/头盔条纹、车身线缆及贴花几何由本项目 Blender 脚本生成。程序化皮革/牛仔布表面 shader 和物理关节实现为本项目原创代码。


v0.4：REVENANT 与 PHANTOM 的长轴车架、肌肉车附件、全包围整流罩和风挡，由本项目 `scripts/build_bike_variants.py` 基于原创 motorcycle.blend 制作；车库展台与灯光为原创程序化场景。


v0.4.1 应用图标由内置 imagegen 为 REDLINE 原创生成：深色圆角方形底、红色机车头盔、象牙色公路线条，无文字或第三方标志。源图 `assets/branding/redline-source.png`，应用 PNG 和多尺寸 macOS ICNS 由系统 sips/iconutil 转换。

Windows 中文字体：Google Fonts / Noto Sans SC，SIL Open Font License 1.1，许可证附 `NotoSansSC-OFL.txt`。原始字体：https://github.com/google/fonts/tree/main/ofl/notosanssc 。未修改字形；粗体通过运行时 FontVariation 显示。


Web 字体：`fonts/RedlineUI.ttf` 为 Noto Sans SC 的字形子集，由 `scripts/build_web_font.py` 生成，字体族名改为 Redline UI。保留现有字形轮廓、hinting、可变字重及排版特性；SIL OFL 1.1 许可证仍附 `NotoSansSC-OFL.txt`。完整原字体保留在源码中。

触控图标：Lucide，ISC license；`ui/*.svg` 来自 https://github.com/lucide-icons/lucide/tree/94e4cb9d9db5907053ebf3636a97c45529cf776b/icons 。使用 hand-fist、shield、zap、pause、disc-3、hand-grab、move-horizontal；仅将固有尺寸设为 96px、描边设为白色供运行时着色。许可证附 `LUCIDE_LICENSE.txt`。


骑手 / 车辆表面贴图：`textures/vehicles/*` 的 albedo、OpenGL normal 和 roughness 由 `scripts/build_surface_maps.py`（Pillow）原创绘制，使用项目自有 REDLINE / ROAD DIVISION 图案及号码。albedo alpha 为队伍换色遮罩，运行材质保持不透明。贴图内字形使用上述 SIL OFL Noto Sans SC；未使用参考照片、第三方车队涂装或游戏贴图。模型 UV 及车身曲面由 Blender 脚本制作；赛车服基于下述成熟人体网格适配，纹理嵌入 GLB。


人体基础网格、成年体型形变及蒙皮权重：MakeHuman Community 核心资产，CC0 1.0。固定来源提交 `a8bc2d54ff0ac92e78ff71431b1023eda42bf482`，原始资产保存在 `models/source/makehuman/`，未引入 MakeHuman 应用程序代码。`scripts/build_human_body.py` 应用成年体型、保留连续人体拓扑，将权重映射到游戏骨骼，调整手指握姿并生成赛车服表面；护靴为本项目几何，头盔采用下述 djengala 素材。资产来源：https://github.com/makehumancommunity/makehuman/tree/a8bc2d54ff0ac92e78ff71431b1023eda42bf482/makehuman/data 。授权说明：https://static.makehumancommunity.org/about/license.html 。CC0 全文附 `MAKEHUMAN_CC0.txt`。


网页首页封面：使用内置 imagegen 生成的原创公路摩托竞速主题图。原始 PNG 保存在 `branding/source/title-road.png`，网页 WebP 为 `web/title-road.webp`，生成提示词保存在 `branding/source/title-road-prompt.txt`。这是首页宣传插画，不是游戏运行截图。


RATCHET 街车：`models/ratchet.glb` 改编自 [Motorcycle](https://sketchfab.com/3d-models/motorcycle-693e83d86e1e4e5b95e4314dbdd95d40)，作者 [Silas6](https://sketchfab.com/Silas6)，[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)。2026-09-08 从 Sketchfab 官方免费下载原始 GLB，保存在 `models/source/silas6/motorcycle.glb`。修改包括轴距/尺寸适配、保持圆形轮胎的轮组拆分、贴图降至最高 1K、握把接触位置，以及运行时车漆换色和车损。原始几何和贴图归属 Silas6；不暗示作者为本项目背书。可用 `scripts/import_street_bike.py` 从保留的源 GLB 重建。许可证全文附 `CC-BY-4.0.txt`。

骑手全盔：改编自 [motorcycle HELMET](https://sketchfab.com/3d-models/motorcycle-helmet-1d489db9cdc24161a7537926a20bb17b)，作者 [djengala](https://sketchfab.com/djengala)，[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)。原始 GLB 保存在 `models/source/djengala/helmet.glb`；`scripts/build_rider.py` 调整尺寸和朝向、绑定头部骨骼、适配外壳 PBR 并将透明镜片改为不透明烟蓝镜面。运行时颜色跟随赛车服，另加入五种程序条纹/棋盘涂装；原始外壳、内衬和源涂装归属作者；不暗示作者背书。许可证全文附 `CC-BY-4.0.txt`。


赛车服广告贴标：`textures/sponsors/brand-sheet.png` 为用户提供的品牌参考图，运行时按原图区域显示 MOTUL、SHOEI、NGK、brembo 和 Red Bull 标识，未重绘这些标识。第三方商标及图形权利归各自权利人，不属于项目原创或 CC0 素材；游戏内装饰不表示实际赞助或背书。`textures/sponsors/ehafo.png` 为根据用户指定文字 EHAFO 通过 imagegen 生成的主标。贴标共用原赛车服 UV 和蒙皮，不改变基础模型或动画。

科技品牌高速广告：`textures/sponsors/{nvidia,microsoft,apple,amazon,anthropic,gemini,tesla}.png` 为根据用户指定品牌通过内置 imagegen 生成的游戏装饰画面，生成提示词保存在 `textures/sponsors/tech-billboards-prompts.md`。品牌名称与标识权利归各自权利人，不属于项目原创商标或 CC0 素材；游戏内出现不表示实际赞助或背书。
