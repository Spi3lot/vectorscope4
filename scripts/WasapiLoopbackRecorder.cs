using System;
using System.Diagnostics;
using System.IO;

using Godot;

using NAudio.Wave;

namespace Vectorscope.Scripts;

public partial class WasapiLoopbackRecorder : Node
{

    private readonly ConcurrentWaveStream _stream = new(new MemoryStream());

    private WasapiLoopbackCapture _capture;

    private long _lastUpdateFpsTimestamp;

    public float Scale { get; set; } = 1;

    public int FrameBufferSize
    {
        get
        {
            int size = FrameBufferSizeUnsafe;
            return size + size % 2; // Returning the bigger even number to ensure we are not lagging behind.
        }
    }

    private int FrameBufferSizeUnsafe => Convert.ToInt32(double.Round(FrameBufferSizeRaw, MidpointRounding.ToEven));

    private double FrameBufferSizeRaw => _stream.WaveFormat.SampleRate / Fps;

    public double Fps { get; private set; }

    public void UpdateFps()
    {
        if (_lastUpdateFpsTimestamp != 0)
        {
            Fps = 1 / Stopwatch.GetElapsedTime(_lastUpdateFpsTimestamp).TotalSeconds;
        }
        else if (Engine.MaxFps > 0)
        {
            Fps = Engine.MaxFps;
        }
        else
        {
            float refreshRate = DisplayServer.ScreenGetRefreshRate();
            Fps = (refreshRate > 0) ? refreshRate : double.PositiveInfinity;
        }

        _lastUpdateFpsTimestamp = Stopwatch.GetTimestamp();
    }

    public void SetRecording(bool value)
    {
        if (!value)
        {
            _capture.Dispose();
            _capture = null;
            _stream.Clear();
            return;
        }

        _capture = new WasapiLoopbackCapture();
        _stream.WaveFormat = _capture.WaveFormat;
        _capture.DataAvailable += (_, args) => _stream.Write(args.Buffer, 0, args.BytesRecorded);
        _capture.StartRecording();
    }

    public int GetFramesAvailable() => (int) _stream.GetFramesAvailable();

    public Vector2[] GetBuffer(int frames) => _stream.ReadStereo(frames, Scale);

}
