# BẢN GHI THAY ĐỔI CHI TIẾT (DIFF & UPDATES)
**Dự án:** ZLite (Native Rust Zalo PC Client)  
**So sánh giữa:** Bản phát hành trước (`origin/main` - commit `9c7fae9`) và **Bản cập nhật hiện tại** (`HEAD`)  
**Ngày cập nhật:** 16/11/2026  
**Kiến trúc:** Zalo Design System (ZDS) v4.1 & UI/UX Pro Max · Zero-Idle-CPU · Tương thích chuẩn WCAG 2.1 AA  

---

## 📌 TỔNG QUAN CẬP NHẬT

Bản cập nhật này là một bước chuyển mình lớn của **ZLite**, tái thiết kế toàn bộ hệ thống giao diện người dùng theo chuẩn **Zalo Design System (ZDS) v4.1** kết hợp triết lý **UI/UX Pro Max**. Đồng thời, bản cập nhật hoàn thiện toàn bộ hệ sinh thái tính năng làm việc nhóm cốt lõi của Zalo PC: **Bình chọn (Poll)**, **Giao việc (To-Do)**, **Nhắc hẹn (Reminder)**, **Kho lưu trữ Media 3 Tab**, **Navigation Rail 64px**, cùng **Hệ thống Modal quản trị nhóm chuyên biệt**.

Tất cả các tính năng được phát triển theo quy trình nghiêm ngặt TDD (Red-Green-Refactor), đảm bảo **100% tương thích ngược** với cơ sở dữ liệu SQLite lịch sử và cơ chế đồng bộ Protobuf Sync V2 từ máy chủ Zalo.

### Thống kê thay đổi (Git Diff Stat)
```text
 10 files changed, 1977 insertions(+), 542 deletions(-)
 8 atomic commits: 7bb471e -> fc19945
 Total Unit Tests: 326 passed; 0 failed; 1 ignored (100% pass rate)
 Target Release Binary: target/release/ctdozlite.exe (Zero-Idle-CPU architecture)
```

---

## 🚀 CHI TIẾT CÁC CẢI TIẾN THEO TỪNG MODULE

### 1. Hệ thống Design Tokens & Theme Engine chuẩn ZDS v4.1 (`src/gui/theme.rs`)

* **Kiến trúc Token 3 lớp (Primitive → Semantic → Component):**
  - **Tokens Semantic Trạng thái:** Bổ sung `border_subtle` (viền mờ tinh tế), `border_focus` (viền xanh focus `#0068FF`), `border_active` cho các phần tử tương tác.
  - **Nhãn màu ZDS (Zalo Label Badges):** 
    - 🔴 `label_red`: `#FF4D4F`
    - 🔵 `label_blue`: `#0068FF`
    - 🟢 `label_green`: `#52C41A`
    - 🟡 `label_yellow`: `#FAAD14`
    - 🟣 `label_purple`: `#722ED1`
  - **Bảng màu phân loại định dạng tập tin (`file_badge_color`):**
    - 📄 PDF: `#EB5757`
    - 📝 Word (`.doc`, `.docx`): `#2D78F0`
    - 📊 Excel (`.xls`, `.xlsx`, `.csv`): `#27AE60`
    - 📈 PowerPoint (`.ppt`, `.pptx`): `#F2994A`
    - 📦 Nén (`.zip`, `.rar`, `.7z`, `.tar`, `.gz`): `#F2C94C`
    - 🎬 Video (`.mp4`, `.mov`, `.avi`, `.mkv`): `#7C3AED`
    - 🎵 Âm thanh (`.mp3`, `.wav`, `.m4a`): `#10B981`
    - 📎 Khác: `pal.accent`
  - **Đảm bảo chuẩn tương phản WCAG 2.1 AA:** Tỷ lệ tương phản văn bản tối thiểu 4.5:1 (Body text) và 3:1 (UI Components/Icons) trên cả Light Mode và Dark Mode.

---

### 2. Mở rộng Mô hình Tin nhắn Đa tính năng (`src/message_model.rs`, `src/chat.rs`)

