"""Blender offline, linear HDR panorama and matching display image, in world bearings."""
import bpy,numpy as np,json,math,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'assets/art/kandy/environment';OUT.mkdir(parents=True,exist_ok=True)
w,h=4096,2048
a=(np.arange(w,dtype=np.float32)[None,:]/w-.5)*2*np.pi
t=(np.arange(h,dtype=np.float32)[:,None]+.5)*np.pi/h
x=np.sin(a)*np.sin(t);y=np.broadcast_to(np.cos(t),(h,w));z=np.cos(a)*np.sin(t)
e=np.clip(y,0,1)[...,None]**.45
rgb=np.array([.75,.93,1.08],np.float32)*(1-e)+np.array([.14,.37,.73],np.float32)*e
# Continuous spherical noise has identical left/right bearings and no polar seam.
cloud=np.zeros((h,w),np.float32)
for f,amp in [(5.,.5),(11.,.25),(23.,.13),(47.,.065)]:cloud+=amp*np.sin(x*f+np.sin(z*f*.8))*np.cos(z*f*.7+np.sin(y*f))
c=np.clip((cloud-.08)*3.2,0,1)*np.clip(y*12,0,1)*np.clip((.95-y)*8,0,1)
rgb=rgb*(1-c[...,None]*.9)+np.array([1.9,1.94,1.98],np.float32)*c[...,None]*.9
# Original generated sky supplies the cloud field; radiance is authored in linear space.
source=OUT/'cloud-source.png'
if source.exists():
    cloud_image=bpy.data.images.load(str(source));cloud_image.scale(w,h)
    pixels=np.empty(w*h*4,np.float32);cloud_image.pixels.foreach_get(pixels)
    encoded=pixels.reshape(h,w,4)[::-1,:,:3].copy()
    rgb=np.where(encoded<=.04045,encoded/12.92,((encoded+.055)/1.055)**2.4)*1.65
    # A periodic, zero-slope boundary is baked into both deliverables, including
    # their lighting mip chain. A screen-only seam blend cannot repair radiance.
    edge=(rgb[:,0,:]+rgb[:,-1,:])*.5
    band=int(w*.065)
    for i in range(band):
        t=i/(band-1);blend=1.-t*t*(3.-2.*t)
        rgb[:,i,:]=rgb[:,i,:]*(1.-blend)+edge*blend
        rgb[:,-1-i,:]=rgb[:,-1-i,:]*(1.-blend)+edge*blend
display_linear=rgb.copy()/1.65 if source.exists() else rgb.copy()
# Same sun bearings as Kandy's DirectionalLight3D (Godot XYZ Euler basis).
from mathutils import Euler,Vector
pitch,yaw=math.radians(-62),math.radians(-120)
sun=np.array([math.sin(yaw)*math.cos(pitch),-math.sin(pitch),math.cos(yaw)*math.cos(pitch)],np.float32)
dot=np.clip(x*sun[0]+y*sun[1]+z*sun[2],-1,1)
disk=np.clip((dot-.99994)/.000035,0,1)*240
rgb+=disk[...,None]*np.array([1.,.96,.86],np.float32)
rgb[y<0]=np.array([.12,.17,.11],np.float32)
rgba=np.ones((h,w,4),np.float32);rgba[:,:,:3]=rgb
image=bpy.data.images.new('Kandy daylight linear radiance',width=w,height=h,float_buffer=True,alpha=False)
image.pixels.foreach_set(rgba[::-1].ravel())
scene=bpy.context.scene;scene.render.image_settings.file_format='OPEN_EXR';scene.render.image_settings.color_depth='16';scene.render.image_settings.exr_codec='ZIP'
image.save_render(str(OUT/'daylight.exr'),scene=scene)
# Matched display panorama. This does not fabricate HDR from an LDR input.
display=rgb/(1+rgb*.25);display=np.where(display<=.0031308,display*12.92,1.055*np.maximum(display,0)**(1/2.4)-.055)
rgba[:,:,:3]=np.clip(display,0,1)
visual=bpy.data.images.new('Kandy daylight visual',width=w,height=h,alpha=False)
visual.pixels.foreach_set(rgba[::-1].ravel());visual.filepath_raw=str(OUT/'daylight.png');visual.file_format='PNG';visual.save()
if source.exists():
    sys.path.append(str(ROOT/'build/kandy231/dependencies/python311'))
    from PIL import Image
    encoded=np.where(display_linear<=.0031308,display_linear*12.92,1.055*np.maximum(display_linear,0)**(1/2.4)-.055)
    Image.fromarray(np.uint8(np.clip(encoded,0,1)*255)).save(OUT/'daylight.png')
(OUT/'lighting.json').write_text(json.dumps({'dimensions':[w,h],'linear_peak':float(rgb.max()),'sun_angles':[-62,-120,0],'source':'tools/bake_kandy231_sky.py','radiance_is_linear':True,'cloud_source':'original built-in imagegen artwork; not a measured HDR photograph','radiance_model':'linear sky/cloud field plus explicit 240-unit solar radiance','left_right_wrap':'periodic zero-slope boundary baked into PNG and linear EXR; runtime wrap blend retained'},indent=2))
print('KANDY_SKY_BAKED',float(rgb.max()))
