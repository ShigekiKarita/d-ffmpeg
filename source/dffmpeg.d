/++
ffmpeg audio wrapper for D
 +/

import std.file : exists;
import std.conv : to, emplace;
import std.process : execute, Config;
import std.format : formattedRead;
import std.exception : enforce;
import std.typecons : tuple;


/// Map D's type string into ffmpeg type string
enum ffmpegTypes = [
    "double": "f64le",
    "float": "f32le",
    "short": "s16le",
    "int": "s32le",
    "uint": "u32le"
    ];


/++
Ask query (e.g., sample_rate, channels) to ffmpeg

Params:
    filename = path to the audio file

Returns:
    query result
+/
T ask(T, string query)(string filename, string loglevel="quiet")
{
    auto x = execute(["ffprobe", "-loglevel", loglevel, "-show_streams", filename]);
    enforce(x.status == 0);
    import std.string;
    import std.algorithm : filter;
    auto line = x.output.lineSplitter.filter!(s => s.startsWith(query)).front;
    string result;
    line.formattedRead!(query ~ "=%s")(result);
    return result.to!T;
}

/++
Loads audio via the ffmpeg process

Params:
     T = (default short as "s16le") reading PCM type
     filename = path to audio
     sampleRate = sampling rate of audio (default 44100)
     channels = number of channels (default 1)
     normalize = normalize gain if true (default true)

See_Also: https://gist.github.com/kylemcdonald/85d70bf53e207bab3775
 +/
auto loadAudio(T=short)(string filename, size_t sampleRate=0, size_t channels=1, string loglevel="quiet")
{

    enforce(filename.exists);
    if (sampleRate == 0)
    {
        sampleRate = ask!(size_t, "sample_rate")(filename);
    }
    if (channels == 0)
    {
        channels = ask!(size_t, "channels")(filename);
    }
    enum ft = ffmpegTypes[T.stringof];
    auto command = [
        "ffmpeg",
        "-i", filename,
        "-loglevel", loglevel,
        "-f", ft,
        "-acodec", "pcm_" ~ ft,
        "-ar", sampleRate.to!string,
        "-ac", channels.to!string,
        "-"
        ];
    auto p = execute(command);
    enforce(p.status == 0);
    auto data = cast(T[]) p.output;
    return tuple!("data", "sampleRate", "channels")(data, sampleRate, channels);
}


unittest
{
    import std.net.curl;
    auto file = "test10k.wav";
    download("https://raw.githubusercontent.com/ShigekiKarita/torch-nmf-ss-toy/master/test10k.wav", file);
    assert(ask!(long, "sample_rate")(file) == 10000);
    assert(ask!(long, "channels")(file) == 1);
    import std.stdio;
    auto wav = loadAudio(file);
    assert(wav.data.length == 62518);
}
