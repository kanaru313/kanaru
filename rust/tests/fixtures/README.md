# Audio fixtures

Tiny audio files used by the Rust tests. Most were made earlier; the four
below were generated with the system `ffmpeg` (each under 20 KB):

```sh
S="sine=frequency=440:duration=2:sample_rate=44100"
ffmpeg -f lavfi -i "$S" -ac 2 -c:a aac -b:a 32k -movflags +faststart sample_aac.m4a   # AAC-LC in MP4
ffmpeg -f lavfi -i "$S" -ac 2 -c:a aac -b:a 32k -f adts sample.aac                    # AAC in ADTS
ffmpeg -f lavfi -i "sine=frequency=440:duration=0.12:sample_rate=96000" -ac 1 \
  -sample_fmt s32 -c:a flac -bits_per_raw_sample 24 sample_96k24.flac                 # 96 kHz, 24-bit
ffmpeg -f lavfi -i "sine=frequency=440:duration=1:sample_rate=8000" -ac 6 \
  -c:a flac sample_6ch.flac                                                           # 6 channels
```
