using System;
using System.Buffers.Binary;
using System.IO;

using Godot;

using NAudio.Wave;


namespace Vectorscope.Scripts;

public class ConcurrentWaveStream(MemoryStream stream)
{

    private readonly object _lock = new();

    public MemoryStream BaseStream { get; } = stream;

    public WaveFormat WaveFormat { get; set; }

    public long GetFramesAvailable()
    {
        long length;

        lock (_lock)
        {
            length = BaseStream.Length;
        }

        return length / WaveFormat.BlockAlign;
    }

    public void Clear()
    {
        lock (_lock)
        {
            BaseStream.SetLength(0);
        }
    }

    public void Write(byte[] buffer, int offset, int count)
    {
        lock (_lock)
        {
            BaseStream.Seek(0, SeekOrigin.End);
            BaseStream.Write(buffer, offset, count);
        }
    }

    public Vector2[] ReadStereo(int frames, float scale = 1)
    {
        byte[] buffer = new byte[WaveFormat.BlockAlign * frames];

        lock (_lock)
        {
            BaseStream.Seek(0, SeekOrigin.Begin);
            TruncateReadBytes(BaseStream.Read(buffer, 0, buffer.Length));
        }

        var vectors = new Vector2[frames];

        for (int i = 0; i < vectors.Length; i++)
        {
            vectors[i] = scale * ReadStereo(buffer, WaveFormat.BlockAlign * i);
        }

        return vectors;
    }

    private Vector2 ReadStereo(byte[] buffer, int startIndex)
    {
        float x = ReadSingleLittleEndian(buffer, startIndex);
        float y = (WaveFormat.Channels == 1) ? x : ReadSingleLittleEndian(buffer, startIndex + sizeof(float));
        return new Vector2(x, y);
    }

    private static float ReadSingleLittleEndian(byte[] buffer, int startIndex)
    {
        return BinaryPrimitives.ReadSingleLittleEndian(buffer.AsSpan(startIndex, sizeof(float)));
    }

    private void TruncateReadBytes(int bytes)
    {
        byte[] buffer = BaseStream.GetBuffer();
        Buffer.BlockCopy(buffer, bytes, buffer, 0, (int) (BaseStream.Length - bytes));
        BaseStream.SetLength(BaseStream.Length - bytes);
    }

}