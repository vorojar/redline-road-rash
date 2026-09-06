"""Render layered Foley and edit licensed field recordings; requires numpy and ffmpeg.
Music: Umplix, CC0. Engine recordings/edited loops: dklon, CC-BY-SA 3.0.
Full source links and modification details: assets/licenses/AUDIO.md.
"""
import io, math, subprocess, wave, zipfile
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parent.parent
OUT=ROOT/'assets/audio'; SR=44100; rng=np.random.default_rng(28)
def save(name,x,loop=False):
 x=np.asarray(x); x=x-np.mean(x,axis=0)
 if not loop:
  n=min(220,len(x)//10); x[:n]*=np.linspace(0,1,n);x[-n:]*=np.linspace(1,0,n)
 x=np.tanh(x*1.1); x=x/max(.001,np.max(np.abs(x)))*.85
 with wave.open(str(OUT/(name+'.wav')),'wb') as w:
  w.setnchannels(1);w.setsampwidth(2);w.setframerate(SR);w.writeframes((x*32767).astype('<i2').tobytes())
def noise(n,low=70,high=5500):
 x=rng.normal(0,1,n);f=np.fft.rfftfreq(n,1/SR)
 filt=(1-np.exp(-(f/low)**4))/(1+(f/high)**4)
 y=np.fft.irfft(np.fft.rfft(x)*filt,n=n);return y/max(.01,np.std(y))
def tone(t,f):return np.sin(math.tau*f*t)
def loop_cut(a,start,end):
 x=a[int(start*SR):int(end*SR)].copy();n=int(.13*SR)
 # Overlap-add the tail into the head; every loop crosses the same smooth seam.
 fade=np.linspace(0,1,n); x[:n]=x[:n]*fade+x[-n:]*(1-fade)
 return x[:-n]
with zipfile.ZipFile(OUT/'source/dklon-engines.zip') as z:
 raw=subprocess.run(['ffmpeg','-v','error','-i','pipe:0','-af','highpass=f=48,lowpass=f=6500','-f','s16le','-ar',str(SR),'-ac','1','pipe:1'],input=z.read('090912-004.mp3'),stdout=subprocess.PIPE,check=True).stdout
 a=np.frombuffer(raw,dtype='<i2').astype(float)/32768
save('engine_idle',loop_cut(a,24,27),True)
save('engine',loop_cut(a,12.5,14.6),True)
for name,duration,low,high in [('wind',4,90,2100),('tire',4,280,2900)]:
 n=int(SR*duration);t=np.arange(n)/SR;x=noise(n,low,high)
 x*=.75+.12*tone(t,2)+.08*tone(t,5)
 save(name,x*.3,True)
t=np.arange(SR*2)/SR
save('siren',.5*np.sin(math.tau*650*t-130*np.cos(math.pi*t))+.13*np.sin(math.tau*1300*t-260*np.cos(math.pi*t)),True)
for variant in range(3):
 t=np.arange(int(SR*.48))/SR;n=len(t)
 body=(tone(t,80+variant*9)*.7+tone(t,153+variant*11)*.25)*np.exp(-t*20)
 cloth=noise(n,200,2200)*np.exp(-t*36)*.3
 crack=noise(n,900,7000)*np.exp(-t*110)*.6
 save('hit_'+str(variant),body+cloth+crack)
 wood=sum(tone(t,f)*np.exp(-t*(18+i*6))/(i+1) for i,f in enumerate([340+variant*21,735,1231,2207]))
 save('wood_'+str(variant),body*.8+wood*.5+crack*.8)
 metal=sum(tone(t,f)*np.exp(-t*(7+i*5))/(i+1) for i,f in enumerate([431+variant*33,1139,1967,3101]))
 save('metal_'+str(variant),body*.9+metal*.45+crack)
t=np.arange(int(SR*1.5))/SR;n=len(t)
crash=noise(n,35,3200)*np.exp(-t*4)*.5+tone(t,49)*np.exp(-t*12)*.7
for delay in [.045,.10,.19,.31,.47,.66]:
 age=np.maximum(0,t-delay);crash+=noise(n,650,8000)*np.exp(-age*42)*(t>=delay)*.2
save('crash',crash)
t=np.arange(int(SR*.26))/SR
save('swing',noise(len(t),500,5200)*np.sin(np.linspace(0,math.pi,len(t)))**2)
t=np.arange(int(SR*.15))/SR
save('shift',noise(len(t),550,4000)*np.exp(-t*75)*.4+tone(t,180)*np.exp(-t*42)*.3)
save('menu',tone(t,530)*np.exp(-t*40)*.3+tone(t,1060)*np.exp(-t*60)*.12)
# Backward-compatible filename for existing callers/assets.
(OUT/'hit.wav').write_bytes((OUT/'hit_0.wav').read_bytes())
print('Audio: field-recorded engine loops, 9 varied impacts, swing/shift and layered Foley rendered.')