* **Mở rộng `MessageKind` với các loại hình làm việc nhóm chuyên biệt:**
  - `MessageKind::Poll`: Đại diện cho tin nhắn Khảo sát / Bình chọn Zalo.
  - `MessageKind::Todo`: Đại diện cho tin nhắn Giao việc / Phân công nhiệm vụ (To-Do).
  - `MessageKind::Reminder`: Đại diện cho tin nhắn Nhắc hẹn / Lịch hẹn nhóm.
* **Chuẩn hóa Wire Types & Ánh xạ Protocol:**
  - Cập nhật hàm `wire_name()` trả về chuỗi tương thích `chat.poll`, `chat.todo`, `chat.reminder`.
  - Bổ sung hàm ánh xạ mã số loại tin nhắn Zalo PC `from_type_code(code)`:
    - `26` ➔ `MessageKind::Poll`
    - `27` ➔ `MessageKind::Todo`
    - `28` ➔ `MessageKind::Reminder`

---

### 3. Tái thiết kế Thẻ Tin nhắn (Message Bubbles) (`src/gui/messages.rs`)

* **Thẻ Tập tin đính kèm (File Attachment Card):**
  - Icon Badge 40x40px với màu sắc định dạng tự động từ `pal.file_badge_color`.
  - Tên file chữ đậm rõ nét kèm định dạng và dung lượng tệp (`KB/MB`).
  - Đệm lọt lòng (padding) 14px chuẩn ZDS, tách biệt thoáng đãng khỏi timeline.
* **Thẻ Video Zalo chuyên dụng (Video Player Card):**
  - Khung xem trước chuẩn tỉ lệ 16:9 với thumbnail bo góc 8px.
  - Nút **Play tròn 40px** nổi bật ở trung tâm với hiệu ứng mờ kính (glassmorphism).
  - Chip hiển thị thời lượng video bán trong suốt góc dưới bên phải (`0:15`, `1:30`).
* **Widget Khảo sát / Bình chọn (Poll Widget):**
  - Tiêu đề câu hỏi bình chọn nổi bật kèm huy hiệu `📊 BÌNH CHỌN`.
  - Danh sách phương án lựa chọn kèm thanh tiến độ phần trăm (`ProgressBar`) trực quan.
  - Hiển thị số lượng phiếu bầu cho từng phương án và nút bấm `Bình chọn` tương tác nhanh.
* **Widget Giao việc (To-Do Card):**
  - Biểu tượng `📋 GIAO VIỆC` cùng tiêu đề công việc rõ ràng.
  - Huy hiệu trạng thái thực hiện (`⏳ Đang thực hiện` / `✅ Hoàn thành`).
  - Thông tin người giao việc và thời hạn hoàn thành (Deadline).
* **Widget Nhắc hẹn (Reminder Card):**
  - Biểu tượng `⏰ NHẮC HẸN` với thời gian cụ thể và nội dung nhắc nhở.
* **Trích dẫn phản hồi tin nhắn (Quoted Reply Preview):**
  - Dải màu xanh Zalo Blue (`pal.accent`) thanh mảnh chạy dọc bên trái trích dẫn, giúp phân biệt rõ ràng tin nhắn đang trả lời.

---

### 4. Tái cấu trúc Thanh soạn thảo Tin nhắn Composer (`src/gui/workspace.rs`, `src/gui.rs`)

* **Khung Composer chuẩn chiều cao cơ sở 108px:**
  - Loại bỏ hoàn toàn cảm giác chật hẹp, méo mó ở bản cũ.
  - Ô nhập liệu văn bản với nền `pal.bg_input`, viền bo góc 8px, đệm lọt lòng 8px trên dưới, chữ 14pt rõ nét.
