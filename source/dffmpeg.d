/++
ffmpeg audio wrapper for D
 +/

import std.stdio;
import std.algorithm : filter;
import std.format : formattedRead, format;
import std.string : startsWith, lineSplitter, join;
import std.file : exists;
import std.conv : to;
import std.process : execute, Config, pipeProcess, Redirect, wait;
import std.exception : enforce;
import std.typecons : tuple;

version(BigEndian) enum endian = "be";
version(LittleEndian) enum endian = "le";

/// Map D's type string into ffmpeg type string
enum d2ffmpegType = [
    "double": "f64",
    "float": "f32",
    "short": "s16",
    "int": "s32",
    "uint": "u32"
    ];


/++
Ask query (e.g., sample_rate, channels) to ffmpeg

Params:
    filename = path to the audio file

Returns:
    query result
+/
string[string] ask(string filename, string[] query, string loglevel="quiet")
{
    enforce(filename.exists);
    immutable command = ["ffprobe", "-loglevel", loglevel, "-show_streams", filename];
    if (loglevel == "debug") command.join(" ").writeln;
    immutable x = execute(command, null, Config.stderrPassThrough);
    enforce(x.status == 0);
    string[string] result;
    foreach (line; x.output.lineSplitter)
    {
        foreach (q; query)
        {
            if (line.startsWith(q)) {
                string r;
                line.formattedRead(q ~ "=%s", r);
                result[q] = r;
            }
        }
    }
    foreach (q; query)
    {
        enforce(q in result, "A query (%s) is not found in a file (%s)".format(q, filename));
    }
    return result;
}

///ditto
string ask(string filename, string query, string loglevel="quiet")
{
    return ask(filename, [query], loglevel)[query];
}

struct AudioInfo
{
    size_t sample_rate;
    size_t channels;
    string sample_fmt;
    string codec_name;

    static load(string filename, string loglevel="quiet")
    {
        AudioInfo ret;
        import std.traits : FieldNameTuple;
        alias nametup = FieldNameTuple!AudioInfo;
        string[nametup.length] names;
        foreach (i, v; nametup) names[i] = v;
        auto result = ask(filename, names, loglevel);
        foreach(k, ref v; ret.tupleof)
        {
            v = result[names[k]].to!(typeof(v));
        }
        return ret;
    }
}

/// Audio array and information struct
struct Audio(T=short)
{
    AudioInfo now, then;
    alias now this;

    /// signal array shaped as (frames * channels)
    T[] data;

    /++
    Loads audio via the ffmpeg process

    Params:
        filename = path to audio
        sampleRate = sampling rate of audio (default 44100)
        channels = number of channels (default 1)
        normalize = normalize gain if true (default true)

    Returns: this

    See_Also: https://gist.github.com/kylemcdonald/85d70bf53e207bab3775
     +/
    auto load(string filename, size_t sampleRate=0, size_t channels=0, string loglevel="quiet")
    {
        enforce(filename.exists);
        enum ft = d2ffmpegType[T.stringof] ~ endian;
        enum acodec = "pcm_" ~ ft;
        this.then = AudioInfo.load(filename, loglevel);
        this.now = AudioInfo(sampleRate == 0 ? then.sample_rate : sampleRate,
                             channels == 0 ? then.channels : channels,
                             ft, acodec);
        immutable command = [
            "ffmpeg",
            "-i", filename,
            "-loglevel", loglevel,
            "-f", ft,
            "-acodec", acodec,
            "-ar", now.sample_rate.to!string,
            "-ac", now.channels.to!string,
            "-"
            ];
        if (loglevel == "debug") stderr.writeln(command.join(" "));
        auto p = execute(command, null, Config.stderrPassThrough);
        enforce(p.status == 0);
        data = cast(T[]) p.output;
        return this;
    }

    /++
    Write audio via the ffmpeg process

    Params:
        filename = path to output audio
        useNow = use AudioInfo now for the output if true, otherwise use AudioInfo then

    Returns: this
      +/
    auto save(string filename, bool useNow=true, string loglevel="quiet")
    {
        const info = useNow ? now : then;
        immutable command = [
            "ffmpeg",
            "-loglevel", loglevel,
            "-f", info.sample_fmt,
            "-acodec", info.codec_name,
            "-ar", info.sample_rate.to!string,
            "-ac", info.channels.to!string,
            "-i", "pipe:0",
            "-y", // overwrite
            filename
            ];
        if (loglevel == "debug") stderr.writeln(command.join(" "));
        auto pipes = pipeProcess(command, Redirect.stdin);
        pipes.stdin.rawWrite(data);
        pipes.stdin.flush();
        pipes.stdin.close();
        wait(pipes.pid);
        return this;
    }
}

unittest
{
    import std.file : exists;
    import std.net.curl : download;

    // prepare audio supported by ffmpeg (e.g., mp3, wav, ..., etc)
    auto file = "test10k.wav";
    if (!file.exists)
    {
        download("https://raw.githubusercontent.com/ShigekiKarita/torch-nmf-ss-toy/master/test10k.wav", file);
    }
    assert(ask(file, "sample_rate").to!size_t == 10000);
    assert(ask(file, "channels").to!size_t == 1);

    // load audio
    auto wav = Audio!short().load(file, 0, 0, "debug");
    assert(wav.data.length == 62518);
    assert(wav.sample_rate == 10000);
    assert(wav.sample_fmt.startsWith("s16"));

    // save audio
    auto file2 = "test.wav";
    wav.save(file2, true, "debug");

    // reload audio
    auto wav2 = Audio!short().load(file2);
    assert(wav == wav2);
}
