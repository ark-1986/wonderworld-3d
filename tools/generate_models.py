"""Original free-to-use lightweight 3D prop pack for WonderWorld Adventure City.
Every model is entirely scripted geometric art created for this game.
No third-party or copyrighted assets are included.
"""
from pathlib import Path
import math
import numpy as np
import trimesh
from trimesh.transformations import rotation_matrix

OUT=Path(__file__).resolve().parent.parent/'godot/assets/models'
OUT.mkdir(parents=True,exist_ok=True)

def rgba(h):
    h=h.strip('#');return np.array([int(h[i:i+2],16) for i in (0,2,4)]+[255],dtype=np.uint8)

def tint(mesh,color):
    mesh.visual.vertex_colors=np.tile(rgba(color),(len(mesh.vertices),1))
    return mesh

class Model:
    def __init__(self):self.meshes=[]
    def add(self, mesh, xyz, color):
        mesh.apply_translation(xyz)
        self.meshes.append(tint(mesh,color));return mesh
    def box(self,xyz,dim,color):return self.add(trimesh.creation.box(extents=dim),xyz,color)
    def ball(self,xyz,r,color,sub=2):return self.add(trimesh.creation.icosphere(subdivisions=sub,radius=r),xyz,color)
    def cyl(self,xyz,r,h,color,sections=14,rotation=None):
        mesh=trimesh.creation.cylinder(radius=r,height=h,sections=sections)
        mesh.apply_transform(rotation_matrix(math.pi/2,[1,0,0]))
        if rotation is not None:mesh.apply_transform(rotation_matrix(rotation[0],rotation[1]))
        return self.add(mesh,xyz,color)
    def cone(self,xyz,r,h,color,sections=12):
        mesh=trimesh.creation.cone(radius=r,height=h,sections=sections)
        mesh.apply_transform(rotation_matrix(-math.pi/2,[1,0,0]))
        return self.add(mesh,xyz,color)
    def beam(self,p,q,r,color,sections=10):
        p=np.array(p,dtype=float);q=np.array(q,dtype=float);v=q-p
        if np.linalg.norm(v)<1e-5:return
        mesh=trimesh.creation.cylinder(radius=r,height=float(np.linalg.norm(v)),sections=sections)
        matrix=trimesh.geometry.align_vectors([0,0,1],v/np.linalg.norm(v))
        if matrix is not None:mesh.apply_transform(matrix)
        return self.add(mesh,(p+q)/2,color)
    def ring(self,xyz,inner,outer,color,n=24,axis='z'):
        for a in range(n):
            t0=2*math.pi*a/n;t1=2*math.pi*(a+1)/n
            if axis=='x':
                p=(xyz[0],xyz[1]+inner*math.cos(t0),xyz[2]+inner*math.sin(t0));q=(xyz[0],xyz[1]+inner*math.cos(t1),xyz[2]+inner*math.sin(t1))
            else:
                p=(xyz[0]+inner*math.cos(t0),xyz[1]+inner*math.sin(t0),xyz[2]);q=(xyz[0]+inner*math.cos(t1),xyz[1]+inner*math.sin(t1),xyz[2])
            self.beam(p,q,outer,color,8)
    def arch(self,xyz,radius,thickness,color,n=24):
        for i in range(n):
            t0=math.pi*i/n;t1=math.pi*(i+1)/n
            p=(xyz[0]+radius*math.cos(t0),xyz[1]+radius*math.sin(t0),xyz[2]);q=(xyz[0]+radius*math.cos(t1),xyz[1]+radius*math.sin(t1),xyz[2])
            self.beam(p,q,thickness,color,8)
    def roof(self,xc, h,zc, w,d, col):
        for z in [-d*0.25,d*0.25]:
            self.box((xc,h+0.3,zc+z),(w+0.5,0.18,d/2+0.20),col)
        self.cone((xc,h+1.15,zc),w*0.64,2.05,col)
    def save(self,name):
        combined=trimesh.util.concatenate(self.meshes)
        # Vertex colors are packed into a single mesh for mobile-friendly draw calls.
        scene=trimesh.Scene()
        scene.add_geometry(combined,geom_name=name,node_name=name)
        path=OUT/(name+'.glb')
        path.write_bytes(scene.export(file_type='glb'))
        back=trimesh.load(path,force='scene')
        assert len(back.geometry)>=1
        assert sum(len(m.faces) for m in back.geometry.values())>100
        print(name,round(path.stat().st_size/1024),"KiB",len(combined.faces),"tris")

C={'pink':'ef729d','coral':'e95d74','gold':'ffce62','blue':'4f9fd9','teal':'40cbb4','cream':'fff0cd','white':'fff9ed','dark':'273d65','wood':'b67859','lime':'71ba7c','violet':'9880d1'}

