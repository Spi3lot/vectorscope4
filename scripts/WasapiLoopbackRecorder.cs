using System.IO;

using Godot;

using NAudio.Wave;

namespace Vectorscope.Scripts;

public partial class WasapiLoopbackRecorder : Node
{

    private readonly ConcurrentWaveStream _stream = new(new MemoryStream());

    private WasapiLoopbackCapture _capture;

    public float Scale { get; set; } = 1;

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