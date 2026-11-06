using Godot;
using Rokojori;
/// <summary>Viewport-local extruded typography sequenced by the existing Rokojori runner.</summary>
public partial class CountdownLetters : Node3D
{
    MeshInstance3D letters, rim, ring;
    CpuParticles3D sparks;
    Sequence sequence;
    StandardMaterial3D material, ringMaterial;
    Godot.Environment environment;
    double age=10;
    bool reduced;
    string last="";
    public override void _Ready()
    {
        var camera=new Camera3D { Position=new Vector3(0,0,7), Projection=Camera3D.ProjectionType.Orthogonal, Size=8, Current=true };
        environment=new Godot.Environment { BackgroundMode=Godot.Environment.BGMode.Color, BackgroundColor=new Color(0,0,0,0), GlowEnabled=true, GlowIntensity=.65f };
        camera.Environment=environment;AddChild(camera);
        var font=GD.Load<Font>("res://assets/fonts/BarlowCondensed-BoldItalic.ttf");
        var mesh=new TextMesh { Font=font, FontSize=96, PixelSize=.06f, Depth=.15f, HorizontalAlignment=HorizontalAlignment.Center, VerticalAlignment=VerticalAlignment.Center, Text="3" };
        material=new StandardMaterial3D { ShadingMode=BaseMaterial3D.ShadingModeEnum.Unshaded, AlbedoColor=new Color("ffc857"), EmissionEnabled=true, Emission=new Color("ffc857"), EmissionEnergyMultiplier=2 };
        letters=new MeshInstance3D { Mesh=mesh, MaterialOverride=material };
        rim=new MeshInstance3D { Mesh=mesh, Position=new Vector3(0,0,-.08f), Scale=Vector3.One*1.05f,
            MaterialOverride=new StandardMaterial3D { ShadingMode=BaseMaterial3D.ShadingModeEnum.Unshaded, AlbedoColor=new Color("102637") } };
        AddChild(rim);AddChild(letters);
        sparks=new CpuParticles3D { Emitting=false, OneShot=true, Amount=30, Lifetime=.5, Explosiveness=1,
            Direction=Vector3.Up, Spread=180, Gravity=Vector3.Zero, InitialVelocityMin=1, InitialVelocityMax=3,
            ScaleAmountMin=.09f, ScaleAmountMax=.18f, Mesh=new SphereMesh { Radius=.5f, Height=1,
                Material=new StandardMaterial3D { ShadingMode=BaseMaterial3D.ShadingModeEnum.Unshaded, AlbedoColor=new Color("67f6ff"), EmissionEnabled=true, Emission=new Color("67f6ff"), EmissionEnergyMultiplier=4 } } };
        AddChild(sparks);
        ringMaterial=new StandardMaterial3D { ShadingMode=BaseMaterial3D.ShadingModeEnum.Unshaded, AlbedoColor=new Color("67f6ff"), EmissionEnabled=true, Emission=new Color("67f6ff"), EmissionEnergyMultiplier=3, Transparency=BaseMaterial3D.TransparencyEnum.Alpha };
        ring=new MeshInstance3D { Mesh=new TorusMesh { InnerRadius=2.15f, OuterRadius=2.2f, Rings=48, RingSegments=8 }, MaterialOverride=ringMaterial, Rotation=new Vector3(Mathf.Pi*.5f,0,0), Position=new Vector3(0,0,-.2f) };
        AddChild(ring);Visible=false;
    }
    public void show_beat(string text,bool reducedMotion,bool glow)
    {
        reduced=reducedMotion;
        environment.GlowEnabled=glow && RenderingServer.GetCurrentRenderingMethod()!="gl_compatibility";
        if(text==last)return;
        last=text;
        if(GodotObject.IsInstanceValid(sequence)){RemoveChild(sequence);sequence.QueueFree();}
        if(text==""){Visible=false;sparks.Emitting=false;return;}
        sequence=new Sequence { Name="Countdown_Rokojori_Sequence",triggerDirectChildren=true,noOverlays=true };
        AddChild(sequence);
        sequence.AddChild(new FeedbackAction { Callback=()=> {
            age=0;Visible=true;((TextMesh)letters.Mesh).Text=text;
            material.AlbedoColor=new Color(text=="GO!"?"67f6ff":"ffc857");material.Emission=material.AlbedoColor;
            material.EmissionEnergyMultiplier=glow?2.2f:0;
            if(!reduced){sparks.Restart();sparks.Emitting=true;}
        }});
        sequence.AddChild(new FeedbackWait { Duration=.82 });
        sequence.Trigger();
    }
    public override void _Process(double delta)
    {
        age+=delta;
        if(!Visible)return;
        float t=(float)age;
        float scale=reduced?1:Mathf.Lerp(1.18f,1,Mathf.Clamp(t*6,0,1));
        letters.Scale=Vector3.One*scale;rim.Scale=Vector3.One*(scale*1.05f);
        letters.Rotation=new Vector3(0,reduced?0:.12f*Mathf.Exp(-t*8),0);rim.Rotation=letters.Rotation;
        ring.Visible=!reduced && t<.55f;
        ring.Scale=Vector3.One*(.8f+t*.9f);
        var ringColor=ringMaterial.AlbedoColor;ringColor.A=Mathf.Clamp(1-t/.55f,0,1);ringMaterial.AlbedoColor=ringColor;
        float alpha=1-Mathf.SmoothStep(.65f,.9f,t);
        material.Transparency=BaseMaterial3D.TransparencyEnum.Alpha;
        var color=material.AlbedoColor;color.A=alpha;material.AlbedoColor=color;
        rim.Visible=alpha>.25f;
    }
}
