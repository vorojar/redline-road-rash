#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = ["numpy==2.3.3"]
# ///
"""Build phase-continuous exhaust banks from firing pulses + licensed field texture.
Edited field texture: dklon, CC-BY-SA 3.0. See assets/licenses/AUDIO.md.
The bank config is shared by this renderer and the in-game engine controller.
"""
import io
import json
import math
import subprocess
import wave
import zipfile
from pathlib import Path
import numpy as np
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/audio/engines"
SR = 44100
BANK = json.loads((ROOT / "data/engine_voices.json").read_text())
rng = np.random.default_rng(916)

def filter_audio(x, low, high):
    f = np.fft.rfftfreq(len(x), 1/SR)
    filt = (1 - np.exp(-(f/max(1,low))**4)) / (1 + (f/high)**6)
    return np.fft.irfft(np.fft.rfft(x) * filt, n=len(x))

def write(name, x, loop=False):
    x = x - x.mean()
    x = np.tanh(x * 1.2)
    x *= .78 / max(.001, np.max(np.abs(x)))
    if not loop:
        count = min(440, len(x)//10)
        x[:count] *= np.linspace(0,1,count)
        x[-count:] *= np.linspace(1,0,count)
    with wave.open(str(OUT / (name+".wav")), "wb") as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(SR)
        f.writeframes((x*32767).astype("<i2").tobytes())
    return {"seconds":round(len(x)/SR,3), "peak":float(np.max(np.abs(x))), "rms":float(np.sqrt(np.mean(x*x))), "seam_step":float(abs(x[-1]-x[0]))}

def texture(z, config):
    raw = subprocess.run(["ffmpeg","-v","error","-i","pipe:0","-f","s16le","-ar",str(SR),"-ac","1","pipe:1"], input=z.read(config["recording"]), stdout=subprocess.PIPE, check=True).stdout
    recording = np.frombuffer(raw, dtype="<i2").astype(float)/32768
    start = int(config["texture_start"]*SR)
    if len(recording)<start+SR: raise ValueError("Not enough source audio: "+config["recording"])
    excerpt = recording[start:min(start+3*SR,len(recording))].copy()
    n = int(.15*SR)
    fade = np.linspace(0,1,n)
    excerpt[:n] = excerpt[:n]*fade + excerpt[-n:]*(1-fade)
    excerpt = filter_audio(excerpt[:-n], 650, 4800)
    return excerpt / max(.001,np.std(excerpt))

def exhaust(config, rpm, load, field):
    # Whole combustion cycles close the loop without a rev ramp resetting each repeat.
    cycles = round(rpm/120*3)
    n = round(cycles*120/rpm*SR)
    impulses = np.zeros(n)
    for cycle in range(cycles):
        for cylinder, offset in enumerate(config["firing"]):
            position = round((cycle+offset)*n/cycles)%n
            impulses[position] += (1 if cylinder%2==0 else .88)*(1+rng.uniform(-.035,.035))
    t = np.arange(n)/SR
    body = config["body_hz"]*(1+.20*load)
    ring = (np.sin(math.tau*body*t)*.72 + np.sin(math.tau*body*2.1*t)*.22)*np.exp(-t*(65+30*load))
    crack = filter_audio(rng.normal(0,1,n),350,1600+config["brightness"]*2200)*np.exp(-t*270)*(.12+.22*load)
    kernel = ring+crack
    pulse = np.fft.irfft(np.fft.rfft(impulses)*np.fft.rfft(kernel),n=n)
    pulse /= max(.001,np.std(pulse))
    # Retain real engine mechanical detail beneath the explicit exhaust firing rhythm.
    src = np.interp(np.arange(n)*len(field)/n,np.arange(len(field)),field,period=len(field))
    x = pulse*(.35+.15*load)+src*(.035+.025*load)
    return filter_audio(x,35,2400+config["brightness"]*3000)

OUT.mkdir(parents=True,exist_ok=True)
report={}
with zipfile.ZipFile(ROOT/"assets/audio/source/dklon-engines.zip") as z:
    for name,config in BANK.items():
        field=texture(z,config)
        layers={}
        for layer,rpm,load in [("idle",config["idle_rpm"],.1),("low",config["redline"]*.35,.55),("high",config["redline"]*.72,1),("coast",config["redline"]*.5,.12)]:
            layers[layer]=exhaust(config,rpm,load,field)
            report[name+"_"+layer]=write(name+"_"+layer,layers[layer],True)
        t=np.arange(int(SR*.7))/SR
        noise=filter_audio(rng.normal(0,1,len(t)),55,1800)
        pop=(np.sin(math.tau*config["body_hz"]*.7*t)*.8+noise*.3)*np.exp(-t*22)
        # A soft delayed tail gives exhaust body rather than a gunshot-like click.
        delay=int(.065*SR); pop[delay:]+=pop[:-delay]*.28
        report[name+"_pop"]=write(name+"_pop",pop)
        t=np.arange(int(SR*1.25))/SR
        starter=filter_audio(rng.normal(0,1,len(t)),100,1200)*(.6+.4*np.sin(math.tau*12*t))*np.exp(-t*7)*.3
        idle=np.resize(layers["idle"],len(t))
        report[name+"_start"]=write(name+"_start",starter+idle*np.clip((t-.16)/.25,0,1)*np.clip((1.25-t)/.35,0,1))
# Original short podium fanfare: a warm rising triad, no external music excerpts.
t=np.arange(int(SR*2.7))/SR
fanfare=np.zeros(len(t))
for start,freq,duration,gain in [(0,293.66,.35,.28),(.22,369.99,.35,.28),(.44,440,.4,.3),(.70,587.33,1.7,.3),(.70,369.99,1.7,.16),(.70,440,1.7,.16)]:
    age=np.maximum(0,t-start)
    env=np.minimum(age/.035,1)*np.exp(-age*2.1)*(t>=start)*(age<duration)
    fanfare+=gain*env*(np.sin(math.tau*freq*age)+.3*np.sin(math.tau*freq*2*age)+.12*np.sin(math.tau*freq*3*age))
report["victory"]=write("victory",fanfare)
(ROOT/"work/engine-audio-report.json").write_text(json.dumps(report,indent=2))
print("Engine bank:",len(report),"mono WAV files; max peak",max(x["peak"] for x in report.values()))
