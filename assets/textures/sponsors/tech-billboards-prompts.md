# 科技品牌高速广告画面

2026-09-10 使用内置 imagegen 分别生成七张画面，原图复制为同目录的 nvidia.png、microsoft.png、apple.png、amazon.png、anthropic.png、gemini.png、tesla.png。Godot 导入时限制为 1024 像素并生成 mipmaps，原 PNG 不裁切、不变形。

每张使用以下完整提示词，将 `{brand}` 和 `{style}` 替换为表中内容：

> Create one finished flat front-face highway advertising texture for {brand}, for a 3D racing game. Use case: ads-marketing. Wide landscape 12:5 aspect ratio, edge-to-edge print-ready flat artwork, no billboard frame, no pole, no environment, no perspective. {style}. Extremely legible oversized recognizable brand mark and exact brand name "{brand}", generous clean margins. Simple premium brand-led composition visible at high driving speed. Only brand name, no slogans, no fine print, no sponsor/partnership claims. Avoid mockup shadows, bevel, photography. Save the finished image.

| brand | style |
| --- | --- |
| NVIDIA | black and NVIDIA green; recognizable eye logo |
| Microsoft | white, four-color square Microsoft logo |
| Apple | black, white Apple bitten-apple logo |
| Amazon | dark navy, white amazon wordmark with orange smile arrow |
| Anthropic | warm ivory, black ANTHROPIC wordmark and simple monogram |
| Gemini | white, Google Gemini four-point blue purple sparkle and Gemini wordmark |
| Tesla | red, white Tesla T symbol and TESLA wordmark |
