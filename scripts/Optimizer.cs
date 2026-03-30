using Godot;

using PidSharp;

namespace Vectorscope.Scripts;

public partial class Optimizer : Node
{


    private readonly PidController _pidController = new(
        1,
        1,
        1,
        4096,
        32
    ) { TargetValue = 0 };

    public static Optimizer Instance { get; private set; }

    public int FrameBufferSize => Mathf.RoundToInt(_pidController.ControlOutput);

    public int SampleRate
    {
        get;
        set
        {
            field = value;
            UpdateCurrentValue();
        }
    }

    public double FramesPerSecond
    {
        get;
        set
        {
            field = value;
            UpdateCurrentValue();
        }
    }

    private void UpdateCurrentValue()
    {
        // TODO: Control using PID ((SampleRate / BufferSize) / MeasuredVectorscopeFPS should have target 1)
        //       bzw. ((SampleRate / BufferSize) / MeasuredVectorscopeFPS should have target 0
        //       oh and maybe not MeasuredVectorscopeFPS but rather DesiredVectorscopeFPS or smthn
        _pidController.CurrentValue = (double) SampleRate / FrameBufferSize - FramesPerSecond;
    }

    public override void _EnterTree()
    {
        if (Instance is not null)
        {
            GD.PushWarning("Tried to manually instantiate an autoload");
            QueueFree();
            return;
        }
        
        Instance = this;
    }

}