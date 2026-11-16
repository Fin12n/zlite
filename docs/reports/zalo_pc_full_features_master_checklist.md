# BẢNG KIỂM TÍNH NĂNG TOÀN DIỆN ZALO PC & SO SÁNH VỚI ZLITE
**Dự án:** ZLite (Native Rust Zalo PC Client)  
**Tài liệu đối chiếu:** `zalo-re` (Zalo Desktop Client v26.11 trích xuất `app-asar`)  
**Ngày khởi tạo:** 16/11/2026 - 14:55  
**Phương châm cốt lõi:** Tốc độ · Hiệu năng · Tối ưu (Zero-Idle-CPU, Native Rust, SQLite Offline-First)

---

## 📊 1. MA TRẬN 9 PHÂN HỆ TÍNH NĂNG ZALO PC & TIẾN ĐỘ THỰC HIỆN

### Phân hệ 1: Xác Thực & Bảo Mật (Auth & Security)
| STT | Tính năng Zalo PC | Trạng thái ZLite | Module Code | Chi tiết & Khoảng cách tính năng |
| :--- | :--- | :---: | :--- | :--- |
| 1.1 | Đăng nhập mã QR code | [x] Hoàn thành | `src/qr_login.rs` | Quét mã qua điện thoại, polling token tự động. |
| 1.2 | Đăng nhập SĐT + Mật khẩu + 2FA | [x] Hoàn thành | `src/session.rs` | Lưu session, cookies mã hóa zpw_sek/enk. |
| 1.3 | Quản lý đa tài khoản (Multi-Account) | [x] Hoàn thành | `src/account_manager.rs` | Lưu danh sách tài khoản, chuyển đổi phiên nhanh. |
| 1.4 | Khóa ứng dụng bằng mã PIN (App Lock) | [-] Một phần | `src/gui/modals.rs` | Đã có modal nhập PIN, cần logic hash PIN, timeout tự khóa. |
| 1.5 | Mã hóa đầu cuối (E2EE Signal Protocol) | [x] Hoàn thành | `src/e2ee.rs`, `crypto.rs` | Trao đổi khóa Curve25519/Ed25519, mã hóa phiên. |
| 1.6 | Tin nhắn tự xóa (TTL / Ephemeral) | [-] Một phần | `src/store.rs` | Đã có cờ `vanish`, cần background job xóa tin quá hạn. |
| 1.7 | Ẩn cuộc trò chuyện bằng mã PIN (Hidden) | [ ] Chưa có | `src/store.rs` | Cần cờ hidden và yêu cầu PIN để hiển thị. |

---

### Phân hệ 2: Trò Chuyện & Tin Nhắn Cốt Lõi (Chat & Messaging Core)
| STT | Tính năng Zalo PC | Trạng thái ZLite | Module Code | Chi tiết & Khoảng cách tính năng |
| :--- | :--- | :---: | :--- | :--- |
| 2.1 | Tin nhắn văn bản & Link preview | [x] Hoàn thành | `src/gui/messages.rs` | Hiển thị link, trích xuất metadata website. |
| 2.2 | Tin nhắn hình ảnh (Đơn & Lưới ảnh) | [x] Hoàn thành | `src/gui/messages.rs` | Hỗ trợ JPG, PNG, WEBP, JXL chuyển đổi sang JPG. |
| 2.3 | Tin nhắn Video Zalo CDN | [x] Hoàn thành | `src/gui/messages.rs` | Card 16:9, nút play kính mờ, phát player hệ thống. |
| 2.4 | Tin nhắn tệp đính kèm (File Attachment) | [x] Hoàn thành | `src/gui/messages.rs` | Badge icon màu theo định dạng (PDF, DOC, XLS,...). |
| 2.5 | Tin nhắn thoại (Voice Message) | [x] Hoàn thành | `src/audio.rs`, `messages.rs` | Ghi âm MP3/Opus, hiển thị thanh phát waveform. |
| 2.6 | Sticker & Emoji Zalo | [x] Hoàn thành | `src/gui/stickers.rs` | Bộ sticker Zalo, render animation sprite frames. |
| 2.7 | Tin nhắn Bình chọn (Poll Card) | [x] Hoàn thành | `src/gui/messages.rs` | Widget hiển thị các phương án, % tiến độ, số phiếu. |
| 2.8 | Tin nhắn Giao việc (To-Do Card) | [x] Hoàn thành | `src/gui/messages.rs` | Widget hiển thị trạng thái, người nhận, hạn chót. |
| 2.9 | Tin nhắn Nhắc hẹn (Reminder Card) | [x] Hoàn thành | `src/gui/messages.rs` | Widget hiển thị thời gian hẹn, chuông báo, tiêu đề. |
| 2.10| Thả cảm xúc tin nhắn (Reactions) | [-] Một phần | `src/chat.rs`, `messages.rs`| Cần tương tác gửi reaction ❤️👍😂😮😭😡 và cập nhật UI. |
| 2.11| Trích dẫn trả lời (Quote / Reply) | [x] Hoàn thành | `src/gui/messages.rs` | Dải màu xanh Zalo Blue, thumbnail ảnh thu nhỏ. |
| 2.12| Thu hồi tin nhắn (`chat.undo`) | [-] Một phần | `src/chat.rs` | Đã có protocol decode, cần hàm gửi lệnh thu hồi API. |
| 2.13| Xóa tin nhắn phía tôi (Delete for me) | [-] Một phần | `src/store.rs` | Cần API và context menu xóa tin khỏi SQLite & RAM. |
| 2.14| Ghim nhiều tin nhắn (Pinned Messages) | [-] Một phần | `src/store.rs` | Cần lưu trữ danh sách pinned và thanh bar ghim đầu chat. |
| 2.15| Đánh dấu sao tin nhắn (Starred Messages) | [x] Hoàn thành | `src/store.rs` | Lưu vào bảng `saved_items`, toggle star. |
| 2.16| Chuyển tiếp tin nhắn (Forward Message) | [x] Hoàn thành | `src/gui/modals.rs` | Modal chuyển tiếp tin nhắn đến nhiều hội thoại. |