def make_gate():
    m=Model();
    for x in [-3.3,3.3]:
        m.box((x,2.4,0),(0.8,4.8,0.75),C['cream'])
        m.box((x,4.72,0),(1.1,0.42,1),C['gold'])
        m.cone((x,5.2,0),.68,1.1,C['coral'])
        m.ball((x,5.9,0),.22,C['gold'])
        for y in [1.25,2.5,3.8]:m.box((x,y,-.42),(1.05,.22,.15),C['pink'])
    # Five pastel strips across a royal welcome arch.
    bands=[C['coral'],C['gold'],'5ac8be',C['blue'],C['violet']]
    for k,color in enumerate(bands):
        m.arch((0,4.45+k*.035,0),3.32+k*.16,.15,color,22)
    m.box((0,4.45,-.25),(5.1,.67,.30),C['dark'])
    for x in [-2.2,2.2]:m.ball((x,4.48,-.58),.26,C['gold'])
    for x in [-1.8,0,1.8]:
        m.beam((x,4.05,-.6),(x,3.55,-.6),.045,C['gold'])
        m.cone((x,3.5,-.6),.22,.54,C['teal'])
    m.save('festival_gate')

def make_kiosk():
    m=Model();m.box((0,.25,0),(4.7,.5,3.6),C['wood']);m.box((0,1.90,0),(4.55,3.0,3.5),'f7d8b7')
    for side in [-1,1]:
        m.box((side*2.1,2.0,-1.79),(.25,2.9,.23),C['pink'])
        m.box((side*1.45,2.5,-1.82),(.65,1.1,.12),C['cream'])
        m.box((side*1.45,2.5,-1.90),(.50,.84,.10),'9fdbea')
        m.box((side*1.45,2.5,-2.0),(.075,.80,.1),C['white'])
    m.box((0,1.35,-1.82),(1.2,1.9,.12),'65425d')
    for k in range(8):
        x=-2.07+k*.59
        m.box((x,3.49,-1.94),(.58,.54,.85),C['coral'] if k%2 else C['white'])
    m.box((0,4.04,0),(5.3,.42,4.15),C['gold'])
    m.cone((0,4.80,0),3.14,1.68,C['coral'])
    m.ball((0,5.72,0),.18,C['gold'])
    m.box((0,3.15,-1.93),(2.65,.52,.22),C['dark'])
    for x in [-.72,.72]:m.ball((x,3.18,-2.12),.2,C['gold'])
    # Display case and bright sweets.
    m.box((0,.85,-2.2),(2.7,.65,.8),C['wood'])
    for i in range(4):
        x=-1.05+.7*i
        m.ball((x,1.31,-2.18),.24,[C['pink'],C['gold'],C['teal'],C['violet']][i])
    m.save('candy_kiosk')

