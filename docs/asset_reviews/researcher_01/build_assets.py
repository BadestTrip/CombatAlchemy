"""Rebuild cleaned native frames from the accepted generated neutral facings.
Requires Pillow; run from repository root. No mirroring or interpolated playback.
"""
from pathlib import Path
import sys, json, math, statistics
sys.path.insert(0, str(Path('.godot/asset_tools').resolve()))
from PIL import Image, ImageDraw

REVIEW = Path('docs/asset_reviews/researcher_01')
OUT = Path('sprites/characters/researcher_01')
OUT.mkdir(parents=True, exist_ok=True)
(OUT / 'frames').mkdir(exist_ok=True)
RAMP = [16, 40, 64, 96, 136, 176, 216, 240]
FACINGS = ['front', 'back', 'side_left', 'side_right']
def ink(i): return (RAMP[i],)*3 + (255,)
source = Image.open(REVIEW/'imagegen_source.png').convert('RGBA')
# Normalize source frames using one scale per facing, not one scale per pose.
bases=[]
for row in range(4):
    tiles=[]
    for col in range(6):
        tile=source.crop((round(col*source.width/6),round(row*source.height/4),round((col+1)*source.width/6),round((row+1)*source.height/4)))
        tile.putalpha(tile.getchannel('A').point(lambda a:255 if a>=200 else 0))
        tiles.append(tile.crop(tile.getbbox()))
    factor=65/statistics.median(t.height for t in tiles)
    tile=tiles[0].resize((round(tiles[0].width*factor),round(tiles[0].height*factor)),Image.Resampling.BOX)
    clean=Image.new('RGBA',tile.size)
    for y in range(tile.height):
        for x in range(tile.width):
            r,g,b,a=tile.getpixel((x,y))
            if a>=128:
                v=min(RAMP,key=lambda v:abs(v-(r+g+b)/3))
                clean.putpixel((x,y),(v,v,v,255))
    frame=Image.new('RGBA',(64,80))
    frame.alpha_composite(clean,((64-clean.width)//2,74-clean.height))
    # Remove disconnected specks, preserving the single main silhouette.
    pixels=frame.load();seen=set();components=[]
    for y in range(80):
        for x in range(64):
            if pixels[x,y][3]==0 or (x,y) in seen: continue
            todo=[(x,y)];seen.add((x,y));part=[]
            while todo:
                xx,yy=todo.pop();part.append((xx,yy))
                for dx,dy in [(0,1),(0,-1),(1,0),(-1,0)]:
                    q=(xx+dx,yy+dy)
                    if 0<=q[0]<64 and 0<=q[1]<80 and q not in seen and pixels[q[0],q[1]][3]:
                        seen.add(q);todo.append(q)
            components.append(part)
    main=max(components,key=len)
    for part in components:
        if part is not main and len(part)<8:
            for x,y in part:pixels[x,y]=(0,0,0,0)
    bases.append(frame)

# Deliberate native leg contacts / passing positions. Boots stay on the y=74
# ground anchor for the support foot. Far limbs are darker, not reflected art.
def leg(canvas,hip,foot,side,near=True):
    # Re-pose the source trouser/boot pixels; retain their worn-material clusters.
    # Row-wise integer shifts bend the knee without smooth raster rotation.
    if side==0:
        box=(20,60,31,74) if hip<32 else (34,60,45,74)
    else:
        box=(27,61,39,74)
    piece=base.crop(box)
    center=(box[0]+box[2]-1)//2
    delta=foot[0]-center
    for yy in range(piece.height):
        t=yy/max(1,piece.height-1)
        dx=round(delta*t)
        for xx in range(piece.width):
            color=piece.getpixel((xx,yy))
            if not color[3]: continue
            if not near:
                index=RAMP.index(color[0]);color=ink(max(0,index-1))
            px=box[0]+xx+dx
            py=box[1]+yy+foot[1]-74
            if 0<=px<64 and 0<=py<80:canvas.putpixel((px,py),color)

frames=[];records=[]
for row,facing in enumerate(FACINGS):
    base=bases[row]
    for col in range(6):
        phase=col-2
        bob=-1 if col in [3,5] else 0
        frame=Image.new('RGBA',(64,80))
        if col<2:
            # Same costume and head in both idles: subtle chest rise only.
            frame=base.copy()
            if col==1:
                upper=base.crop((0,0,64,55))
                frame.paste((0,0,0,0),(0,0,64,54))
                frame.alpha_composite(upper,(0,-1))
            sockets=[(44,50),(19,50)] if row==0 else ([(19,49),(44,49)] if row==1 else ([(32,51),(25,48)] if row==2 else [(39,48),(32,51)]))
            if col==1:sockets=[(x,y-1) for x,y in sockets]
        else:
            body=base.copy()
            body.paste((0,0,0,0),(0,63,64,80))
            if row<2:
                contacts=[[(25,71),(37,74)],[(27,69),(36,74)],[(25,74),(37,71)],[(26,74),(35,69)]][phase]
                for n in sorted(range(2),key=lambda i:contacts[i][1]):leg(frame,[26,37][n],contacts[n],0,contacts[n][1]>=73)
                deltas=[[(0,1),(0,-1)],[(0,0),(0,0)],[(0,-1),(0,1)],[(0,0),(0,0)]][phase]
                boxes=[(14,42,24,54),(40,42,49,54)]
                parts=[body.crop(b) for b in boxes]
                for b in boxes:body.paste((0,0,0,0),b)
                frame.alpha_composite(body,(0,bob))
                points=[]
                for b,part,(dx,dy) in zip(boxes,parts,deltas):
                    frame.alpha_composite(part,(b[0]+dx,b[1]+dy+bob))
                    points.append((19 if b[0]<30 else 44,50+dy+bob))
                sockets=[points[1],points[0]] if row==0 else points
            else:
                direction=-1 if row==2 else 1
                near_offsets=[-8,0,8,0] if row==2 else [8,0,-8,0]
                far_offsets=[8,0,-8,0] if row==2 else [-8,0,8,0]
                near=(32+near_offsets[phase],70 if phase==3 else 74)
                far=(32+far_offsets[phase],70 if phase==1 else 74)
                leg(frame,31,far,direction,False)
                leg(frame,33,near,direction,True)
                # Restore the coat plane behind the near forearm before posing it.
                d=ImageDraw.Draw(body)
                d.polygon([(28,42),(34,42),(36,56),(28,57)],fill=ink(3))
                hand_dx=[3,0,-3,0][phase]*(-direction)
                hand=(31+hand_dx,51+bob)
                forearm=base.crop((28,42,35,54))
                d.line([(31,40),(31+hand_dx//2,44)],fill=ink(1),width=5)
                d.line([(30,40),(30+hand_dx//2,44)],fill=ink(3),width=2)
                body.alpha_composite(forearm,(28+hand_dx,42))
                frame.alpha_composite(body,(0,bob))
                far_hand=(25,48+bob) if row==2 else (39,48+bob)
                sockets=[hand,far_hand] if row==2 else [far_hand,hand]
        state='idle' if col<2 else 'walk'
        index=col if col<2 else col-2
        name=f'{state}_{facing}_{index:02d}'
        frame.save(OUT/'frames'/f'{name}.png')
        frames.append(frame)
        records.append({'name':name,'facing':facing,'animation':state,'index':index,'sheet_rect':[col*64,row*80,64,80],'duration_seconds':0.8 if state=='idle' else 0.18,'pivot':[32,74],'hand_left':list(sockets[0]),'hand_right':list(sockets[1]),'hand_draw_order': {'hand_left': -1 if row in [1,3] else 1, 'hand_right': -1 if row in [1,2] else 1}})

sheet=Image.new('RGBA',(384,320))
for i,f in enumerate(frames):sheet.alpha_composite(f,((i%6)*64,(i//6)*80))
sheet.save(OUT/'researcher_01_v001.png')
metadata={'version':1,'asset':'researcher_01','status':'active character sprite asset; used by characters/player/PlayerModel.tscn','cell_size':[64,80],'sheet_size':[384,320],'sheet':'researcher_01_v001.png','row_order':FACINGS,'columns':['idle_0','idle_1','walk_0','walk_1','walk_2','walk_3'],'display_scale_hint':2,'palette':['#%02X%02X%02X'%(v,v,v) for v in RAMP],'coordinate_system':'native cell pixels, origin top-left; subtract pivot then multiply by sprite scale for local sockets','frames':records}
(OUT/'researcher_01_v001.json').write_text(json.dumps(metadata,indent=2)+'\n')
# Godot-native SpriteFrames resource: no new gameplay implementation required.
text='[gd_resource type="SpriteFrames" load_steps=26 format=3]\n\n[ext_resource type="Texture2D" path="res://sprites/characters/researcher_01/researcher_01_v001.png" id="1"]\n\n'
for i,r in enumerate(records):
    x,y,w,h=r['sheet_rect'];text+=f'[sub_resource type="AtlasTexture" id="Frame{i}"]\natlas = ExtResource("1")\nregion = Rect2({x}, {y}, {w}, {h})\n\n'
text+='[resource]\nanimations = [\n'
animations=[]
for row,facing in enumerate(FACINGS):
    for state,cols,speed in [('idle',range(2),1.25),('walk',range(2,6),50/9)]:
        entries=', '.join('{"duration": 1.0, "texture": SubResource("Frame%d")}'%(row*6+c) for c in cols)
        animations.append('{"frames": ['+entries+'], "loop": true, "name": &"'+state+'_'+facing+'", "speed": '+str(speed)+'}')
text+=',\n'.join(animations)+'\n]\n'
(OUT/'Researcher01Frames.tres').write_text(text)
# Exportable metadata resource used by the active character model.
data_text='[gd_resource type="Resource" script_class="PlayerSpriteData" load_steps=3 format=3]\n\n[ext_resource type="Script" path="res://characters/player/PlayerSpriteData.gd" id="1"]\n[ext_resource type="SpriteFrames" path="res://sprites/characters/researcher_01/Researcher01Frames.tres" id="2"]\n\n[resource]\nscript = ExtResource("1")\nsprite_frames = ExtResource("2")\npivot = Vector2(32,74)\nframe_sockets = {\n'
groups=[]
for facing in FACINGS:
    for state in ['idle','walk']:
        items=[]
        for record in records:
            if record['facing']!=facing or record['animation']!=state:continue
            lx,ly=record['hand_left'];rx,ry=record['hand_right']
            lz=record['hand_draw_order']['hand_left'];rz=record['hand_draw_order']['hand_right']
            items.append('{"hand_left": Vector2(%d,%d), "hand_right": Vector2(%d,%d), "left_z": %d, "right_z": %d}'%(lx,ly,rx,ry,lz,rz))
        groups.append('&"'+state+'_'+facing+'": [ '+', '.join(items)+' ]')
data_text+=',\n'.join(groups)+'\n}\n'
(OUT/'Researcher01Data.tres').write_text(data_text)

# Solid review backgrounds are separate from runtime transparency.
for bg,name in [(40,'dark'),(216,'light')]:
    plate=Image.new('RGBA',sheet.size,(bg,bg,bg,255));plate.alpha_composite(sheet)
    plate.resize((1536,1280),Image.Resampling.NEAREST).save(REVIEW/f'sheet_{name}_4x.png')
# Four directions side-by-side, 4x. GIF/APNG include exact loop timings.
for state,cols,durations in [('idle',range(2),[800,800]),('walk',range(2,6),[180]*4)]:
    sequence=[]
    for col in cols:
        canvas=Image.new('RGBA',(256,80),(40,40,40,255))
        for row in range(4):canvas.alpha_composite(frames[row*6+col],(row*64,0))
        sequence.append(canvas.resize((1024,320),Image.Resampling.NEAREST))
    sequence[0].save(REVIEW/f'{state}_preview.gif',save_all=True,append_images=sequence[1:],duration=durations,loop=0,disposal=2)
    sequence[0].save(REVIEW/f'{state}_preview.png',save_all=True,append_images=sequence[1:],duration=durations,loop=0,disposal=0,blend=0)
print('Exported 24 frames, 384x320 atlas, JSON, SpriteFrames and animation previews')
