"""Convert this untextured Blender OBJ/MTL prototype to MilkShape ASCII."""
from pathlib import Path
import argparse
import json
import math
import shutil
from PIL import Image, ImageDraw

parser = argparse.ArgumentParser()
parser.add_argument('obj', type=Path)
parser.add_argument('--asset-name', default='TitleCity')
args = parser.parse_args()
source = args.obj.resolve()
if not args.asset_name.isidentifier():
    raise ValueError('Asset name must be a single identifier')
out = Path(__file__).resolve().parents[1] / 'Graphics/VOLT26' / args.asset_name
out.mkdir(parents=True, exist_ok=True)
vertices, normals, faces, objects = [], [], [], {}
material, name, mtl = None, 'default', None
def triangulate(points):
    # Ear clipping preserves concave OBJ polygons after projection to their plane.
    normal = [0.,0.,0.]
    for a,b in zip(points,points[1:]+points[:1]):
        for k in range(3):
            normal[k] += (a[(k+1)%3]-b[(k+1)%3])*(a[(k+2)%3]+b[(k+2)%3])
    drop=max(range(3),key=lambda k:abs(normal[k]))
    q=[tuple(p[k] for k in range(3) if k!=drop) for p in points]
    def cross(a,b,c): return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
    area=sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(q,q[1:]+q[:1]))
    sign=1 if area>0 else -1
    pending=list(range(len(points)))
    result=[]
    while len(pending)>3:
        for j,b in enumerate(pending):
            a,c=pending[j-1],pending[(j+1)%len(pending)]
            if sign*cross(q[a],q[b],q[c])<=1e-10: continue
            if any(all(sign*cross(q[u],q[v],q[p])>=-1e-10 for u,v in [(a,b),(b,c),(c,a)])
                   for p in pending if p not in (a,b,c)): continue
            result.append([points[a],points[b],points[c]])
            pending.pop(j)
            break
        else: raise ValueError('Cannot triangulate polygon; check degenerate or non-planar geometry')
    result.append([points[i] for i in pending])
    return result
for line in source.read_text(encoding='utf-8-sig').splitlines():
    parts = line.split()
    if not parts or parts[0].startswith('#'):
        continue
    key, values = parts[0], parts[1:]
    if key == 'mtllib':
        mtl = source.parent / ' '.join(values)
    elif key == 'o':
        name = ' '.join(values)
    elif key == 'v':
        vertices.append(tuple(map(float, values[:3])))
    elif key == 'vn':
        normals.append(tuple(map(float, values[:3])))
    elif key == 'usemtl':
        material = ' '.join(values)
    elif key == 'f':
        indices = []
        for value in values:
            i = int(value.split('/')[0])
            indices.append(i-1 if i>0 else len(vertices)+i)
        points = [vertices[i] for i in indices]
        objects.setdefault(name, []).extend(points)
        for triangle in triangulate(points):
            faces.append((material, triangle))
if mtl is None or mtl.resolve().parent != source.parent:
    raise ValueError('Expected a sibling MTL')
colors = {}
for line in mtl.read_text(encoding='utf-8-sig').splitlines():
    p = line.split()
    if not p: continue
    if p[0] == 'newmtl': material = ' '.join(p[1:])
    elif p[0] == 'Kd': colors[material] = tuple(map(float,p[1:4]))
    elif p[0].startswith('map_'): raise ValueError('Texture maps require a different importer')
names = sorted(colors)
if len(names)>8: raise ValueError('Palette supports up to eight materials')
def srgb(v):
    return round(255*(12.92*v if v<=0.0031308 else 1.055*v**(1/2.4)-.055))
atlas = Image.new('RGB',(64,8))
draw = ImageDraw.Draw(atlas)
for i,name in enumerate(names):
    draw.rectangle((i*8,0,i*8+7,7),fill=tuple(srgb(v) for v in colors[name]))
atlas.save(out/'palette.png')
# Preserve Blender's Y-up OBJ export. Scale one meter to 35 theme units.
factor=35
chunks=[faces[i:i+20000] for i in range(0,len(faces),20000)]
# The engine uses 16-bit vertex indices within each mesh.
for chunk_index,chunk in enumerate(chunks):
    lines=[]
    lines.extend([f'"ImportedCity{chunk_index}" 0 0',str(len(chunk)*3)])
    face_normals=[]
    for material,points in chunk:
        u=(names.index(material)*8+4)/64
        for x,y,z in points: lines.append(f'0 {x*factor:.6f} {y*factor:.6f} {z*factor:.6f} {u} 0.5 -1')
        a,b,c=points
        ab=[b[i]-a[i] for i in range(3)]; ac=[c[i]-a[i] for i in range(3)]
        n=[ab[1]*ac[2]-ab[2]*ac[1],ab[2]*ac[0]-ab[0]*ac[2],ab[0]*ac[1]-ab[1]*ac[0]]
        length=math.sqrt(sum(v*v for v in n))
        if length<1e-10: raise ValueError('Degenerate face')
        face_normals.append(tuple(v/length for v in n))
    lines.append(str(len(face_normals)))
    lines.extend(' '.join(map(str,n)) for n in face_normals)
    lines.append(str(len(chunk)))
    lines.extend(f'0 {3*i} {3*i+1} {3*i+2} {i} {i} {i} 1' for i in range(len(chunk)))
    material_lines=['Materials: 1','"Palette"','1 1 1 1','1 1 1 1','0 0 0 1','0 0 0 1','0','1','"palette.png"','""','Bones: 0']
    # Separate Model actors also avoid 16-bit offsets across compiled meshes.
    part_lines=['// MilkShape 3D ASCII','Frames: 1','Frame: 1','Meshes: 1']+lines+material_lines
    filename='city.txt' if chunk_index==0 else f'city-{chunk_index}.txt'
    (out/filename).write_text('\n'.join(part_lines)+'\n',encoding='ascii')
shutil.copy2(source,out/source.name)
shutil.copy2(mtl,out/mtl.name)
def bounds(points):
    return [[min(p[i] for p in points),max(p[i] for p in points)] for i in range(3)]
report={'triangles':len(faces),'model_parts':len(chunks),'objects':len(objects),'materials':names,'bounds':bounds(vertices),
        'banners':{n:bounds(p) for n,p in objects.items() if 'banner' in n.lower() and not any(s in n.lower() for s in ('frame','support'))}}
(out/'import-info.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