def make_ferris_wheel():
    m=Model()
    for x in [-1.1,1.1]:
        m.beam((x,.15,0),(0,5.25,0),.18,C['cream'])
        m.beam((x,.15,0),(0,5.25,-.0),.11,C['gold'])
    m.ring((0,5.35,0),4.25,.17,C['coral'],32,axis='z')
    m.ring((0,5.35,.08),3.35,.085,C['cream'],32,axis='z')
    for k in range(12):
        a=math.pi*k/6
        x=4.25*math.sin(a);y=5.35+4.25*math.cos(a)
        m.beam((0,5.35,0),(x,y,0),.09,C['gold'])
        if k%2==0:
            m.beam((x,y,0),(x,y-.45,0),.07,C['white'])
            color=[C['pink'],C['blue'],C['gold'],C['teal'],C['violet'],C['coral']][k//2]
            m.box((x,y-.81,0),(.85,.54,.92),color)
            m.box((x,y-.54,0),(.95,.10,1.03),C['cream'])
    m.cyl((0,5.35,0),.52,1.10,C['gold'])
    m.box((0,0.14,0),(7,.28,3.2),'edccb3')
    m.save('ferris_wheel')

def make_lamp():
    m=Model();m.cyl((0,.25,0),.41,.48,C['dark'])
    m.cyl((0,2.15,0),.12,3.8,C['dark'])
    for y in [1.5,3.5]:m.cyl((0,y,0),.22,.14,C['gold'])
    m.box((0,4.15,0),(.78,.18,.76),C['dark'])
    m.box((0,4.55,0),(.6,.7,.6),C['gold'])
    m.box((0,4.55,-.32),(.5,.56,.08),C['cream'])
    m.cone((0,5.05,0),.53,.56,C['dark'])
    m.ball((0,5.43,0),.12,C['gold'])
    m.save('lantern_post')

def make_bench():
    m=Model()
    for x in [-1.15,1.15]:
        for z in [-.43,.43]:m.box((x,.47,z),(.19,.9,.22),C['dark'])
    for z in [-.35,.1,.55]:m.box((0,1.03,z),(2.75,.15,.23),C['wood'])
    for y in [1.3,1.65,2.0]:m.box((0,y,.52),(2.75,.24,.18),C['wood'])
    for x in [-1.23,1.23]:m.box((x,1.15,.18),(.2,.14,1.15),C['dark'])
    m.save('park_bench')

def make_balloon_cart():
    m=Model();m.box((0,1.0,0),(2.25,.5,1.45),C['wood'])
    m.box((0,1.48,0),(1.9,.43,1.1),C['cream'])
    for x in [-.80,.80]:
        for z in [-.62,.62]:m.cyl((x,.45,z),.31,.29,C['dark'])
    for x in [-.80,.80]:m.cyl((x,2.28,.0),.055,1.75,C['gold'])
    m.box((0,3.12,0),(2.5,.20,1.8),C['pink'])
    m.cone((0,3.41,0),1.25,.65,C['coral'])
    for i in range(8):
        x=math.sin(i*2.1)*1.02
        z=math.cos(i*2.1)*.8
        y=4.8+(i%3)*.45
        m.beam((x*.25,3.25,z*.25),(x,y,z),.025,C['white'],6)
        m.ball((x,y,z),.46,[C['pink'],C['gold'],C['blue'],C['teal'],C['violet']][i%5],sub=1)
    m.save('balloon_cart')

def make_pet_house():
    m=Model();m.box((0,.90,0),(2.8,1.8,2.5),C['cream'])
    m.box((0,.08,0),(3.1,.16,2.9),C['wood'])
    m.cone((0,2.02,0),2.06,1.9,C['coral'])
    m.box((0,.8,-1.30),(1.2,1.45,.12),C['dark'])
    m.ball((0,1.55,-1.43),.33,C['gold'])
    for x in [-.5,.5]:m.ball((x,.46,-1.47),.22,C['gold'])
    for x in [-.7,.7]:m.box((x,1.6,-1.36),(.31,.31,.15),C['pink'])
    m.save('pet_house')

def make_trophy_portal():
    m=Model();
    for x in [-2.3,2.3]:m.cyl((x,2.2,0),.28,4.4,C['dark'])
    m.ring((0,3.35,0),2.35,.26,C['gold'],24)
    m.ring((0,3.35,-.17),2.7,.13,C['pink'],24)
    for i in range(5):
        a=math.pi*i/4
        m.ball((2.45*math.cos(a),3.35+2.45*math.sin(a),-.36),.16,C['white'])
    m.box((0,5.92,0),(2.85,.68,.3),C['dark'])
    for x in [-.85,0,.85]:m.ball((x,5.96,-.28),.19,C['gold'])
    m.save('trophy_portal')

def make_flower_bed():
    m=Model();m.box((0,.22,0),(3.4,.44,1.55),'ad7756')
    m.box((0,.48,0),(3.05,.12,1.3),'7e613c')
    for i in range(11):
        x=-1.35+.27*i
        z=.30*math.sin(i*1.5)
        color=[C['pink'],C['gold'],'86d8eb',C['violet'],'f2f1da'][i%5]
        m.cyl((x,.78,z),.055,.54,'3c8c62',8)
        m.ball((x,1.06,z),.19,color,sub=1)
        for j in range(3):m.ball((x+.14*math.cos(j*2.1),1.08+.14*math.sin(j*2.1),z),.09,color,sub=1)
    m.save('flower_bed')

def make_magic_tower():
    m=Model();m.cyl((0,2.65,0),1.7,5.3,'f3d6b2',12)
    m.cyl((0,5.35,0),2,.55,'fff0ce',12)
    for yy in [1.0,2.6,4.2]:m.cyl((0,yy,0),1.76,.18,'dfaa85',12)
    for yy in [2.0,3.8]:m.box((0,yy,-1.75),(.85,1.1,.20),C['blue'])
    m.cone((0,7.0,0),2.5,3.4,C['coral'],12)
    m.cyl((0,9.04,0),.08,.75,C['gold'])
    m.box((.35,9.17,0),(.75,.50,.05),C['gold'])
    m.save('magic_tower')

def make_palm():
    m=Model();m.cyl((0,2.45,0),.28,4.9,C['wood'])
    for i in range(9):
        a=i*2*math.pi/9
        x,z=math.cos(a),math.sin(a)
        for k in range(1,5):
            rr=k*.66
            m.beam((0,4.9,0),(rr*x,5.3-.36*k,rr*z),.14-.02*k,'3d9e70',8)
            m.ball((rr*x,5.3-.36*k,rr*z),.19,'65c790',sub=1)
    for j in range(4):m.ball((.28*math.cos(j*math.pi/2),4.83,.28*math.sin(j*math.pi/2)),.16,'b88c58',sub=1)
    m.save('palm_tree')

if __name__=='__main__':
    for fun in [make_gate,make_kiosk,make_ferris_wheel,make_lamp,make_bench,make_balloon_cart,make_pet_house,make_trophy_portal,make_flower_bed,make_magic_tower,make_palm]:
        fun()
