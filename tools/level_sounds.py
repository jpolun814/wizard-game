"""Sets the loudness of every sound so they sit together (data/sound_levels.json, and Sfx.VOLUME for the voices).

    python tools/level_sounds.py            # lists the sounds that are more than 3 dB from their target
    python tools/level_sounds.py --apply    # and writes the new values into scripts/core/sfx.gd

A sound's level is the RMS of its loud parts (everything over a tenth of its peak) plus its VOLUME entry. Each kind has a target: footsteps -46 dB, jumps and hurts -30,
Ignite -32, creatures -26, interface and weather -32, quake, volcano and tornado -20, explosion -22, heartbeat -22 and everything else -24. A boost is limited so
that the file's peak stays under -1 dB. Calls that pass their own volume_db (Sfx.play(name, at, db)) are not counted. Numbers only: judge by ear after.
"""
import os,re,glob,sys,numpy as np,soundfile as sf
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
path="scripts/core/sfx.gd"
src=open(path,encoding="utf-8",newline="").read(); nl="\r\n" if "\r\n" in src else "\n"; src=src.replace("\r\n","\n")
import json
blk=src[src.index("const VOLUME"):src.index("const REGISTRY")]
LV="data/sound_levels.json"; levels=json.load(open(LV))
vol={k:float(v) for k,v in re.findall(r'"([a-z_0-9]+)": (-?[0-9.]+)',blk)}; vol.update(levels)
peaks=[]
def level(p):
    x,r=sf.read(p,always_2d=True); x=x.mean(axis=1)
    win=int(0.05*r); e=np.array([np.sqrt(np.mean(x[i:i+win]**2)) for i in range(0,max(1,len(x)-win),win)])
    act=e[e>e.max()*0.1]; peaks.append(20*np.log10(np.abs(x).max()+1e-9)); return 20*np.log10(np.sqrt(np.mean(act**2))+1e-9)
g={}; pk={}
for f in glob.glob("audio/*"):
    if f.endswith(".import"): continue
    b=re.sub(r"\.(wav|ogg|mp3)$","",os.path.basename(f)); k=re.sub(r"_\d+$","",b); g.setdefault(k,[]).append(level(f)); pk[k]=max(pk.get(k,-99),peaks[-1])
def target(k):
    if k.startswith("wizard__step"): return -46
    if k.startswith("wizard__land"): return -42
    owner,_,ev=k.partition("__")
    if ev in ("hurt","die","shoot","whoosh","rocks") and owner.startswith("mob_"): return -26
    if ev in ("click","page","book_open","book_close","rustle","wind"): return -32
    if ev in ("rumble","whirl"): return -20
    if ev=="explosion": return -22
    if k.startswith("step_"): return -46
    if k.startswith("jump_voice"): return -30
    if k.startswith("hurt_voice"): return -30  # as loud as a jump
    if k=="player_hurt": return -21
    if k=="cast_fire": return -32
    if k.startswith("mob_"): return -26
    if k in ("book_open","book_close","page","pickup","ui_click","snow"): return -32
    if k in ("quake","volcano","tornado"): return -20
    if k in ("explosion",): return -22
    if k=="heartbeat": return -22
    return -24
changes={}
for k,v in g.items():
    rms=float(np.mean(v)); cur=vol.get(k,0.0); eff=rms+cur; t=target(k)
    if abs(eff-t)>3.0:
        nv=min(round((t-rms)*2)/2, -1.0-pk[k]); changes[k]=(cur,nv)
        if nv<(t-rms)-0.5: print('  (peak-limited)',k,'effective',round(rms+nv,1),'target',t)
for k,(a,b) in sorted(changes.items()): print("%-16s %5.1f -> %5.1f"%(k,a,b))
if "--apply" in sys.argv:
    new=blk
    for k,(a,b) in changes.items():
        if k in levels or "__" in k: levels[k]=b
        elif re.search(r'"%s": -?[0-9.]+'%k,new): new=re.sub(r'"%s": -?[0-9.]+'%k,'"%s": %.1f'%(k,b),new)
        else: print("missing",k)
    json.dump(dict(sorted(levels.items())),open(LV,"w"),indent=1)
    src=src.replace(blk,new)
    open(path,"w",encoding="utf-8",newline="").write(src.replace("\n",nl))
