//! Khớp tin nhắn mới với từ khóa theo dõi của nhóm (Group Workspace).
//!
//! Đọc `group_watch` từ SQLite theo tài khoản (`db_path_for_account`), so khớp
//! case-insensitive trên text RAM. Không đoán: thiếu DB/keyword → không hit.

use crate::chat::ChatMessage;

/// 1 tin mới khớp 1 từ khóa.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct WatchHit {
    pub keyword: String,
    pub msg_id: String,
    pub sender: String,
    pub preview: String,
}

fn truncate_preview(text: &str) -> String {
    let t = text.trim();
    if t.chars().count() > 96 {
        let s: String = t.chars().take(96).collect();
        format!("{s}…")
    } else if t.is_empty() {
        "[ Đính kèm / Nhãn dán ]".to_string()
    } else {
        t.to_string()
    }
}

/// So khớp các tin mới (`fresh`, mới nhất xếp sau) với keyword đã lưu của thread.
/// Mở DB read-only theo `user_uin`; lỗi DB → `Vec::new()`.
pub fn match_new_messages(
    user_uin: &str,
    thread_id: &str,
    fresh: &[&ChatMessage],
) -> Vec<WatchHit> {
    if thread_id.is_empty() || fresh.is_empty() {
        return Vec::new();
    }
    let db = crate::store::db_path_for_account(user_uin);
    let store = match crate::store::MessageStore::open(&db) {
        Ok(s) => s,
        Err(_) => return Vec::new(),
    };
    let keywords = store.list_group_watch(thread_id);
    if keywords.is_empty() {
        return Vec::new();
    }
    let lowered: Vec<(String, String)> = keywords
        .iter()
        .map(|k| (k.clone(), k.to_lowercase()))
        .filter(|(_, n)| !n.is_empty())
        .collect();
    if lowered.is_empty() {
        return Vec::new();
    }
    let mut hits = Vec::new();
    for m in fresh {
        let hay = m.text.to_lowercase();
        if hay.is_empty() {
            continue;
        }
        for (kw, needle) in &lowered {
            if hay.contains(needle) {
                hits.push(WatchHit {
                    keyword: kw.clone(),
                    msg_id: m.id.clone(),
                    sender: if m.sender.is_empty() {
                        "Ẩn danh".to_string()
                    } else {
                        m.sender.clone()
                    },
                    preview: truncate_preview(&m.text),
                });
            }
        }
    }
    hits
}

#[cfg(test)]
mod tests {
    use super::*;

    fn msg(id: &str, sender: &str, text: &str) -> ChatMessage {
        ChatMessage {
            id: id.into(),
            sender: sender.into(),
            text: text.into(),
            ..Default::default()
        }
    }

    #[test]
    fn empty_inputs_never_hit() {
        assert!(match_new_messages("u", "", &[]).is_empty());
        let m = msg("m1", "An", "báo cáo");
        assert!(match_new_messages("u", "", &[&m]).is_empty());
        assert!(match_new_messages("u", "g1", &[]).is_empty());
    }
}
