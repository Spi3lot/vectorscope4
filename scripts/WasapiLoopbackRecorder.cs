using System;
using System.Collections.Generic;
using System.IO;
using System.Threading;

using Godot;

using NAudio.Wave;

namespace Vectorscope.Scripts;

public partial class WasapiLoopbackRecorder : Node
{

    private readonly WasapiLoopbackCapture _capture = new();

    private readonly WaveFormat _waveFormat;

    private readonly MemoryStream _memoryStream = new();

    private readonly BinaryReader _memoryReader;
    
    private readonly object _streamLock = new();

    [Export]
    private bool _writeToFile;

    private WasapiLoopbackRecorder()
    {
        _waveFormat = _capture.WaveFormat;
        _memoryReader = new BinaryReader(_memoryStream);
    }

    private float Scale { get; set; } = 1;

    public override void _EnterTree()
    {
        var memoryWriter = new WaveFileWriter(_memoryStream, _waveFormat);

        var fileWriter = (_writeToFile)
            ? new WaveFileWriter(new FileStream("audio/output.wav", FileMode.Create), _waveFormat)
            : null;

        _capture.DataAvailable += (_, args) =>
        {
            fileWriter?.Write(args.Buffer, 0, args.BytesRecorded);
            
            lock (_streamLock)
            {
                memoryWriter.Write(args.Buffer, 0, args.BytesRecorded);
            }
        };

        _capture.RecordingStopped += (_, _) => fileWriter?.Dispose();
    }

    public override void _ExitTree()
    {
        _capture.Dispose();
    }

    private void SetRecording(bool value)
    {
        if (value) _capture.StartRecording();
        else _capture.StopRecording();
    }

    public long GetFramesAvailable() => _memoryStream.Length / _waveFormat.BlockAlign;

    private Vector2[] ReadStereo(long frames)
    {
        var vectors = new Vector2[frames];

        lock (_streamLock)
        {
            for (long i = 0; i < frames; i++)
            {
                _memoryStream.Position = i * _waveFormat.BlockAlign;
                float x = _memoryReader.ReadSingle();
                float y = (_waveFormat.Channels >= 2) ? _memoryReader.ReadSingle() : x;
                vectors[i] = new Vector2(x, y) * Scale;
            }

            _memoryStream.Position = 0;
            _memoryStream.SetLength(0);
        }

        return vectors;
    }

}