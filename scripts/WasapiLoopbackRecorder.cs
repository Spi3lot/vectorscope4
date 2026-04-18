using System;
using System.Runtime.InteropServices;
using System.Threading;

using Godot;

using NAudio.CoreAudioApi;
using NAudio.Wave;

namespace Vectorscope.Scripts;

public partial class WasapiLoopbackRecorder : Node
{

    private readonly WasapiCapturePipeline _pipeline = new();

    private WasapiLoopbackCapture _capture;

    private CancellationTokenSource _cts;

    public double BufferLength
    {
        get => _pipeline.BufferLength;
        set => _pipeline.BufferLength = value;
    }

    public double SampleRate => _pipeline.WaveFormat.SampleRate;

    public int GetFramesAvailable() => _pipeline.GetFramesAvailable();

    public Vector2[] GetBuffer(int frames) => _pipeline.ReadStereo(frames);

    public void TogglePaused()
    {
        if (_capture.CaptureState == CaptureState.Stopped)
        {
            _cts = new CancellationTokenSource();
            _pipeline.Reset();
            _capture.StartRecording();
        }
        else
        {
            _capture.StopRecording();
        }
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
            _capture = new WasapiLoopbackCapture(); // Reinitialize on every start to update used audio output device
        }
        catch (COMException ex) when (ex.HResult == unchecked((int) 0x80070490)) // E_ELEMENT_NOT_FOUND
        {
            return Error.CantOpen;
        }

        _pipeline.WaveFormat = _capture.WaveFormat;

        if (_pipeline.WaveFormat.Encoding != WaveFormatEncoding.IeeeFloat)
        {
            return Error.CantResolve;
        }

        _cts = new CancellationTokenSource();
        _pipeline.Reset();
        _capture.RecordingStopped += RecordingStopped;
        _capture.DataAvailable += DataAvailable;
        _capture.StartRecording();
        return Error.Ok;
    }

    private Error StopRecording()
    {
        _capture?.Dispose();
        _capture = null;
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
        try
        {
            await _pipeline.WriteAsync(args, _cts.Token);
        }
        catch (OperationCanceledException)
        {
            // Recording stopped (probably because loopback mode was turned off)
        }
        catch (Exception ex)
        {
            GD.PushError(ex.ToString());
        }
    }

}
