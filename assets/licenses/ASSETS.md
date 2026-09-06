# Asset provenance

- `models/motorcycle.glb`, `models/rider.glb`, `models/sedan.glb`: Original geometry authored for this project by `scripts/build_models.py` and `scripts/build_traffic.py` using Blender 4.4.3. Editable sources in `models/source`; no original Road Rash assets used.
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