---

### Phân hệ 3: Hội Nhóm & Cộng Đồng (Groups & Community)
| STT | Tính năng Zalo PC | Trạng thái ZLite | Module Code | Chi tiết & Khoảng cách tính năng |
| :--- | :--- | :---: | :--- | :--- |
| 3.1 | Tạo nhóm mới | [x] Hoàn thành | `src/gui/modals.rs` | Modal chọn thành viên, đặt tên, tạo nhóm. |
| 3.2 | Thêm thành viên vào nhóm | [x] Hoàn thành | `src/gui/modals.rs` | Modal tìm kiếm và thêm thành viên. |
| 3.3 | Xóa thành viên / Kích khỏi nhóm | [x] Hoàn thành | `src/chat.rs` | API `kick_member`, kiểm tra quyền Admin. |
| 3.4 | Rời nhóm an toàn | [x] Hoàn thành | `src/chat.rs` | API `leave_group`, chuyển quyền trước khi rời. |
| 3.5 | Đổi tên nhóm / Ảnh đại diện nhóm | [x] Hoàn thành | `src/chat.rs` | Cập nhật thông tin nhóm và đồng bộ. |
| 3.6 | Bảng tin nhóm / Ghi chú (Group Board) | [-] Một phần | `src/store.rs` | Đã có bảng `group_notes`, cần UI xem và chỉnh sửa. |

---

### Phân hệ 4: Tiện Ích Nhóm (Group Productivity)
| STT | Tính năng Zalo PC | Trạng thái ZLite | Module Code | Chi tiết & Khoảng cách tính năng |
| :--- | :--- | :---: | :--- | :--- |
| 4.1 | Tạo bình chọn khảo sát (Create Poll) | [x] Hoàn thành | `src/gui/modals.rs` | Modal tạo nhiều phương án, tùy chọn đa phương án. |
| 4.2 | Bỏ phiếu bình chọn (Vote Poll Interaction) | [-] Một phần | `src/gui/messages.rs` | Cần xử lý click vote, cập nhật số phiếu và thanh %. |
| 4.3 | Tạo việc cần làm (Create To-Do Task) | [x] Hoàn thành | `src/gui/modals.rs` | Modal giao việc, chọn người thực hiện, deadline. |
| 4.4 | Cập nhật trạng thái việc (Toggle To-Do) | [-] Một phần | `src/gui/messages.rs` | Cần toggle hoàn thành việc trực tiếp trên thẻ card. |
| 4.5 | Đặt lịch hẹn nhắc giờ (Create Reminder) | [x] Hoàn thành | `src/store.rs`, `modals.rs` | Lưu lịch hẹn vào bảng `reminders`. |
| 4.6 | Kích hoạt chuông báo nhắc hẹn (Due Alarm) | [-] Một phần | `src/os_notify.rs` | Cần background checker quét lịch hẹn đến hạn và báo popup. |
| 4.7 | Tin nhắn nhanh (Quick Messages `/`) | [-] Một phần | `src/gui/workspace.rs` | Cần popup gợi ý phím tắt `/` trong composer. |
| 4.8 | Thanh định dạng chữ (RTF Mini Bar) | [x] Hoàn thành | `src/gui/workspace.rs` | In đậm, In nghiêng, Trích dẫn Code, Gạch ngang. |

