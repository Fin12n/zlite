# Báo Cáo Nghiệm Thu: Sửa Lỗi Đồng Bộ/Emoji & Triển Khai 3 Tính Năng Mới

> **Ngày báo cáo**: 17/11/2026 14:25  
> **Chuyên gia thực hiện**: ZLite (Rust Specialist & Zalo Protocol Architect)  
> **Mục tiêu**: Nghiệm thu kết quả sửa 2 lỗi và triển khai 3 tính năng mới theo quy trình PDCA.  
> **Trạng thái**: ✅ **100% HOÀN THÀNH (341/341 tests pass)**

---

## 1. TỔNG QUAN KẾT QUẢ THỰC HIỆN

| Nhiệm vụ | Hạng mục | Trạng thái | Module liên quan |
| :--- | :--- | :---: | :--- |
| **Sửa lỗi 1** | Lỗi Sync Unread: Tin nhắn đã đọc trên Zalo Mobile nhưng mở ZLite vẫn bị tính là Chưa đọc | ✅ ĐÃ SỬA TRIỆT ĐỂ | `src/unread.rs`, `src/chat.rs`, `src/gui.rs` |
| **Sửa lỗi 2** | Lỗi thả Emojis: Không có nút thả emoji vào tin nhắn | ✅ ĐÃ SỬA TRIỆT ĐỂ | `src/gui/messages.rs`, `src/gui/workspace.rs` |
| **Tính năng mới 1** | STT 1.7 - Ẩn cuộc trò chuyện bằng mã PIN (Hidden Chats) | ✅ HOÀN THÀNH | `src/app_lock.rs`, `src/gui.rs`, `src/gui/workspace.rs`, `src/gui/modals.rs` |
| **Tính năng mới 2** | STT 5.5 - Tải tệp hàng loạt (Bulk Download) | ✅ HOÀN THÀNH | `src/gui/workspace.rs` |
| **Tính năng mới 3** | STT 6.3 - Danh mục sản phẩm & Báo giá (Catalog & Price Quotes) | ✅ HOÀN THÀNH | `src/catalog.rs`, `src/gui/modals.rs`, `src/gui/workspace.rs`, `src/gui/messages.rs` |

---

## 2. CHI TIẾT SỬA LỖI (BUG FIXES)

### 2.1. Lỗi Đồng Bộ Unread (Sync Seen State from Mobile)
- **Nguyên nhân gốc rễ**:
  1. `merge_read_points` trong `unread.rs` chỉ tìm kiếm trường cố định `idTo`, `lastMsgId` và không hề được gọi trong các luồng nhận dữ liệu `merge_previews`, `poll_new_messages`, `get_last_msgs`.
  2. `merge_thread_into` bỏ qua việc sao chép metadata `unread.last_seen_id` từ `incoming` sang `target`.
  3. Khi ZLite khởi động (`old_len == 0`), vì `last_seen_id` rỗng, logic đếm unread đã đếm tất cả tin nhắn lịch sử nạp vào thành tin nhắn mới đến (`inc_cnt`), làm huy hiệu unread tăng vọt dù trên mobile người dùng đã đọc hết.
- **Giải pháp đã áp dụng**:
  1. Nâng cấp `merge_read_points`: tự động giải mã bọc JSON payload, quét cả `clearUnreads`, `clearUnreadInfo`, `statusMap` và mảng `conversations` (nếu `unreadCount == 0`, tự động đặt `seen = lastMsgId`). Hỗ trợ nhận diện linh hoạt các biến thể ID (`idTo`, `userId`, `threadId`, `convId`).
  2. Tự động gọi `merge_read_points` ngay trong `merge_previews`.
  3. Cập nhật `merge_thread_into`: tự động merge `unread.merge_metadata` và `advance_seen`.
  4. Trong GUI `ThreadsUpdated`: phân tách rõ ràng lần nạp đầu tiên (`old_len == 0`) tôn trọng trực tiếp trạng thái unread từ server, và tự động xóa badge khi `unread.count() == 0`.
  5. Viết unit test `unread_sync_from_mobile_conversations_advances_seen` xác minh thành công.

### 2.2. Lỗi Nút thả Emojis vào tin nhắn (Reaction Bar)
- **Nguyên nhân gốc rễ**:
  - Hàm `render_hover_reaction_bar` (vẽ thanh 6 emoji chuẩn Zalo 👍 ❤️ 😆 😮 😢 😠) đã được xây dựng trước đó nhưng bị gắn `#[allow(dead_code)]` và không được gọi trong `render_chat_bubble`.
  - Thiếu nút bấm biểu tượng cảm xúc (Reaction Trigger `😊`) trực tiếp trên thanh công cụ/bubble.
- **Giải pháp đã áp dụng**:
  1. Kích hoạt gọi `render_hover_reaction_bar` ở cả nhánh tin nhắn đi (outgoing) và tin nhắn đến (incoming) trong `render_chat_bubble`.
  2. Thêm nút icon mặt cười (`😊` / `lucide::SMILE`) trực tiếp bên cạnh timestamp trong bubble; người dùng click vào sẽ kích hoạt hiển thị ngay dải 6 emoji để thả 1-click.
  3. Gắn action phản ứng vào worker `WorkerCmd::React` đồng bộ lên server Zalo và lưu vào SQLite.

---

## 3. CHI TIẾT TRIỂN KHAI 3 TÍNH NĂNG MỚI

