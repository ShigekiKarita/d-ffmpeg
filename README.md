# d-ffmpeg-light: ffmpeg wrapper for D

This library is thin wrapper to call ffmpeg to extract audio in subprocess.

## usage

```d
import dffmpeg;
import std.net.curl;

void main() {
    // prepare audio supported by ffmpeg (e.g., mp3, wav, ..., etc)
    auto file = "test10k.wav";
    download("https://raw.githubusercontent.com/ShigekiKarita/torch-nmf-ss-toy/master/test10k.wav", file);

    // auto detect using ffprobe
    assert(ask!(long, "sample_rate")(file) == 10000);
    assert(ask!(long, "channels")(file) == 1);

    // loading the audio, you can specify
    // any quatized type T from (double, float, short(recommended), int, uint)
    // verbosity from from ("quiet" (default), "error", "warning", ..., "debug")
    auto wav = loadAudio!short(file, 10000, 1, "quiet");
    assert(wav.sampleRate == 10000);
    assert(wav.channels == 1);
    assert(wav.data.length == 62518); // data is short[] array
}
```

for heavy usage, I recommend you  https://github.com/ljubobratovicrelja/ffmpeg-d
