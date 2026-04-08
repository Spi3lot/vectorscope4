using System;
using System.Buffers;
using System.IO.Pipelines;

using Godot;

using NAudio.Wave;


namespace Vectorscope.Scripts;

public class WaveProcessor
{

    public Pipe Pipe { get; } = new(new PipeOptions(pauseWriterThreshold: 0, resumeWriterThreshold: 0));

    public WaveFormat WaveFormat { get; set; }

    public int GetFramesAvailable()
    {
        if (!Pipe.Reader.TryRead(out var result))
        {
            return 0;
        }

        int available = (int) (result.Buffer.Length / WaveFormat.BlockAlign);
        Pipe.Reader.AdvanceTo(result.Buffer.Start, result.Buffer.Start);
        return available;
    }

    /// <summary>
    /// Reads and returns the requested amount of stereo audio frames as <code>Vector2</code>
    /// </summary>
    /// <param name="requestedFrameCount">
    ///     This parameter acts as ...
    ///     1. ... an upper limit to the amount of lines that are drawn per frame
    ///        in order to leave enough data for the next frame to visualize
    ///        so that the framerate does not drop unnecessarily.
    ///        This process can be thought of as "spreading across multiple frames"
    ///        or "inter-frame spreading" if you like.
    ///     2. ... a lower limit to the amount of lines that are drawn per frame
    ///        to make the program wait for more data to arrive
    ///        in order to not leave too much for the upcoming frames,
    ///        which otherwise could make them struggle with keeping
    ///        up a high and somewhat constant framerate.
    /// </param>
    /// <param name="scale">The factor to multiply each frame by</param>
    /// <returns>
    ///     A <code>Vector2[]</code> containing the requested amount of stereo audio frames
    ///     or nothing if there is not enough data available yet. 
    /// </returns>
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

        Pipe.Reader.AdvanceTo(reader.Position);
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
