"""Turns a match log (MatchRecorder) into one web page that plays the world back as moving dots: wizards, their shots and what lies about.

    python -I tools/replay_match.py LOG [OUT.html]       (any one world's log of a match: the match's other worlds are found beside it and play on in the same page)

It is a map, not the game's picture: wizards are colored circles with a name, a stamina bar and their states, shots are small dots, a spell cast leaves a ring, a blow
flashes red, and a fallen wizard's mark stays. The person at the machine (the log's S lines) has a white ring and their screen drawn as a box. Space plays and pauses,
the slider moves through time, and the buttons set the speed. The ground is drawn from the log's TERR lines (matches recorded before they were written have none),
and a shot or a thing carries its name once the view is close enough to read it."""
import glob, html, json, os, sys

PAGE = r"""<!doctype html><meta charset=utf-8><meta name=viewport content="width=device-width,initial-scale=1">
<title>Match replay</title>
<style>
:root{--bg:#14121a;--fg:#e8e4f0;--mut:#8d87a0;--line:#2e2a3c}
@media (prefers-color-scheme:light){:root{--bg:#f4f2f8;--fg:#1d1a26;--mut:#6a647c;--line:#d6d1e2}}
body{margin:0;background:var(--bg);color:var(--fg);font:14px system-ui,sans-serif}
#bar{display:flex;gap:8px;align-items:center;flex-wrap:wrap;padding:8px 16px;border-bottom:1px solid var(--line)}
button{background:transparent;color:var(--fg);border:1px solid var(--line);border-radius:6px;padding:4px 10px;cursor:pointer}
button.on{border-color:var(--fg)}
#t{flex:1;min-width:160px}
canvas{display:block;width:100%;height:calc(100vh - 150px)}
#log{padding:6px 16px;color:var(--mut);height:60px;overflow:auto;font-size:12px}
</style>
<div id=bar><button id=play>Play</button><input id=t type=range min=0 value=0 step=0.05><span id=clock></span>
<span>speed</span><button data-s=1 class=on>1x</button><button data-s=2>2x</button><button data-s=5>5x</button><button data-s=10>10x</button>
<label><input type=checkbox id=follow checked> follow the person</label></div>
<canvas id=c></canvas><div id=log></div>
<script>
const D=__DATA__;
const cv=document.getElementById('c'),cx=cv.getContext('2d');
const COL=['#e6855e','#5eb0e6','#8ee65e','#e6d75e','#c05ee6','#5ee6c3','#e65e8f','#a0a0a0'];
const wz=D.wizards,ids=Object.keys(wz);
const TL=32;
let T=0,playing=false,speed=1,last=null,view={x:0,y:0,s:0.2};
const slider=document.getElementById('t');slider.max=D.end;
const clock=document.getElementById('clock');
function at(rows,t){ // rows sorted by time: [t,x,y,...]
  let lo=0,hi=rows.length-1;if(hi<0)return null;
  if(t<=rows[0][0])return rows[0];if(t>=rows[hi][0])return rows[hi];
  while(hi-lo>1){const m=(lo+hi)>>1;if(rows[m][0]<=t)lo=m;else hi=m}
  const a=rows[lo],b=rows[hi],k=(t-a[0])/(b[0]-a[0]||1);
  return [t,a[1]+(b[1]-a[1])*k,a[2]+(b[2]-a[2])*k,a[3],a[4],a[5],a[6]];
}
function resize(){cv.width=cv.clientWidth*devicePixelRatio;cv.height=cv.clientHeight*devicePixelRatio}
addEventListener('resize',resize);resize();
function draw(){
  const W=cv.width,H=cv.height,dpr=devicePixelRatio;cx.clearRect(0,0,W,H);
  const person=ids.find(i=>wz[i].kind==='person'&&vis(i));
  let fx=view.x,fy=view.y;
  if(document.getElementById('follow').checked&&person){const pid=ids.find(i=>wz[i].kind==='person'&&vis(i));const p=pid?at(wz[pid].rows,T):null;if(p){fx=p[1];fy=p[2]}}
  else{let sx=0,sy=0,n=0;for(const i of ids){const p=at(wz[i].rows,T);if(p&&vis(i)&&!dead(i)){sx+=p[1];sy+=p[2];n++}}if(n){fx=sx/n;fy=sy/n}}
  view.x=fx;view.y=fy;const S=view.s*dpr;
  const X=x=>(x-fx)*S+W/2,Y=y=>(y-fy)*S+H/2;
  const wd=D.worlds.find(w=>T>=w.t0&&T<=w.t1+0.01)||D.worlds[D.worlds.length-1];
  if(wd&&wd.rows.length){cx.fillStyle='#4a4137';const y0=Math.max(0,Math.floor((fy-H/S/2)/TL)),y1=Math.min(wd.h-1,Math.ceil((fy+H/S/2)/TL));
    for(const r of wd.rows){if(r[0]<y0||r[0]>y1)continue;for(const run of r[1]){const xa=run[0]*TL,xb=(run[1]+1)*TL;if(xb<fx-W/S/2||xa>fx+W/S/2)continue;cx.fillRect(X(xa),Y(r[0]*TL),(xb-xa)*S+1,TL*S+1)}}}
  cx.strokeStyle='rgba(128,128,150,.15)';cx.lineWidth=1;
  const g=500;for(let x=Math.floor((fx-W/S/2)/g)*g;x<fx+W/S/2;x+=g){cx.beginPath();cx.moveTo(X(x),0);cx.lineTo(X(x),H);cx.stroke()}
  for(let y=Math.floor((fy-H/S/2)/g)*g;y<fy+H/S/2;y+=g){cx.beginPath();cx.moveTo(0,Y(y));cx.lineTo(W,Y(y));cx.stroke()}
  for(const o of D.things){ if(o.t0<=T&&T<o.t1){ // lasting things and pages
      cx.fillStyle=o.shot?'#ffd36e':(o.cls==='PagePickup'?'#9ad0ff':'rgba(160,150,190,.55)');
      const p=o.rows?at(o.rows,T):[0,o.x,o.y];if(!p)continue;
      const r=o.shot?2.2*dpr:4*dpr;cx.fillRect(X(p[1])-r,Y(p[2])-r,2*r,2*r);if(view.s>0.12&&(o.shot||o.cls!=='PagePickup')){cx.fillStyle='rgba(200,195,215,.8)';cx.font=(9*dpr)+'px system-ui';cx.textAlign='left';cx.fillText(o.cls,X(p[1])+6*dpr,Y(p[2])-4*dpr)}}}
  for(const c of D.casts){const a=T-c.t;if(a>=0&&a<1){cx.strokeStyle=COL[c.k%8];cx.globalAlpha=1-a;cx.lineWidth=2*dpr;cx.beginPath();cx.arc(X(c.x),Y(c.y),(20+a*60)*S,0,7);cx.stroke();cx.fillStyle=COL[c.k%8];cx.font=(11*dpr)+'px system-ui';cx.textAlign='left';cx.fillText(c.s,X(c.x)+10*dpr,Y(c.y)-10*dpr-a*20*dpr);cx.globalAlpha=1}}
  for(const h of D.hits){const a=T-h.t;if(a>=0&&a<.6){cx.fillStyle='rgba(255,60,60,'+(0.7-a)+')';cx.beginPath();cx.arc(X(h.x),Y(h.y),(14+h.a)*S*1.2,0,7);cx.fill()}}
  for(const i of ids){const w=wz[i];if(T<w.t0||T>w.t1)continue;const p=at(w.rows,T);if(!p)continue;
    const d=dead(i);const x=X(p[1]),y=Y(p[2]-30),k=w.k;
    cx.globalAlpha=d?0.35:1;cx.fillStyle=COL[k%8];cx.beginPath();cx.arc(x,y,11*dpr,0,7);cx.fill();
    if(w.kind==='person'){cx.strokeStyle='#fff';cx.lineWidth=2*dpr;cx.beginPath();cx.arc(x,y,15*dpr,0,7);cx.stroke()}
    cx.fillStyle=getComputedStyle(document.body).color;cx.font=(11*dpr)+'px system-ui';cx.textAlign='center';
    cx.fillText(w.name+(d?' (fell)':''),x,y-20*dpr);
    if(!d){const f=Math.max(0,Math.min(1,p[5]/Math.max(1,p[6])));cx.fillStyle='rgba(128,128,128,.4)';cx.fillRect(x-14*dpr,y+16*dpr,28*dpr,4*dpr);cx.fillStyle='#6ec86e';cx.fillRect(x-14*dpr,y+16*dpr,28*dpr*f,4*dpr);
      const st=stateAt(i);if(st){cx.fillStyle='#d6a8ff';cx.fillText(st,x,y+32*dpr)}}
    cx.globalAlpha=1}
  if(person){const s=D.screen.length?at(D.screen,T):null;if(s&&Math.abs(s[0]-T)<1){const hw=640/s[3]*1.0,hh=360/s[3];cx.strokeStyle='rgba(255,255,255,.35)';cx.lineWidth=1;cx.strokeRect(X(s[1]-hw),Y(s[2]-hh),2*hw*S,2*hh*S)}}
  clock.textContent=(wd?wd.name+' '+(T-wd.t0).toFixed(0)+' s':'')+'   total '+T.toFixed(0)+' / '+D.end.toFixed(0)+' s';
  const lg=D.events.filter(e=>e.t<=T).slice(-4).map(e=>e.t.toFixed(1)+'s '+e.s).join('<br>');document.getElementById('log').innerHTML=lg;
}
function dead(i){const f=wz[i].fell;return f!==null&&T>=f}
function vis(i){return T>=wz[i].t0&&T<=wz[i].t1}
function stateAt(i){const a=wz[i].states;let s='';for(const e of a){if(e[0]<=T)s=e[1];else break}return s==='-'?'':s}
function frame(ts){if(playing){if(last!==null)T=Math.min(D.end,T+(ts-last)/1000*speed);last=ts;if(T>=D.end)playing=false;slider.value=T}else last=null;draw();requestAnimationFrame(frame)}
document.getElementById('play').onclick=function(){playing=!playing;this.textContent=playing?'Pause':'Play'};
addEventListener('keydown',e=>{if(e.code==='Space'){e.preventDefault();document.getElementById('play').click()}});
slider.oninput=()=>{T=+slider.value;draw()};
document.querySelectorAll('[data-s]').forEach(b=>b.onclick=()=>{speed=+b.dataset.s;document.querySelectorAll('[data-s]').forEach(x=>x.classList.toggle('on',x===b))});
cv.addEventListener('wheel',e=>{e.preventDefault();view.s=Math.max(0.03,Math.min(1.2,view.s*(e.deltaY<0?1.15:0.87)))},{passive:false});
requestAnimationFrame(frame);
</script>"""


