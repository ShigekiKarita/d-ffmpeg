# d-ffmpeg-light: ffmpeg wrapper for D

[![Build Status](https://travis-ci.org/ShigekiKarita/d-ffmpeg-light.svg?branch=master)](https://travis-ci.org/ShigekiKarita/d-ffmpeg-light)
[![codecov](https://codecov.io/gh/ShigekiKarita/d-ffmpeg-light/branch/master/graph/badge.svg)](https://codecov.io/gh/ShigekiKarita/d-ffmpeg-light)


This library is thin wrapper to call ffmpeg to extract audio in subprocess.

## usage

install ffmpeg (there are static builds) https://www.ffmpeg.org/download.html

```d
import dffmpeg;
import std.stdio;
import std.net.curl;

void main() {
    // prepare audio supported by ffmpeg (e.g., mp3, wav, ..., etc)
    auto file = "test10k.wav";
    download("https://raw.githubusercontent.com/ShigekiKarita/torch-nmf-ss-toy/master/test10k.wav", file);

    // you can ask audio info to ffprobe
    assert(ask(file, "sample_rate").to!size_t == 10000);
    assert(ask(file, "channels").to!size_t == 1);

    // load audio (short is nice for PCM16 here)
    auto wav = Audio!short().load(file);
    assert(wav.data.length == 62518);
    assert(wav.sample_rate == 10000);
    assert(wav.sample_fmt.startsWith("s16"));

    // audio info now (maybe resampled or requantized)
    writeln(wav.now);
    // audi info then (origin settings)
    writeln(wav.then);

    // save audio
    auto file2 = "test.wav";
    wav.save(file2);
    // if you want to keep origin settings
    wav.save("origin.wav", false);

    // reload audio
    auto wav2 = Audio!short().load(file2);
    assert(wav == wav2);
}
```

for heavy usage, I recommend you  https://github.com/ljubobratovicrelja/ffmpeg-d
