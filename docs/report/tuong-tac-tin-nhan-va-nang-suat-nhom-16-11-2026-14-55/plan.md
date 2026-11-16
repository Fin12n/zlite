# Tương Tác Tin Nhắn & Năng Suất Nhóm (Interactive Messaging & Group Productivity) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Hoàn thiện toàn bộ các tính năng tương tác nghiệp vụ cốt lõi của Zalo PC: Thu hồi/Xóa tin nhắn, Thả cảm xúc trực tiếp, Bỏ phiếu bình chọn (Poll Voting), Đổi trạng thái việc (To-Do Toggle), Quét và kích hoạt chuông báo nhắc hẹn (Reminder Due Notification), Phím tắt tin nhắn nhanh `/` (Quick Messages), và Khóa ứng dụng bảo mật PIN kết hợp Dọn dẹp bộ nhớ đệm cache.

**Architecture:** Mở rộng mô hình tương tác hướng sự kiện `BubbleAction` trong `egui`, cập nhật trạng thái thời gian thực và đồng bộ hai chiều với SQLite (`zalo_history.db`); sử dụng background timer nhẹ nhàng kiểm tra chuông báo nhắc hẹn với chi phí 0.0% CPU nhàn rỗi; triển khai cơ chế hash PIN và dọn dẹp cache an toàn.

**Tech Stack:** Rust 1.75+, `egui 0.26+`, SQLite (`rusqlite`), Native Notifications (`os_notify`), `serde`/`serde_json`, `chrono`/`std::time`.

---

## 📋 Bite-Sized Tasks Breakdown

### Task 1: Thu Hồi (`chat.undo`) & Xóa Tin Nhắn Phía Tôi (Delete For Me)
**Files:**
- Modify: `zlite/src/store.rs`
- Modify: `zlite/src/gui.rs`
- Modify: `zlite/src/gui/messages.rs`
- Test: `zlite/src/store.rs` (inline test `test_task1_delete_and_undo_message`)

**Step 1: Viết failing test kiểm tra logic xóa và thu hồi tin nhắn trong `store.rs`**
```rust
#[test]
fn test_task1_delete_and_undo_message() {
    let store = MessageStore::open(":memory:").unwrap();
    let thread_id = "test_thread_undo";
    let msg_id = "msg_1001";
    
    // Insert initial message
    store.insert_message(thread_id, msg_id, "UserA", "Tin nhắn gốc", "10:00", 1700000000, false, None, "chat.text", None).unwrap();
    
    // Test Undo
    let undone = store.undo_message(thread_id, msg_id).unwrap();
    assert!(undone);
    let msgs = store.messages_for(thread_id).unwrap();
    assert_eq!(msgs[0].content, "Tin nhắn đã được thu hồi");
    assert_eq!(msgs[0].kind, MessageKind::Undo);
    
    // Test Delete for me
    let deleted = store.delete_message_for_me(thread_id, msg_id).unwrap();
    assert!(deleted);
    let msgs_after = store.messages_for(thread_id).unwrap();
    assert_eq!(msgs_after.len(), 0);
}
```

**Step 2: Chạy test xác nhận fail**
Run: `cargo test --manifest-path zlite/Cargo.toml test_task1_delete_and_undo_message`

**Step 3: Triển khai trong `src/store.rs`, `src/gui.rs` & `src/gui/messages.rs`**
- Trong `store.rs`: Viết method `undo_message(&self, thread_id: &str, msg_id: &str) -> Result<bool>` và `delete_message_for_me(&self, thread_id: &str, msg_id: &str) -> Result<bool>`.
- Trong `gui.rs`: Thêm handler `BubbleAction::DeleteForMe(msg_id)` và `BubbleAction::UndoMessage(msg_id)`: cập nhật bộ nhớ RAM `self.messages`, cập nhật preview thread nếu là tin nhắn cuối cùng.
- Trong `gui/messages.rs`: Thêm nút bấm/menu chuột phải cho thao tác `Xóa` và `Thu hồi`.

**Step 4: Chạy test xác nhận pass**
Run: `cargo test --manifest-path zlite/Cargo.toml test_task1_delete_and_undo_message`

