# Các lỗi thường gặp khi "Vibe Coding" với AI

> **Vibe Coding**: để AI sinh code, chạy thử thấy chạy được là nhận, không đọc hay hiểu sâu bản chất.
> AI thường gây ra các nhóm lỗi dưới đây.

## Mục lục

- [A. Kiến trúc và thiết kế](#a-kiến-trúc-và-thiết-kế)
- [B. Logic và xử lý lỗi](#b-logic-và-xử-lý-lỗi)
- [C. Bất đồng bộ, trạng thái và tài nguyên](#c-bất-đồng-bộ-trạng-thái-và-tài-nguyên)
- [D. Dữ liệu và database](#d-dữ-liệu-và-database)
- [E. Bảo mật](#e-bảo-mật)
- [F. Hiệu năng](#f-hiệu-năng)
- [G. Kiểm thử](#g-kiểm-thử)
- [H. DevOps, cấu hình và vận hành](#h-devops-cấu-hình-và-vận-hành)
- [I. Tài liệu và chất lượng code](#i-tài-liệu-và-chất-lượng-code)
- [J. Lỗi về quy trình làm việc với AI](#j-lỗi-về-quy-trình-làm-việc-với-ai)
- [K. Checklist review nhanh](#k-checklist-review-nhanh)
- [L. Cách phòng tránh chung](#l-cách-phòng-tránh-chung)

---

## A. Kiến trúc và thiết kế

### 1. Vá lỗi kiểu "chắp vá" làm nát kiến trúc (Patch-on-Patch)

- **Hiện tượng**: Khi gặp bug hoặc edge case, thay vì tìm nguyên nhân gốc (root cause) trong mô hình dữ liệu hay luồng xử lý, AI thêm ngay một `if-else`, một biến cờ (flag) cục bộ, hoặc một hàm bọc tạm thời.
- **Hậu quả**:
  - Sau vài lần "prompt để fix", code thành spaghetti với các điều kiện chồng chéo, logic mâu thuẫn nhau.
  - Phá vỡ ranh giới module: UI gọi thẳng xuống Database, feature này import chéo feature kia thay vì đi qua tầng `shared/core`.

### 2. Over-engineering và trừu tượng hoá thừa

- **Hiện tượng**: Dựng sẵn interface, factory, strategy, generic cho thứ chỉ có một implementation.
- **Hậu quả**: Code dài gấp nhiều lần mức cần thiết, khó đọc, khó sửa. Đây là mặt trái của lỗi số 1: một bên vá quá ít, một bên thiết kế quá nhiều.

### 3. Bất nhất quy ước và "mất trí nhớ" ngữ cảnh (Context Drift)

- **Hiện tượng**: Context window có giới hạn, AI không hiểu toàn diện kiến trúc cả dự án.
- **Biểu hiện**:
  - Xử lý lỗi mỗi nơi một kiểu: chỗ dùng `Result<T, E>`, chỗ ném Exception, chỗ âm thầm trả `null`.
  - Đặt tên lộn xộn: trộn `snake_case` và `camelCase`, tên biến chung chung vô nghĩa.
  - **Ảo giác phiên bản thư viện** (Version Hallucination): gọi phương thức đã deprecated, hoặc phương thức chỉ có ở bản tương lai hay thư viện khác.

### 4. Tạo lại bánh xe (Reinventing the Wheel)

- Tự viết lại thứ đã có sẵn trong standard library hoặc trong chính codebase (hàm util, helper, component dùng chung).
- Thêm thư viện nặng chỉ để làm việc chỉ cần vài dòng code (xem thêm mục E.6).

---

## B. Logic và xử lý lỗi

### 1. Thiên kiến "Happy Path" và bỏ quên Edge Cases

AI được huấn luyện trên code mẫu phổ biến nên code chạy rất mượt ở trường hợp lý tưởng. Các lỗi hay bị bỏ sót:

- **Mạng và I/O**: mất mạng giữa chừng, timeout, HTTP 429 (rate limit), server trả JSON rỗng hoặc sai format.
- **Dữ liệu biên**: chuỗi đặc biệt, emoji, chuỗi rỗng, số âm, tràn số (integer overflow), ngày tháng khác múi giờ.
- **Hệ điều hành / Filesystem**: không có quyền ghi (Permission denied), ổ đĩa đầy, ký tự phân cách đường dẫn (`/` vs `\`), tên file chứa ký tự cấm.

### 2. Nuốt lỗi (Swallowed Exceptions)

- `catch (e) {}` rỗng, hoặc chỉ `console.log(e)` rồi chạy tiếp như không có gì.
- Trả về giá trị mặc định (`[]`, `0`, `null`) khi lỗi, bug bị che giấu và lộ ra rất xa nơi gây lỗi.
- Khác với lỗi A.3: đây là xử lý _có nhưng sai bản chất_, không chỉ là bất nhất.

### 3. Né lỗi thay vì giải quyết

- Thêm `try/catch` bao ngoài cho hết báo đỏ.
- Dùng `// @ts-ignore`, `as any`, `@SuppressWarnings` để qua mặt compiler.

### 4. Xử lý dữ liệu đầu vào lỏng lẻo

- Chỉ validate ở frontend, backend tin tưởng hoàn toàn.
- Không giới hạn kích thước body hoặc file upload; chỉ kiểm tra đuôi file mà không kiểm tra MIME thật (magic bytes).
- Không kiểm tra schema khi parse JSON từ nguồn ngoài (output của LLM, webhook, API bên thứ ba) nên crash khi thiếu trường hoặc sai kiểu.
- Regex dễ dính ReDoS.

### 5. Xử lý thời gian, tiền tệ và số

- Dùng `float`/`double` để tính tiền thay vì `BigDecimal` hoặc số nguyên theo đơn vị nhỏ nhất.
- Lưu giờ local thay vì UTC; nhầm `LocalDateTime` với `Instant`/`ZonedDateTime`.
- Làm tròn sai quy tắc nghiệp vụ; so sánh số thực bằng `==`.
- Tính ngày bằng cách cộng 86400 giây, bỏ qua DST và năm nhuận.

---

## C. Bất đồng bộ, trạng thái và tài nguyên

### 1. Race conditions

Hai tác vụ cùng đọc/ghi một biến trạng thái mà không có lock/mutex hay kiểm tra phiên bản (optimistic locking).

### 2. Unmounted / Disposed State

Trong UI (Flutter, React...), AI hay gọi `setState` hoặc truy cập `context` sau một lệnh `await` kéo dài mà không kiểm tra component/widget còn tồn tại hay không (`mounted`, `isMounted`, `AbortController`).

### 3. Rò rỉ bộ nhớ và tài nguyên (Memory / Resource Leak)

- Lắng nghe Stream, Event, Timer, WebSocket nhưng quên huỷ (`dispose`, `cancel`, `close`, `removeEventListener`) khi đối tượng bị huỷ.
- Không đóng file handle, connection, cursor, HTTP client.

### 4. Timeout và retry sai cách

- Đặt timeout vô hạn hoặc không đặt timeout cho lời gọi ra ngoài.
- Retry ngay lập tức, không có backoff và jitter, gây thundering herd.
- Retry cả những thao tác không idempotent.

---

## D. Dữ liệu và database

### 1. Quản lý transaction và tính nhất quán

- Thiếu `@Transactional` hoặc đặt sai phạm vi, nghiệp vụ nhiều bước ghi dở dang khi lỗi giữa chừng.
- Gọi hàm `@Transactional` nội bộ trong cùng class (self-invocation), proxy không hoạt động.
- Thiếu idempotency cho API thanh toán/tạo đơn, retry là nhân đôi dữ liệu.
- Kiểm tra "đã tồn tại chưa" ở tầng code (check-then-insert) mà thiếu unique constraint ở DB, dính race condition.

### 2. Thiết kế và truy vấn database kém

- Thiếu index cho cột hay dùng trong `WHERE`/`JOIN`, hoặc ngược lại đánh index tràn lan.
- Dùng `SELECT *`; lazy loading của ORM sinh N+1 ngầm (khó thấy hơn N+1 viết tay).
- Không phân trang, trả về toàn bộ bảng.

### 3. Migration không an toàn

- Đổi kiểu cột, thêm cột `NOT NULL` không có default trên bảng lớn.
- Sửa schema trực tiếp mà không có migration (Flyway, Liquibase, Prisma Migrate...).
- Dùng `ddl-auto=update` trên production.

---

## E. Bảo mật

### 1. Lỗ hổng "nhìn có vẻ an toàn" (Silent Security Holes)

AI giải quyết đúng chức năng yêu cầu nhưng bỏ qua nguyên tắc phòng thủ:

- **Nối chuỗi trực tiếp**: sinh truy vấn SQL/Shell bằng cộng chuỗi (SQL Injection, Command Injection). Cần dùng prepared statement / tham số hoá.
- **Path Traversal**: mở file theo đường dẫn người dùng nhập mà không chặn `../` hay ký tự NUL.
- **CORS và Auth quá thoáng**: tự cấu hình `Access-Control-Allow-Origin: *`, bỏ qua xác thực token ở API phụ.
- **Hardcode dữ liệu nhạy cảm**: sinh sẵn secret key, token mẫu, hoặc lưu thông tin nhạy cảm dạng plain text.

### 2. Xác thực và phân quyền sâu hơn

- **IDOR/BOLA**: chỉ kiểm tra đã đăng nhập, không kiểm tra tài nguyên có thuộc về user đó không (ví dụ `GET /orders/{id}`).
- **Mass assignment**: bind thẳng request body vào entity, user tự gửi `role: "admin"` hoặc `isVerified: true`. Cần dùng DTO với whitelist trường.
- **Thiếu kiểm tra phân quyền theo vai trò** ở từng endpoint, chỉ ẩn nút ở UI.

### 3. JWT và quản lý phiên sai cách

- Không kiểm tra `exp`, chấp nhận `alg: none`, secret yếu.
- Lưu token trong `localStorage` (dễ bị XSS đánh cắp) thay vì cookie `HttpOnly` + `Secure` + `SameSite`.
- Không có cơ chế thu hồi (revoke) hay rotate refresh token.

### 4. Mật khẩu và dữ liệu nhạy cảm

- Hash password bằng MD5/SHA-1 hoặc SHA-256 trơn, thay vì bcrypt/argon2/scrypt.
- Trả về stack trace hoặc message lỗi chi tiết ra client.
- Log ra password, token, PII.

### 5. Thiếu giới hạn tần suất

Không có rate limit cho login, OTP, reset password, các API tốn tài nguyên (brute force, enumeration, DoS).

### 6. Phụ thuộc và chuỗi cung ứng (Supply Chain)

- **Slopsquatting**: AI bịa tên package không tồn tại, kẻ xấu đăng ký tên đó kèm mã độc, người dùng cài theo.
- Không pin version, cài package cũ có CVE đã biết.
- Chạy `curl | bash` hoặc copy lệnh cài đặt từ nguồn không rõ.

---

## F. Hiệu năng

### 1. Thuật toán kém hiệu năng tiềm ẩn (Hidden Performance Traps)

AI thường chọn giải pháp dễ viết nhất thay vì tối ưu:

- **O(N²) ngầm**: dùng `list.contains(...)` bên trong vòng lặp duyệt list khác (nên dùng `Set`/`Map` để đạt O(1)).
- **Re-render vô tội vạ**: đặt state ở component cha khiến mỗi thao tác nhỏ rebuild toàn bộ cây giao diện.
- **N+1 Query**: query DB trong vòng lặp thay vì batch (`JOIN` hoặc `WHERE id IN (...)`).
- **Deep copy / parse lặp lại**: deserialize JSON hoặc clone object lớn liên tục ở đoạn code chạy 60fps.

### 2. Đọc toàn bộ dữ liệu vào bộ nhớ

Đọc cả file lớn hoặc cả bảng vào RAM thay vì xử lý theo stream/chunk/cursor.

---

## G. Kiểm thử

### 1. Test "ảo tưởng" (Tautological / False-Positive Tests)

Khi nhờ AI viết unit test cho code nó vừa sinh ra:

- AI mock hết mọi thứ, đến mức test chỉ kiểm tra hàm mock có được gọi hay không, không kiểm tra logic nghiệp vụ thật.
- Viết test khẳng định lại chính logic lỗi: hàm tính sai thì test assert giá trị sai đó là đúng. Kết quả: All Tests Passed nhưng lên production thì vỡ.

### 2. Xoá hoặc vô hiệu hoá test/check để pipeline xanh

- `skip`, `@Ignore`, `xit`, nới lỏng assert, tắt lint, hạ ngưỡng coverage.
- Sửa test cho khớp code lỗi thay vì sửa code.

### 3. Thiếu test cho đường lỗi

Chỉ test happy path; không test timeout, input sai, quyền truy cập, concurrency.

---

## H. DevOps, cấu hình và vận hành

### 1. Docker và hạ tầng

- Dockerfile chạy bằng root, dùng tag `latest`, không multi-stage, copy cả `.env` vào image.
- Thiếu healthcheck, graceful shutdown, giới hạn tài nguyên (CPU/RAM limit).

### 2. CI/CD

- Nhét secret thẳng vào file workflow.
- Cấp quyền quá rộng cho pipeline hoặc token.

### 3. Cấu hình dev lọt lên production

`DEBUG=true`, `ddl-auto=update`, CORS mở toang, tài khoản admin mặc định, endpoint debug/actuator không bảo vệ.

### 4. Giả định môi trường ("chạy được trên máy tôi")

- Hardcode đường dẫn, port, URL `localhost`.
- Phụ thuộc thứ tự khởi động; biến môi trường không được khai báo hay validate.
- Code chỉ chạy đúng trên một OS hoặc một phiên bản runtime.
- Không validate cấu hình lúc khởi động (fail fast), lỗi lộ ra giữa chừng khi đang chạy.

### 5. Khả năng quan sát (Observability)

- Không có log ở điểm quan trọng, hoặc log quá nhiều và lộ dữ liệu.
- Log không có correlation/request ID nên không truy vết được.
- Không có metrics, health endpoint, alert.
- Thông báo lỗi chung chung kiểu "Something went wrong", thiếu ngữ cảnh để debug.

---

## I. Tài liệu và chất lượng code

### 1. Comment sai mục đích

- Comment mô tả _code làm gì_ (thừa) thay vì _vì sao làm vậy_ (cần).
- Comment lỗi thời so với code sau nhiều lần sửa.

### 2. Code chết và rác

- Hàm không dùng, import thừa, biến thừa, TODO không ai làm sau nhiều vòng "prompt để fix".
- File sinh ra tạm thời (`test2.js`, `utils_new.ts`) bị bỏ lại.

### 3. Không đồng bộ tài liệu

Đổi hành vi nhưng không cập nhật README, tài liệu API (OpenAPI), test, changelog.

---

## J. Lỗi về quy trình làm việc với AI

| Lỗi                                        | Biểu hiện                                         | Hậu quả                                                   |
| ------------------------------------------ | ------------------------------------------------- | --------------------------------------------------------- |
| **Sửa quá phạm vi**                        | Yêu cầu sửa một chỗ nhưng AI refactor nhiều file  | Diff khổng lồ, không review nổi, dễ phá chức năng khác    |
| **Tự tin quá mức**                         | Khẳng định "đã fix" hoặc "test pass" mà chưa chạy | Bug lọt qua, mất niềm tin vào kết quả                     |
| **Ảo giác API/thư viện**                   | Gọi hàm, tham số, cờ CLI không tồn tại            | Lỗi biên dịch/runtime, hoặc tệ hơn là hành vi sai âm thầm |
| **Không đọc code AI sinh ra**              | Chạy được là nhận                                 | Nợ kỹ thuật tích tụ, không ai hiểu hệ thống               |
| **Prompt mơ hồ, thiếu ràng buộc**          | Không nêu stack, quy ước, giới hạn                | Context drift, code lệch kiến trúc                        |
| **Dán secret/dữ liệu nhạy cảm vào prompt** | Gửi key, dữ liệu khách hàng cho AI                | Rò rỉ thông tin                                           |

---

## K. Checklist review nhanh

Dùng khi review code do AI sinh ra.

**Kiến trúc**

- [ ] Có đúng ranh giới module/layer không? Có import chéo bất hợp lý không?
- [ ] Có abstraction thừa hoặc code trùng lặp với thứ đã có sẵn không?
- [ ] Cách xử lý lỗi, đặt tên có nhất quán với phần còn lại của dự án không?

**Logic**

- [ ] Đã xét: null, rỗng, âm, rất lớn, ký tự đặc biệt, múi giờ?
- [ ] Đường lỗi (timeout, mất mạng, 429, JSON sai format) có được xử lý không?
- [ ] Có `catch` rỗng hoặc nuốt lỗi không?
- [ ] Tiền tệ/thời gian dùng đúng kiểu dữ liệu chưa?

**Async và tài nguyên**

- [ ] Có race condition trên state dùng chung không?
- [ ] Mọi listener/timer/stream/connection có được huỷ/đóng không?
- [ ] Có kiểm tra `mounted` sau `await` trong UI không?

**Dữ liệu**

- [ ] Nghiệp vụ nhiều bước có nằm trong transaction đúng phạm vi không?
- [ ] Ràng buộc unique/FK có ở DB, không chỉ ở code không?
- [ ] Có N+1, thiếu index, thiếu phân trang không?
- [ ] Migration có an toàn trên bảng lớn không?

**Bảo mật**

- [ ] Mọi query có tham số hoá? Có chỗ nối chuỗi vào SQL/Shell/path không?
- [ ] Mỗi endpoint có kiểm tra quyền sở hữu tài nguyên (chống IDOR) không?
- [ ] Có dùng DTO whitelist thay vì bind thẳng entity không?
- [ ] Password hash bằng bcrypt/argon2? JWT kiểm tra đủ `exp`, `alg`?
- [ ] Không còn secret hardcode, không log dữ liệu nhạy cảm?
- [ ] Các package được nhắc tới có thật, có đáng tin, đã pin version?

**Hiệu năng**

- [ ] Có `contains` trong vòng lặp, query trong vòng lặp không?
- [ ] Có đọc toàn bộ dữ liệu lớn vào RAM không?

**Test**

- [ ] Test có kiểm tra hành vi thật hay chỉ kiểm tra mock?
- [ ] Giá trị kỳ vọng được suy từ yêu cầu nghiệp vụ hay chép từ output của code?
- [ ] Có test nào bị skip/xoá/nới lỏng không?

**Vận hành**

- [ ] Dockerfile không chạy root, không dùng `latest`, không chứa `.env`?
- [ ] Cấu hình dev/prod tách biệt? Có validate config lúc khởi động?
- [ ] Có log đủ ngữ cảnh, request ID, health endpoint?

**Quy trình**

- [ ] Diff có nằm trong phạm vi yêu cầu không?
- [ ] Mình đã tự chạy thử, không chỉ tin vào lời AI?

---

## L. Cách phòng tránh chung

1. **Giữ diff nhỏ**: mỗi lần một thay đổi; bắt AI nêu _nguyên nhân gốc_ trước khi sửa.
2. **Tự viết hoặc review kỹ test** cho nghiệp vụ lõi và edge case; không để AI vừa viết code vừa viết test mà không kiểm chứng.
3. **Tự động hoá kiểm tra trong CI**: linter, type-check strict, SAST, dependency audit, secret scanning.
4. **Cung cấp tài liệu quy ước dự án** (kiểu `AGENTS.md` / `CLAUDE.md`): kiến trúc, đặt tên, cách xử lý lỗi, thư viện được phép dùng.
5. **Kiểm chứng mọi package và API** AI nhắc tới trước khi dùng (có tồn tại không, đúng phiên bản không, đọc docs chính thức).
6. **Đọc và hiểu code trước khi merge**; nếu không giải thích được đoạn code làm gì thì chưa nên nhận.
7. **Đặt ràng buộc rõ trong prompt**: stack, phiên bản, phạm vi file được sửa, yêu cầu không refactor ngoài phạm vi.
8. **Không đưa secret hay dữ liệu thật vào prompt**.