def read_world(path, off, tag):
    """One world's file: everything in it, its times moved on by `off` seconds, its ids made apart from the other worlds' by `tag`."""
    head, end = "", 0.0
    wizards, things = {}, {}
    casts, hits, events, screen = [], [], [], []
    last_wz = {}
    terr = dict(w=0, h=0, rows=[])
    for line in open(path, encoding="utf-8", errors="ignore"):
        p = line.split()
        if len(p) < 2:
            continue
        try:
            t = float(p[0])
        except ValueError:
            continue
        end = max(end, t)
        k = p[1]
        T = round(t + off, 2)
        if k == "HEAD":
            head = " ".join(p[2:])
        elif k == "TERR" and len(p) >= 4:
            terr["w"], terr["h"] = int(p[2]), int(p[3])
        elif k == "TR" and len(p) >= 4:
            terr["rows"].append([int(p[2]), [[int(a) for a in r.split("-")] for r in p[3].split(",")]])
        elif k == "WZ" and len(p) >= 15:
            i = tag + p[2]
            w = wizards.setdefault(i, dict(name=p[3], kind=p[4], k=0, rows=[], fell=None, states=[]))
            if t - last_wz.get(i, -1.0) >= 0.09 and p[15] != "death":
                last_wz[i] = t
                w["rows"].append([T, int(float(p[6])), int(float(p[7])), p[8], p[9], float(p[12]), float(p[13])])
        elif k == "S" and len(p) >= 13:
            screen.append([T, float(p[11]), float(p[12]), float(p[13]) if len(p) > 13 else 1.0])
        elif k == "CAST" and len(p) >= 7 and tag + p[2] in wizards:
            w = wizards[tag + p[2]]
            casts.append(dict(t=T, x=int(float(p[5])), y=int(float(p[6])), id=tag + p[2], s=p[3].replace("_", " ")))
            events.append(dict(t=T, s="%s cast %s" % (w["name"], p[3].replace("_", " "))))
        elif k == "HIT" and len(p) >= 9:
            hits.append(dict(t=T, x=int(float(p[7])), y=int(float(p[8])) - 30, a=float(p[5])))
        elif k == "FALL" and len(p) >= 3 and tag + p[2] in wizards:
            wizards[tag + p[2]]["fell"] = T
            events.append(dict(t=T, s="%s fell" % wizards[tag + p[2]]["name"]))
        elif k == "ST" and len(p) >= 4 and tag + p[2] in wizards:
            text = ", ".join(x.split(":")[0] for x in p[3].split(",")) if p[3] != "-" else "-"
            wizards[tag + p[2]]["states"].append([T, text])
        elif k == "PAGE" and len(p) >= 5 and p[2].isdigit() and tag + p[2] in wizards:
            events.append(dict(t=T, s="%s read %s" % (wizards[tag + p[2]]["name"], p[3].replace("_", " "))))
        elif k in ("NEW", "OB") and len(p) >= 7:
            idn = tag + p[2]
            shot = (k == "NEW" and p[-1] == "shot")
            th = things.setdefault(idn, dict(cls=p[3], shot=False, rows=[], t0=T, t1=T + 0.5))
            th["shot"] = th["shot"] or shot or p[3] in ("Fireball", "IceSpear", "Pebble", "Thorn")
            th["rows"].append([T, int(float(p[5])), int(float(p[6]))])
            th["t1"] = T + 0.3 if th["shot"] else T + 1.2
        elif k == "GONE" and len(p) >= 3 and tag + p[2] in things:
            things[tag + p[2]]["t1"] = T
    for i in [i for i, w in wizards.items() if len(w["rows"]) < 5]:  # a body seen for an instant as the world was being built
        del wizards[i]
    for w in wizards.values():
        w["t0"], w["t1"] = w["rows"][0][0], off + end
    return dict(head=head, off=off, end=end, wizards=wizards, things=things, casts=casts, hits=hits, events=events, screen=screen, terr=terr)


