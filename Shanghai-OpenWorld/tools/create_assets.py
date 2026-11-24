#!/usr/bin/env python3
"""Generate original application artwork and synthesized audio."""
from pathlib import Path
import math
import random
import wave
from array import array
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
TEX = ROOT / 'assets/textures'
AUDIO = ROOT / 'assets/audio'
rng = random.Random(559)

def city(size, icon=False):
    w, h = size
    image = Image.new('RGB', size)
    draw = ImageDraw.Draw(image)
    for y in range(h):
        t = y / h
        draw.line((0, y, w, y), fill=(int(6 + 19*t), int(22 + 24*t), int(34 + 27*t)))
    for idx in range(18):
        x = idx * 0.067 * w
        top = (0.69 - rng.uniform(0.015, .21)) * h
        draw.rectangle((x, top, x + w * .045, h * .75), fill=(43,63,71))
    draw.polygon([(w*.59,h*.70),(w*.61,h*.13),(w*.65,h*.105),(w*.69,h*.70)], fill='#78959d')
    draw.rectangle((w*.73,h*.30,w*.755,h*.70), fill='#568090')
    draw.rectangle((w*.80,h*.30,w*.825,h*.70), fill='#568090')
    draw.rectangle((w*.73,h*.28,w*.825,h*.325), fill='#7396a0')
    draw.rectangle((w*.73,h*.397,w*.825,h*.70), fill='#7396a0')
    px = .40 * w
    for line in [((.34,.70),(.40,.47)),((.46,.70),(.40,.47)),((.4,.70),(.4,.17))]:
        draw.line([((a)*w,(b)*h) for a,b in line], fill='#ddb58c', width=max(2,int(w*.013)))
    for y, s in [(.48,.085),(.32,.068),(.23,.036)]:
        rx, ry = s*w*.5, s*h*.41
        draw.ellipse((px-rx,y*h-ry,px+rx,y*h+ry), fill='#ffb780', outline='#ffe0ac', width=max(1,int(w*.003)))
    draw.rectangle((0, .72*h, w, .74*h), fill='#ffb780')
    for _ in range(50):
        x, y = rng.random()*w, rng.uniform(.745,.99)*h
        draw.line((x, y, x+rng.uniform(.01,.09)*w,y), fill=rng.choice(('#426875','#294c60','#795d53')), width=max(1,int(h*.004)))
    if not icon:
        face = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
        draw.text((w*.041,h*.075), 'SHANGHAI', font=ImageFont.truetype(face, int(h*.076)), fill='#ffe3c5')
        draw.text((w*.047,h*.175), 'O P E N   W O R L D', font=ImageFont.truetype(face, int(h*.027)), fill='#d5dfe3')
    return image

def sample(name, duration, fn, loop=False):
    rate = 22050
    values = array('h')
    for i in range(round(duration * rate)):
        t = i / rate
        envelope = 1 if loop else min(1,t * 180,max(0,(duration-t)*12))
        values.append(int(max(-1,min(1,fn(t)*envelope))*27000))
    with wave.open(str(AUDIO / (name + '.wav')), 'wb') as out:
        out.setparams((1,2,rate,len(values),'NONE','not compressed'))
        out.writeframes(values.tobytes())

def s(f, t):
    return math.sin(math.tau*f*t)

def noise():
    return rng.uniform(-1,1)

city((512,512), True).save(TEX / 'icon.png')
city((1280,720)).save(TEX / 'splash.png')
sample('motor',1,lambda t: .30*s(42,t)+.18*s(84,t)+.08*s(126,t)+.06*noise(), True)
sample('horn',.45,lambda t: .31*s(322,t)+.28*s(431,t)+.12*s(644,t))
sample('impact',.42,lambda t: (.54*noise()+.32*s(89,t))*math.exp(-t*8))
sample('step',.18,lambda t: (.35*noise()+.12*s(82,t))*math.exp(-t*19))
sample('skid',.38,lambda t: (.25*s(640+140*t,t)+.25*noise())*math.exp(-t*5))
sample('rain',4,lambda t: (.12+.045*s(.5,t))*noise()+.025*s(100,t),True)
sample('river',4,lambda t: .09*(1+s(.5,t)*.6)*noise()+.035*s(54,t),True)
sample('ambience',5,lambda t: .036*s(44,t)+.04*s(62,t)+.035*noise(),True)
sample('thunder',1.7,lambda t: (.27*s(39,t)+.32*noise()+.16*s(56,t))*math.exp(-t*1.8))
sample('complete',.75,lambda t: .23*s([440,554,660][min(2,int(t*5))],t)*math.exp(-t*.85))
sample('ferry',.9,lambda t: (.31*s(146,t)+.15*s(220,t))*math.exp(-t*1.7))
sample('night',8,lambda t: sum(.055*s(f,t)*(1+s(.25,t)*.3) for f in [110,138.625,165,207.625]),True)
