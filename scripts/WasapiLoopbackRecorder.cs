using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;

using Godot;

using NAudio.Wave;

namespace Vectorscope.Scripts;

public partial class WasapiLoopbackRecorder : Node
{

    private const double DefaultFps = 60;

    private readonly SemaphoreSlim _writeSemaphore = new(1, 1);

    private readonly WaveProcessor _waveProcessor = new();

    private WasapiLoopbackCapture _capture;

    private long _lastUpdateDtTimestamp;

    public float Scale { get; set; } = 1;

    public double SampleRate => _waveProcessor.WaveFormat.SampleRate;

    public double DeltaTime { get; private set; } = 1 / DefaultFps;

    public int OptimalFrameBufferSize(double sampleRate)
    {
        int size = Mathf.RoundToInt(sampleRate * DeltaTime);
        return 1024; // Returning the bigger even number to reduce latency, at least on odd sizes.
    }

    public void UpdateDeltaTime()
    {
        DeltaTime = CalculateDeltaTime();
        _lastUpdateDtTimestamp = Stopwatch.GetTimestamp();
    }

    private double CalculateDeltaTime()
    {
        return (_lastUpdateDtTimestamp != 0)
            ? Stopwatch.GetElapsedTime(_lastUpdateDtTimestamp).TotalSeconds
            : 1 / GetMaxFps();
    }

    private static double GetMaxFps()
    {
        if (Engine.MaxFps > 0)
        {
            return Engine.MaxFps;
        }

        float refreshRate = DisplayServer.ScreenGetRefreshRate();
        return (refreshRate <= 0) ? DefaultFps : refreshRate;
    }

    public Error SetRecording(bool value)
    {
        try
        {
            return (value) ? StartRecording() : StopRecording();
        }
        catch (Exception ex)
        {
            GD.PushError(ex.ToString());
            return Error.Failed;
        }
    }

    private Error StartRecording()
    {
        try
        {
            _capture = new WasapiLoopbackCapture();
        }
        catch (COMException ex) when (ex.HResult == unchecked((int) 0x80070490)) // E_ELEMENT_NOT_FOUND
        {
            return Error.CantOpen;
        }

        _capture.DataAvailable += async (_, args) =>
        {
            await _writeSemaphore.WaitAsync();

            try
            {
                await _waveProcessor.Pipe.Writer.WriteAsync(args.Buffer.AsMemory(0, args.BytesRecorded));
            }
            finally
            {
                _writeSemaphore.Release();
            }
        };

        _waveProcessor.WaveFormat = _capture.WaveFormat;
        _capture.StartRecording();
        return Error.Ok;
    }

    private Error StopRecording()
    {
        _capture.Dispose();
        _capture = null;
        _waveProcessor.Pipe.Writer.Complete();
        _waveProcessor.Pipe.Reader.Complete();
        _waveProcessor.Pipe.Reset();
        return Error.Ok;
    }

    public Vector2[] GetBuffer(int frames) => _waveProcessor.ReadStereo(frames, Scale);

}
