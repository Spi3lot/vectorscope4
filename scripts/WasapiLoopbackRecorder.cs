using System;
using System.Runtime.InteropServices;
using System.Threading;

using Godot;

using NAudio.Wave;

namespace Vectorscope.Scripts;

public partial class WasapiLoopbackRecorder : Node
{

    private readonly SemaphoreSlim _writeSemaphore = new(1, 1);

    private readonly WaveProcessor _waveProcessor = new();

    private WasapiLoopbackCapture _capture;

    private CancellationTokenSource _cts;

    public float Scale { get; set; } = 1;

    public double SampleRate => _waveProcessor.WaveFormat.SampleRate;

    public int GetFramesAvailable() => _waveProcessor.GetFramesAvailable();

    public Vector2[] GetBuffer(int frames) => _waveProcessor.ReadStereo(frames, Scale);

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

        _waveProcessor.WaveFormat = _capture.WaveFormat;

        if (_waveProcessor.WaveFormat.Encoding != WaveFormatEncoding.IeeeFloat)
        {
            return Error.CantResolve;
        }

        _cts = new CancellationTokenSource();
        _capture.RecordingStopped += RecordingStopped;
        _capture.DataAvailable += DataAvailable;
        _capture.StartRecording();
        return Error.Ok;
    }

    private Error StopRecording()
    {
        _capture?.Dispose();
        _capture = null;
        _waveProcessor.Pipe.Writer.Complete();
        _waveProcessor.Pipe.Reader.Complete();
        _waveProcessor.Pipe.Reset();
        return Error.Ok;
    }

    private async void RecordingStopped(object sender, StoppedEventArgs args)
    {
        try
        {
            if (args.Exception is not null)
            {
                GD.PushError(args.Exception.ToString());
            }

            await _cts.CancelAsync();
            _cts.Dispose();
            _cts = null;
        }
        catch (Exception ex)
        {
            GD.PushError(ex.ToString());
        }
    }

    private async void DataAvailable(object sender, WaveInEventArgs args)
    {
        bool semaphoreAcquired = false;

        try
        {
            await _writeSemaphore.WaitAsync(_cts.Token);
            semaphoreAcquired = true;

            await _waveProcessor.Pipe.Writer.WriteAsync(
                args.Buffer.AsMemory(0, args.BytesRecorded),
                _cts.Token);
        }
        catch (OperationCanceledException)
        {
            // Recording stopped (probably because loopback mode was turned off)
        }
        catch (Exception ex)
        {
            GD.PushError(ex.ToString());
        }
        finally
        {
            if (semaphoreAcquired)
            {
                _writeSemaphore.Release();
            }
        }
    }

}
