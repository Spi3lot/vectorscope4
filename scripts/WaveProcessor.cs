using System;
using System.Buffers;
using System.IO.Pipelines;

using Godot;

using NAudio.Wave;


namespace Vectorscope.Scripts;

public class WaveProcessor
{

    public Pipe Pipe { get; } = new();

    public WaveFormat WaveFormat { get; set; }

    public long GetFramesAvailable()
    {
        if (!Pipe.Reader.TryRead(out var result))
        {
            return 0;
        }

        long frameCount = result.Buffer.Length / WaveFormat.BlockAlign;
        Pipe.Reader.AdvanceTo(result.Buffer.Start);
        return frameCount;
    }

    public Vector2[] ReadStereo(int frames, float scale = 1)
    {
        if (!Pipe.Reader.TryRead(out var result))
        {
            return [];
        }

        var reader = new SequenceReader<byte>(result.Buffer);
        var vectors = new Vector2[frames];

        for (int i = 0; i < frames; i++)
        {
            vectors[i] = scale * ReadStereo(ref reader);
        }

        Pipe.Reader.AdvanceTo(result.Buffer.End);
        return vectors;
    }

    private Vector2 ReadStereo(ref SequenceReader<byte> reader)
    {
        float x = ReadSingleLittleEndian(ref reader);
        int usedChannels = int.Min(WaveFormat.Channels, 2);

        float y = usedChannels switch
        {
            1 => x,
            2 => ReadSingleLittleEndian(ref reader),
            _ => throw new InvalidOperationException("Cannot have less than 1 channel: " + usedChannels),
        };

        reader.Advance((WaveFormat.Channels - usedChannels) * sizeof(float));
        return new Vector2(x, y);
    }

    private static float ReadSingleLittleEndian(ref SequenceReader<byte> reader)
    {
        return (reader.TryReadLittleEndian(out int bits))
            ? BitConverter.Int32BitsToSingle(bits)
            : throw new InvalidOperationException("Not enough data, at least 4 bytes required.");
    }

}
