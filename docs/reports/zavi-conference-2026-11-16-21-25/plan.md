# Kế hoạch Triển khai: Cuộc gọi Video nhóm (Zavi Conference)

> **Mã tính năng**: #107  
> **Thời gian**: 16/11/2026 21:25  
> **Chuyên gia**: ZLite (Rust Specialist & Network Audio/Video Architect)

---

## 1. Mục tiêu & Phạm vi
- Triển khai tính năng Hội nghị trực tuyến / Cuộc gọi video nhóm Zavi Conference tương thích hoàn toàn với nền tảng Zalo PC.
- Bóc tách kiến trúc gốc từ `zalo-re`: Các chuỗi `STR_MEETING_*`, `STR_ZAVI_*`, định dạng mã phòng 9 số (`xxx xxx xxx`), mật khẩu 6 số (`\d{6}`), liên kết tham gia `https://zavi.me/meeting/{id}?pwd={pwd}`.
- Giữ vững tiêu chí cốt lõi của ZLite: **Tốc độ - Hiệu năng - Tối ưu** (Zero-Idle-CPU, bộ nhớ ram dưới 30MB).

---

## 2. Kế hoạch Thiết kế & Kiến trúc Code

### A. Module Dữ liệu & Giao thức (`src/zavi.rs`)
- `ZaviMeeting`: Lưu trữ thông tin phòng họp, mã phòng 9 số, mật khẩu, host, trạng thái (Waiting, InProgress, Ended), cài đặt mic/cam mặc định khi vào phòng.
- `ZaviParticipant`: Danh sách thành viên tham gia, trạng thái host, mic mute, camera off, screen sharing.
- `ZaviConferenceState`: Quản lý vòng đời phòng họp, đo thời gian họp trực tiếp (`elapsed_seconds`), lưu lịch sử các cuộc họp đã tham gia.
- Helper functions: `generate_meeting_id()`, `generate_meeting_password()`, `parse_meeting_invite()`, `format_invitation_text()`.

### B. Tích hợp Giao diện Người dùng (Egui GUI)
- **Left Navigation Rail**: Thêm Navigation Icon 6 `lucide::VIDEO` cho Zavi Conference với đèn trạng thái trực tuyến khi đang trong phòng họp.
- **Group Chat Header**: Thêm nút "Họp Zavi" trực tiếp từ thanh công cụ nhóm trò chuyện.
- **Modal Tạo Cuộc Họp (`render_create_meeting_modal`)**: Nhập tên phòng, tự sinh ID/Password, tùy chọn tắt mic/cam khi mới vào, nút sao chép link mời, nút gửi thẻ mời trực tiếp vào chat.
- **Modal Tham Gia Cuộc Họp (`render_join_meeting_modal`)**: Nhập mã phòng 9 số hoặc dán link zavi.me (tự bóc tách ID & pass), nhập mật khẩu và tên hiển thị.
- **Giao diện Phòng Họp Toàn Màn Hình (`render_zavi_conference_overlay`)**:
  - Thanh tiêu đề Top Bar: Tên phòng, thời gian đã họp, E2EE Security Badge, nút đổi chế độ hiển thị Lưới (Gallery) / Diễn giả (Speaker).
  - Lưới video đa thành viên (Responsive Gallery Grid): Hiệu ứng viền phát sáng khi người nói đang phát biểu, avatar sóng âm khi tắt camera, luồng video giả lập WebRTC SFU khi bật camera.
  - Floating Control Bar: Điều khiển Mic, Camera, Chia sẻ màn hình (Screen Share), Sao chép link mời, Gửi vào chat Zalo, Rời phòng họp (End Call).

---

## 3. Tiêu chí Nghiệm thu (Acceptance Criteria)
1. 100% test case trong `src/zavi.rs` và `src/gui/modals.rs` pass.
2. Mã nguồn biên dịch sạch sẽ không có lỗi borrow hay type mismatch.
3. Liên kết mời họp chuẩn xác `https://zavi.me/meeting/{clean_id}?pwd={pwd}`.
4. Điều khiển micro, camera, chia sẻ màn hình hoạt động mượt mà, không giật lag.
