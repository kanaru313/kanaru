# Kanaru — Danh sách tính năng chi tiết

Tài liệu này chi tiết hoá phần **Features** và **Roadmap** trong [`README.md`](../README.md). Mỗi tính năng có ID ổn định để tham chiếu trong plan, issue và commit.

Tham khảo chính: [Harmonoid](https://harmonoid.com) ([GitHub](https://github.com/harmonoid/harmonoid)). Những mục Harmonoid đã có được đánh dấu **H**. Các mục ghi "(Namida)" lấy hành vi từ Namida; không dùng lại code hay asset của Namida (license EULA, xem §15).

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
| PLAY-01 | Phát file local                       | Phát được MP3, FLAC, ALAC, AAC/M4A, OGG Vorbis, Opus, WAV, AIFF, APE, WavPack, DSD (DSF/DFF) qua libmpv — ✅ đã làm | P0      | 0     | H   |
| PLAY-02 | Play / pause / stop / next / previous | Previous luôn lùi về bài trước, không có quy tắc "đã phát > 3 giây thì về đầu bài". Ở hai đầu hàng đợi chỉ repeat all mới quay vòng; ngoài ra (kể cả repeat one) nút xám, MPRIS báo `CanGoNext`/`CanGoPrevious` = false. Stop: dừng và tua về đầu bài, giữ hàng đợi. Fade khi play/pause (thời lượng riêng cho phát và dừng): chưa làm (Namida) — ✅ đã làm | P0      | 0     | H   |
| PLAY-03 | Seek                                  | Bấm hoặc kéo seekbar, bong bóng hiện thời điểm đích; phím ←/→ ±5s; hiển thị thời gian đã phát và tổng thời lượng; tuỳ chọn hiện thời gian còn lại và nam châm khi kéo: chưa làm (Namida) — ✅ đã làm | P0      | 0     | H   |
| PLAY-04 | Âm lượng & mute                       | Thanh âm lượng, cuộn chuột để chỉnh, nhớ giá trị giữa các phiên — ✅ đã làm | P0      | 1     | H   |
| PLAY-05 | Volume boost                          | Cho phép vượt 100% (tối đa 200%), có cảnh báo méo tiếng                                                                                                                                                                                                             | P2      | 4     | H   |
| PLAY-06 | Gapless playback                      | Chuyển bài không có khoảng lặng (album live, concept album) — ✅ đã làm; tuỳ chọn tắt gapless có trong Settings (Sắp có), chưa nối | P1      | 1     | H   |
| PLAY-07 | ReplayGain                            | Đọc tag RG track/album; chế độ: tắt / track / album / tự động (album nếu đang phát cả album); có preamp và chống clipping — ✅ đã làm. Tự động chốt một lần cho mỗi lượt bài: album khi bài trước hoặc sau trong thứ tự phát cùng album (tra theo thư viện), ngược lại track; sửa hàng đợi không đổi mức bài đang phát. Preamp −15..15 dB, chống clipping mặc định bật. File không có tag RG giữ nguyên mức                                                                                                                                           | P1      | 1     | H   |
| PLAY-08 | Crossfade                             | Mờ dần 0–12 giây giữa các bài; tự tắt khi phát liền mạch trong cùng một album; beat matching theo BPM/key (Namida 8.2, chưa làm); tuỳ chọn có trong Settings (Sắp có), chưa nối | P2      | 4     | H   |
| PLAY-09 | Tốc độ & cao độ                       | Chỉnh tốc độ 0.5×–2× và cao độ độc lập (có giữ cao độ khi đổi tốc độ); nhập số chính xác, cao độ theo nửa cung và 432 Hz, liên kết tốc độ với cao độ (Namida, chưa làm)                                                                                                                                                                                               | P2      | 4     | H   |
| PLAY-10 | Chọn thiết bị đầu ra                  | Liệt kê và chọn audio device (PipeWire/PulseAudio/ALSA), tự chuyển khi rút tai nghe — ✅ đã làm (Settings > Nâng cao). Chọn theo tên đúng một thiết bị mpv liệt kê; thiết bị vắng thì dùng Tự động và quay lại sau 2 giây khi có mặt ổn định, setting giữ nguyên; thiết bị liệt kê nhưng không mở được thì về Tự động và báo "không mở được". ALSA không tự chuyển khi rút thiết bị. Tên thiết bị khác giữa bản Nix (ao pipewire) và AppImage (ao pulse), không ánh xạ chéo                                                                                                                                                                                 | P1      | 1     |     |
| PLAY-11 | Exclusive mode / bit-perfect          | Xuất trực tiếp ra thiết bị (ALSA hw, WASAPI exclusive), bỏ qua mixer hệ thống; thêm 32-bit float (Namida, chưa làm). USB DAC trực tiếp trên Android: SYS-21                                                                                                                                                                                       | P3      | 4     | H   |
| PLAY-12 | Khôi phục phiên                       | Mở lại app thì có lại hàng đợi, bài đang phát và vị trí (không tự phát) — ✅ đã làm | P0      | 1     | H   |
| PLAY-13 | Xử lý lỗi phát                        | File hỏng hoặc bị xoá: báo lỗi nhẹ nhàng rồi tự nhảy sang bài kế, không crash; cả hàng đợi đều lỗi liên tiếp thì dừng, không thử lại mãi — ✅ đã làm | P0      | 1     |     |
| PLAY-14 | Hẹn giờ tắt                           | Dừng sau N phút, hoặc khi hết bài / hết album / hết hàng đợi; có fade out; preset thời gian; cập nhật hoặc tạm dừng khi đang đếm (Namida, chưa làm)                                                                                                                                                                                           | P2      | 4     |     |
| PLAY-15 | Equalizer                             | EQ 10 band + preset (Rock, Pop, Bass boost…) + preset tự tạo; dùng filter của mpv; EQ tham số (parametric) và import/export AutoEQ, mở ứng dụng EQ ngoài (Namida, chưa làm)                                                                                                                                                                                   | P2      | 4     |     |
| PLAY-16 | Mono / cân bằng trái-phải             | Downmix mono và chỉnh balance cho trợ năng                                                                                                                                                                                                                          | P3      | 4     |     |
| PLAY-17 | Bỏ khoảng lặng                        | Tuỳ chọn cắt khoảng lặng ở đầu và cuối bài                                                                                                                                                                                                                          | P3      | 4     |     |
| PLAY-18 | Tạm dừng khi rút tai nghe, có cuộc gọi | Tự tạm dừng khi rút tai nghe, có cuộc gọi hoặc thông báo, khi âm lượng về 0; cắm lại trong N phút thì phát tiếp (Namida: resume on connect, pausing scenarios). Chưa làm | P2      | 1     |     |
| PLAY-19 | Đường tín hiệu âm thanh | Màn hình xem từng bước từ file tới thiết bị ra: decoder, bộ lọc, định dạng, thiết bị (Namida "Audio Path"). Chưa làm | P3      | 4     |     |
| PLAY-20 | Âm thanh theo bài và preset | Tốc độ, cao độ, âm lượng, EQ riêng cho từng bài; preset âm thanh để đổi cả bộ một lần (Namida). Chưa làm | P3      | 4     |     |
| PLAY-21 | Bookmark trong bài | Đánh dấu vị trí trong bài, nhảy lại từ danh sách bookmark của bài đó (Namida 8.2). Chưa làm | P3      | 4     |     |
| PLAY-22 | Chương (chapters) | Nhận chương nhúng trong file để nhảy chương trong player; khác IDX-08 (CUE sheet) (Namida 8.2). Chưa làm | P3      | 4     |     |
| PLAY-23 | Hiệu ứng âm thanh | Bass enhancer, reverb, virtual surround, 8D, crossfeed, compressor, echo, chorus, loudness enhancer, dùng filter của mpv (Namida). Vocal remover chỉ có ở Namida Android, để Phase 2 nếu làm. Chưa làm | P3      | 4     |     |

Không tìm thấy libmpv (hoặc không tạo được player) thì app vẫn mở ở chế độ chỉ duyệt thư viện: có banner báo phát nhạc bị tắt, bấm phát chỉ báo một lỗi rồi đứng ở trạng thái tạm dừng, không thử lần lượt cả hàng đợi.

## 2. Hàng đợi (queue) & chế độ phát

| ID       | Tính năng                      | Mô tả / tiêu chí hoàn thành                                                                                                                                                               | Ưu tiên | Phase | H   |
| -------- | ------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- | ----- | --- |
| QUEUE-01 | Phát từ ngữ cảnh               | Bấm một bài trong album / playlist / danh sách thì cả ngữ cảnh đó thành hàng đợi. Phát từ kết quả tìm kiếm: chọn chế độ (chỉ bài đó, kết quả, album, nghệ sĩ đầu, thể loại đầu) và phát nhẹ nhàng, thêm bài kế rồi phát mà không thay hàng đợi (Namida, chưa làm) — ✅ đã làm | P0      | 1     | H   |
| QUEUE-02 | Phát tiếp theo / thêm vào cuối | "Play next" chèn ngay sau bài hiện tại; "Add to queue" thêm vào cuối — ✅ đã làm. "Play next" giữ thứ tự chọn (chèn sau bài đang phát, sau các bài đã "Play next" chưa phát); "Add to queue" thêm vào cuối. Cho bài, album, nghệ sĩ qua menu chuột phải / nhấn giữ và nút trên trang album/nghệ sĩ; hàng đợi rỗng thì phát luôn; hỏi trước khi thay hàng đợi; animation bài/album bay vào hàng đợi khi bật animation (Namida, con-ton-dong §10; chưa làm)                                                                                                                      | P0      | 1     | H   |
| QUEUE-03 | Sắp xếp hàng đợi               | Kéo thả để đổi thứ tự, vuốt hoặc bấm nút để xoá, xoá toàn bộ; xoá bài trùng hoặc các bài trước/sau; hoàn tác khi xoá; hiện thời lượng còn lại (Namida, chưa làm) — ✅ đã làm | P0      | 1     | H   |
| QUEUE-04 | Shuffle                        | Xáo trộn kiểu Fisher–Yates, không lặp bài cho tới khi hết vòng; bật shuffle thì bài đang phát vẫn phát tiếp và lên đầu thứ tự mới; tắt shuffle thì quay về thứ tự gốc, vẫn ở bài hiện tại. Chưa làm: chế độ xáo tắt / xáo bài kế / xáo tất cả (Namida 8.4); loại N bài vừa nghe khỏi lượt xáo (con-ton-dong §7) — ✅ đã làm | P0      | 1     | H   |
| QUEUE-05 | Repeat                         | Tắt / lặp cả hàng đợi / lặp một bài — ✅ đã làm. Chưa làm (Namida): lặp một bài N lần trước khi sang bài kế; khi hết hàng đợi phát lại hàng đợi đã xáo trộn | P0      | 1     | H   |
| QUEUE-06 | Lưu hàng đợi thành playlist    | Một thao tác để biến hàng đợi hiện tại thành playlist                                                                                                                                     | P1      | 1     |     |
| QUEUE-07 | Lịch sử phát                   | Xem các bài đã phát gần đây, bấm để phát lại (đọc từ lượt nghe STAT-01)                                                                                                                                              | P1      | 1     |     |
| QUEUE-08 | Shuffle thông minh             | Shuffle theo album (giữ nguyên thứ tự trong album), hạn chế hai bài cùng nghệ sĩ đứng liền nhau                                                                                           | P3      | 4     |     |
| QUEUE-09 | Phát ngẫu nhiên thư viện       | Nút "Shuffle all" và "Random album". Shuffle all ✅ (trang Bài hát); Shuffle album và nghệ sĩ ✅ (nút Shuffle cạnh Play); Random album chưa làm                                                                                                                                                       | P1      | 1     | H   |
| QUEUE-10 | Dừng sau bài này               | Tạm dừng khi bài hiện tại kết thúc                                                                                                                                                        | P2      | 1     |     |
| QUEUE-11 | Hàng đợi tương tự & tự động | Tạo hàng đợi các bài giống bài đang phát theo lượt nghe, năm phát hành, khoảng thời gian, rating, mood hoặc ngẫu nhiên; bỏ qua lượt nghe quá gần (Namida "smart tracks", recommended). Chưa làm | P3      | 4     |     |
| QUEUE-12 | Tiếp tục nghe theo từng danh sách | Album, playlist, nghệ sĩ, hàng đợi nhớ bài nghe cuối; mở lại thì đánh dấu và cuộn tới bài đó, phát tiếp từ đó; hàng đợi hiện tên nguồn (Namida "resume"). Chưa làm | P2      | 1     |     |
| QUEUE-13 | Lưu nhiều hàng đợi | Lưu nhiều hàng đợi chứ không chỉ hàng đợi cuối (khác PLAY-12); mở lại từ trang Hàng đợi, xoá từng cái (Namida "persistent queues"). Chưa làm | P2      | 1     |     |
| QUEUE-14 | Dialog phát nâng cao | Giữ đè nút Shuffle hoặc Play ở trang album, nghệ sĩ, playlist: sắp xếp, xáo, lọc trước khi phát; giới hạn theo số bài, thời lượng, dung lượng; chỉ bài rating cao. Gồm nút Shuffle cạnh Play ở trang album và nghệ sĩ (con-ton-dong §9). Chưa làm | P2      | 1     |     |
| QUEUE-15 | Hàng đợi vô hạn (tuỳ chọn) | Công tắc trong Settings → Nâng cao, tắt mặc định. Khi bật, bấm Tiếp theo ở bài cuối thì nhảy về bài đầu và ngược lại, bất kể chế độ lặp. Khi tắt giữ quy tắc của PLAY-02 (chỉ repeat all quay vòng); tuỳ chọn có trong Settings (Sắp có), chưa nối | P2      | 1     |     |

## 3. Quét thư viện & index

Indexer nằm trong `lib/core/indexer/`; đọc tag bằng lofty (Rust); lưu vào drift (SQLite).

| ID     | Tính năng                | Mô tả / tiêu chí hoàn thành                                                                                                                                                          | Ưu tiên | Phase | H   |
| ------ | ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------- | ----- | --- |
| IDX-01 | Chọn thư mục nhạc        | Lần đầu mở app (thư viện chưa có nguồn) hiện màn chọn nguồn nhạc trước khi vào thư viện; sau đó thêm và bỏ thư mục gốc trong Settings → Thư viện (bỏ có hộp xác nhận, file trên đĩa không bị xoá); mặc định gợi ý `$XDG_MUSIC_DIR`. Mỗi thư mục chỉ có nút thùng rác (hiện khi hover hoặc focus bàn phím; không có nút đổi, đổi = thêm rồi xoá). Thư mục không còn tồn tại hiện gạch ngang kèm thùng rác đỏ luôn hiện. Màn chọn nguồn chỉ hiện một lần sau khi cài, kể cả khi sau đó đã bỏ hết thư mục (feat/library-folders) | P0      | 1     | H   |
| IDX-02 | Quét lần đầu             | Quét đệ quy, đọc tag song song trên isolate/Rust, có thanh tiến độ, UI không bị đơ. Mục tiêu: 10.000 bài dưới 60 giây trên SSD — ✅ đã làm (feat/library-indexer) | P0      | 1     | H   |
| IDX-03 | Quét lại tăng dần        | So `mtime` + kích thước, chỉ đọc lại file đã đổi; xoá bản ghi của file đã mất — ✅ đã làm (feat/library-indexer). File không bao giờ đọc được (lỗi parse, định dạng không hỗ trợ) không được đọc lại cho tới khi file đổi hoặc `tagReaderVersion` đổi; lỗi tạm (I/O, quyền) được thử lại mỗi lần quét (fix/library-data-hardening) | P0      | 1     | H   |
| IDX-04 | Theo dõi thư mục         | Dùng inotify để tự cập nhật khi thêm/xoá/sửa file lúc app đang chạy                                                                                                                  | P1      | 1     |     |
| IDX-05 | Loại trừ                 | Bỏ qua thư mục con, file `.nomedia`, file ngắn hơn N giây (nhạc chuông, ghi âm) — một phần: thư mục ẩn (tên bắt đầu bằng `.`, gồm `.Trash-<uid>`), `lost+found`, `@eaDir` và `$RECYCLE.BIN` được bỏ qua tự động; thư mục gốc là thư mục ẩn vẫn được quét. Đã làm: `.nomedia` (thư mục **dưới** thư mục gốc; gốc có `.nomedia` vẫn quét), dung lượng tối thiểu và thời lượng tối thiểu, bật trong Settings > Thư viện. Bài đã index bị xoá ở lần quét kế tiếp, không tự quét khi đổi tuỳ chọn; bài ngắn hơn ngưỡng chỉ đọc lại một lần mỗi phiên; ai đã đặt bộ lọc lúc còn "Sắp có" sẽ thấy bài bị xoá ở lần quét đầu. Chưa làm: loại trừ thư mục con do người dùng chọn; Namida còn loại trừ theo đuôi file | P1      | 1     |     |
| IDX-06 | Quét khi khởi động       | Tuỳ chọn tự quét lại khi mở app, chạy nền sau khi cửa sổ hiện; mặc định bật, công tắc trong Settings → Thư viện. Chỉ báo khi có thay đổi hoặc lỗi (feat/library-folders); báo ngay khi khởi động nếu có thư mục gốc không còn tồn tại: snackbar có nút mở Settings, mỗi lần mở app một lần, không phụ thuộc công tắc quét khi khởi động (✅). Giới hạn: điểm mount còn là thư mục khi ổ chưa mount thì không bị báo | P1      | 1     | H   |
| IDX-07 | Bài lỗi / không đọc được | Liệt kê file có tag lỗi hoặc định dạng không hỗ trợ để người dùng xử lý                                                                                                              | P2      | 1     |     |
| IDX-08 | CUE sheet                | Tách một file FLAC/APE + `.cue` thành nhiều track ảo                                                                                                                                 | P2      | 4     |     |
| IDX-09 | Phát file ngoài thư viện | Mở file/thư mục bằng dòng lệnh, kéo thả hoặc "Open with" mà không cần thêm vào thư viện; chọn phát / thêm vào tiếp theo / thêm vào cuối / hỏi; nhận file `.m3u` (Namida 8.4, chưa làm)                                                                                              | P1      | 1     | H   |
| IDX-10 | Tiến độ quét mượt        | Vòng tiến độ của nút quét lại luôn thấy được và nhích đều. Trước đây batch cố định 512 file nên thư viện nhỏ hơn chỉ có một batch, và ở `0/total` vòng M3 determinate không vẽ gì (483 file đọc lại lấy cover mất ~14,7 s mà icon biến mất). Giờ vòng xoay cho tới khi đọc xong batch đầu; batch `ceil(total / 20)` trong khoảng 32–512 để mỗi root có ~20 bước; nút quét lại nằm trên header (bên trái Settings), luôn hiện ở mọi trang và mọi độ rộng cửa sổ khi có thư mục nhạc, thay nút nổi cũ — ✅ đã làm | P1      | 1     |     |
| IDX-11 | Gộp bản trùng | Các file trùng tên (khác thư mục) được coi là một bài; chỉ ẩn bản thừa, không xoá file, tắt được (Namida "Prevent Duplicated Tracks"). Bản thừa vẫn nằm trong DB, chỉ bị ẩn khỏi thư viện; tuỳ chọn có trong Settings (Sắp có), chưa nối | P2      | 1     |     |
| IDX-12 | Báo cáo quét & thống kê thư viện | Trong Settings → Thư viện: số bài đọc được / tổng, kèm số trùng, lỗi, bị `.nomedia`, bị loại theo dung lượng và thời lượng; số ảnh bìa đã tạo (ghi rõ hệ thống tự tạo, tránh trùng và không tìm thấy); số nghệ sĩ, album, thể loại, bài; cài đặt cần quét lại có ghi chú (con-ton-dong §11). Một phần: Settings → Thư viện hiện số bài, album, nghệ sĩ, thể loại (cập nhật live khi quét; thể loại đếm theo tag đã gộp hoa/thường, tag nhiều giá trị tính một); báo cáo quét (trùng, lỗi, `.nomedia`, dung lượng, thời lượng, ảnh bìa) chưa làm | P2      | 1     |     |
| IDX-13 | Thư mục loại trừ | Danh sách thư mục bị loại trừ trong Settings: thêm, bỏ; quét lại khi đổi (Namida "excluded folders"). Chưa làm | P1      | 1     |     |
| IDX-14 | Bài bị mất & nối lại đường dẫn | Trang bài thiếu liệt kê bài có file đã mất; tìm file trùng tên hoặc kích thước ở chỗ mới để nối lại đường dẫn; dọn lượt nghe của bài đã mất, chạy nền (Namida "missing tracks"; con-ton-dong §7). Chưa làm | P2      | 1     |     |

**Giới hạn khi quét** (fix/library-data-hardening):

| Tình huống | Hành vi |
| --- | --- |
| Tên file hoặc thư mục không phải UTF-8 | Bỏ qua và đếm. Sau quét hiện số lượng và ghi log; file không được index |
| Walk một root, hoặc một lô đọc tag, quá 60 s | Root dừng dở, các lô đã ghi giữ nguyên, kết quả quét báo root bị bỏ qua. Walk vẫn chạy nền; khi nó xong (hoặc khi lần đọc tag chậm xong), app tự quét lại một lần và dùng luôn kết quả walk đó; lần quét tự động đó không kích hoạt thêm lần nào nữa |
| Mount mạng hoặc FUSE (sshfs, rclone…) | Không hỗ trợ. App không nhận diện; timeout chỉ để quét không treo |
| Khoá sắp xếp đổi phiên bản (sau khi nâng cấp) | Tính lại trong nền. Khi đó các màn Album, Nghệ sĩ và Bài hát hiện "Đang cập nhật thư viện…" kèm tiến độ; phát nhạc không bị ảnh hưởng |

**Nút "Mở file / Mở thư mục" trên top bar đã bỏ** (feat/library-folders). Nó chỉ có từ lúc làm player core, để nạp nhạc khi chưa có thư viện. Hiện chỉ phát được bài trong thư viện; phát file ngoài thư viện chờ IDX-09 / SYS-07 (dòng lệnh, kéo thả, "Open with"). Còn lại:

- Đường phát nhạc (`PlayerService.openTracks`, hàng đợi, player bar) giữ nguyên; màn thư viện dùng nó.
- `walkAudioFilesInIsolate` và `isAudioFile` nằm ở `lib/core/indexer/`, dùng cho việc quét thư viện.
- `file_selector` dùng cho hộp thoại chọn thư mục nguồn (`lib/shared/directory_picker_provider.dart`).
- Top bar cửa sổ hẹp (dưới 720 px, sidebar thành drawer): nút Back `‹` luôn hiện trước ô tìm kiếm (chỉ Back, không Forward; nút bên chuột vẫn đi tới), thành `☰ ‹ [Tìm kiếm] ⚙`. Hiện tại `‹ ›` bị ẩn khi top bar dưới 560 px. Settings `⚙` giữ ở góc phải ở mọi độ rộng, không gộp vào menu `⋮`, không chuyển xuống sidebar.

## 4. Metadata & artwork

| ID      | Tính năng                  | Mô tả / tiêu chí hoàn thành                                                                                                                                                            | Ưu tiên | Phase | H   |
| ------- | -------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- | ----- | --- |
| META-01 | Đọc tag chuẩn              | ID3v2.3/2.4, Vorbis Comment, MP4, APE: title, artist, album, album artist, track/disc number, year/date, genre, composer, comment, duration, bitrate, sample rate, bit depth, channels — ✅ đã làm (feat/library-indexer). Giới hạn lưu: 1 KB mỗi trường chữ (title, artist, album, album artist, genre, composer), 4 KB comment, tối đa 32 nghệ sĩ (fix/library-data-hardening). Namida còn đọc style, release type, record label, MusicBrainz album ID; BPM và key xem META-14 (chưa làm) | P0      | 1     | H   |
| META-02 | Nhiều nghệ sĩ / thể loại   | Tách theo multi-value tag và theo dấu phân cách cấu hình được (`;`, `/`, `feat.`); danh sách chặn không tách (ví dụ AC/DC), tách cả composer, danh sách có nút xoá và đếm mục (Namida, chưa làm)                                                                                                      | P1      | 1     | H   |
| META-03 | Ảnh bìa nhúng              | Đọc ảnh nhúng (ưu tiên front cover; nhận JPEG/PNG/WebP, cạnh ≤ 4096 px) trong lượt quét thứ hai, chạy nền sau khi đọc tag xong (thư viện hiện ngay, ảnh bìa hiện dần; lượt này nhường khi có lượt quét mới (thêm thư mục, quét tự động) và chạy tiếp ở lần quét sau, luồng ưu tiên thấp; trong lúc đó nút quét lại thành vòng tiến độ ảnh bìa và bị khoá), tạo thumbnail JPEG 512 px cache trên đĩa (`~/.cache/kanaru/covers/512`, dedup theo hash blake3 ảnh gốc, tự sửa khi cache mất, dọn ảnh mồ côi); thumbnail resize Lanczos3 và xoay theo EXIF orientation (chỉ JPEG); ảnh gốc đọc lại từ file khi cần (`read_original_cover`, chọn cùng nguồn với lượt quét: bỏ nguồn mà lượt quét không decode được vì giới hạn decode): Now Playing hiện thumbnail trước rồi đổi sang ảnh gốc của bài đang phát khi decode xong (ảnh lỗi thì giữ thumbnail; không LRU, không prefetch; ảnh gốc không ở lại cache ảnh sau khi đổi bài; tuỳ chọn tắt cache ảnh (Namida, chưa làm)); thanh phát và MPRIS giữ thumbnail; thanh phát, Now Playing và MPRIS lấy ảnh bìa của bài đang phát từ thư viện, nên ảnh bìa tạo sau khi bài đã phát (hoặc được thay khi quét lại) hiện ngay mà không phải phát lại. Mới một cỡ, chưa có nhiều kích cỡ — ✅ đã làm (feat/cover-art) | P0      | 1     | H   |
| META-04 | Ảnh bìa trong thư mục      | Thứ tự: ảnh nhúng → `<tên bài>.jpg/jpeg/png` → `cover`/`folder`/`front` `.jpg/jpeg/png` (không phân biệt hoa thường) → icon placeholder; dùng được cả cho file không có tag (DSD: quét theo tên file, không báo lỗi; WMA: không được quét). Giới hạn: đổi riêng file ảnh khi file nhạc không đổi không được phát hiện khi rescan — ✅ đã làm (feat/cover-art) | P0      | 1     | H   |
| META-05 | Ảnh nghệ sĩ                | Ảnh local (`artist.jpg`) hoặc tải từ nguồn mở (MusicBrainz / Wikidata / Fanart.tv), có thể tắt; ảnh album tải từ mạng và đặt ảnh tuỳ chọn cho nghệ sĩ hoặc album (Namida, chưa làm)                                                                                         | P2      | 4     | H   |
| META-06 | Tag sắp xếp                | Tôn trọng `ALBUMARTISTSORT`, `ARTISTSORT`; bỏ qua "The", "A" khi sắp xếp (tuỳ chọn) — một phần: luôn bỏ "The" ở đầu tên nghệ sĩ và album (không bỏ "A", tiêu đề bài giữ "The"); sắp xếp không phân biệt hoa thường và dấu (chữ có dấu Việt/châu Âu gộp về chữ gốc, chữ khác theo mã Unicode); chưa đọc `ALBUMARTISTSORT`/`ARTISTSORT`, chưa có tuỳ chọn tắt bỏ "The"; Namida còn bỏ thêm "A"/"An" theo từng loại và sắp xếp theo phiên âm (chưa làm) (fix/library-data-hardening)                                                                                                    | P2      | 1     |     |
| META-07 | Thông tin file             | Màn hình chi tiết: đường dẫn, định dạng, codec, bitrate, sample rate, kích thước, toàn bộ tag thô; kiểm tra file lossless (Namida 8.2, chưa làm)                                                                                      | P1      | 1     | H   |
| META-08 | Trình sửa tag              | Sửa tag một bài hoặc nhiều bài cùng lúc, đổi ảnh bìa, ghi xuống file qua lofty; gợi ý giá trị đã có khi gõ; khi sửa nhiều bài chỉ điền ô trống; đổi BPM ×2 / ÷2 (Namida); giữ mtime của file khi ghi tag (con-ton-dong §7). Chưa làm                                                                                                         | P2      | 4     | H   |
| META-09 | Sửa tag hàng loạt nâng cao | Lấy tag từ tên file, đánh số track tự động. Không đổi tên file nhạc (chỉ ghi tag) | P3      | 4     |     |
| META-10 | Tra cứu MusicBrainz        | Gợi ý metadata đúng theo MusicBrainz/AcoustID                                                                                                                                          | P3      | 4     |     |
| META-11 | Yêu thích | Thả tim: Yêu thích = playlist `kind = favorites` (một playlist duy nhất, tạo lần đầu bấm tim; bảng có từ schema 6, UI chưa làm); phím tắt yêu thích (Namida, chưa làm). Chấm 1–5 sao bỏ khỏi đợt này (follow-up) | P1      | 1     |     |
| META-12 | Khoá nhận diện album | Chọn cách nhận diện album: mặc định theo tên, có thể thêm năm, album artist, MusicBrainz album ID (Namida "album identifiers"). Đổi khoá cần quét lại. Chưa làm | P2      | 1     |     |
| META-13 | Ghi chú thư mục (`.info.txt`) | Đọc file `.info.txt` trong thư mục và hiện như ghi chú nhỏ của thư mục (Namida). Chưa làm | P3      | 4     |     |
| META-14 | BPM và key nhạc | Đọc BPM và key từ tag; tuỳ chọn phân tích để tìm khi chưa có; dùng để sắp xếp, smart playlist và beat matching (PLAY-08) (Namida 8.2). Chưa làm | P3      | 4     |     |

## 5. Duyệt thư viện

| ID     | Tính năng              | Mô tả / tiêu chí hoàn thành                                                                                                                                 | Ưu tiên | Phase | H   |
| ------ | ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- | ----- | --- |
| LIB-01 | Album                  | Lưới ảnh bìa + tên/nghệ sĩ/năm; có chế độ danh sách; trang chi tiết album liệt kê bài theo đĩa; lọc album đơn và đĩa đơn, nhận đĩa đơn theo số track, bài có nhiều album (Namida, chưa làm) — ✅ đã làm; tuỳ chọn có trong Settings (Sắp có), chưa nối (nhóm album theo album artist và năm) | P0      | 1     | H   |
| LIB-02 | Nghệ sĩ & album artist | Danh sách nghệ sĩ (chuyển lưới/danh sách, nhớ trong phiên chạy, chưa nhớ giữa các lần mở); trang nghệ sĩ gồm album, bài hát, xuất hiện trong (featured); album và đĩa đơn tách riêng trong trang nghệ sĩ (Namida, chưa làm) — ✅ đã làm | P0      | 1     | H   |
| LIB-03 | Bài hát                | Danh sách mọi bài, cuộn mượt với 100k bài (virtualized list) — ✅ đã làm (fix/library-data-hardening): danh sách ảo hoá, đọc từng trang khi cuộn. Chạm một bài thì phát đúng bài đó và hàng đợi theo thứ tự đang hiển thị, kể cả khi quét vừa xoá bài khác; nếu chính bài đó đã bị xoá thì không phát và báo lỗi                                                                                                | P0      | 1     | H   |
| LIB-04 | Thể loại               | Danh sách thể loại (chuyển lưới/danh sách với ô tròn như nghệ sĩ, nhớ trong phiên chạy); trang thể loại gồm album và bài, có Phát/Xáo trộn — ✅ đã làm. Chỉ lưu thể loại đầu tiên của mỗi file (scanner chỉ giữ giá trị đầu); tag có nhiều thể loại gõ tay được tách theo `;` lúc đọc (tuỳ chọn dấu phân cách sẽ làm sau trong Cài đặt) | P1      | 1     | H   |
| LIB-05 | Năm / thập niên        | Nhóm theo năm, có gom theo thập niên                                                                                                                        | P2      | 1     |     |
| LIB-06 | Thư mục                | Trang Thư mục luôn liệt kê các thư mục nhạc (cả khi chỉ có một); bật tắt phân cấp (cây hoặc danh sách phẳng mọi thư mục có bài, nhãn theo đường dẫn tương đối), chuyển lưới/danh sách, nhớ trong phiên chạy; tên xếp theo số tự nhiên (Music 2 trước Music 12); số bài và số thư mục con đệ quy; dựng từ đường dẫn bài đã lưu, không đi đĩa — ✅ đã làm. Hiện mục con đã ẩn (cần indexer, walker đang bỏ thư mục ẩn) và gộp thư mục con đơn vào thư mục cha (Namida và con-ton-dong §7) chưa làm |  P1      | 1     | H   |
| LIB-07 | Sắp xếp                | Theo tên, nghệ sĩ, năm, ngày thêm, thời lượng, số lần phát; tăng/giảm; nhớ lựa chọn từng màn hình; thêm BPM, bit depth, đường dẫn, nhãn đĩa, lần nghe đầu và cuối, yêu thích; preset; đảo chiều bằng icon mũi tên ✅ (Songs, Albums, Artists; ô chọn trường chỉ hiện tên), đảo riêng từng kiểu (Namida, chưa làm). Tên và nghệ sĩ/album sắp theo cùng một quy tắc trên mọi màn hình (xem META-06) (fix/library-data-hardening)                                                           | P0      | 1     | H   |
| LIB-08 | Lọc nhanh              | Lọc trong màn hình hiện tại (ví dụ chỉ FLAC, chỉ bài yêu thích)                                                                                             | P2      | 1     |     |
| LIB-09 | Nhảy theo chữ cái      | Thanh A–Z / thanh cuộn nhanh có chữ cái đầu; nhãn theo năm, ngày hoặc số lượt khi không sắp theo chữ (Namida, chưa làm)                                                                                                                 | P1      | 1     |     |
| LIB-10 | Trang chủ              | Mới thêm gần đây, phát gần đây, phát nhiều nhất, album ngẫu nhiên; bật tắt và sắp xếp các mục trang chủ (Namida, chưa làm)                                                                                           | P2      | 1     |     |
| LIB-11 | Hyperlink khắp nơi     | Bấm tên nghệ sĩ/album/thể loại ở bất kỳ đâu thì mở trang tương ứng                                                                                          | P1      | 1     | H   |
| LIB-12 | Menu ngữ cảnh          | Chuột phải / nhấn giữ: phát, phát tiếp theo, thêm vào hàng đợi, thêm vào playlist, đi tới album/nghệ sĩ ✅, thông tin, mở thư mục chứa file ✅ (menu bài: Show artist / Show album / Show in file manager), xoá khỏi thư viện | P0      | 1     | H   |
| LIB-13 | Chọn nhiều             | Chọn nhiều mục (Ctrl/Shift click, nhấn giữ trên mobile) để thao tác hàng loạt; giữ lựa chọn khi chuyển trang và chọn từ nhiều nơi vào cùng một danh sách (Namida, chưa làm)                                                                               | P1      | 1     |     |
| LIB-14 | Kéo thả                | Kéo bài vào hàng đợi / playlist; kéo ra file manager                                                                                                        | P2      | 1     |     |
| LIB-15 | Ẩn mục                 | Ẩn bài/album khỏi thư viện mà không xoá file                                                                                                                | P3      | 1     |     |
| LIB-16 | Xoá file               | Đưa vào thùng rác hệ thống (có xác nhận)                                                                                                                    | P3      | 1     |     |
| LIB-17 | Duyệt theo mood, tag và rating | Trang duyệt theo mood và tag tuỳ chỉnh (đọc từ TXXX hoặc tag tương đương) và theo rating; tạo danh sách từ mood (Namida "moods/tags/ratings"). Chưa làm | P3      | 4     |     |
| LIB-18 | Duyệt theo ngôn ngữ | Trang nhóm bài theo ngôn ngữ (Namida 8.2), chỉ lấy từ tag (`TLAN` trong ID3, `LANGUAGE` trong Vorbis comment/FLAC); bài không có tag thì không vào nhóm nào, không đoán ngôn ngữ. Chưa làm | P3      | 4     |     |
| LIB-19 | Hành động trên thư mục | Trang thư mục và menu chuột phải có Phát, Xáo, Thêm vào hàng đợi, Phát tiếp, Thêm vào playlist, Tạo playlist (tên = tên thư mục) cho cả cây con; số bài và số thư mục con đệ quy hiện nhỏ dưới tên, không quét lại khi vào thư mục; chế độ lưới hoặc danh sách (con-ton-dong §7 và §11) — ✅ đã làm | P2      | 1     | H   |

## 6. Tìm kiếm

| ID        | Tính năng            | Mô tả / tiêu chí hoàn thành                                                                     | Ưu tiên | Phase | H   |
| --------- | -------------------- | ----------------------------------------------------------------------------------------------- | ------- | ----- | --- |
| SEARCH-01 | Tìm toàn văn         | SQLite FTS5 trên title, artist, album, album artist, genre; tuỳ chọn thêm tên file, lời và mô tả (Namida, chưa làm); kết quả chia nhóm bài/album/nghệ sĩ — ✅ đã làm (feat/search) | P0      | 1     | H   |
| SEARCH-02 | Tìm khi gõ           | Kết quả cập nhật trong < 50 ms với thư viện 50k bài — ✅ đã làm (feat/search), đo bằng benchmark `KANARU_BENCH=1` trên dữ liệu tổng hợp (p95 khoảng 30–45 ms, trường hợp xấu nhất là truy vấn khớp một nửa thư viện) | P0      | 1     | H   |
| SEARCH-03 | Không phân biệt dấu  | "son tung" khớp "Sơn Tùng"; xử lý dấu tiếng Việt, ký tự Unicode, viết hoa/thường — ✅ đã làm (feat/search) | P0      | 1     |     |
| SEARCH-04 | Tìm gần đúng         | Chấp nhận gõ sai nhẹ, khớp tiền tố                                                              | P2      | 1     |     |
| SEARCH-05 | Lịch sử tìm kiếm     | Gợi ý các lần tìm trước, có nút xoá                                                             | P2      | 1     |     |
| SEARCH-06 | Cú pháp nâng cao     | `artist:`, `year:>2010`, `genre:jazz`, `format:flac`; hoặc bộ lọc giống smart playlist (Namida 6.2.5, chưa làm)                                            | P3      | 4     |     |
| SEARCH-07 | Phím tắt mở tìm kiếm | `Ctrl+F` hoặc `/` để focus ô tìm kiếm                                                           | P1      | 1     |     |
| SEARCH-08 | Chọn trường tìm kiếm | Chọn trường được tìm (tiêu đề, nghệ sĩ, album, thể loại, tên file, lời, mô tả) bằng picker, có preset sẵn (Namida 8.4). Chưa làm | P2      | 1     |     |
| SEARCH-09 | Tìm trong danh sách con và hàng đợi | Ô tìm kiếm trong trang album, nghệ sĩ, thể loại, playlist và hàng đợi; kết quả xếp theo mức khớp (Namida). Chưa làm | P2      | 1     |     |

Giới hạn đã chấp nhận của tìm kiếm (SEARCH-01 đến SEARCH-03):

- `mtp` không khớp `M-TP`: dấu gạch ngang và dấu câu tách từ. Gõ `m-tp` hoặc `m tp` thì khớp.
- Chữ Trung, Nhật, Hàn: chỉ khớp từ đầu của một chuỗi chữ liên tục. Gõ `本` không tìm ra `日本語`.
- Tiếng Thái và một số chữ Ấn Độ: dấu tách từ, nên `กิน` bị tách thành `ก` và `น`.
- Không sửa lỗi gõ: `sonn tung` không khớp. Việc này thuộc SEARCH-04.
- Ký tự được gán sau Unicode 6.1 (emoji mới, ví dụ) không được FTS5 coi là dấu tách từ: `love🥰you` là một từ, nên gõ `you` không khớp.
- Tag dài: chỉ 256 ký tự đầu của mỗi tag được lập chỉ mục.
- Một truy vấn dùng tối đa 8 từ; từ thừa bị bỏ qua.

## 7. Playlist

| ID    | Tính năng            | Mô tả / tiêu chí hoàn thành                                                                         | Ưu tiên | Phase | H   |
| ----- | -------------------- | --------------------------------------------------------------------------------------------------- | ------- | ----- | --- |
| PL-01 | Tạo / đổi tên / xoá  | CRUD playlist; ảnh đại diện ghép từ tối đa 4 ảnh bìa khác nhau của các bài đầu tiên; hoặc ảnh tuỳ chọn (Namida, chưa làm) — ✅ đã làm       | P0      | 1     | H   |
| PL-02 | Thêm / bớt / sắp xếp | Thêm từ menu ngữ cảnh, kéo thả để sắp xếp; bài trùng bị bỏ qua và snackbar báo số bài đã thêm / đã có; thêm lên đầu playlist (Namida, chưa làm) — ✅ đã làm | P0      | 1     | H   |
| PL-03 | Playlist "Yêu thích" | Playlist hệ thống, tự cập nhật theo META-11                                                         | P1      | 1     | H   |
| PL-04 | Import M3U/M3U8      | Nhập playlist; đường dẫn tương đối/tuyệt đối; báo các bài không tìm thấy; tự đồng bộ khi file M3U đổi (Namida, chưa làm); tuỳ chọn có trong Settings (Sắp có), chưa nối (đọc m3u khi quét) | P1      | 1     |     |
| PL-05 | Export M3U/M3U8      | Xuất playlist, chọn đường dẫn tương đối hoặc tuyệt đối                                              | P1      | 1     |     |
| PL-06 | Smart playlist       | Playlist theo quy tắc (thể loại = X, năm trong khoảng, rating ≥ 4, chưa phát 30 ngày…), tự cập nhật; giới hạn theo số bài, thời lượng, dung lượng; theo nghệ sĩ, album, thể loại, thư mục; số lượt theo tháng; xáo ngẫu nhiên mỗi ngày; chỉ bài rating cao; sắp xếp nhiều cấp; dùng được trong tìm kiếm (Namida, chưa làm) | P2      | 4     |     |
| PL-07 | Playlist tự động     | Mới thêm, phát nhiều nhất, phát gần đây, chưa từng phát                                             | P2      | 1     |     |
| PL-08 | Thư mục playlist     | Gom playlist vào thư mục; hoặc gắn tag lồng nhau, lọc và nhóm theo tag, chọn nhiều để gắn tag, xuất, xoá (Namida 7.8, chưa làm)                                                                            | P3      | 4     |     |
| PL-09 | Import/export khác   | XSPF, PLS                                                                                           | P3      | 4     |     |
| PL-10 | Mô tả, ghim và gộp playlist | Mô tả cho playlist; ghim lên trang chủ; gộp nhiều playlist (Namida 7.8, 8.2). Chưa làm | P3      | 4     |     |

## 8. Now Playing & mini player

| ID    | Tính năng                  | Mô tả / tiêu chí hoàn thành                                                                                        | Ưu tiên | Phase | H   |
| ----- | -------------------------- | ------------------------------------------------------------------------------------------------------------------ | ------- | ----- | --- |
| NP-01 | Thanh điều khiển dưới cùng | Luôn hiển thị: ảnh bìa, tên bài/nghệ sĩ, play/pause, next/prev, seekbar, âm lượng, shuffle/repeat, nút mở hàng đợi; thanh rộng có thêm nút thêm bài hiện tại vào playlist (cạnh âm lượng) — ✅ đã làm | P0      | 1     | H   |
| NP-02 | Màn hình Now Playing       | Ảnh bìa lớn, thông tin bài, điều khiển, dưới dòng nghệ sĩ có dòng album (bấm để đóng Now Playing và mở trang album; ẩn khi file ngoài thư viện hoặc không có album), danh sách hàng đợi gọi là "Đang phát" (tab thông tin bài là "Bài hát"), hàng đợi bên cạnh (desktop) hoặc vuốt lên (mobile); tuỳ chọn bố cục ngang (widescreen) cho player (Namida, chưa làm) — ✅ đã làm | P0      | 1     | H   |
| NP-03 | Chuyển cảnh mượt           | Hero animation ảnh bìa từ mini player sang Now Playing; đổi bài có animation                                       | P1      | 1     | H   |
| NP-04 | Hiển thị chất lượng        | Badge định dạng / bitrate / sample rate (ví dụ `FLAC 24/96`)                                                       | P2      | 1     |     |
| NP-05 | Waveform seekbar           | Seekbar hiển thị dạng sóng của bài, sinh nền và cache lại                                                          | P2      | 4     |     |
| NP-06 | Visualizer                 | Hiệu ứng phổ âm thanh đơn giản; nhiều kiểu visualizer (Namida 7.8, chưa làm)                                                                                     | P3      | 4     | H   |
| NP-07 | Nền động                   | Nền mờ hoặc gradient lấy từ ảnh bìa                                                                                | P2      | 1     | H   |
| NP-08 | Chế độ thu nhỏ (compact)   | Cửa sổ nhỏ, luôn nằm trên cùng, chỉ có ảnh bìa và điều khiển                                                       | P3      | 4     |     |
| NP-09 | Chế độ toàn màn hình       | Now Playing toàn màn hình, dùng cho máy để bàn hoặc TV                                                             | P3      | 4     |     |
| NP-10 | Nền động & ảnh nền | Nền động (ánh sáng, bokeh, lưới màu, hiệu ứng theo mùa), nền lấy từ ảnh bìa đang phát, ảnh nền tuỳ chọn cho app (Namida 7.8, 8.2). Chưa làm | P3      | 4     |     |
| NP-11 | Hiệu ứng ảnh bìa và viền | Ảnh bìa động theo nhịp, hạt chuyển động theo đỉnh âm, viền sáng theo nhịp ở miniplayer (party mode), glow quanh ảnh bìa (Namida). Chưa làm | P3      | 4     |     |
| NP-12 | Cử chỉ trên ảnh bìa | Bấm để xem toàn màn hình, nhấn giữ để lưu ảnh ra file người dùng chọn (chỉ ghi file ảnh, không đụng file nhạc), hoặc tới bài trong danh sách hiện tại (Namida). Chưa làm | P3      | 4     |     |
| NP-13 | Nhấn giữ nút điều khiển | Nhấn giữ Tiếp theo: tốc độ 2× (chỉnh được); Trước: về đầu bài; thời gian hiện tại: tua lùi; tổng thời lượng: tua tới (Namida 6.3.1, 7.1.2). Chưa làm | P3      | 4     |     |

## 9. Lời bài hát

| ID     | Tính năng                   | Mô tả / tiêu chí hoàn thành                                                 | Ưu tiên | Phase | H   |
| ------ | --------------------------- | --------------------------------------------------------------------------- | ------- | ----- | --- |
| LYR-01 | File `.lrc` cạnh bài        | Tự nhận `<tên file>.lrc` cùng thư mục; nhiều mẫu tên file, đọc file UTF-16 (Namida, chưa làm)                                       | P1      | 4     | H   |
| LYR-02 | Lời nhúng                   | Đọc tag `LYRICS` / `USLT` / `SYLT`; ưu tiên lời nhúng hơn file `.lrc` (có công tắc) (Namida, chưa làm); tuỳ chọn có trong Settings (Sắp có), chưa nối (ưu tiên lời nhúng) | P1      | 4     | H   |
| LYR-03 | Tải online                  | Lấy từ LRCLIB (ưu tiên lời đồng bộ), cache cục bộ, có thể tắt hoàn toàn; nhiều nhà cung cấp, chọn nguồn, tìm lại (Namida, chưa làm)     | P1      | 4     | H   |
| LYR-04 | Lời đồng bộ                 | Highlight dòng đang hát, tự cuộn, bấm vào dòng để seek; chỉnh cỡ chữ (Ctrl+cuộn, nút hoặc pinch), nhấn giữ để sao chép dòng, chế độ toàn màn hình (Namida, chưa làm)                      | P1      | 4     | H   |
| LYR-05 | Chỉnh lệch thời gian        | Dời ±0.1s nếu lời bị lệch, lưu theo từng bài; co giãn thời gian lời theo tốc độ hoặc cao độ, cho bản nightcore và slowed (Namida, chưa làm)                                | P2      | 4     |     |
| LYR-06 | Tự thêm lời                 | Dán lời hoặc chọn file `.lrc` cho một bài; ghi lời vào tag `LYRICS`; chọn nơi đọc và ghi file lời (Namida, chưa làm)                                   | P2      | 4     | H   |
| LYR-07 | Bản dịch                    | Hiển thị song song lời gốc và lời dịch (LRC nhiều ngôn ngữ); tự nhận chữ RTL và căn lề đúng (Namida, chưa làm)                 | P3      | 4     | H   |
| LYR-08 | Lời trong thông báo / MPRIS | Hiển thị dòng lời hiện tại trong notification (Android) hoặc metadata MPRIS | P3      | 4     | H   |
| LYR-09 | Lời theo từng chữ           | Hỗ trợ enhanced LRC (karaoke từng chữ) và TTML (Namida, chưa làm)                                      | P3      | 4     |     |
| LYR-10 | Cửa sổ lời nổi (desktop) | Cửa sổ nhỏ luôn nổi, hiện dòng lời đang hát (Namida "floating lyrics"). Chưa làm | P3      | 4     |     |
| LYR-11 | Editor đồng bộ lời | Tự đồng bộ lời: gõ theo nhịp, chỉnh mốc từng dòng và từng chữ, xem sóng âm, hỗ trợ bè và bản dịch (Namida 8.2). Ưu tiên thấp, chỉ làm khi có nhu cầu. Chưa làm | P3      | 4     |     |
| LYR-12 | Phiên âm lời | Hiện phiên âm (romanization) cho lời không phải Latin, bật tắt theo ngôn ngữ (Namida). Chưa làm | P3      | 4     |     |
| LYR-13 | Lời một dòng | Chế độ hiện một dòng lời đang hát trong player, có karaoke theo dòng (Namida 7.0, 7.5). Chưa làm | P3      | 4     |     |

## 10. Giao diện & theme

| ID    | Tính năng                  | Mô tả / tiêu chí hoàn thành                                                             | Ưu tiên | Phase | H   |
| ----- | -------------------------- | --------------------------------------------------------------------------------------- | ------- | ----- | --- |
| UI-01 | Material Design 3          | Toàn bộ UI theo M3; khoảng cách, padding, căn lề nhất quán — ✅ đã làm | P0      | 0     | H   |
| UI-02 | Sáng / tối / theo hệ thống | Đổi theme ngay lập tức, không cần khởi động lại — ✅ đã làm | P0      | 0     | H   |
| UI-03 | Màu động từ ảnh bìa        | Lấy seed color từ ảnh bìa bài đang phát (`material_color_utilities`), chuyển màu mượt; tuỳ chọn có trong Settings (Sắp có), chưa nối | P1      | 1     | H   |
| UI-04 | Màu hệ thống               | Dùng accent color của hệ điều hành (`dynamic_color`) hoặc màu tự chọn — một phần: dùng accent của hệ thống qua `dynamic_color`, chưa có màu tự chọn | P1      | 1     |     |
| UI-05 | Responsive                 | Bố cục desktop (navigation rail/drawer) và mobile (bottom bar); co giãn từ 360px tới 4K — một phần: desktop có sidebar thu gọn và drawer dưới 720 px; chưa có bottom bar cho mobile | P0      | 1     | H   |
| UI-06 | Animation                  | Chuyển trang, danh sách, hover có animation; có tuỳ chọn giảm chuyển động — một phần: chuyển trang và overlay có animation, tôn trọng giảm chuyển động của hệ thống; tuỳ chọn trì hoãn animation cho tai nghe Bluetooth (Namida, chưa làm); tuỳ chọn tắt animation có trong Settings → Giao diện (Sắp có), chưa nối: lưu cờ `animations`, chưa ép giảm chuyển động | P1      | 1     | H   |
| UI-07 | Thanh tiêu đề riêng        | Chọn title bar tự vẽ, của hệ thống (Wayland: header bar GTK) hoặc không có (tiling WM) — ✅ đã làm | P2      | 1     |     |
| UI-08 | AMOLED đen tuyệt đối       | Chế độ tối dùng nền `#000000`                                                           | P2      | 1     |     |
| UI-09 | Font & cỡ chữ              | Chọn font, scale cỡ chữ; tuỳ chọn có trong Settings (Sắp có), chưa nối (chỉ cỡ chữ; chọn font chưa làm) | P3      | 1     |     |
| UI-10 | Đa ngôn ngữ                | i18n (`flutter_localizations` + ARB); bắt đầu với tiếng Anh và tiếng Việt — ✅ đã làm | P1      | 1     | H   |
| UI-11 | Trợ năng                   | Semantics cho screen reader, điều hướng hoàn toàn bằng bàn phím, đủ độ tương phản       | P1      | 1     |     |
| UI-12 | Material 2 style           | Tuỳ chọn giao diện M2 như Harmonoid                                                     | P3      | 4     | H   |
| UI-13 | Ẩn và sắp xếp mục thư viện và sidebar | Ẩn, bật và đổi thứ tự tab thư viện và mục sidebar (hàng đợi hiện tại, yêu thích, lịch sử, playlist) (Namida, con-ton-dong §7 và §11). Chưa làm; tuỳ chọn có trong Settings (Sắp có), chưa nối (chỉ ẩn tab; đổi thứ tự chưa làm) | P2      | 1     |     |
| UI-14 | Lưu bảng màu lúc quét | Trích bảng màu từ ảnh bìa khi quét và lưu vào DB, không trích lại lúc phát nhạc (con-ton-dong §7). Chưa làm | P2      | 1     |     |
| UI-15 | Chế độ hiệu năng | Preset tiết kiệm, cân bằng, đẹp (chỉnh animation, blur, glow), và tuỳ chỉnh riêng (Namida "performance mode"). Chưa làm | P3      | 4     |     |

## 11. Tích hợp hệ thống (desktop & mobile)

| ID     | Tính năng                   | Mô tả / tiêu chí hoàn thành                                                                                                                                                                                                                                                                                        | Ưu tiên | Phase | H   |
| ------ | --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------- | ----- | --- |
| SYS-01 | MPRIS (Linux)               | D-Bus `org.mpris.MediaPlayer2`: metadata, ảnh bìa, play/pause/next/prev/seek, shuffle/loop, volume; GNOME/KDE/`playerctl` điều khiển được — ✅ đã làm | P0      | 0     | H   |
| SYS-02 | Phím media                  | Phím Play/Next/Prev trên bàn phím (qua MPRIS hoặc global hotkey); trên Android: nút tai nghe 1, 2, 3 lần nhấn; trên tiling WM: phím tắt toàn cục qua portal XDG GlobalShortcuts (Namida, chưa làm)                                                                                                                                                                                                                                                   | P0      | 0     | H   |
| SYS-03 | Phím tắt trong app          | Space: play/pause (cả khi đang focus nút, trừ ô nhập liệu) · ←/→: seek ±5s · Ctrl+S: bật/tắt shuffle · Ctrl+R: đổi repeat · Ctrl+←/→: đổi bài · ↑/↓: âm lượng · Ctrl+F: tìm kiếm · có màn hình liệt kê phím tắt — ✅ đã làm | P1      | 1     |     |
| SYS-04 | Thông báo đổi bài           | Desktop notification khi đổi bài (tuỳ chọn); nút điều khiển trong thông báo tuỳ chỉnh (Namida 8.2, chưa làm)                                                                                                                                                                                                                                                                        | P2      | 1     |     |
| SYS-05 | System tray                 | Icon ở khay hệ thống, menu điều khiển nhanh, đóng cửa sổ thì thu xuống tray; nhấn giữa để play/pause, cuộn để chỉnh âm lượng (Namida, chưa làm)                                                                                                                                                                                                                                        | P2      | 1     |     |
| SYS-06 | Một instance duy nhất       | Bản Profile/Release chỉ chạy một instance (`GtkApplication` unique): mở lần hai thì đưa cửa sổ đang chạy lên trước; bản Debug chạy song song được. Mở file khi app đang chạy thì gửi sang instance hiện có (làm cùng SYS-07) — một phần: Release/Profile chỉ một instance, mở lần hai đưa cửa sổ lên; tham số dòng lệnh của lần mở thứ hai bị bỏ (SYS-07/08) | P1      | 1     |     |
| SYS-07 | Liên kết file               | Đăng ký MIME audio trong `.desktop` file để có "Open with Kanaru" — ✅ đã làm: `.desktop` đăng ký MIME audio; mở file qua "Open with" chỉ đưa app lên, chưa phát file (SYS-08)                                                                                                                                                                                                                                                  | P1      | 1     | H   |
| SYS-08 | Tham số dòng lệnh           | `kanaru file.flac`, `kanaru --play-pause`, `--next`…                                                                                                                                                                                                                                                               | P2      | 1     |     |
| SYS-09 | Ngăn ngủ máy                | Chặn màn hình khoá/ngủ khi đang phát ở chế độ toàn màn hình (tuỳ chọn)                                                                                                                                                                                                                                             | P3      | 1     |     |
| SYS-10 | Windows                     | SMTC, nút trên thumbnail taskbar, tiến độ trên taskbar                                                                                                                                                                                                                                                             | P1      | 2     | H   |
| SYS-11 | macOS                       | `MPNowPlayingInfoCenter`, phím media, menu Dock                                                                                                                                                                                                                                                                    | P1      | 2     | H   |
| SYS-12 | Android                     | Phát nền, `MediaStyle` notification, màn hình khoá, Android Auto (P3), tạm dừng khi rút tai nghe                                                                                                                                                                                                                   | P1      | 2     | H   |
| SYS-13 | iOS                         | Phát nền, Control Center, CarPlay (P3)                                                                                                                                                                                                                                                                             | P1      | 2     | H   |
| SYS-14 | Chạy portable               | Lưu toàn bộ dữ liệu cạnh file chạy (AppImage/Windows portable)                                                                                                                                                                                                                                                     | P3      | 1     | H   |
| SYS-15 | Đưa cửa sổ lên trên Wayland | Mở lần hai / MPRIS `Raise` đưa cửa sổ lên trước trên compositor Wayland (niri, Sway…) qua xdg-activation: instance thứ hai chuyển `XDG_ACTIVATION_TOKEN` sang instance chính. MPRIS `Raise` không mang token nên chỉ sửa được đường mở lần hai. Đã kiểm: niri không lên, không urgent; GNOME/KDE Wayland chưa kiểm | P2      | 1     |     |
| SYS-16 | Đổi phím tắt trong Settings | Màn hình phím tắt có tìm kiếm; ghi phím tắt mới, kể cả phím toàn cục; cảnh báo trùng; khôi phục mặc định (Namida 8.4; con-ton-dong §7). Chưa làm | P2      | 1     |     |
| SYS-17 | Widget màn hình chính (Android) | Widget hiện bài đang phát và điều khiển, tuỳ chỉnh nút (Namida). Chưa làm | P2      | 2     |     |
| SYS-18 | Ô Quick Settings (Android) | Ô trong bảng cài đặt nhanh: play/pause, shuffle, hẹn giờ (Namida). Chưa làm | P3      | 2     |     |
| SYS-19 | Android Auto | Điều khiển và duyệt thư viện trên xe, xem thêm SYS-12 (Namida). Chưa làm | P3      | 2     |     |
| SYS-20 | Wear OS | Ứng dụng đồng hành trên đồng hồ: điều khiển phát và xem bài đang phát (Namida). Chưa làm | P3      | 2     |     |
| SYS-21 | USB DAC trực tiếp (Android) | Xuất thẳng ra USB DAC, bỏ qua mixer Android; có cảnh báo chỉnh âm lượng trước khi cắm (Namida 7.8). Chưa làm | P3      | 2     |     |
| SYS-22 | Thư mục qua Storage Access Framework (Android) | Thêm thư mục nhạc qua SAF, không cần quyền truy cập toàn bộ bộ nhớ (Namida 7.4, 8.2). Chưa làm | P2      | 2     |     |
| SYS-23 | Vuốt trên dòng bài | Vuốt trái hoặc phải trên dòng bài hoặc thẻ video để thao tác (phát tiếp, thêm hàng đợi, xem thông tin...), cấu hình được (Namida). Chưa làm | P3      | 2     |     |
| SYS-24 | Web server trong LAN (tuỳ chọn) | Tắt mặc định. Khi bật, trình duyệt trên cùng Wi-Fi hoặc LAN nghe nhạc (stream trong trình duyệt) và quản lý: duyệt, tìm kiếm, hàng đợi, playlist, điều khiển player trên máy, Settings. Chỉ mở cổng trên LAN khi bật; khi tắt không lắng nghe mạng. HTTP thuần (không HTTPS tự ký); ghép đôi bằng mã PIN hiện trên máy, sau đó dùng token phiên, bắt buộc với mọi yêu cầu, không đưa token vào URL. Có công tắc riêng theo PRIV-03. Tái dùng proxy HTTP local của SRC-01 khi đã có. Liên quan mục 21 (server mode, DLNA, Chromecast): đây chỉ là giao diện web, không phải renderer phát cho thiết bị khác. Chưa làm | P2      | 3     |     |

## 12. Dịch vụ bên ngoài

Tất cả đều **tắt mặc định** và chỉ hoạt động khi người dùng bật (xem [Quyền riêng tư](#17-quyền-riêng-tư)).

| ID     | Tính năng             | Mô tả / tiêu chí hoàn thành                                                            | Ưu tiên | Phase | H   |
| ------ | --------------------- | -------------------------------------------------------------------------------------- | ------- | ----- | --- |
| EXT-01 | Scrobble Last.fm      | Scrobble sau 50% hoặc 4 phút, cập nhật "now playing", xếp hàng khi offline rồi gửi lại | P2      | 4     | H   |
| EXT-02 | Scrobble ListenBrainz | Như EXT-01, dùng token ListenBrainz                                                    | P2      | 4     |     |
| EXT-03 | Discord Rich Presence | Hiện bài đang nghe trên Discord (qua IPC); có thanh tiến độ, trên desktop và Android (Namida 8.4, chưa làm)                                              | P2      | 4     | H   |
| EXT-04 | Scrobble lên Subsonic | Gọi `scrobble` cho server Subsonic khi bài thuộc nguồn đó                              | P2      | 3     |     |
| EXT-05 | Webhook và hook khi đổi bài | Gửi sự kiện bài đang phát tới URL do người dùng cấu hình, hoặc chạy script (Tasker, script, scrobbler tự viết). Tắt mặc định; secret nằm trong header, không trong URL; theo PRIV-03 (Namida 8.2, con-ton-dong §7). Chưa làm | P3      | 4     |     |

## 13. Nguồn từ xa (remote sources)

Mỗi nguồn implement `StorageProvider` trong `lib/core/storage/<name>/`. Player luôn phát qua proxy local `127.0.0.1`, không bao giờ gọi thẳng dịch vụ từ xa. Credential lưu trong `flutter_secure_storage`.

| ID     | Tính năng                       | Mô tả / tiêu chí hoàn thành                                                                                                              | Ưu tiên | Phase |
| ------ | ------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | ------- | ----- |
| SRC-01 | `StorageProvider` + proxy local | Interface chung (list, stat, đọc theo range, artwork); proxy `shelf` lo xác thực, refresh token, range request                           | P0      | 3     |
| SRC-02 | Quản lý nguồn                   | Màn hình thêm/sửa/xoá/tạm tắt nguồn, nút kiểm tra kết nối, hiện trạng thái online/offline từng nguồn                                     | P0      | 3     |
| SRC-03 | Thư viện hợp nhất               | Bài từ mọi nguồn gộp vào một thư viện; lọc được theo nguồn; gộp bài trùng (tuỳ chọn)                                                     | P1      | 3     |
| SRC-04 | Subsonic / OpenSubsonic         | Navidrome, Gonic, Airsonic: lấy metadata và artwork từ server (không cần quét), transcode tuỳ chọn, starred ↔ yêu thích, playlist server; nhập playlist từ server và báo phát về server (Namida 6.0, 6.5, chưa làm) | P1      | 3     |
| SRC-05 | WebDAV                          | Nextcloud, ownCloud, Synology, rclone serve; Basic/Digest auth; lấy file `.lrc` từ server (Namida, chưa làm)                                                                           | P1      | 3     |
| SRC-06 | S3-compatible                   | AWS S3, R2, B2, MinIO, Wasabi; endpoint tuỳ chỉnh, path-style hoặc virtual-host, SigV4                                                   | P1      | 3     |
| SRC-07 | SFTP                            | Đăng nhập bằng mật khẩu hoặc private key, xác minh host key                                                                              | P2      | 3     |
| SRC-08 | Google Drive                    | OAuth 2.0 (PKCE, loopback redirect), cho phép dùng client ID riêng, Drive Changes API để quét tăng dần                                   | P2      | 3     |
| SRC-09 | Đọc tag từ xa                   | Đọc tag bằng HTTP range (chỉ đầu/cuối file), không tải cả file khi index                                                                 | P1      | 3     |
| SRC-10 | Quét lại tăng dần               | Dựa vào ETag / mtime / Changes API                                                                                                       | P1      | 3     |
| SRC-11 | SMB / NFS                       | Chia sẻ mạng nội bộ: SMB v2/v3 (Namida), NFS mount thì đã chạy được như thư mục local                                                                       | P2      | 3     |
| SRC-12 | Dropbox / OneDrive              | OAuth, tương tự Google Drive                                                                                                             | P3      | 3     |
| SRC-13 | Jellyfin | Metadata, ảnh bìa, nhập playlist từ server, báo phát về server; xác thực bằng user và mật khẩu hoặc API key, credential trong keyring (Namida). Chưa làm | P2      | 3     |
| SRC-14 | FTP | Duyệt và phát từ FTP. Ưu tiên FTPS; cảnh báo khi dùng FTP thường vì mật khẩu gửi dạng rõ (Namida hỗ trợ FTP). Chưa làm | P3      | 3     |

## 14. Cache & offline

| ID       | Tính năng              | Mô tả / tiêu chí hoàn thành                                                  | Ưu tiên | Phase |
| -------- | ---------------------- | ---------------------------------------------------------------------------- | ------- | ----- |
| CACHE-01 | Cache đĩa trong suốt   | LRU cache cho file đã stream, giới hạn dung lượng cấu hình được              | P0      | 3     |
| CACHE-02 | Tải về để nghe offline | Ghim bài/album/playlist; hiện tiến độ tải; không bị LRU xoá                  | P1      | 3     |
| CACHE-03 | Chỉ báo offline        | Icon cho bài đã có sẵn; làm mờ bài không phát được khi mất mạng              | P1      | 3     |
| CACHE-04 | Tải trước              | Tải sẵn N bài tiếp theo trong hàng đợi                                       | P1      | 3     |
| CACHE-05 | Chính sách mạng        | Chỉ stream/tải qua Wi-Fi, giới hạn chất lượng khi dùng mạng di động (mobile) | P2      | 3     |
| CACHE-06 | Quản lý cache          | Xem dung lượng theo nguồn, xoá cache, đổi vị trí lưu; chọn xoá theo mức ưu tiên (Namida 7.4, chưa làm)                         | P1      | 3     |

## 15. Thống kê nghe nhạc

Lịch sử chỉ lưu trên máy, không gọi mạng. Lượt nghe được ghi từ Phase 1 dù UI làm sau, vì lịch sử không thể bù lại. Nhật ký nghe, phát nhiều nhất, lịch sử từng bài và import/export luôn miễn phí; chỉ biểu đồ nâng cao và tổng kết năm là ứng viên premium (§20). UX tham khảo Namida, chỉ lấy hành vi: license của Namida là EULA, không dùng lại code hay asset.

| ID      | Tính năng                | Mô tả / tiêu chí hoàn thành                                                                                                                                                                                                                                           | Ưu tiên | Phase |
| ------- | ------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- | ----- |
| STAT-01 | Ghi lượt nghe            | Một lượt được tính khi bài dài hơn 30 giây và đã nghe ≥ min(50% thời lượng, 4 phút) (quy tắc Last.fm/ListenBrainz, dùng chung với EXT-01). Thời gian nghe cộng dồn lúc đang phát, không tính seek và pause; repeat-one tính lại mỗi vòng; thời điểm lượt = lúc bắt đầu phát; bài chưa biết thời lượng thì xét sau 4 phút. Ngưỡng (30 giây, 50 % hoặc 4 phút) chỉnh được trong Settings (Namida; chưa làm). Lưu append-only trong DB thư viện, kèm play count, lần đầu và lần cuối của từng bài. Lượt nghe định danh bài bằng path (không khoá ngoại tới `tracks`): file mất khỏi thư viện thì lượt nghe vẫn còn và tự khớp lại khi file quay lại đúng chỗ; file bị chuyển chỗ thì lượt nghe cũ thành mồ côi (nối lại theo size, mtime, tag để sau) — ✅ đã làm; tuỳ chọn có trong Settings (Sắp có), chưa nối (ngưỡng phút và phần trăm) | P0      | 1     |
| STAT-02 | Bỏ qua                   | Đếm lượt skip, dùng cho smart playlist                                                                                                                                                                                                                                | P2      | 1     |
| STAT-03 | Màn hình thống kê        | Top bài/album/nghệ sĩ theo tuần/tháng/năm, tổng thời gian nghe; biểu đồ heatmap, giờ nghe trong ngày, streak, session                                                                                                                                                 | P2      | 4     |
| STAT-04 | Tổng kết năm             | Trang "Năm của bạn" kiểu Wrapped, có thể xuất ảnh                                                                                                                                                                                                                     | P3      | 4     |
| STAT-05 | Import lịch sử           | Nhập lịch sử từ Last.fm / ListenBrainz. Ghép bài theo MBID, rồi title + artist đã chuẩn hoá; bài không ghép được vào danh sách chờ để người dùng chọn bài, không ghi thẳng vào lịch sử. Bỏ trùng trong cửa sổ 280 giây chỉ áp dụng cho dữ liệu import/đồng bộ; thêm import file export Spotify (Namida 6.5, chưa làm)          | P3      | 4     |
| STAT-06 | Nhật ký nghe             | Timeline mới nhất trước, nhóm theo ngày (header dính), chip chọn năm, lịch có chấm ở ngày có nghe để nhảy tới; mỗi dòng có badge "lần nghe thứ N"; xoá lượt nghe có undo                                                                                               | P1      | 1     |
| STAT-07 | Phát nhiều nhất theo khoảng | Hôm nay, 7 ngày, 30 ngày, 6 tháng, năm, tất cả, khoảng tuỳ chọn; khoảng tính theo mốc ngày lịch; nút sang kỳ trước/sau. Bằng lượt thì bài có lần nghe cuối sớm hơn đứng trước; tạo playlist từ kết quả (Namida 8.2, chưa làm)                                                                                       | P1      | 1     |
| STAT-08 | Lịch sử từng bài         | Số lượt nghe, lần đầu, lần cuối và danh sách các lượt của một bài; xoá từng lượt; sửa thời điểm hoặc gộp lượt (Namida, chưa làm); hiện số lượt và lần nghe gần nhất trên dòng bài                                                                                                                                                                                      | P1      | 1     |
| STAT-09 | Xuất lịch sử             | Xuất NDJSON có version, mỗi dòng một lượt; nằm trong bản sao lưu (SET-03)                                                                                                                                                                                             | P2      | 4     |
| STAT-10 | Tắt ghi & xoá lịch sử    | Cài đặt bật/tắt ghi lịch sử (tắt thì không ghi thêm, giữ dữ liệu cũ); "Xoá toàn bộ lịch sử" có xác nhận — ✅ đã làm | P0      | 1     |
| STAT-11 | Ngữ cảnh của lượt nghe   | Mỗi lượt ghi lại phát từ đâu (album, nghệ sĩ, playlist…)                                                                                                                                                                                                             | P2      | 1     |
| STAT-12 | Thời gian nghe theo ngày | Tổng thời gian nghe mỗi ngày, lấy từ lượt nghe                                                                                                                                                                                                                       | P2      | 4     |
| STAT-13 | Nghe lại (Lost Memories) | Gợi ý bài đã nghe quanh thời điểm này vài năm trước, dựa trên nhật ký lượt nghe STAT-01 (Namida "Lost Memories"). Chưa làm. ID này thay cho "STAT-06" trong con-ton-dong §7, vì STAT-06 đã là Nhật ký nghe | P3      | 4     |

## 16. Cài đặt, sao lưu & đồng bộ

| ID     | Tính năng             | Mô tả / tiêu chí hoàn thành                                                                                                                                                        | Ưu tiên | Phase |
| ------ | --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- | ----- |
| SET-01 | Màn hình cài đặt      | Nhóm: Thư viện, Phát nhạc, Giao diện, Lời bài hát, Nguồn, Tích hợp, Nâng cao, Giới thiệu; hiện có: Giao diện, Thư viện, Sao lưu & khôi phục (giữ chỗ), Nâng cao, Giới thiệu                                                                                       | P0      | 1     |
| SET-02 | Lưu theo chuẩn XDG    | Config ở `$XDG_CONFIG_HOME/kanaru`, DB ở `$XDG_DATA_HOME/kanaru`, cache ở `$XDG_CACHE_HOME/kanaru`, log ở `$XDG_CACHE_HOME/kanaru/logs` (không có biến thì `~/.cache/kanaru/logs`) — ✅ đã làm | P0      | 1     |
| SET-03 | Sao lưu / khôi phục   | Xuất và nhập một file chứa cài đặt, playlist, rating, play count (không chứa credential); sao lưu tự động theo lịch, giữ tối đa N file; nhập có gộp với dữ liệu hiện có; tự khôi phục khi cài mới (Namida, chưa làm); mục giữ chỗ (Sắp có) trong Settings → Sao lưu & khôi phục | P2      | 4     |
| SET-04 | Đồng bộ giữa thiết bị | Đồng bộ playlist, rating, cài đặt qua một nguồn của người dùng (WebDAV/S3); hoặc trực tiếp qua LAN (xem SET-10)                                                                                                         | P3      | 4     |
| SET-05 | Đặt lại               | Xoá thư viện và quét lại; đặt lại toàn bộ cài đặt                                                                                                                                  | P1      | 1     |
| SET-06 | Log & báo lỗi         | Xem và xuất log để đính kèm khi báo lỗi; không tự gửi đi đâu. Một phần: Settings → Nâng cao có nút mở thư mục log (mật khẩu và token đã được che trước khi ghi); xem và xuất trong app chưa làm                                                                                                                       | P1      | 1     |
| SET-07 | Kiểm tra cập nhật     | Báo khi có bản mới (tắt được; tự tắt trong bản Flatpak/distro)                                                                                                                     | P3      | 1     |
| SET-08 | Tìm trong Settings | Ô tìm mục cài đặt và gợi ý nhanh ở đầu trang Settings; hiện cả mục đang ẩn (Namida "settings search"). Chưa làm | P3      | 1     |
| SET-09 | Mô tả và tài liệu trong Settings | Mỗi dòng cài đặt có một dòng chữ nhỏ giải thích trọng tâm; liên kết tới tài liệu; tài liệu đi kèm bản cài để đọc offline (con-ton-dong §11; Namida). Một phần: mọi dòng Settings có chữ phụ (en, vi); phần liên kết tài liệu chưa làm | P2      | 1     |
| SET-10 | Đồng bộ trực tiếp qua LAN | Đồng bộ metadata, lượt nghe, playlist, hàng đợi và lời giữa các thiết bị qua mạng nội bộ, ghép đôi bằng mã. Tắt mặc định, có công tắc riêng theo PRIV-03 (Namida "sync over local network"). Khác SET-04 (qua nguồn của người dùng). Chưa làm | P3      | 4     |

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
| PKG-01 | AppImage        | Một file chạy được trên các distro phổ biến, đã bundle libmpv — ✅ đã làm (x86_64, glibc ≥ 2.35, `make appimage`) | P0      | 1     |
| PKG-02 | Flatpak         | Phát hành trên Flathub; sandbox chỉ cấp quyền vào thư mục nhạc qua portal | P1      | 1     |
| PKG-03 | `.deb` / `.rpm` | Gói cho Debian/Ubuntu và Fedora                                           | P1      | 1     |
| PKG-04 | AUR             | `kanaru-bin` cho Arch                                                     | P2      | 1     |
| PKG-05 | Nix             | Package trong `flake.nix`                                                 | P2      | 1     |
| PKG-06 | Windows / macOS | Installer MSIX/EXE, bản portable; `.dmg` đã ký                            | P1      | 2     |
| PKG-07 | Android / iOS   | Play Store, F-Droid (bản không có thành phần đóng), App Store             | P1      | 2     |
| PKG-08 | Gộp schema DB trước khi phát hành | Chưa phát hành nên chưa có DB nào của người dùng cần nâng cấp; các bước migrate hiện có (v1→v2→v3) chỉ để máy dev khỏi phải quét lại. Ngay trước bản phát hành đầu tiên: xoá lịch sử schema cũ (`drift_schemas/library_db/`, `library_database.steps.dart`, các `fromXToY`, `library_migration_v3.dart`, test migration), đặt `schemaVersion = 1` và chụp lại snapshot v1. Từ bản phát hành trở đi mới bắt buộc viết migration. Giữ `library_keys_backfill.dart`: nó chạy theo `keysVersion`, không phụ thuộc migration | P0 | 1 |

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
| Thống kê nâng cao, tổng kết năm                | STAT-03, STAT-04 | Nhật ký nghe và lịch sử cơ bản vẫn miễn phí |
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
