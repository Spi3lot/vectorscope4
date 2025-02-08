using System;
using System.Collections.Generic;
using System.IO;

using Godot;

using NAudio.Wave;

namespace Vectorscope.Scripts;

public partial class WasapiLoopbackRecorder : Node
{

    private readonly WasapiLoopbackCapture _capture = new();

    private readonly WaveFormat _waveFormat;

    private readonly MemoryStream _memoryStream = new();

    private readonly BinaryReader _memoryReader;

    [Export]
    private bool _writeToFile;

    private WasapiLoopbackRecorder()
    {
        _waveFormat = _capture.WaveFormat;
        _memoryReader = new BinaryReader(_memoryStream);
    }

    public override void _EnterTree()
    {
        var memoryWriter = new WaveFileWriter(_memoryStream, _waveFormat);

        var fileWriter = (_writeToFile)
            ? new WaveFileWriter(new FileStream("audio/output.wav", FileMode.Create), _waveFormat)
            : null;

        _capture.DataAvailable += (_, args) =>
        {
            memoryWriter.Write(args.Buffer, 0, args.BytesRecorded);
            fileWriter?.Write(args.Buffer, 0, args.BytesRecorded);
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

    private long GetFramesAvailable() => _memoryStream.Length / _waveFormat.BlockAlign;

    private Vector2[] ReadStereo(long frames)
    {
        var vectors = new Vector2[frames];
        _memoryStream.Position = 0;
        
        for (long i = 0; i < frames; i++)
        {
            float x = _memoryReader.ReadSingle();
            float y = _waveFormat.Channels >= 2 ? _memoryReader.ReadSingle() : x;
            vectors[i] = new Vector2(x, y);

            for (int j = 0; j < _waveFormat.Channels - 2; j++)
            {
                _memoryReader.ReadSingle();
            }
        }

        if (_memoryStream.Position == _memoryStream.Length)
        {
            _memoryStream.Position = 0;
            _memoryStream.SetLength(0);
        }
        
        return vectors;
    }

}