### 3.1. Phân hệ 1, STT 1.7 - Ẩn cuộc trò chuyện bằng mã PIN (Hidden Chats)
- **Bảo mật**: Mã PIN từ 4 đến 12 ký tự được băm bằng SHA-256 kèm salt domain riêng biệt (`zlite_hidden_chat_pin_v1:`) tại `src/app_lock.rs`.
- **Cơ chế ẩn an toàn**:
  - Khi chưa mở khóa (`hidden_chats_unlocked == false`), các cuộc trò chuyện bị ẩn sẽ bị lọc hoàn toàn khỏi sidebar, kể cả khi gõ tìm kiếm thông thường (bảo vệ quyền riêng tư tuyệt đối).
- **Mở khóa linh hoạt**:
  - Cách 1: Gõ trực tiếp mã PIN vào ô Tìm kiếm (`Search Bar`) -> Hệ thống tự động nhận diện và mở khóa ngay lập tức.
  - Cách 2: Bấm nút biểu tượng ổ khóa (`🔒`) trên thanh tìm kiếm -> Mở modal nhập mã PIN.
- **Trải nghiệm sau khi mở khóa**:
  - Xuất hiện banner thông báo `🔓 Đang mở trò chuyện ẩn` cùng nút `Khóa lại` tiện lợi.
  - Các cuộc trò chuyện ẩn hiển thị huy hiệu ổ khóa `🔒 [Tên hội thoại]` trên danh sách.
  - Menu chuột phải cho phép "Bỏ ẩn trò chuyện", "Đổi mã PIN" hoặc "Gỡ mã PIN".

### 3.2. Phân hệ 5, STT 5.5 - Tải tệp hàng loạt (Bulk Download)
- **Vị trí**: Thanh thông tin hội thoại (Info Drawer -> Tab Tệp tin / Media).
- **Tính năng**:
  - Nút `📥 Tải hàng loạt`: Bật chế độ chọn nhiều với checkbox cạnh từng tệp tin.
  - Nút `Chọn hết` / `Bỏ chọn`: Chọn tất cả tệp chỉ với 1-click.
  - Nút `Tải (<N> tệp)`: Tải đồng loạt các tệp đã chọn về thư mục Downloads.
  - Nút `Tải tất cả`: Tải toàn bộ tệp trong cuộc trò chuyện về máy mà không cần thao tác từng tệp.

### 3.3. Phân hệ 6, STT 6.3 - Danh mục sản phẩm & Báo giá (Catalog & Price Quotes)
- **Module mới**: `src/catalog.rs` với struct `ProductItem`, bộ sinh ID băm, format tiền tệ VND chuẩn quốc gia (`165.000 ₫`, `12.500.000 ₫`).
- **Composer Toolbar**:
  - Thêm icon `lucide::STORE` ("Danh mục sản phẩm & Báo giá nhanh").
  - Mở modal quản lý danh mục sản phẩm: Xem danh sách, thêm sản phẩm mới (Tên, Giá VND, SKU, Mô tả), xóa sản phẩm.
  - Bấm `Gửi báo giá`: Tự động tạo và gửi tin nhắn thẻ báo giá chuẩn vào chat.
- **Hiển thị thẻ sản phẩm trong chat (Product Card Widget)**:
  - Tự động nhận diện tin nhắn `[Sản phẩm]` hoặc `[Báo giá]` để render thành thẻ sản phẩm sang trọng bo góc, giá tiền màu đỏ cam nổi bật, mã SKU.
  - Tích hợp nút `💬 Hỏi báo giá / Đặt hàng`: Tự động tạo quote trích dẫn vào composer để người mua trao đổi với người bán ngay lập tức.

---

## 4. KẾT QUẢ KIỂM THỬ (TEST VERIFICATION)

Chạy lệnh kiểm thử toàn diện:
```bash
cargo test --lib
```
**Kết quả**:
```
test result: ok. 341 passed; 0 failed; 1 ignored; 0 measured; 0 filtered out; finished in 51.65s
```
- Không có bất kỳ lỗi biên dịch nào.
- Đảm bảo triệt để nguyên tắc **Zero-Idle-CPU** và không block UI thread.

---

## 5. CÁC TÍNH NĂNG CẦN USER TEST & REVIEW
1. **Kiểm tra Unread Sync**: Đọc tin nhắn trên Zalo điện thoại, sau đó mở ZLite để xác nhận cuộc trò chuyện đó không còn bị gắn nhãn "Chưa đọc".
2. **Kiểm tra Emoji**: Rê chuột vào tin nhắn hoặc click vào icon mặt cười `😊` cạnh giờ gửi tin nhắn để thả cảm xúc 1-click.
3. **Kiểm tra Ẩn cuộc trò chuyện**: Chuột phải vào một hội thoại -> chọn "Ẩn trò chuyện" -> đặt mã PIN 4 số. Thử gõ mã PIN vào ô Tìm kiếm hoặc bấm nút ổ khóa trên thanh tìm kiếm để mở khóa.
4. **Kiểm tra Tải tệp hàng loạt**: Mở Info Drawer (icon chữ i hoặc tab tệp) -> chọn Tab Tệp tin -> bấm "Tải hàng loạt" hoặc "Tải tất cả".
5. **Kiểm tra Báo giá sản phẩm**: Bấm nút icon cửa hàng (`STORE`) trên thanh soạn thảo -> chọn "Gửi báo giá" vào chat và kiểm tra hiển thị thẻ sản phẩm.