**Step 5: Commit**
```bash
git add zlite/src/store.rs zlite/src/gui.rs zlite/src/gui/messages.rs
git commit -m "feat(messaging): implement delete for me and undo message lifecycle"
```

---

### Task 2: Hệ Thống Thả Cảm Xúc Tin Nhắn (Message Reactions)
**Files:**
- Modify: `zlite/src/store.rs`
- Modify: `zlite/src/gui/messages.rs`
- Modify: `zlite/src/gui.rs`
- Test: `zlite/src/store.rs` (inline test `test_task2_toggle_reaction`)

**Step 1: Viết failing test kiểm tra thêm và chuyển đổi cảm xúc tin nhắn**
```rust
#[test]
fn test_task2_toggle_reaction() {
    let store = MessageStore::open(":memory:").unwrap();
    let thread_id = "test_thread_react";
    let msg_id = "msg_2001";
    store.insert_message(thread_id, msg_id, "UserA", "Hello", "10:00", 1700000000, false, None, "chat.text", None).unwrap();
    
    // Toggle reaction ❤️
    let count1 = store.toggle_reaction(thread_id, msg_id, "❤️").unwrap();
    assert_eq!(count1, 1);
    
    // Toggle reaction ❤️ again (toggle off or increase from another user)
    let reactions = store.get_reactions(thread_id, msg_id).unwrap();
    assert!(reactions.iter().any(|(emoji, c)| emoji == "❤️" && *c >= 1));
}
```

**Step 2: Chạy test xác nhận fail**
Run: `cargo test --manifest-path zlite/Cargo.toml test_task2_toggle_reaction`

**Step 3: Triển khai trong `src/store.rs`, `src/gui/messages.rs`, `src/gui.rs`**
- Trong `store.rs`: Thêm bảng `message_reactions (thread_id, msg_id, emoji, count)` hoặc lưu vào JSON metadata của message, viết hàm `toggle_reaction` và `get_reactions`.
- Trong `gui/messages.rs`: Render thanh reaction emoji nhỏ (`❤️`, `👍`, `😂`, `😮`, `😭`, `😡`) khi hover hoặc click vào nút phản hồi. Thêm `BubbleAction::React { msg_id: String, emoji: String }`.
- Trong `gui.rs`: Xử lý `BubbleAction::React`, cập nhật ngay vào `ChatMessage.reactions` trong RAM và lưu vào SQLite.

**Step 4: Chạy test xác nhận pass**
Run: `cargo test --manifest-path zlite/Cargo.toml test_task2_toggle_reaction`

**Step 5: Commit**
```bash
git add zlite/src/store.rs zlite/src/gui/messages.rs zlite/src/gui.rs
git commit -m "feat(reactions): implement interactive emoji reactions and persistence"
```

---

### Task 3: Tương Tác Bỏ Phiếu (Vote Poll) & Đổi Trạng Thái Việc (Toggle To-Do)
**Files:**
- Modify: `zlite/src/gui/messages.rs`
- Modify: `zlite/src/gui.rs`
- Modify: `zlite/src/store.rs`
- Test: `zlite/src/gui/messages.rs` (inline test `test_task3_poll_and_todo_interaction`)

**Step 1: Viết failing test kiểm tra cập nhật vote poll và toggle todo**
```rust
#[test]
fn test_task3_poll_and_todo_interaction() {
    let mut msg_poll = ChatMessage {
        id: "poll_1".to_string(),
        content: "Nơi ăn trưa?".to_string(),
        raw_json: Some(r#"{"question":"Nơi ăn trưa?","options":[{"id":"1","text":"Cơm tấm","votes":2},{"id":"2","text":"Phở","votes":1}],"total_votes":3}"#.to_string()),
        kind: MessageKind::Poll,
        ..Default::default()
    };
    
    // Simulate voting option 2
    let updated = apply_poll_vote(&mut msg_poll, 1);
    assert!(updated);
    let parsed: serde_json::Value = serde_json::from_str(msg_poll.raw_json.as_deref().unwrap()).unwrap();
    assert_eq!(parsed["options"][1]["votes"], 2);
    assert_eq!(parsed["total_votes"], 4);
}
```

**Step 2: Chạy test xác nhận fail**
Run: `cargo test --manifest-path zlite/Cargo.toml test_task3_poll_and_todo_interaction`

