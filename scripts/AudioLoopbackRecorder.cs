using System;
using System.IO;

using NAudio.Wave;

namespace Vectorscope.Scripts;

public static class AudioLoopbackRecorder
{

    private static readonly MemoryStream Stream = new();

    static AudioLoopbackRecorder()
    {
        var capture = new WasapiLoopbackCapture();
        var writer = new WaveFileWriter(Stream, capture.WaveFormat);

        capture.DataAvailable += (_, args) =>
        {
            Console.WriteLine(args.Buffer.Length);
            Console.WriteLine(args.BytesRecorded);
            Console.WriteLine();
            writer.Write(args.Buffer, 0, args.BytesRecorded);

            if (writer.Position > capture.WaveFormat.AverageBytesPerSecond * 20)
            {
                capture.StopRecording();
            }
        };

        capture.RecordingStopped += (_, _) =>
        {
            writer.Dispose();
            capture.Dispose();
        };

        capture.StartRecording();
    }

    // TODO: or .ToArray()?
    public static byte[] Buffer { get; } = Stream.GetBuffer();

}