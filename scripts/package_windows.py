"""Package only the Windows runtime, data and redistributable license notices."""
from pathlib import Path
import re, shutil, zipfile, hashlib
ROOT=Path(__file__).resolve().parent.parent
version=re.search(r'config/version="([^"]+)"',(ROOT/'project.godot').read_text()).group(1)
stage=ROOT/'outputs/windows';licenses=stage/'licenses';licenses.mkdir(exist_ok=True)
for source in (ROOT/'assets/licenses').iterdir():
 if source.suffix in ('.md','.txt'):shutil.copy2(source,licenses/source.name)
readme=f'''REDLINE · 公路狂徒 {version} — Windows x64

运行方法
1. 将 ZIP 完整解压到一个普通文件夹。
2. 双击 REDLINE.exe 开始游戏，无需安装 Godot。
3. REDLINE.exe 和 REDLINE.pck 必须放在同一目录，请勿只复制 exe。

目标环境：Windows 10/11，Intel/AMD 64 位处理器，支持 OpenGL 3.3 的显卡及驱动。
已内置 Noto Sans SC 中文字体和全部音乐/游戏素材。

操作
W / ↑：油门；S / ↓：刹车；A、D / ←、→：转向。
J 拳击；K 踢击；L 持械攻击；O 夺械；U 格挡；I 闪避。
Shift 按住蓄力，蓄满松开冲刺；Space 攻击；C 定速；Esc 暂停；Enter 开赛。
弯道前请收油或刹车，留意建议速度和路侧箭头。
设置中可分别调节总音量和音乐音量。

存档：%APPDATA%\\Godot\\app_userdata\\REDLINE • 公路狂徒\\career_v2.json
首次启动会建立独立 Windows 生涯，不包含开发者或 macOS 玩家的存档。

本包未经 Windows Authenticode 签名。
本次完成导出、PE 架构/图标/版本检查，以及 PCK 资源和中文字体加载检查；未进行 Windows 真机运行验证。
第三方音乐、引擎录音、字体和引擎授权详见 licenses 文件夹。
'''
(stage/'运行说明.txt').write_text(readme,encoding='utf-8-sig')
files=[stage/'REDLINE.exe',stage/'REDLINE.pck',stage/'运行说明.txt']+sorted(licenses.glob('*'))
for file in files:
 if not file.is_file() or file.stat().st_size==0:raise RuntimeError(f'Missing package input: {file}')
name=f'REDLINE-v{version.removesuffix(".0")}-Windows-x64'
output=ROOT/'outputs'/f'{name}.zip'
with zipfile.ZipFile(output,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
 for file in files:archive.write(file,Path(name)/file.relative_to(stage))
with zipfile.ZipFile(output) as archive:
 assert archive.testzip() is None
 assert len(archive.namelist())==len(files)
checksum=hashlib.sha256(output.read_bytes()).hexdigest()
output.with_suffix('.zip.sha256').write_text(f'{checksum}  {output.name}\n')
print(f'Windows package: {output} ({output.stat().st_size/1024/1024:.1f} MiB), ZIP CRC passed')
