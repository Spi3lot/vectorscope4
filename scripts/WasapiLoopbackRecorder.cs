using System.IO;

using Godot;

using NAudio.Wave;

namespace Vectorscope.Scripts;

public partial class WasapiLoopbackRecorder : Node
{

    private readonly object _streamLock = new();

    private readonly MemoryStream _memoryStream = new();

    private readonly BinaryReader _memoryReader;

    private WasapiLoopbackCapture _capture;

    private WaveFormat _waveFormat;

    [Export]
    private bool _writeToFile;

    private WasapiLoopbackRecorder()
    {
        _memoryReader = new BinaryReader(_memoryStream);
    }

    private float Scale { get; set; } = 1;

    public void SetRecording(bool value)
    {
        if (!value)
        {
            _capture.Dispose();
            _capture = null;
            _waveFormat = null;
            return;
        }

        _capture = new WasapiLoopbackCapture();
        _waveFormat = _capture.WaveFormat;

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
        _capture.StartRecording();
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