---

### Phân hệ 5: Đa Phương Tiện & Lưu Trữ (Media & Storage)
| STT | Tính năng Zalo PC | Trạng thái ZLite | Module Code | Chi tiết & Khoảng cách tính năng |
| :--- | :--- | :---: | :--- | :--- |
| 5.1 | Kho lưu trữ 3 Tab (Ảnh/Video, Tệp, Link)| [x] Hoàn thành | `src/gui/workspace.rs` | Lưới 3 cột vuông chuẩn ZDS 1:1, File badge màu. |
| 5.2 | Xem ảnh phóng to & Xoay ảnh | [x] Hoàn thành | `src/gui/modals.rs` | Image viewer với zoom, pan, tải về. |
| 5.3 | Phát video in-app kèm điều khiển | [x] Hoàn thành | `src/gui/modals.rs` | Modal player, tải cache ngầm, mở player ngoài. |
| 5.4 | Dọn dẹp dung lượng bộ nhớ đệm (Cache) | [-] Một phần | `src/gui/workspace.rs` | Cần tính toán kích thước thư mục cache và nút dọn dẹp. |
| 5.5 | Tải tệp hàng loạt (Bulk Download) | [ ] Chưa có | `src/chat.rs` | Lưu nhiều file về thư mục Downloads. |

---

### Phân hệ 6: Công Cụ Kinh Doanh (Business Tools)
| STT | Tính năng Zalo PC | Trạng thái ZLite | Module Code | Chi tiết & Khoảng cách tính năng |
| :--- | :--- | :---: | :--- | :--- |
| 6.1 | Nhãn phân loại hội thoại (Chat Labels) | [x] Hoàn thành | `src/gui/workspace.rs` | Gắn thẻ màu, bộ lọc `Phân loại ▾`. |
| 6.2 | Trả lời tự động (Auto-Reply Engine) | [x] Hoàn thành | `src/api_mcp.rs` | Khớp từ khóa, phạm vi phản hồi, rule engine. |
| 6.3 | Danh mục sản phẩm & Báo giá | [ ] Chưa có | `src/chat.rs` | Tính năng Zalo OA / Business Catalog. |

---

### Phân hệ 7: Thoại & Video Trực Tuyến (Call & Video)
| STT | Tính năng Zalo PC | Trạng thái ZLite | Module Code | Chi tiết & Khoảng cách tính năng |
| :--- | :--- | :---: | :--- | :--- |
| 7.1 | Cuộc gọi thoại 1-1 (VoIP Call) | [x] Hoàn thành | `src/call.rs`, `call_probe.rs` | RTP audio, signaling, P2P & Relay. |
| 7.2 | Nhật ký cuộc gọi (Call History Logs) | [x] Hoàn thành | `src/voip_log.rs` | Phân tích RTCP, NAL units, call status. |
| 7.3 | Cuộc gọi Video nhóm (Zavi Conference) | [x] Hoàn thành | `src/zavi.rs`, `src/gui/modals.rs`, `src/gui/workspace.rs` | Hỗ trợ tạo/tham gia phòng họp Zavi 9 số, mật khẩu 6 số, link zavi.me, lưới responsive video tiles, điều khiển mic/cam/screen share, gửi thẻ mời vào Zalo chat. |

---

### Phân hệ 8: Danh Bạ & Hồ Sơ (Contacts & Social)
| STT | Tính năng Zalo PC | Trạng thái ZLite | Module Code | Chi tiết & Khoảng cách tính năng |
| :--- | :--- | :---: | :--- | :--- |
| 8.1 | Danh bạ bạn bè A-Z | [x] Hoàn thành | `src/gui/workspace.rs` | Hiển thị danh sách, tìm kiếm tên bạn bè. |
| 8.2 | Đặt tên gợi nhớ / Biệt danh (Alias) | [x] Hoàn thành | `src/store.rs` | Lưu alias vào SQLite, hiển thị thay thế tên gốc. |
| 8.3 | Chặn tin nhắn / Bỏ chặn (Block / Unblock)| [x] Hoàn thành | `src/chat.rs` | Quản lý danh sách đen. |
| 8.4 | Nhật ký mạng xã hội (Social Feed) | [x] Hoàn thành | `src/feed.rs` | Dòng thời gian, Like, Bình luận, Realtime like. |

