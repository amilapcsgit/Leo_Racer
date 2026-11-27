using Godot;
using Rokojori;

/// <summary>Presentation-only Rokojori sequences; never changes vehicle state.</summary>
public partial class RaceFeedbackBridge : Node
{
    private Sequence boostSequence;
    private double boostAge = 99, clock, shakeTime, recoverTime;
    private float shakeStrength, peak = 14, hold = 9;
    private bool boostActive, reduced;
    private float activePeak = 14, activeHold = 9;
    private double driftAge = 99;
    private double driftDuration;
    private float driftPeak;
    public int sequence_count { get; private set; }

    public override void _Ready() { ProcessMode = ProcessModeEnum.Pausable; ProcessPriority = -10; }
    public void configure(float peakDegrees, float holdDegrees) { peak = peakDegrees; hold = holdDegrees; }
    public void set_reduced_motion(bool value) { reduced = value; if (value) reset_feedback(); }

    public void play_boost(string source, double duration) => play_boost_explicit("nitro", 0, duration);
    public void play_boost_explicit(string kind, int tier, double duration)
    {
        if (kind == "drift") {
            driftAge = 0; driftDuration = duration; driftPeak = tier >= 2 ? 10 : 6;
            if (!reduced) { shakeTime = tier >= 2 ? .18 : .12; shakeStrength = tier >= 2 ? .20f : .12f; }
            return;
        }
        activePeak = kind == "drift" ? (tier >= 2 ? 10 : 6) : peak;
        activeHold = kind == "drift" ? 0 : hold;
        activePeak = Mathf.Clamp(activePeak, 0, 14);
        if (kind == "drift" && !reduced) { shakeTime = tier >= 2 ? .18 : .12; shakeStrength = tier >= 2 ? .20f : .12f; }
        clear_sequence();
        boostSequence = new Sequence { Name = "Nitro_Rokojori_Sequence", triggerDirectChildren = true, noOverlays = true };
        AddChild(boostSequence);
        var begin = new FeedbackAction { Name = "Ignition", Callback = () => { boostAge = 0; boostActive = true; } };
        var sustain = new FeedbackWait { Name = "Sustain", Duration = duration };
        var end = new FeedbackAction { Name = "CoolDown", Callback = () => boostActive = false };
        boostSequence.AddChild(begin); boostSequence.AddChild(sustain); boostSequence.AddChild(end);
        boostSequence.Trigger();
        sequence_count++;
    }
    public void set_boost_active(bool active) { if (!active) { boostActive = false; driftAge = 99; } }
    public void play_impact(float strength) { shakeTime = .28; shakeStrength = Mathf.Clamp(strength, 0, 1); }
    public void play_recover() { reset_feedback(); recoverTime = .20; }
    public void reset_feedback()
    {
        clear_sequence(); boostAge = driftAge = 99; boostActive = false; shakeTime = recoverTime = 0;
    }
    private void clear_sequence()
    {
        if (GodotObject.IsInstanceValid(boostSequence))
        {
            // Removing the entire private sequence cancels its clock and listeners.
            RemoveChild(boostSequence); boostSequence.QueueFree();
        }
        boostSequence = null;
    }
    public override void _Process(double delta)
    {
        clock += delta; boostAge += delta; driftAge += delta;
        shakeTime = System.Math.Max(0, shakeTime - delta);
        recoverTime = System.Math.Max(0, recoverTime - delta);
    }
    public float get_boost_gain() => boostActive || driftAge < driftDuration ? 1 : 0;
    public float get_fov_offset()
    {
        if (reduced) return 0;
        float drift = driftAge < .1 ? driftPeak * Mathf.SmoothStep(0, 1, (float)driftAge / .1f)
            : driftPeak * (1 - Mathf.SmoothStep(0, 1, (float)(driftAge - .1) / .32f));
        float nitro = !boostActive ? 0 : boostAge < .1 ? activePeak * Mathf.SmoothStep(0, 1, (float)boostAge / .1f)
            : Mathf.Lerp(activePeak, activeHold, Mathf.SmoothStep(0, 1, (float)(boostAge - .1) / .22f));
        return Mathf.Clamp(drift + nitro, 0, 14);
    }
    public float get_shake_roll() => reduced ? 0 : (float)(System.Math.Sin(clock * 92) * shakeTime * shakeStrength * .06);
    public Vector3 get_shake_offset() => reduced ? Vector3.Zero : new Vector3(
        (float)System.Math.Sin(clock * 89), (float)System.Math.Cos(clock * 73), 0) * (float)shakeTime * shakeStrength * .72f;
    public float get_recover_glitch() => reduced ? 0 : (float)recoverTime / .20f;
    public override void _ExitTree() { boostActive = false; }
}

// These tiny actions adapt game-specific callbacks to the actual Rokojori runner.
public partial class FeedbackAction : Rokojori.Action
{
    public System.Action Callback;
    protected override void _OnTrigger() => Callback?.Invoke();
}
public partial class FeedbackWait : SequenceAction
{
    public double Duration;
    private double elapsed;
    private int runId;
    private bool running;
    protected override void _OnTrigger() { elapsed = 0; runId = DispatchStart(); running = true; }
    public override void _Process(double delta)
    {
        if (!running) return;
        elapsed += delta;
        if (elapsed >= Duration) { running = false; DispatchEnd(runId); }
    }
}
