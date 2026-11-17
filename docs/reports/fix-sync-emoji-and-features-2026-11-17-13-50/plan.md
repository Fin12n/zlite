# Kế hoạch Thực hiện: Sửa lỗi Sync/Emoji & Triển khai 3 Tính năng Mới

> **Ngày thực hiện**: 17/11/2026 13:50  
> **Chuyên gia**: ZLite (Rust Specialist & Zalo Protocol Architect)  
> **Mục tiêu**: Khắc phục triệt để 2 lỗi đồng bộ và giao diện, phát triển 3 tính năng mới theo chuẩn Zalo PC.

---

## PHẦN 1: SỬA CHỮA (BUG FIXES)

### 1. Sửa lỗi Đồng bộ Unread (Sync Seen State)
- **Hiện tượng**: Trên Zalo Mobile đã đọc tin nhắn rồi, nhưng mở ZLite lên vẫn load tin nhắn và bị đánh dấu là "Chưa đọc".
- **Nguyên nhân gốc rễ**:
  1. `merge_read_points` không được gọi trong `poll_new_messages` và `merge_previews`, khiến `clearUnreads` (danh sách ID tin nhắn đã đọc trên mobile) bị bỏ qua.
  2. `merge_thread_into` không đồng bộ `unread.last_seen_id` từ `incoming` sang `target`.
  3. `merge_read_points` chỉ tìm các key cố định `idTo`, `lastMsgId` mà thiếu `userId`, `threadId`, `convId`, `lastSeenMsgId`, `lastReadMsgId`.
  4. Khi ZLite mở lên, `existing.unread.last_seen_id` rỗng hoặc cũ hơn ID tin nhắn từ server, dẫn tới vòng lặp đếm unread tăng vọt cho toàn bộ tin nhắn đã đọc trên mobile.
- **Giải pháp**:
  - Mở rộng `merge_read_points` hỗ trợ đầy đủ các trường của Zalo API.
  - Tự động gọi `merge_read_points` trong `merge_previews`, `poll_new_messages`, `load_recent`.
  - Trong `merge_thread_into`, merge metadata `unread` và `advance_seen`.
  - Trong GUI `ThreadsUpdated`: nếu `seen >= last_msg.id` hoặc `unread.count() == 0`, tự động xóa thread khỏi `self.unread_counts` và lưu vào SQLite để duy trì trạng thái.

### 2. Sửa lỗi Nút thả Emojis vào tin nhắn (Reaction Bar)
- **Hiện tượng**: Không có nút để thả emoji trực tiếp vào tin nhắn.
- **Nguyên nhân**:
  - Hàm `render_hover_reaction_bar` đã có sẵn nhưng bị đánh dấu `#[allow(dead_code)]` và không được gọi trong `render_chat_bubble`.
  - Thiếu nút biểu tượng cảm xúc (Reaction Trigger Icon `😊`) trực tiếp trên thanh công cụ hover/bubble.
- **Giải pháp**:
  - Kích hoạt gọi `render_hover_reaction_bar` trong `render_chat_bubble` khi người dùng di chuột vào bubble tin nhắn.
  - Thêm nút icon mặt cười (`😊`) ở góc dưới/bên cạnh bubble tin nhắn; khi click vào sẽ mở ngay dải 6 emoji Zalo (👍 ❤️ 😆 😮 😢 😠) để thả cảm xúc 1-click.

---

## PHẦN 2: PHÁT TRIỂN 3 TÍNH NĂNG MỚI

### 1. Phân hệ 1, STT 1.7 - Ẩn cuộc trò chuyện bằng mã PIN (Hidden Chats)
- Đặt và xác thực mã PIN 4 số bảo vệ cuộc trò chuyện ẩn.
- Thêm cờ `hidden` trong `AppSettings` và `ThreadPresentation`.
- Thêm tùy chọn "Ẩn trò chuyện" trong menu chuột phải của hội thoại.
- Hội thoại bị ẩn sẽ không hiển thị trên danh sách chat thông thường.
- Khi người dùng nhập đúng mã PIN vào ô tìm kiếm (hoặc bấm nút mở khóa trò chuyện ẩn), các hội thoại ẩn sẽ hiển thị với huy hiệu bảo mật.
- Cho phép "Bỏ ẩn trò chuyện" hoặc "Đổi mã PIN".

### 2. Phân hệ 5, STT 5.5 - Tải tệp hàng loạt (Bulk Download)
- Trong Info Drawer (Tab Tệp tin / Media):
  - Thêm nút "Tải hàng loạt" / "Tải tất cả".
  - Cho phép người dùng chọn checkbox nhiều tệp tin hoặc "Chọn tất cả".
  - Sử dụng `pick_native_folder_dialog_result` để chọn thư mục đích trên máy tính.
  - Tải đồng loạt các file được chọn về máy và hiển thị thông báo kết quả.

### 3. Phân hệ 6, STT 6.3 - Danh mục sản phẩm & Báo giá (Catalog & Price Quotes)
- Tạo module `src/catalog.rs`:
  - Struct `ProductItem`: `id`, `name`, `price`, `image_url`, `description`, `sku`.
  - Struct `CatalogState`: Danh sách sản phẩm, quản lý thêm/sửa/xóa sản phẩm.
- Tích hợp vào Composer Toolbar: Nút "Danh mục & Báo giá" (`lucide::STORE`).
- Modal Quản lý danh mục & Chọn sản phẩm gửi vào chat.
- Thẻ sản phẩm / Thẻ báo giá (Product Quote Card) hiển thị đẹp mắt trong dòng tin nhắn với hình ảnh, giá tiền VND, mô tả, nút "Hỏi báo giá".

---

## PHẦN 3: TIÊU CHÍ NGHIỆM THU (ACCEPTANCE CRITERIA)
1. Tin nhắn đã đọc trên mobile khi mở ZLite lên không bị hiển thị là Chưa đọc.
2. Di chuột vào tin nhắn hiển thị ngay thanh 6 emoji để thả 1-click; có nút mặt cười trực tiếp.
3. Ẩn/hiện hội thoại bằng mã PIN hoạt động chính xác và bảo mật.
4. Tải tệp hàng loạt lưu đúng các file về thư mục người dùng chọn.
5. Tạo và gửi thẻ sản phẩm & báo giá vào chat chuẩn xác.
6. 100% unit tests pass, không có lỗi biên dịch.
