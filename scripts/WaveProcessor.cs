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

    /// <summary>
    /// Reads and returns the requested amount of stereo audio frames
    /// </summary>
    /// <param name="requestedFrameCount">
    ///     This parameter exists to ...
    ///     1. ... set a maximum to the amount of lines that are drawn per frame
    ///        in order to leave enough data for the next frame to draw so that the framerate
    ///        does not artificially drop. This process can be thought of as "spreading across multiple frames"
    ///        or "inter-frame spreading" if you like.
    ///     2. ... set a minimum to the amount of lines that are drawn per frame
    ///        in order to retain clear visual feedback which would be lost when
    ///        not drawing enough lines in a single frame.
    /// </param>
    /// <param name="scale">The factor to multiply each frame by</param>
    /// <returns></returns>
    public Vector2[] ReadStereo(int requestedFrameCount, float scale = 1)
    {
        if (!Pipe.Reader.TryRead(out var result))
        {
            return [];
        }

        if (result.Buffer.Length < requestedFrameCount * WaveFormat.BlockAlign)
        {
            Pipe.Reader.AdvanceTo(result.Buffer.Start, result.Buffer.End);
            return [];
        }

        var reader = new SequenceReader<byte>(result.Buffer);
        var vectors = new Vector2[requestedFrameCount];

        for (int i = 0; i < requestedFrameCount; i++)
        {
            vectors[i] = scale * ReadStereoFrame(ref reader);
        }

        Pipe.Reader.AdvanceTo(reader.Position, reader.Position);
        return vectors;
    }

    private Vector2 ReadStereoFrame(ref SequenceReader<byte> reader)
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