def match_files(path):
    """The worlds of the match this log is one of: files with the same stamp, in order (the waiting room is left out)."""
    base = os.path.basename(path)
    stamp = base.rsplit("_w", 1)[0]
    found = sorted(glob.glob(os.path.join(os.path.dirname(path), stamp + "_w*.log")), key=lambda f: int(f.rsplit("_w", 1)[1].split(".")[0]))
    return found or [path]


def build(path):
    off, worlds = 0.0, []
    data = dict(end=0.0, wizards={}, things=[], casts=[], hits=[], events=[], screen=[], worlds=[])
    names = {}
    for n, f in enumerate(match_files(path)):
        w = read_world(f, off, "w%d_" % n)
        if "Lab" in w["head"] or not w["wizards"]:
            continue
        for i, wz in w["wizards"].items():
            wz["k"] = len(data["wizards"]) % 8
            data["wizards"][i] = dict(name=html.escape(wz["name"]), kind=wz["kind"], k=wz["k"], rows=wz["rows"], fell=wz["fell"], states=wz["states"], t0=wz["t0"], t1=wz["t1"])
        for c in w["casts"]:
            c["k"] = data["wizards"][c.pop("id")]["k"]
        data["things"] += [dict(cls=th["cls"], shot=th["shot"], rows=th["rows"], t0=th["t0"], t1=th["t1"]) for th in w["things"].values() if th["rows"]]
        data["casts"] += w["casts"]
        data["hits"] += w["hits"]
        data["events"] += w["events"]
        data["screen"] += w["screen"]
        biome = w["head"].split("biome")[-1].strip() if "biome" in w["head"] else "world"
        data["worlds"].append(dict(name="world %d, %s" % (len(data["worlds"]) + 1, biome), t0=off, t1=off + w["end"], w=w["terr"]["w"], h=w["terr"]["h"], rows=w["terr"]["rows"]))
        off += w["end"] + 2.0
    data["end"] = max(0.0, off - 2.0)
    data["events"].sort(key=lambda e: e["t"])
    return data


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return
    src = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.splitext(src)[0] + ".html"
    data = build(src)
    open(out, "w", encoding="utf-8").write(PAGE.replace("__DATA__", json.dumps(data, separators=(",", ":"))))
    print("wrote", out, "%.1f MB" % (os.path.getsize(out) / 1e6), "(%d worlds, %d wizards, %.0f s)" % (len(data["worlds"]), len(data["wizards"]), data["end"]))


if __name__ == "__main__":
    main()
