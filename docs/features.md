# Kanaru — Danh sách tính năng chi tiết

Tài liệu này chi tiết hoá phần **Features** và **Roadmap** trong [`README.md`](../README.md). Mỗi tính năng có ID ổn định để tham chiếu trong plan, issue và commit.

Tham khảo chính: [Harmonoid](https://harmonoid.com) ([GitHub](https://github.com/harmonoid/harmonoid)). Những mục Harmonoid đã có được đánh dấu **H**.

## Quy ước

| Cột         | Ý nghĩa                                                                                                                 |
| ----------- | ----------------------------------------------------------------------------------------------------------------------- |
| **ID**      | `<NHÓM>-<số>`, ví dụ `PLAY-03`. Không đổi ID khi sửa mô tả.                                                             |
| **Ưu tiên** | **P0**: bắt buộc cho bản dùng được đầu tiên · **P1**: cần có trước 1.0 · **P2**: nên có · **P3**: ý tưởng, làm khi rảnh |
| **Phase**   | Phase trong roadmap của README (0–4)                                                                                    |
| **H**       | Harmonoid có tính năng này                                                                                              |
| **Gói**     | `Free` hoặc `Premium?` (premium chỉ là đề xuất, chưa chốt — xem [Premium](#20-premium-đề-xuất))                         |

Nếu không ghi gói thì mặc định là `Free`. Mọi tính năng cốt lõi của một player offline đều miễn phí.

---

## 1. Phát nhạc (engine)

Dùng `media_kit` (libmpv). Logic player nằm trong `lib/core/player/`.

| ID      | Tính năng                             | Mô tả / tiêu chí hoàn thành                                                                                                                                                                                                                                         | Ưu tiên | Phase | H   |
| ------- | ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- | ----- | --- |
| PLAY-01 | Phát file local                       | Phát được MP3, FLAC, ALAC, AAC/M4A, OGG Vorbis, Opus, WAV, AIFF, APE, WavPack, DSD (DSF/DFF) qua libmpv                                                                                                                                                             | P0      | 0     | H   |
| PLAY-02 | Play / pause / stop / next / previous | Previous luôn lùi về bài trước, không có quy tắc "đã phát > 3 giây thì về đầu bài". Ở hai đầu hàng đợi chỉ repeat all mới quay vòng; ngoài ra (kể cả repeat one) nút xám, MPRIS báo `CanGoNext`/`CanGoPrevious` = false. Stop: dừng và tua về đầu bài, giữ hàng đợi | P0      | 0     | H   |
| PLAY-03 | Seek                                  | Bấm hoặc kéo seekbar, bong bóng hiện thời điểm đích; phím ←/→ ±5s; hiển thị thời gian đã phát và tổng thời lượng                                                                                                                                                    | P0      | 0     | H   |
| PLAY-04 | Âm lượng & mute                       | Thanh âm lượng, cuộn chuột để chỉnh, nhớ giá trị giữa các phiên                                                                                                                                                                                                     | P0      | 1     | H   |
| PLAY-05 | Volume boost                          | Cho phép vượt 100% (tối đa 200%), có cảnh báo méo tiếng                                                                                                                                                                                                             | P2      | 4     | H   |
| PLAY-06 | Gapless playback                      | Chuyển bài không có khoảng lặng (album live, concept album)                                                                                                                                                                                                         | P1      | 1     | H   |
| PLAY-07 | ReplayGain                            | Đọc tag RG track/album; chế độ: tắt / track / album / tự động (album nếu đang phát cả album); có preamp và chống clipping                                                                                                                                           | P1      | 1     | H   |
| PLAY-08 | Crossfade                             | Mờ dần 0–12 giây giữa các bài; tự tắt khi phát liền mạch trong cùng một album                                                                                                                                                                                       | P2      | 4     | H   |
| PLAY-09 | Tốc độ & cao độ                       | Chỉnh tốc độ 0.5×–2× và cao độ độc lập (có giữ cao độ khi đổi tốc độ)                                                                                                                                                                                               | P2      | 4     | H   |
| PLAY-10 | Chọn thiết bị đầu ra                  | Liệt kê và chọn audio device (PipeWire/PulseAudio/ALSA), tự chuyển khi rút tai nghe                                                                                                                                                                                 | P1      | 1     |     |
| PLAY-11 | Exclusive mode / bit-perfect          | Xuất trực tiếp ra thiết bị (ALSA hw, WASAPI exclusive), bỏ qua mixer hệ thống                                                                                                                                                                                       | P3      | 4     | H   |
| PLAY-12 | Khôi phục phiên                       | Mở lại app thì có lại hàng đợi, bài đang phát và vị trí (không tự phát)                                                                                                                                                                                             | P0      | 1     | H   |
| PLAY-13 | Xử lý lỗi phát                        | File hỏng hoặc bị xoá: báo lỗi nhẹ nhàng rồi tự nhảy sang bài kế, không crash; cả hàng đợi đều lỗi liên tiếp thì dừng, không thử lại mãi                                                                                                                            | P0      | 1     |     |
| PLAY-14 | Hẹn giờ tắt                           | Dừng sau N phút, hoặc khi hết bài / hết album / hết hàng đợi; có fade out                                                                                                                                                                                           | P2      | 4     |     |
| PLAY-15 | Equalizer                             | EQ 10 band + preset (Rock, Pop, Bass boost…) + preset tự tạo; dùng filter của mpv                                                                                                                                                                                   | P2      | 4     |     |
| PLAY-16 | Mono / cân bằng trái-phải             | Downmix mono và chỉnh balance cho trợ năng                                                                                                                                                                                                                          | P3      | 4     |     |
| PLAY-17 | Bỏ khoảng lặng                        | Tuỳ chọn cắt khoảng lặng ở đầu và cuối bài                                                                                                                                                                                                                          | P3      | 4     |     |

Không tìm thấy libmpv (hoặc không tạo được player) thì app vẫn mở ở chế độ chỉ duyệt thư viện: có banner báo phát nhạc bị tắt, bấm phát chỉ báo một lỗi rồi đứng ở trạng thái tạm dừng, không thử lần lượt cả hàng đợi.

## 2. Hàng đợi (queue) & chế độ phát

| ID       | Tính năng                      | Mô tả / tiêu chí hoàn thành                                                                                                                                                               | Ưu tiên | Phase | H   |
| -------- | ------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- | ----- | --- |
| QUEUE-01 | Phát từ ngữ cảnh               | Bấm một bài trong album / playlist / danh sách thì cả ngữ cảnh đó thành hàng đợi                                                                                                          | P0      | 1     | H   |
| QUEUE-02 | Phát tiếp theo / thêm vào cuối | "Play next" chèn ngay sau bài hiện tại; "Add to queue" thêm vào cuối                                                                                                                      | P0      | 1     | H   |
| QUEUE-03 | Sắp xếp hàng đợi               | Kéo thả để đổi thứ tự, vuốt hoặc bấm nút để xoá, xoá toàn bộ                                                                                                                              | P0      | 1     | H   |
| QUEUE-04 | Shuffle                        | Xáo trộn kiểu Fisher–Yates, không lặp bài cho tới khi hết vòng; bật shuffle thì bài đang phát vẫn phát tiếp và lên đầu thứ tự mới; tắt shuffle thì quay về thứ tự gốc, vẫn ở bài hiện tại | P0      | 1     | H   |
| QUEUE-05 | Repeat                         | Tắt / lặp cả hàng đợi / lặp một bài                                                                                                                                                       | P0      | 1     | H   |
| QUEUE-06 | Lưu hàng đợi thành playlist    | Một thao tác để biến hàng đợi hiện tại thành playlist                                                                                                                                     | P1      | 1     |     |
| QUEUE-07 | Lịch sử phát                   | Xem các bài đã phát gần đây, bấm để phát lại                                                                                                                                              | P1      | 1     |     |
| QUEUE-08 | Shuffle thông minh             | Shuffle theo album (giữ nguyên thứ tự trong album), hạn chế hai bài cùng nghệ sĩ đứng liền nhau                                                                                           | P3      | 4     |     |
| QUEUE-09 | Phát ngẫu nhiên thư viện       | Nút "Shuffle all" và "Random album"                                                                                                                                                       | P1      | 1     | H   |
| QUEUE-10 | Dừng sau bài này               | Tạm dừng khi bài hiện tại kết thúc                                                                                                                                                        | P2      | 1     |     |

## 3. Quét thư viện & index

Indexer nằm trong `lib/core/indexer/`; đọc tag bằng lofty (Rust); lưu vào drift (SQLite).

| ID     | Tính năng                | Mô tả / tiêu chí hoàn thành                                                                                                                                                          | Ưu tiên | Phase | H   |
| ------ | ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------- | ----- | --- |
| IDX-01 | Chọn thư mục nhạc        | Lần đầu mở app (thư viện chưa có nguồn) hiện màn chọn nguồn nhạc trước khi vào thư viện; sau đó thêm và bỏ nhiều thư mục gốc trong Settings → Nguồn; mặc định gợi ý `$XDG_MUSIC_DIR` — một phần: màn chọn nguồn lần đầu đã làm (feat/library-indexer); thêm/bỏ trong Settings → Nguồn chưa làm | P0      | 1     | H   |
| IDX-02 | Quét lần đầu             | Quét đệ quy, đọc tag song song trên isolate/Rust, có thanh tiến độ, UI không bị đơ. Mục tiêu: 10.000 bài dưới 60 giây trên SSD — ✅ đã làm (feat/library-indexer) | P0      | 1     | H   |
| IDX-03 | Quét lại tăng dần        | So `mtime` + kích thước, chỉ đọc lại file đã đổi; xoá bản ghi của file đã mất — ✅ đã làm (feat/library-indexer). File không bao giờ đọc được (lỗi parse, định dạng không hỗ trợ) không được đọc lại cho tới khi file đổi hoặc `tagReaderVersion` đổi; lỗi tạm (I/O, quyền) được thử lại mỗi lần quét (fix/library-data-hardening) | P0      | 1     | H   |
| IDX-04 | Theo dõi thư mục         | Dùng inotify để tự cập nhật khi thêm/xoá/sửa file lúc app đang chạy                                                                                                                  | P1      | 1     |     |
| IDX-05 | Loại trừ                 | Bỏ qua thư mục con, file `.nomedia`, file ngắn hơn N giây (nhạc chuông, ghi âm) — một phần: thư mục ẩn (tên bắt đầu bằng `.`, gồm `.Trash-<uid>`), `lost+found`, `@eaDir` và `$RECYCLE.BIN` được bỏ qua tự động; thư mục gốc là thư mục ẩn vẫn được quét. Bài đã index trong các thư mục này bị xoá khỏi thư viện ở lần quét kế tiếp. `.nomedia` và lọc theo thời lượng chưa làm (fix/library-data-hardening)                                                                                                      | P1      | 1     |     |
| IDX-06 | Quét khi khởi động       | Tuỳ chọn tự quét lại khi mở app, chạy nền                                                                                                                                            | P1      | 1     | H   |
| IDX-07 | Bài lỗi / không đọc được | Liệt kê file có tag lỗi hoặc định dạng không hỗ trợ để người dùng xử lý                                                                                                              | P2      | 1     |     |
| IDX-08 | CUE sheet                | Tách một file FLAC/APE + `.cue` thành nhiều track ảo                                                                                                                                 | P2      | 4     |     |
| IDX-09 | Phát file ngoài thư viện | Mở file/thư mục bằng dòng lệnh, kéo thả hoặc "Open with" mà không cần thêm vào thư viện                                                                                              | P1      | 1     | H   |
| IDX-10 | Tiến độ quét mượt        | Vòng tiến độ của nút quét lại luôn thấy được và nhích đều. Trước đây batch cố định 512 file nên thư viện nhỏ hơn chỉ có một batch, và ở `0/total` vòng M3 determinate không vẽ gì (483 file đọc lại lấy cover mất ~14,7 s mà icon biến mất). Giờ vòng xoay cho tới khi đọc xong batch đầu; batch `ceil(total / 20)` trong khoảng 32–512 để mỗi root có ~20 bước — ✅ đã làm | P1      | 1     |     |

**Giới hạn khi quét** (fix/library-data-hardening):

| Tình huống | Hành vi |
| --- | --- |
| Tên file hoặc thư mục không phải UTF-8 | Bỏ qua và đếm. Sau quét hiện số lượng và ghi log; file không được index |
| Walk một root, hoặc một lô đọc tag, quá 60 s | Root dừng dở, các lô đã ghi giữ nguyên, kết quả quét báo root bị bỏ qua. Walk vẫn chạy nền; khi nó xong (hoặc khi lần đọc tag chậm xong), app tự quét lại một lần và dùng luôn kết quả walk đó; lần quét tự động đó không kích hoạt thêm lần nào nữa |
| Mount mạng hoặc FUSE (sshfs, rclone…) | Không hỗ trợ. App không nhận diện; timeout chỉ để quét không treo |
| Khoá sắp xếp đổi phiên bản (sau khi nâng cấp) | Tính lại trong nền. Khi đó các màn Album, Nghệ sĩ và Bài hát hiện "Đang cập nhật thư viện…" kèm tiến độ; phát nhạc không bị ảnh hưởng |

**Nút "Mở file / Mở thư mục" trên top bar chỉ là tạm thời.** Nó có từ lúc làm player core, để nạp nhạc khi chưa có thư viện, và sẽ bị bỏ khi IDX-01 xong. Khi đó:

- Đường phát nhạc (`PlayerService.openTracks`, hàng đợi, player bar) vẫn giữ nguyên; màn thư viện dùng lại nó.
- `isAudioFile` / `scanFolder` trong `lib/features/player/open_media.dart` chuyển sang `lib/core/indexer/`.
- `file_selector` vẫn dùng cho hộp thoại chọn thư mục nguồn.
- Phát file ngoài thư viện đi qua IDX-09 / SYS-07 (dòng lệnh, kéo thả, "Open with"), không qua nút.
- Top bar cửa sổ hẹp (dưới 720 px, sidebar thành drawer): nút Back `‹` luôn hiện trước ô tìm kiếm (chỉ Back, không Forward; nút bên chuột vẫn đi tới), thành `☰ ‹ [Tìm kiếm] ⚙`. Hiện tại `‹ ›` bị ẩn khi top bar dưới 560 px. Settings `⚙` giữ ở góc phải ở mọi độ rộng, không gộp vào menu `⋮`, không chuyển xuống sidebar.

## 4. Metadata & artwork

| ID      | Tính năng                  | Mô tả / tiêu chí hoàn thành                                                                                                                                                            | Ưu tiên | Phase | H   |
| ------- | -------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- | ----- | --- |
| META-01 | Đọc tag chuẩn              | ID3v2.3/2.4, Vorbis Comment, MP4, APE: title, artist, album, album artist, track/disc number, year/date, genre, composer, comment, duration, bitrate, sample rate, bit depth, channels — ✅ đã làm (feat/library-indexer). Giới hạn lưu: 1 KB mỗi trường chữ (title, artist, album, album artist, genre, composer), 4 KB comment, tối đa 32 nghệ sĩ (fix/library-data-hardening) | P0      | 1     | H   |
| META-02 | Nhiều nghệ sĩ / thể loại   | Tách theo multi-value tag và theo dấu phân cách cấu hình được (`;`, `/`, `feat.`)                                                                                                      | P1      | 1     | H   |
| META-03 | Ảnh bìa nhúng              | Đọc ảnh nhúng (ưu tiên front cover; nhận JPEG/PNG/WebP, cạnh ≤ 4096 px) cùng lượt đọc tag, tạo thumbnail JPEG 512 px cache trên đĩa (`~/.cache/kanaru/covers/512`, dedup theo hash blake3 ảnh gốc, tự sửa khi cache mất, dọn ảnh mồ côi); ảnh gốc đọc lại từ file khi cần (`read_original_cover`). Mới một cỡ, chưa có nhiều kích cỡ — ✅ đã làm (feat/cover-art) | P0      | 1     | H   |
| META-04 | Ảnh bìa trong thư mục      | Thứ tự: ảnh nhúng → `<tên bài>.jpg/jpeg/png` → `cover`/`folder`/`front` `.jpg/jpeg/png` (không phân biệt hoa thường) → icon placeholder; dùng được cả cho file không có tag (DSD: quét theo tên file, không báo lỗi; WMA: không được quét). Giới hạn: đổi riêng file ảnh khi file nhạc không đổi không được phát hiện khi rescan — ✅ đã làm (feat/cover-art) | P0      | 1     | H   |
| META-05 | Ảnh nghệ sĩ                | Ảnh local (`artist.jpg`) hoặc tải từ nguồn mở (MusicBrainz / Wikidata / Fanart.tv), có thể tắt                                                                                         | P2      | 4     | H   |
| META-06 | Tag sắp xếp                | Tôn trọng `ALBUMARTISTSORT`, `ARTISTSORT`; bỏ qua "The", "A" khi sắp xếp (tuỳ chọn) — một phần: luôn bỏ "The" ở đầu tên nghệ sĩ và album (không bỏ "A", tiêu đề bài giữ "The"); sắp xếp không phân biệt hoa thường và dấu (chữ có dấu Việt/châu Âu gộp về chữ gốc, chữ khác theo mã Unicode); chưa đọc `ALBUMARTISTSORT`/`ARTISTSORT`, chưa có tuỳ chọn tắt bỏ "The" (fix/library-data-hardening)                                                                                                    | P2      | 1     |     |
| META-07 | Thông tin file             | Màn hình chi tiết: đường dẫn, định dạng, codec, bitrate, sample rate, kích thước, toàn bộ tag thô                                                                                      | P1      | 1     | H   |
| META-08 | Trình sửa tag              | Sửa tag một bài hoặc nhiều bài cùng lúc, đổi ảnh bìa, ghi xuống file qua lofty                                                                                                         | P2      | 4     | H   |
| META-09 | Sửa tag hàng loạt nâng cao | Đặt tên file theo tag, lấy tag từ tên file, đánh số track tự động                                                                                                                      | P3      | 4     |     |
| META-10 | Tra cứu MusicBrainz        | Gợi ý metadata đúng theo MusicBrainz/AcoustID                                                                                                                                          | P3      | 4     |     |
| META-11 | Đánh giá & yêu thích       | Thả tim, chấm 1–5 sao (lưu trong DB; tuỳ chọn ghi vào tag `RATING`/`POPM`)                                                                                                             | P1      | 1     |     |

## 5. Duyệt thư viện

| ID     | Tính năng              | Mô tả / tiêu chí hoàn thành                                                                                                                                 | Ưu tiên | Phase | H   |
| ------ | ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- | ----- | --- |
| LIB-01 | Album                  | Lưới ảnh bìa + tên/nghệ sĩ/năm; có chế độ danh sách; trang chi tiết album liệt kê bài theo đĩa                                                              | P0      | 1     | H   |
| LIB-02 | Nghệ sĩ & album artist | Danh sách nghệ sĩ; trang nghệ sĩ gồm album, bài hát, xuất hiện trong (featured)                                                                             | P0      | 1     | H   |
| LIB-03 | Bài hát                | Danh sách mọi bài, cuộn mượt với 100k bài (virtualized list) — ✅ đã làm (fix/library-data-hardening): danh sách ảo hoá, đọc từng trang khi cuộn. Chạm một bài thì phát đúng bài đó và hàng đợi theo thứ tự đang hiển thị, kể cả khi quét vừa xoá bài khác; nếu chính bài đó đã bị xoá thì không phát và báo lỗi                                                                                                | P0      | 1     | H   |
| LIB-04 | Thể loại               | Danh sách thể loại; trang thể loại gồm album và bài                                                                                                         | P1      | 1     | H   |
| LIB-05 | Năm / thập niên        | Nhóm theo năm, có gom theo thập niên                                                                                                                        | P2      | 1     |     |
| LIB-06 | Thư mục                | Duyệt theo cây thư mục thật trên đĩa, phát cả thư mục                                                                                                       | P1      | 1     |     |
| LIB-07 | Sắp xếp                | Theo tên, nghệ sĩ, năm, ngày thêm, thời lượng, số lần phát; tăng/giảm; nhớ lựa chọn từng màn hình. Tên và nghệ sĩ/album sắp theo cùng một quy tắc trên mọi màn hình (xem META-06) (fix/library-data-hardening)                                                           | P0      | 1     | H   |
| LIB-08 | Lọc nhanh              | Lọc trong màn hình hiện tại (ví dụ chỉ FLAC, chỉ bài yêu thích)                                                                                             | P2      | 1     |     |
| LIB-09 | Nhảy theo chữ cái      | Thanh A–Z / thanh cuộn nhanh có chữ cái đầu                                                                                                                 | P1      | 1     |     |
| LIB-10 | Trang chủ              | Mới thêm gần đây, phát gần đây, phát nhiều nhất, album ngẫu nhiên                                                                                           | P2      | 1     |     |
| LIB-11 | Hyperlink khắp nơi     | Bấm tên nghệ sĩ/album/thể loại ở bất kỳ đâu thì mở trang tương ứng                                                                                          | P1      | 1     | H   |
| LIB-12 | Menu ngữ cảnh          | Chuột phải / nhấn giữ: phát, phát tiếp theo, thêm vào hàng đợi, thêm vào playlist, đi tới album/nghệ sĩ, thông tin, mở thư mục chứa file, xoá khỏi thư viện | P0      | 1     | H   |
| LIB-13 | Chọn nhiều             | Chọn nhiều mục (Ctrl/Shift click, nhấn giữ trên mobile) để thao tác hàng loạt                                                                               | P1      | 1     |     |
| LIB-14 | Kéo thả                | Kéo bài vào hàng đợi / playlist; kéo ra file manager                                                                                                        | P2      | 1     |     |
| LIB-15 | Ẩn mục                 | Ẩn bài/album khỏi thư viện mà không xoá file                                                                                                                | P3      | 1     |     |
| LIB-16 | Xoá file               | Đưa vào thùng rác hệ thống (có xác nhận)                                                                                                                    | P3      | 1     |     |

## 6. Tìm kiếm

| ID        | Tính năng            | Mô tả / tiêu chí hoàn thành                                                                     | Ưu tiên | Phase | H   |
| --------- | -------------------- | ----------------------------------------------------------------------------------------------- | ------- | ----- | --- |
| SEARCH-01 | Tìm toàn văn         | SQLite FTS5 trên title, artist, album, album artist, genre; kết quả chia nhóm bài/album/nghệ sĩ | P0      | 1     | H   |
| SEARCH-02 | Tìm khi gõ           | Kết quả cập nhật trong < 50 ms với thư viện 50k bài                                             | P0      | 1     | H   |
| SEARCH-03 | Không phân biệt dấu  | "son tung" khớp "Sơn Tùng"; xử lý dấu tiếng Việt, ký tự Unicode, viết hoa/thường                | P0      | 1     |     |
| SEARCH-04 | Tìm gần đúng         | Chấp nhận gõ sai nhẹ, khớp tiền tố                                                              | P2      | 1     |     |
| SEARCH-05 | Lịch sử tìm kiếm     | Gợi ý các lần tìm trước, có nút xoá                                                             | P2      | 1     |     |
| SEARCH-06 | Cú pháp nâng cao     | `artist:`, `year:>2010`, `genre:jazz`, `format:flac`                                            | P3      | 4     |     |
| SEARCH-07 | Phím tắt mở tìm kiếm | `Ctrl+F` hoặc `/` để focus ô tìm kiếm                                                           | P1      | 1     |     |

## 7. Playlist

| ID    | Tính năng            | Mô tả / tiêu chí hoàn thành                                                                         | Ưu tiên | Phase | H   |
| ----- | -------------------- | --------------------------------------------------------------------------------------------------- | ------- | ----- | --- |
| PL-01 | Tạo / đổi tên / xoá  | CRUD playlist; ảnh đại diện ghép từ 4 ảnh bìa đầu tiên                                              | P0      | 1     | H   |
| PL-02 | Thêm / bớt / sắp xếp | Thêm từ menu ngữ cảnh, kéo thả để sắp xếp, cảnh báo khi thêm bài trùng                              | P0      | 1     | H   |
| PL-03 | Playlist "Yêu thích" | Playlist hệ thống, tự cập nhật theo META-11                                                         | P1      | 1     | H   |
| PL-04 | Import M3U/M3U8      | Nhập playlist; đường dẫn tương đối/tuyệt đối; báo các bài không tìm thấy                            | P1      | 1     |     |
| PL-05 | Export M3U/M3U8      | Xuất playlist, chọn đường dẫn tương đối hoặc tuyệt đối                                              | P1      | 1     |     |
| PL-06 | Smart playlist       | Playlist theo quy tắc (thể loại = X, năm trong khoảng, rating ≥ 4, chưa phát 30 ngày…), tự cập nhật | P2      | 4     |     |
| PL-07 | Playlist tự động     | Mới thêm, phát nhiều nhất, phát gần đây, chưa từng phát                                             | P2      | 1     |     |
| PL-08 | Thư mục playlist     | Gom playlist vào thư mục                                                                            | P3      | 4     |     |
| PL-09 | Import/export khác   | XSPF, PLS                                                                                           | P3      | 4     |     |

## 8. Now Playing & mini player

| ID    | Tính năng                  | Mô tả / tiêu chí hoàn thành                                                                                        | Ưu tiên | Phase | H   |
| ----- | -------------------------- | ------------------------------------------------------------------------------------------------------------------ | ------- | ----- | --- |
| NP-01 | Thanh điều khiển dưới cùng | Luôn hiển thị: ảnh bìa, tên bài/nghệ sĩ, play/pause, next/prev, seekbar, âm lượng, shuffle/repeat, nút mở hàng đợi | P0      | 1     | H   |
| NP-02 | Màn hình Now Playing       | Ảnh bìa lớn, thông tin bài, điều khiển, hàng đợi bên cạnh (desktop) hoặc vuốt lên (mobile)                         | P0      | 1     | H   |
| NP-03 | Chuyển cảnh mượt           | Hero animation ảnh bìa từ mini player sang Now Playing; đổi bài có animation                                       | P1      | 1     | H   |
| NP-04 | Hiển thị chất lượng        | Badge định dạng / bitrate / sample rate (ví dụ `FLAC 24/96`)                                                       | P2      | 1     |     |
| NP-05 | Waveform seekbar           | Seekbar hiển thị dạng sóng của bài, sinh nền và cache lại                                                          | P2      | 4     |     |
| NP-06 | Visualizer                 | Hiệu ứng phổ âm thanh đơn giản                                                                                     | P3      | 4     | H   |
| NP-07 | Nền động                   | Nền mờ hoặc gradient lấy từ ảnh bìa                                                                                | P2      | 1     | H   |
| NP-08 | Chế độ thu nhỏ (compact)   | Cửa sổ nhỏ, luôn nằm trên cùng, chỉ có ảnh bìa và điều khiển                                                       | P3      | 4     |     |
| NP-09 | Chế độ toàn màn hình       | Now Playing toàn màn hình, dùng cho máy để bàn hoặc TV                                                             | P3      | 4     |     |

## 9. Lời bài hát

| ID     | Tính năng                   | Mô tả / tiêu chí hoàn thành                                                 | Ưu tiên | Phase | H   |
| ------ | --------------------------- | --------------------------------------------------------------------------- | ------- | ----- | --- |
| LYR-01 | File `.lrc` cạnh bài        | Tự nhận `<tên file>.lrc` cùng thư mục                                       | P1      | 4     | H   |
| LYR-02 | Lời nhúng                   | Đọc tag `LYRICS` / `USLT` / `SYLT`                                          | P1      | 4     | H   |
| LYR-03 | Tải online                  | Lấy từ LRCLIB (ưu tiên lời đồng bộ), cache cục bộ, có thể tắt hoàn toàn     | P1      | 4     | H   |
| LYR-04 | Lời đồng bộ                 | Highlight dòng đang hát, tự cuộn, bấm vào dòng để seek                      | P1      | 4     | H   |
| LYR-05 | Chỉnh lệch thời gian        | Dời ±0.1s nếu lời bị lệch, lưu theo từng bài                                | P2      | 4     |     |
| LYR-06 | Tự thêm lời                 | Dán lời hoặc chọn file `.lrc` cho một bài                                   | P2      | 4     | H   |
| LYR-07 | Bản dịch                    | Hiển thị song song lời gốc và lời dịch (LRC nhiều ngôn ngữ)                 | P3      | 4     | H   |
| LYR-08 | Lời trong thông báo / MPRIS | Hiển thị dòng lời hiện tại trong notification (Android) hoặc metadata MPRIS | P3      | 4     | H   |
| LYR-09 | Lời theo từng chữ           | Hỗ trợ enhanced LRC (karaoke từng chữ)                                      | P3      | 4     |     |

## 10. Giao diện & theme

| ID    | Tính năng                  | Mô tả / tiêu chí hoàn thành                                                             | Ưu tiên | Phase | H   |
| ----- | -------------------------- | --------------------------------------------------------------------------------------- | ------- | ----- | --- |
| UI-01 | Material Design 3          | Toàn bộ UI theo M3; khoảng cách, padding, căn lề nhất quán                              | P0      | 0     | H   |
| UI-02 | Sáng / tối / theo hệ thống | Đổi theme ngay lập tức, không cần khởi động lại                                         | P0      | 0     | H   |
| UI-03 | Màu động từ ảnh bìa        | Lấy seed color từ ảnh bìa bài đang phát (`material_color_utilities`), chuyển màu mượt   | P1      | 1     | H   |
| UI-04 | Màu hệ thống               | Dùng accent color của hệ điều hành (`dynamic_color`) hoặc màu tự chọn                   | P1      | 1     |     |
| UI-05 | Responsive                 | Bố cục desktop (navigation rail/drawer) và mobile (bottom bar); co giãn từ 360px tới 4K | P0      | 1     | H   |
| UI-06 | Animation                  | Chuyển trang, danh sách, hover có animation; có tuỳ chọn giảm chuyển động               | P1      | 1     | H   |
| UI-07 | Thanh tiêu đề riêng        | Chọn title bar tự vẽ, của hệ thống (Wayland: header bar GTK) hoặc không có (tiling WM)  | P2      | 1     |     |
| UI-08 | AMOLED đen tuyệt đối       | Chế độ tối dùng nền `#000000`                                                           | P2      | 1     |     |
| UI-09 | Font & cỡ chữ              | Chọn font, scale cỡ chữ                                                                 | P3      | 1     |     |
| UI-10 | Đa ngôn ngữ                | i18n (`flutter_localizations` + ARB); bắt đầu với tiếng Anh và tiếng Việt               | P1      | 1     | H   |
| UI-11 | Trợ năng                   | Semantics cho screen reader, điều hướng hoàn toàn bằng bàn phím, đủ độ tương phản       | P1      | 1     |     |
| UI-12 | Material 2 style           | Tuỳ chọn giao diện M2 như Harmonoid                                                     | P3      | 4     | H   |

## 11. Tích hợp hệ thống (desktop & mobile)

| ID     | Tính năng                   | Mô tả / tiêu chí hoàn thành                                                                                                                                                                                                                                                                                        | Ưu tiên | Phase | H   |
| ------ | --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------- | ----- | --- |
| SYS-01 | MPRIS (Linux)               | D-Bus `org.mpris.MediaPlayer2`: metadata, ảnh bìa, play/pause/next/prev/seek, shuffle/loop, volume; GNOME/KDE/`playerctl` điều khiển được                                                                                                                                                                          | P0      | 0     | H   |
| SYS-02 | Phím media                  | Phím Play/Next/Prev trên bàn phím (qua MPRIS hoặc global hotkey)                                                                                                                                                                                                                                                   | P0      | 0     | H   |
| SYS-03 | Phím tắt trong app          | Space: play/pause (cả khi đang focus nút, trừ ô nhập liệu) · ←/→: seek ±5s · Ctrl+S: bật/tắt shuffle · Ctrl+R: đổi repeat · Ctrl+←/→: đổi bài · ↑/↓: âm lượng · Ctrl+F: tìm kiếm · có màn hình liệt kê phím tắt                                                                                                    | P1      | 1     |     |
| SYS-04 | Thông báo đổi bài           | Desktop notification khi đổi bài (tuỳ chọn)                                                                                                                                                                                                                                                                        | P2      | 1     |     |
| SYS-05 | System tray                 | Icon ở khay hệ thống, menu điều khiển nhanh, đóng cửa sổ thì thu xuống tray                                                                                                                                                                                                                                        | P2      | 1     |     |
| SYS-06 | Một instance duy nhất       | Bản Profile/Release chỉ chạy một instance (`GtkApplication` unique): mở lần hai thì đưa cửa sổ đang chạy lên trước; bản Debug chạy song song được. Mở file khi app đang chạy thì gửi sang instance hiện có (làm cùng SYS-07)                                                                                       | P1      | 1     |     |
| SYS-07 | Liên kết file               | Đăng ký MIME audio trong `.desktop` file để có "Open with Kanaru"                                                                                                                                                                                                                                                  | P1      | 1     | H   |
| SYS-08 | Tham số dòng lệnh           | `kanaru file.flac`, `kanaru --play-pause`, `--next`…                                                                                                                                                                                                                                                               | P2      | 1     |     |
| SYS-09 | Ngăn ngủ máy                | Chặn màn hình khoá/ngủ khi đang phát ở chế độ toàn màn hình (tuỳ chọn)                                                                                                                                                                                                                                             | P3      | 1     |     |
| SYS-10 | Windows                     | SMTC, nút trên thumbnail taskbar, tiến độ trên taskbar                                                                                                                                                                                                                                                             | P1      | 2     | H   |
| SYS-11 | macOS                       | `MPNowPlayingInfoCenter`, phím media, menu Dock                                                                                                                                                                                                                                                                    | P1      | 2     | H   |
| SYS-12 | Android                     | Phát nền, `MediaStyle` notification, màn hình khoá, Android Auto (P3), tạm dừng khi rút tai nghe                                                                                                                                                                                                                   | P1      | 2     | H   |
| SYS-13 | iOS                         | Phát nền, Control Center, CarPlay (P3)                                                                                                                                                                                                                                                                             | P1      | 2     | H   |
| SYS-14 | Chạy portable               | Lưu toàn bộ dữ liệu cạnh file chạy (AppImage/Windows portable)                                                                                                                                                                                                                                                     | P3      | 1     | H   |
| SYS-15 | Đưa cửa sổ lên trên Wayland | Mở lần hai / MPRIS `Raise` đưa cửa sổ lên trước trên compositor Wayland (niri, Sway…) qua xdg-activation: instance thứ hai chuyển `XDG_ACTIVATION_TOKEN` sang instance chính. MPRIS `Raise` không mang token nên chỉ sửa được đường mở lần hai. Đã kiểm: niri không lên, không urgent; GNOME/KDE Wayland chưa kiểm | P2      | 1     |     |

## 12. Dịch vụ bên ngoài

Tất cả đều **tắt mặc định** và chỉ hoạt động khi người dùng bật (xem [Quyền riêng tư](#17-quyền-riêng-tư)).

| ID     | Tính năng             | Mô tả / tiêu chí hoàn thành                                                            | Ưu tiên | Phase | H   |
| ------ | --------------------- | -------------------------------------------------------------------------------------- | ------- | ----- | --- |
| EXT-01 | Scrobble Last.fm      | Scrobble sau 50% hoặc 4 phút, cập nhật "now playing", xếp hàng khi offline rồi gửi lại | P2      | 4     | H   |
| EXT-02 | Scrobble ListenBrainz | Như EXT-01, dùng token ListenBrainz                                                    | P2      | 4     |     |
| EXT-03 | Discord Rich Presence | Hiện bài đang nghe trên Discord (qua IPC)                                              | P2      | 4     | H   |
| EXT-04 | Scrobble lên Subsonic | Gọi `scrobble` cho server Subsonic khi bài thuộc nguồn đó                              | P2      | 3     |     |

## 13. Nguồn từ xa (remote sources)

Mỗi nguồn implement `StorageProvider` trong `lib/core/storage/<name>/`. Player luôn phát qua proxy local `127.0.0.1`, không bao giờ gọi thẳng dịch vụ từ xa. Credential lưu trong `flutter_secure_storage`.

| ID     | Tính năng                       | Mô tả / tiêu chí hoàn thành                                                                                                              | Ưu tiên | Phase |
| ------ | ------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | ------- | ----- |
| SRC-01 | `StorageProvider` + proxy local | Interface chung (list, stat, đọc theo range, artwork); proxy `shelf` lo xác thực, refresh token, range request                           | P0      | 3     |
| SRC-02 | Quản lý nguồn                   | Màn hình thêm/sửa/xoá/tạm tắt nguồn, nút kiểm tra kết nối, hiện trạng thái online/offline từng nguồn                                     | P0      | 3     |
| SRC-03 | Thư viện hợp nhất               | Bài từ mọi nguồn gộp vào một thư viện; lọc được theo nguồn; gộp bài trùng (tuỳ chọn)                                                     | P1      | 3     |
| SRC-04 | Subsonic / OpenSubsonic         | Navidrome, Gonic, Airsonic: lấy metadata và artwork từ server (không cần quét), transcode tuỳ chọn, starred ↔ yêu thích, playlist server | P1      | 3     |
| SRC-05 | WebDAV                          | Nextcloud, ownCloud, Synology, rclone serve; Basic/Digest auth                                                                           | P1      | 3     |
| SRC-06 | S3-compatible                   | AWS S3, R2, B2, MinIO, Wasabi; endpoint tuỳ chỉnh, path-style hoặc virtual-host, SigV4                                                   | P1      | 3     |
| SRC-07 | SFTP                            | Đăng nhập bằng mật khẩu hoặc private key, xác minh host key                                                                              | P2      | 3     |
| SRC-08 | Google Drive                    | OAuth 2.0 (PKCE, loopback redirect), cho phép dùng client ID riêng, Drive Changes API để quét tăng dần                                   | P2      | 3     |
| SRC-09 | Đọc tag từ xa                   | Đọc tag bằng HTTP range (chỉ đầu/cuối file), không tải cả file khi index                                                                 | P1      | 3     |
| SRC-10 | Quét lại tăng dần               | Dựa vào ETag / mtime / Changes API                                                                                                       | P1      | 3     |
| SRC-11 | SMB / NFS                       | Chia sẻ mạng nội bộ (NFS mount thì đã chạy được như thư mục local)                                                                       | P3      | 3     |
| SRC-12 | Dropbox / OneDrive              | OAuth, tương tự Google Drive                                                                                                             | P3      | 3     |

## 14. Cache & offline

| ID       | Tính năng              | Mô tả / tiêu chí hoàn thành                                                  | Ưu tiên | Phase |
| -------- | ---------------------- | ---------------------------------------------------------------------------- | ------- | ----- |
| CACHE-01 | Cache đĩa trong suốt   | LRU cache cho file đã stream, giới hạn dung lượng cấu hình được              | P0      | 3     |
| CACHE-02 | Tải về để nghe offline | Ghim bài/album/playlist; hiện tiến độ tải; không bị LRU xoá                  | P1      | 3     |
| CACHE-03 | Chỉ báo offline        | Icon cho bài đã có sẵn; làm mờ bài không phát được khi mất mạng              | P1      | 3     |
| CACHE-04 | Tải trước              | Tải sẵn N bài tiếp theo trong hàng đợi                                       | P1      | 3     |
| CACHE-05 | Chính sách mạng        | Chỉ stream/tải qua Wi-Fi, giới hạn chất lượng khi dùng mạng di động (mobile) | P2      | 3     |
| CACHE-06 | Quản lý cache          | Xem dung lượng theo nguồn, xoá cache, đổi vị trí lưu                         | P1      | 3     |

## 15. Thống kê nghe nhạc

| ID      | Tính năng         | Mô tả / tiêu chí hoàn thành                                     | Ưu tiên | Phase |
| ------- | ----------------- | --------------------------------------------------------------- | ------- | ----- |
| STAT-01 | Đếm lượt phát     | Tăng play count khi phát ≥ 50% bài; lưu thời điểm phát gần nhất | P1      | 1     |
| STAT-02 | Bỏ qua            | Đếm lượt skip, dùng cho smart playlist                          | P2      | 1     |
| STAT-03 | Màn hình thống kê | Top bài/album/nghệ sĩ theo tuần/tháng/năm, tổng thời gian nghe  | P2      | 4     |
| STAT-04 | Tổng kết năm      | Trang "Năm của bạn" kiểu Wrapped, có thể xuất ảnh               | P3      | 4     |
| STAT-05 | Import lịch sử    | Nhập lịch sử từ Last.fm / ListenBrainz                          | P3      | 4     |

## 16. Cài đặt, sao lưu & đồng bộ

| ID     | Tính năng             | Mô tả / tiêu chí hoàn thành                                                                                                                                                        | Ưu tiên | Phase |
| ------ | --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- | ----- |
| SET-01 | Màn hình cài đặt      | Nhóm: Thư viện, Phát nhạc, Giao diện, Lời bài hát, Nguồn, Tích hợp, Nâng cao, Giới thiệu                                                                                           | P0      | 1     |
| SET-02 | Lưu theo chuẩn XDG    | Config ở `$XDG_CONFIG_HOME/kanaru`, DB ở `$XDG_DATA_HOME/kanaru`, cache ở `$XDG_CACHE_HOME/kanaru`, log ở `$XDG_CACHE_HOME/kanaru/logs` (không có biến thì `~/.cache/kanaru/logs`) | P0      | 1     |
| SET-03 | Sao lưu / khôi phục   | Xuất và nhập một file chứa cài đặt, playlist, rating, play count (không chứa credential)                                                                                           | P2      | 4     |
| SET-04 | Đồng bộ giữa thiết bị | Đồng bộ playlist, rating, cài đặt qua một nguồn của người dùng (WebDAV/S3)                                                                                                         | P3      | 4     |
| SET-05 | Đặt lại               | Xoá thư viện và quét lại; đặt lại toàn bộ cài đặt                                                                                                                                  | P1      | 1     |
| SET-06 | Log & báo lỗi         | Xem và xuất log để đính kèm khi báo lỗi; không tự gửi đi đâu                                                                                                                       | P1      | 1     |
| SET-07 | Kiểm tra cập nhật     | Báo khi có bản mới (tắt được; tự tắt trong bản Flatpak/distro)                                                                                                                     | P3      | 1     |

Log tự che mật khẩu, token, cookie và user:pass trong URL (cả dạng percent-encode) trước khi ghi ra file. Một lỗi lặp lại liên tục chỉ được ghi một lần trong 10 giây, kèm dòng "lặp lại ×N".

## 17. Quyền riêng tư

| ID      | Yêu cầu                | Mô tả                                                                                                                                   |
| ------- | ---------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| PRIV-01 | Không telemetry        | Không gửi số liệu sử dụng hay crash report tự động                                                                                      |
| PRIV-02 | Không cần tài khoản    | Mọi tính năng offline dùng được mà không cần đăng nhập                                                                                  |
| PRIV-03 | Kết nối mạng minh bạch | Mọi tính năng gọi mạng (lời bài hát, ảnh nghệ sĩ, scrobble, cập nhật) đều có công tắc riêng; có một công tắc "Chế độ offline hoàn toàn" |
| PRIV-04 | Credential an toàn     | Mật khẩu và token chỉ nằm trong keyring hệ thống (libsecret/Keychain/Keystore), không ghi vào DB hay log                                |

## 18. Đóng gói & phân phối

| ID     | Tính năng       | Mô tả / tiêu chí hoàn thành                                               | Ưu tiên | Phase |
| ------ | --------------- | ------------------------------------------------------------------------- | ------- | ----- |
| PKG-01 | AppImage        | Một file chạy được trên các distro phổ biến, đã bundle libmpv             | P0      | 1     |
| PKG-02 | Flatpak         | Phát hành trên Flathub; sandbox chỉ cấp quyền vào thư mục nhạc qua portal | P1      | 1     |
| PKG-03 | `.deb` / `.rpm` | Gói cho Debian/Ubuntu và Fedora                                           | P1      | 1     |
| PKG-04 | AUR             | `kanaru-bin` cho Arch                                                     | P2      | 1     |
| PKG-05 | Nix             | Package trong `flake.nix`                                                 | P2      | 1     |
| PKG-06 | Windows / macOS | Installer MSIX/EXE, bản portable; `.dmg` đã ký                            | P1      | 2     |
| PKG-07 | Android / iOS   | Play Store, F-Droid (bản không có thành phần đóng), App Store             | P1      | 2     |

## 19. Yêu cầu phi chức năng

| ID     | Yêu cầu             | Mục tiêu                                                                              |
| ------ | ------------------- | ------------------------------------------------------------------------------------- |
| NFR-01 | Thời gian khởi động | Hiện thư viện < 1.5 giây với 20k bài (khởi động nguội, SSD)                           |
| NFR-02 | RAM                 | < 200 MB khi phát với thư viện 20k bài (Harmonoid khoảng 150 MB)                      |
| NFR-03 | Quy mô thư viện     | Duyệt, tìm kiếm và cuộn mượt ở 60 fps với 100k bài                                    |
| NFR-04 | Kích thước gói      | AppImage < 60 MB                                                                      |
| NFR-05 | Độ ổn định          | File hỏng, tag lỗi, mất mạng hay nguồn từ xa chết đều không làm crash app             |
| NFR-06 | Toàn vẹn dữ liệu    | Migration drift có test; không làm mất playlist/rating khi nâng cấp                   |
| NFR-07 | Kiểm thử            | Unit test cho core (player, indexer, storage, licensing); widget test cho luồng chính |

## 20. Premium (đề xuất)

Nguyên tắc: **mọi thứ cần để dùng Kanaru như một player offline hoàn chỉnh đều miễn phí**. Premium chỉ dành cho tính năng "thêm", chủ yếu ở mảng nguồn từ xa và tiện ích nâng cao. Mọi kiểm tra premium đi qua `licenseService.has(PremiumFeature.x)` trong `core/licensing`.

Ứng viên (chưa chốt):

| Ứng viên                                       | ID liên quan     | Lý do                                       |
| ---------------------------------------------- | ---------------- | ------------------------------------------- |
| Nhiều nguồn từ xa cùng lúc (bản free: 1 nguồn) | SRC-03           | Giá trị chính của Kanaru so với player khác |
| Google Drive / Dropbox / OneDrive              | SRC-08, SRC-12   | Tốn công duy trì OAuth                      |
| Tải về để nghe offline không giới hạn          | CACHE-02         |                                             |
| Đồng bộ giữa thiết bị                          | SET-04           |                                             |
| Smart playlist                                 | PL-06            |                                             |
| Sửa tag hàng loạt nâng cao, tra MusicBrainz    | META-09, META-10 |                                             |
| Thống kê nâng cao, tổng kết năm                | STAT-03, STAT-04 |                                             |
| Equalizer nâng cao (parametric, preset tự tạo) | PLAY-15          |                                             |

## 21. Ngoài phạm vi (hiện tại)

- Stream từ dịch vụ thương mại (Spotify, Apple Music, YouTube Music, Tidal…)
- Podcast, audiobook, radio internet (có thể cân nhắc sau 1.0)
- Phát video / music video
- Mạng xã hội, chia sẻ playlist công khai
- Server mode / phát cho thiết bị khác (DLNA/UPnP renderer, Chromecast) — xem xét sau 1.0

---

## Câu hỏi mở

1. Danh sách premium cuối cùng là gì? Bản free giới hạn số nguồn từ xa hay giới hạn theo loại nguồn?
2. Có cần tính năng tag editor (META-08) ngay trong Phase 1 không, hay để sang Phase 4 như hiện tại?
3. Mốc 1.0 gồm những gì: chỉ Phase 1 trên Linux, hay phải có thêm Phase 3 (nguồn từ xa)?
4. Có hỗ trợ giao diện M2 (UI-12) như Harmonoid không, hay chỉ làm M3?