**Step 3: Triển khai hàm `apply_poll_vote` và `toggle_todo_status`**
- Trong `gui/messages.rs`: 
  - Render option trong `render_poll_widget` với nút click để bỏ phiếu, sinh ra `BubbleAction::VotePollOption { msg_id, option_idx }`.
  - Render checkbox trong `render_todo_widget` với nút toggle, sinh ra `BubbleAction::ToggleTodoStatus { msg_id }`.
- Trong `gui.rs`: 
  - Xử lý hai actions trên: cập nhật `raw_json` trong `ChatMessage`, lưu cập nhật vào CSDL qua `store.update_message_content(thread_id, msg_id, new_content, new_raw_json)`.

**Step 4: Chạy test xác nhận pass**
Run: `cargo test --manifest-path zlite/Cargo.toml test_task3_poll_and_todo_interaction`

**Step 5: Commit**
```bash
git add zlite/src/gui/messages.rs zlite/src/gui.rs zlite/src/store.rs
git commit -m "feat(collab): enable interactive poll voting and to-do status toggling"
```

---

### Task 4: Quét & Báo Động Nhắc Hẹn (Reminder Due Daemon & Desktop Alert)
**Files:**
- Modify: `zlite/src/store.rs`
- Modify: `zlite/src/gui.rs`
- Test: `zlite/src/store.rs` (inline test `test_task4_reminder_due_scan`)

**Step 1: Viết failing test kiểm tra quét reminder đến hạn**
```rust
#[test]
fn test_task4_reminder_due_scan() {
    let store = MessageStore::open(":memory:").unwrap();
    let now = 1700000000;
    store.insert_reminder("Họp nhóm", "Thảo luận sprint", now - 10, Some("thread_1")).unwrap();
    
    let due = store.get_unnotified_due_reminders(now).unwrap();
    assert_eq!(due.len(), 1);
    assert_eq!(due[0].title, "Họp nhóm");
    
    // Mark notified
    store.mark_reminder_notified(due[0].id).unwrap();
    let due_after = store.get_unnotified_due_reminders(now).unwrap();
    assert_eq!(due_after.len(), 0);
}
```

**Step 2: Chạy test xác nhận fail**
Run: `cargo test --manifest-path zlite/Cargo.toml test_task4_reminder_due_scan`

**Step 3: Triển khai trong `src/store.rs` và `src/gui.rs`**
- Trong `store.rs`: Thêm cột `is_notified INTEGER DEFAULT 0` trong bảng `reminders`, viết hàm `get_unnotified_due_reminders(now_ts: i64)` và `mark_reminder_notified(id: i64)`.
- Trong `gui.rs`: Thêm trường `last_reminder_check: std::time::Instant` vào `ZaloGuiApp`. Trong `update()`, mỗi 2 giây quét các reminder đến hạn:
  - Nếu có reminder đến hạn, gọi `crate::os_notify::notify("⏰ ZLite - Nhắc Hẹn", &format!("{}: {}", r.title, r.desc), "appointment-soon", None)`.
  - Cập nhật trạng thái `is_notified = 1` trong SQLite.

**Step 4: Chạy test xác nhận pass**
Run: `cargo test --manifest-path zlite/Cargo.toml test_task4_reminder_due_scan`

**Step 5: Commit**
```bash
git add zlite/src/store.rs zlite/src/gui.rs
git commit -m "feat(reminder): implement due daemon and native desktop reminder alerts"
```

---

### Task 5: Gợi Ý Tin Nhắn Nhanh Phím Tắt `/` (Quick Messages Suggestions)
**Files:**
- Modify: `zlite/src/gui/workspace.rs`
- Modify: `zlite/src/gui.rs`
- Test: `zlite/src/gui/workspace.rs` (inline test `test_task5_quick_message_suggestions`)

**Step 1: Viết failing test kiểm tra matching phím tắt tin nhắn nhanh**
```rust
#[test]
fn test_task5_quick_message_suggestions() {
    let qm_list = vec![
        QuickMessage { shortcut: "/chao".to_string(), text: "Xin chào bạn, tôi có thể hỗ trợ gì?".to_string() },
        QuickMessage { shortcut: "/stk".to_string(), text: "Số tài khoản: 1903... Techcombank".to_string() },
    ];
    let matched = find_matching_quick_messages(&qm_list, "/ch");
    assert_eq!(matched.len(), 1);
    assert_eq!(matched[0].shortcut, "/chao");
}
```