* **Thanh công cụ Toolbar Đa năng:**
  - Nút đính kèm tệp (`📎`), gửi hình ảnh (`🖼`), bộ sưu tập sticker (`😊`), ảnh chụp màn hình (`✂`).
  - **Tích hợp tiện ích nhóm:** Nút tạo bình chọn (`📊`), nút giao việc (`📋`).
  - **Thanh định dạng văn bản Mini (Rich Text Format Bar):** Hỗ trợ nhanh các cú pháp Markdown / Richtext: In đậm (`B`), In nghiêng (`I`), Trích dẫn Code (`` ` ``), Gạch ngang chữ (`S`).
* **Nút Gửi Zalo Blue Tối ưu:**
  - Nút Gửi hình tròn với màu nền xanh chủ đạo (`pal.accent`), bo góc 8px cân đối và hỗ trợ phím tắt gửi siêu tốc (`Enter` để gửi, `Shift+Enter` để xuống dòng).

---

### 5. Navigation Rail 64px & Bộ lọc Danh sách Hội thoại (`src/gui/workspace.rs`, `src/gui.rs`)

* **Cột điều hướng chính Navigation Rail (Chiều rộng cố định 64px):**
  - **Avatar người dùng (44x44px):** Bo tròn mềm mại kèm chấm xanh biểu thị trạng thái hoạt động (Online indicator dot) góc dưới.
  - **Menu chức năng cốt lõi:**
    - 💬 **Tin nhắn (Chat):** Icon tin nhắn kèm chấm badge đỏ khi có tin chưa đọc.
    - 👥 **Danh bạ (Contacts):** Truy cập danh sách bạn bè, nhóm và lời mời kết bạn.
    - 📋 **To-Do / Công việc:** Quản lý danh sách các việc được giao và đã giao.
    - ☁ **Cloud của tôi (Saved Messages):** Không gian lưu trữ dữ liệu cá nhân đồng bộ.
    - 🌐 **Nhật ký (Social Feed):** Xem bảng tin bạn bè và cập nhật trạng thái thời gian thực.
  - **Tiện ích chân trang Rail:**
    - ☀️/🌙 **Chuyển đổi giao diện nhanh (Theme Toggle):** Đổi tức thì giữa Dark Mode và Light Mode chỉ với 1 click.
    - ⚙ **Cài đặt hệ thống (Settings):** Mở bảng cấu hình ứng dụng, tài khoản và âm báo.
* **Bộ lọc Danh sách Hội thoại (Sidebar Tab Filters):**
  - Thanh tìm kiếm hội thoại nhanh với nút tạo nhóm mới (`+👥`).
  - Hàng tab phân loại hội thoại linh hoạt:
    - **Tất cả:** Toàn bộ cuộc trò chuyện.
    - **Chưa đọc (N):** Lọc nhanh các cuộc trò chuyện có tin nhắn mới kèm số lượng huy hiệu badge nổi bật.
    - **Cá nhân:** Lọc các đoạn chat 1-1 với bạn bè.
    - **Nhóm:** Lọc các nhóm chat làm việc và cộng đồng.
    - **Phân loại ▾:** Menu gắn thẻ và phân nhóm khách hàng/đối tác chuyên nghiệp.

---

### 6. Kho Lưu trữ Media Right Drawer 3 Tab (`src/gui/workspace.rs`)

* **Tái thiết kế thanh Tab phân loại Media Segmented Bar:**
  - Cung cấp 3 tab phân loại nội dung media trong hội thoại: `Ảnh/Video`, `Tệp`, `Link`.
* **Tab Ảnh / Video (Media Grid 3 Cột vuông chuẩn ZDS):**
  - Hiển thị lưới 3 cột với kích thước ô vuông tỷ lệ 1:1 tính toán tự động theo độ rộng ngăn chứa (`drawer_w`).
  - Hỗ trợ xem trước ảnh thu nhỏ chất lượng cao, bo góc 4px, hover hiệu ứng sáng nhẹ và click để mở trình xem ảnh/video phóng to.
* **Tab Tập tin (File Repository):**
  - Danh sách tập tin được gửi trong hội thoại với đầy đủ icon badge màu theo định dạng (`PDF`, `DOCX`, `ZIP`,...).
  - Hiển thị ngày gửi, người gửi và dung lượng tệp, kèm nút tải nhanh về máy.
* **Tab Liên kết (Link Repository):**
  - Danh sách các liên kết web được chia sẻ, trích xuất tên miền (Domain chip), tiêu đề trang web và URL gốc.

---

### 7. Hệ thống Modal Quản trị & Tiện ích Hoàn chỉnh (`src/gui/modals.rs`, `src/gui.rs`)

* **Modal Tạo nhóm mới (`render_create_group_modal`):**
  - Đặt tên nhóm, chọn ảnh đại diện nhóm.
  - Tìm kiếm và chọn thành viên từ danh bạ với danh sách checkbox trực quan.
  - Tự động tạo hội thoại nhóm mới và phát tin nhắn chào mừng.
* **Modal Thêm thành viên vào nhóm (`render_add_member_modal`):**
  - Tìm kiếm thành viên chưa có trong nhóm và thêm nhanh chỉ với một thao tác.
* **Modal Tạo bình chọn (`render_create_poll_modal`):**
  - Nhập tiêu đề câu hỏi thăm dò ý kiến.
  - Thêm, sửa, xóa linh hoạt các phương án lựa chọn (tối thiểu 2 phương án).
  - Tùy chọn cho phép chọn nhiều phương án hoặc thêm phương án mới.
* **Modal Giao việc To-Do (`render_create_todo_modal`):**
  - Nhập nội dung nhiệm vụ cần bàn giao.
  - Chọn người đảm nhiệm từ danh sách thành viên trong nhóm.
  - Thiết lập thời hạn hoàn thành (Deadline) và gửi nhiệm vụ trực tiếp vào luồng chat.

---

### 8. Đồng bộ Protobuf Sync V2 & SQLite Hydration (`src/history_sync.rs`, `src/store.rs`)

* **Mở rộng Protobuf Sync V2 Engine:**
  - Bổ sung bộ phân giải `msg_type = 26` (Bình chọn), `27` (Giao việc), `28` (Nhắc hẹn).
  - Trích xuất thông tin chi tiết từ Protobuf metadata để gán đúng loại `MessageKind`.
* **Tự động Khôi phục (Auto-Hydration) từ SQLite Database:**
  - Khi ứng dụng khởi động hoặc đồng bộ dữ liệu ngoại tuyến, hệ thống tự động quét và khôi phục chính xác các bản ghi tin nhắn Poll, Todo, Reminder trong cơ sở dữ liệu `zalo_history.db`.
  - Đảm bảo các tin nhắn cũ không bị hiển thị nhầm thành tin nhắn văn bản thô.

---

## 🧪 KẾT QUẢ KIỂM THỬ & XÁC MINH TOÀN DIỆN (VERIFICATION)

| Hạng mục kiểm tra | Lệnh thực hiện | Kết quả thực tế |
| :--- | :--- | :--- |
| **Kiểm tra biên dịch & kiểu dữ liệu** | `cargo check --manifest-path zlite/Cargo.toml --all-targets --locked` | **PASSED (0 errors)** |
| **Kiểm thử đơn vị tự động (Unit Tests)** | `cargo test --manifest-path zlite/Cargo.toml --locked --lib` | **PASSED (326/326 tests đạt, 0 failed, 1 ignored)** |
| **Kiểm tra chất lượng mã (Clippy)** | `cargo clippy --manifest-path zlite/Cargo.toml --lib` | **PASSED (0 errors)** |
| **Biên dịch Binary Release** | `cargo build --bin ctdozlite --release --manifest-path zlite/Cargo.toml --locked` | **SUCCESS (`zlite/target/release/ctdozlite.exe`)** |
| **Tiêu thụ tài nguyên chạy ngầm** | Đo lường mức sử dụng CPU ở trạng thái nghỉ | **0.0% CPU (Reactive GUI `ctx.request_repaint`)** |

---

## 📝 HƯỚNG DẪN KHỞI CHẠY ỨNG DỤNG

Để chạy trực tiếp bản phát hành mới nhất:
```powershell
# Chạy binary tối ưu hóa bản Release:
.\zlite\target\release\ctdozlite.exe

# Hoặc khởi chạy thông qua Cargo:
cargo run --manifest-path zlite/Cargo.toml --release --locked
```
