import math
from fontTools.ttLib import TTCollection
from fontTools.pens.recordingPen import RecordingPen
from fontTools.pens.boundsPen import BoundsPen
FONTS={w:TTCollection(f'/System/Library/Fonts/ヒラギノ角ゴシック W{w}.ttc').fonts[0] for w in (8,9)}

# --- counter opening for W9 (font units, y up). Only straight horizontal edges are moved, staying at 0°.
KEN_EDGES={116:146,246:230,267:290,384:377,405:431,524:522,549:576,663:667,688:721}
def fix_ken(x,y):
    if x>=928 and 515<y<700: return x,y          # long crossbar's right end: untouched
    y0=y
    if x>=340:
        for old,new in KEN_EDGES.items():
            if abs(y-old)<=6: y=new+(y-old); break
        else:
            if (x,y) in [(366,689),(370,694),(380,708)]: y+=33   # follow the moved 688 edge at the 廴 joint
        if x==761 and 515<y0<720: x=773                       # widen the two small windows (46u -> 58u)
    return x,y
def fix_taku(x,y):
    if y==632: y=660                                         # space under ウ: raise the counter's top edge
    if (x,y)==(791,219): y=181                               # 乚 hook tip: open the gap to the crossbar
    if (x,y)==(862,190): y=168
    if (x,y)==(908,177): y=170
    return x,y
FIX={'宅':fix_taku,'建':fix_ken}

def rec(ch,w,fix=True):
    f=FONTS[w]; gs=f.getGlyphSet(); gn=f.getBestCmap()[ord(ch)]
    p=RecordingPen(); gs[gn].draw(p)
    fx=FIX.get(ch) if (fix and w==9) else None
    val=[(op,[fx(*pt) if fx else pt for pt in args]) for op,args in p.value]
    xs=[]; ys=[]
    bp=BoundsPen(gs); gs[gn].draw(bp)
    return val,bp.bounds
def to_d(val,s,ox,oy):
    """font units -> px: x'=ox+s*x, y'=oy-s*y"""
    out=[]
    T=lambda p:f'{ox+s*p[0]:.2f},{oy-s*p[1]:.2f}'
    for op,args in val:
        if op=='moveTo': out.append('M'+T(args[0]))
        elif op=='lineTo': out.append('L'+T(args[0]))
        elif op=='curveTo': out.append('C'+' '.join(T(a) for a in args))
        elif op=='qCurveTo': out.append('Q'+' '.join(T(a) for a in args))
        elif op in('closePath','endPath'): out.append('Z')
    return ''.join(out)

def build(fn, copy='合格', ai='#F5D447', bg='#F5D447', ty0=142, ty1=552, kern=16,
          band=(82,690,860,180,36), band_h=96, gaps=None, hl_tl=(75,482), hl_tr=(968,470), hl_h=115,
          slant_deg=12, fix=True):
    v1,b1=rec('宅',9,fix); v2,b2=rec('建',9,fix)
    miny=min(b1[1],b2[1]); maxy=max(b1[3],b2[3]); s=(ty1-ty0)/(maxy-miny); base=ty0+maxy*s
    w1=(b1[2]-b1[0])*s; w2=(b2[2]-b2[0])*s; tot=w1+w2+kern; x=512-tot/2
    big=f'<path id="letters" fill="#1F4233" d="{to_d(v1,s,x-b1[0]*s,base)}{to_d(v2,s,x+w1+kern-b2[0]*s,base)}"/>'
    # marker: straight top edge TL->TR (about -1 deg), parallel bottom, both ends one straight 12 deg chisel cut
    (tlx,tly),(trx,try_)=hl_tl,hl_tr
    dx=hl_h*math.tan(math.radians(slant_deg)); sag=3
    blx,bly=tlx-dx,tly+hl_h; brx,bry=trx-dx,try_+hl_h
    hd=(f'M{tlx:.1f},{tly:.1f} Q{(tlx+trx)/2:.1f},{(tly+try_)/2+2*sag:.1f} {trx:.1f},{try_:.1f} '
        f'L{brx:.1f},{bry:.1f} Q{(blx+brx)/2:.1f},{(bly+bry)/2+2*sag:.1f} {blx:.1f},{bly:.1f} Z')
    hl=f'<path id="marker" fill="#FFFEFB" d="{hd}"/>'
    bx,by,bw,bh,br=band
    chars=['A','I','と','話','し','て']+(['合','格'] if copy=='合格' else ['学','ぶ'])
    gaps=gaps or [6,16,8,6,4,10,6]
    recs=[rec(c,8,False) for c in chars]
    miny=min(b[1] for _,b in recs); maxy=max(b[3] for _,b in recs); sb=band_h/(maxy-miny)
    widths=[(b[2]-b[0])*sb for _,b in recs]; tw=sum(widths)+sum(gaps); x=512-tw/2
    bl=by+bh/2-band_h/2+maxy*sb
    ad=''; rd=''
    for i,(v,b) in enumerate(recs):
        d=to_d(v,sb,x-b[0]*sb,bl)
        if i<2: ad+=d
        else: rd+=d
        x+=widths[i]+(gaps[i] if i<len(gaps) else 0)
    svg=f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
<rect width="1024" height="1024" fill="{bg}"/>
{hl}
{big}
<rect x="{bx}" y="{by}" width="{bw}" height="{bh}" rx="{br}" fill="#1F4233"/>
<path fill="{ai}" d="{ad}"/><path fill="#FFFEFB" d="{rd}"/>
</svg>'''
    open(fn,'w').write(svg)
    print(fn,'宅建 x',round(512-tot/2),'-',round(512+tot/2),'w',round(tot),'scale',round(s,4),'band text w',round(tw))
if __name__=='__main__':
    build('ship_A2.svg'); build('ship_A2_manabu.svg',copy='学ぶ',gaps=[6,16,8,6,4,10,4])
    build('ship_A2_nofix.svg',fix=False)