---

### Phân hệ 9: Hệ Thống & Quản Trị (System & Utilities)
| STT | Tính năng Zalo PC | Trạng thái ZLite | Module Code | Chi tiết & Khoảng cách tính năng |
| :--- | :--- | :---: | :--- | :--- |
| 9.1 | Chụp màn hình nhanh (Screen Capture) | [x] Hoàn thành | `src/screencap.rs` | Cắt khung hình màn hình, lưu clipboard. |
| 9.2 | Đồng bộ lịch sử Protobuf Sync V2 | [x] Hoàn thành | `src/history_sync.rs` | Giải mã Type 1, 2, 11, 18, 19, 26, 27, 28. |
| 9.3 | Tìm kiếm tin nhắn & tệp toàn năng | [x] Hoàn thành | `src/search_index.rs` | Tìm kiếm full-text SQLite với các toán tử `from:`, `has:`. |
| 9.4 | Cấu hình Dark / Light Theme tức thì | [x] Hoàn thành | `src/gui/theme.rs` | Bảng màu ZDS v4.1, WCAG 2.1 AA, nút Sun/Moon trên rail. |
| 9.5 | Tự động kiểm tra bản cập nhật mới | [x] Hoàn thành | `src/updater.rs` | Kiểm tra GitHub Releases, hash SHA256 tự động. |

---

## 🎯 2. KẾ HOẠCH TRIỂN KHAI VÒNG LẶP TIẾP THEO (SPRINT ITERATION)

Sau khi đối chiếu với code hiện tại, các tính năng **đã được phát triển và kiểm thử thành công** theo yêu cầu của User:
> **"Phát triển tiếp các tính năng tiếp theo. Chưa yêu cầu phát triển UI/UX mới. Giữ nguyên phương châm: Tốc độ - Hiệu năng - Tối ưu."**

### ✅ KẾT QUẢ SPRINT 16/11/2026:
1. **Gói Tính Năng 1: Tương Tác Tin Nhắn Nâng Cao (Interactive Messaging)**:
   - [x] **Thu hồi tin nhắn (`chat.undo`)**: Xử lý hoàn chỉnh API / state thu hồi cho người dùng, lưu SQLite và cập nhật UI. (`a3ca958`)
   - [x] **Xóa tin nhắn phía tôi (Delete for me)**: Xóa khỏi bộ nhớ đệm SQLite và cập nhật danh sách RAM tức thì, không gây giật lag. (`a3ca958`)
   - [x] **Thả cảm xúc tin nhắn (Reactions ❤️👍😂😮😭😡)**: Thêm reaction bar tương tác trực tiếp trên bubble, optimistic UI update và lưu trữ trạng thái cảm xúc. (`8175731`)
2. **Gói Tính Năng 2: Tương Tác Năng Suất Nhóm (Group Productivity Actions)**:
   - [x] **Bỏ phiếu bình chọn (Vote Poll)**: Click phương án bỏ phiếu trực tiếp trên widget card, cập nhật số lượng và tính lại % thanh tiến độ. (`8175731`)
   - [x] **Hoàn thành công việc (To-Do Toggle)**: Click button để chuyển trạng thái việc hoàn thành/chưa hoàn thành kèm gạch ngang trực quan. (`8175731`)
   - [x] **Kích hoạt chuông thông báo Lịch hẹn (Reminder Due Notification)**: Background timer quét lịch hẹn và gửi thông báo native qua `os_notify`. (`65a897e`)
   - [x] **Phím tắt Tin nhắn nhanh `/` (Quick Messages)**: Tự động nạp danh sách mẫu câu, lọc tìm kiếm theo phím tắt/tiêu đề và điền tự động khi chọn trong composer. (`a2b47d0`)
3. **Gói Tính Năng 3: Bảo Mật & Quản Trị Hệ Thống (Security & Cache Maintenance)**:
   - [x] **Khóa ứng dụng bằng mã PIN (App Lock PIN)**: Băm SHA-256 có muối domain, cấu hình tự động khóa khi nhàn rỗi (idle lock), phím tắt khóa nhanh Ctrl+L, màn hình khóa toàn diện che giấu tin nhắn nhạy cảm. (`c7c4262`)
   - [x] **Dọn dẹp bộ nhớ đệm (Media Cache Cleaner)**: Quét dung lượng, dọn dẹp các tệp tạm video, ảnh thu nhỏ, audio, sticker và trả về báo cáo số MB/số file đã giải phóng. (`c7c4262`)
