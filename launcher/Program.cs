using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Text.Json;
using System.Windows.Forms;

namespace LeoRacerLauncher;
internal static class Program {
    [STAThread] static void Main(string[] args) {
        ApplicationConfiguration.Initialize();
        if (Array.Exists(args, a => a == "--self-test")) {
            if (!File.Exists(Path.Combine(AppContext.BaseDirectory, "Leo Racer.exe"))) Environment.Exit(1);
            return;
        }
        Application.Run(new Launcher());
    }
}
internal sealed class Launcher : Form {
    public Launcher() {
        Text = "Leo Racer · Colombo Motor Club";
        ClientSize = new Size(780, 470); FormBorderStyle = FormBorderStyle.FixedSingle;
        MaximizeBox = false; StartPosition = FormStartPosition.CenterScreen;
        Icon = System.Drawing.Icon.ExtractAssociatedIcon(Environment.ProcessPath!);
        BackColor = Color.FromArgb(13, 21, 32); ForeColor = Color.FromArgb(243, 225, 182);
        Font = new Font("Segoe UI", 11);
        using var source = Assembly.GetExecutingAssembly().GetManifestResourceStream("crest.png");
        var crest = Image.FromStream(source!);
        Controls.Add(new PictureBox { Image=crest, SizeMode=PictureBoxSizeMode.Zoom, Bounds=new Rectangle(12,55,350,350) });
        Controls.Add(new Label {Text="LEO RACER",Font=new Font("Segoe UI",30,FontStyle.Bold),Bounds=new Rectangle(380,57,380,64)});
        string version = "1.7.0";
        try { using var info=JsonDocument.Parse(File.ReadAllText(Path.Combine(AppContext.BaseDirectory,"build-manifest.json")));version=info.RootElement.GetProperty("version").GetString()!; } catch { }
        Controls.Add(new Label {Text=$"INSTALLED  v{version}\nCOLOMBO GRAND PRIX",ForeColor=Color.FromArgb(202,167,84),Bounds=new Rectangle(385,132,355,64)});
        AddButton("PLAY  →",214,true,()=>Play(false));
        AddButton("COMPATIBILITY MODE",277,false,()=>Play(true));
        AddButton("DOWNLOADS / UPDATES",340,false,()=>Process.Start(new ProcessStartInfo("https://github.com/amilapcsgit/Leo_Racer/releases") {UseShellExecute=true}));
        Controls.Add(new Label {Text="OFFLINE PLAY  ·  SIX RACERS  ·  YOUR COAST",ForeColor=Color.FromArgb(130,161,172),Bounds=new Rectangle(23,430,735,30),TextAlign=ContentAlignment.MiddleCenter});
    }
    void AddButton(string title,int y,bool primary,Action action) {
        var b=new Button {Text=title,Bounds=new Rectangle(385,y,352,49),FlatStyle=FlatStyle.Flat,BackColor=primary?Color.FromArgb(205,164,71):Color.FromArgb(26,41,57),ForeColor=primary?Color.FromArgb(12,22,33):ForeColor,Font=new Font("Segoe UI",12,FontStyle.Bold)};
        b.FlatAppearance.BorderColor=Color.FromArgb(205,164,71);b.Click+=(_,_)=>action();Controls.Add(b);
    }
    void Play(bool compatibility) {
        try { Process.Start(new ProcessStartInfo(Path.Combine(AppContext.BaseDirectory,"Leo Racer.exe")) {WorkingDirectory=AppContext.BaseDirectory,UseShellExecute=false,Arguments=compatibility?"--rendering-method gl_compatibility --rendering-driver opengl3":""}); }
        catch(Exception e) {MessageBox.Show(this,"Keep the complete game folder beside this launcher.\n\n"+e.Message,"Unable to start Leo Racer",MessageBoxButtons.OK,MessageBoxIcon.Error);}
    }
}