**Step 2: Chạy test xác nhận fail**
Run: `cargo test --manifest-path zlite/Cargo.toml test_task5_quick_message_suggestions`

**Step 3: Triển khai trong `src/gui/workspace.rs` và `src/gui.rs`**
- Thêm struct `QuickMessage { pub shortcut: String, pub text: String }`.
- Thêm danh sách `quick_messages` mặc định trong `ZaloGuiApp` (hoặc nạp từ settings).
- Khi người dùng gõ vào composer bắt đầu bằng `/`:
  - Hiển thị khung popup gợi ý phía trên ô composer liệt kê các mẫu câu tương ứng.
  - Khi click vào gợi ý, tự động thay thế `composer_input` bằng nội dung mẫu câu.

**Step 4: Chạy test xác nhận pass**
Run: `cargo test --manifest-path zlite/Cargo.toml test_task5_quick_message_suggestions`

**Step 5: Commit**
```bash
git add zlite/src/gui/workspace.rs zlite/src/gui.rs
git commit -m "feat(composer): implement slash quick messages autocomplete popup"
```

---

### Task 6: Khóa Ứng Dụng (App Lock PIN) & Dọn Dẹp Bộ Nhớ Đệm (Cache Cleaner)
**Files:**
- Modify: `zlite/src/gui.rs`
- Modify: `zlite/src/gui/modals.rs`
- Modify: `zlite/src/session.rs`
- Test: `zlite/src/gui.rs` (inline test `test_task6_app_lock_and_cache_cleaner`)

**Step 1: Viết failing test kiểm tra hash PIN và tính toán dung lượng cache**
```rust
#[test]
fn test_task6_app_lock_and_cache_cleaner() {
    let pin = "1234";
    let hash = hash_app_pin(pin);
    assert!(verify_app_pin(pin, &hash));
    assert!(!verify_app_pin("9999", &hash));
}
```

**Step 2: Chạy test xác nhận fail**
Run: `cargo test --manifest-path zlite/Cargo.toml test_task6_app_lock_and_cache_cleaner`

**Step 3: Triển khai trong `src/gui.rs`, `src/gui/modals.rs`, `src/session.rs`**
- Thêm hàm `hash_app_pin(pin: &str) -> String` và `verify_app_pin(pin: &str, hashed: &str) -> bool`.
- Trong `ZaloGuiApp`:
  - Thêm trường `is_locked: bool`, `last_user_activity: std::time::Instant`.
  - Nếu `settings.app_lock_enabled` và `is_locked`: hiển thị overlay khóa toàn màn hình yêu cầu nhập 4 số PIN.
  - Sau thời gian nhàn rỗi (ví dụ 15 phút không click/gõ phím), tự động gán `is_locked = true`.
- Thêm utility dọn dẹp cache: `purge_temp_cache() -> u64` (trả về số byte đã giải phóng) và hiển thị thông báo kết quả.

**Step 4: Chạy test xác nhận pass**
Run: `cargo test --manifest-path zlite/Cargo.toml test_task6_app_lock_and_cache_cleaner`

**Step 5: Commit**
```bash
git add zlite/src/gui.rs zlite/src/gui/modals.rs zlite/src/session.rs
git commit -m "feat(security): implement app lock PIN verification and cache cleaner utility"
```

---

## 🧪 Verification & Acceptance Criteria
- `cargo test --manifest-path zlite/Cargo.toml --locked --lib`: Tất cả 326+ unit tests hiện có và 6 unit tests mới đều vượt qua (100% pass).
- `cargo clippy --manifest-path zlite/Cargo.toml --lib`: 0 lỗi.
- Đảm bảo giữ nguyên kiến trúc Zero-Idle-CPU (0.0% khi nghỉ, chỉ repaint khi có tương tác hoặc timer kích hoạt).
- Xuất file báo cáo chi tiết nghiệm thu tại `docs/report/tuong-tac-tin-nhan-va-nang-suat-nhom-16-11-2026-14-55/report.md`.
