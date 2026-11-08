//! Thống kê nhóm cho Group Workspace: tính từ DB (SQLite) + RAM (thread đang mở).
//!
//! Rẻ: 1 query COUNT + GROUP BY cho DB, còn lại duyệt RAM. Không đoán —
//! thiếu dữ liệu thì số 0 / chuỗi rỗng.

use std::collections::HashMap;

use crate::chat::Thread;
use crate::message_model::MessageKind;
use crate::store::MessageStore;

/// Thống kê 1 thread nhóm.
#[derive(Debug, Clone, Default)]
pub struct GroupStats {
    /// Tổng số tin (DB + RAM, khử trùng theo id).
    pub total: usize,
    /// Số tin 7 ngày gần nhất.
    pub last_7d: usize,
    /// Phân phối 7 ngày (cũ → mới, 7 bucket).
    pub daily: [usize; 7],
    /// Top 5 người gửi (tên, số tin).
    pub top_senders: Vec<(String, usize)>,
    /// Đếm media: ảnh, file, link, voice.
    pub photos: usize,
    pub files: usize,
    pub links: usize,
    pub voices: usize,
    /// Giờ sôi động nhất 0–23h (giờ địa phương). `None` khi chưa có tin nào.
    pub peak_hour: Option<u8>,
    /// Số tin trong giờ sôi động nhất.
    pub peak_hour_count: usize,
}

fn classify(kind: MessageKind, link_src: Option<&str>, text: &str) -> &'static str {
    match kind {
        MessageKind::Photo => "photo",
        MessageKind::Video => "photo",
        MessageKind::File => "file",
        MessageKind::Voice => "voice",
        MessageKind::Link | MessageKind::WebContent => "link",
        _ => {
            let src = link_src.unwrap_or("");
            let t = text.trim();
            if src == "Hình ảnh Zalo"
                || t == "[Hình ảnh]"
                || t.starts_with("[Hình ảnh] ")
            {
                "photo"
            } else if src == "Tập tin Zalo" || t.starts_with("[Tập tin]") {
                "file"
            } else if src == "Thoại Zalo"
                || t == "[Tin nhắn thoại]"
                || t.starts_with("[Tin nhắn thoại]")
            {
                "voice"
            } else if t.starts_with("http://") || t.starts_with("https://") {
                "link"
            } else {
                "text"
            }
        }
    }
}

fn hour_of(ts_ms: i64) -> Option<u8> {
    crate::clock::local_datetime(ts_ms).map(|d| {
        use chrono::Timelike;
        d.hour() as u8
    })
}

fn day_bucket(ts_ms: i64, now_ms: i64) -> Option<usize> {
    if ts_ms <= 0 || now_ms <= 0 || ts_ms > now_ms + 86_400_000 {
        return None;
    }
    let diff_days = (now_ms - ts_ms) / 86_400_000;
    if !(0..7).contains(&diff_days) {
        return None;
    }
    // Cũ → mới: bucket 0 = 6 ngày trước, bucket 6 = hôm nay.
    Some((6 - diff_days) as usize)
}

/// Tính thống kê từ DB (toàn bộ lịch sử đã lưu) + RAM (tin chưa persist).
/// DB thiếu (mở lỗi) → chỉ dùng RAM; RAM thiếu → chỉ dùng DB.
pub fn compute_group_stats(store: Option<&MessageStore>, thread: Option<&Thread>) -> GroupStats {
    let now_ms = crate::clock::normalize_ts_ms(chrono::Local::now().timestamp_millis());
    let week_ago = now_ms - 7 * 86_400_000;

    // Gộp (id → bản ghi nhẹ): DB trước, RAM đè (RAM mới hơn / đủ kind).
    // key: (sender, text, ts_ms, kind_label)
    let mut by_id: HashMap<String, (String, String, i64, &'static str)> = HashMap::new();
    if let (Some(s), Some(t)) = (store, thread) {
        if let Ok(rows) = s.messages_for(&t.id, 100_000) {
            for r in rows {
                let kind = MessageKind::from_wire_name(&r.msg_type);
                by_id
                    .entry(r.msg_id.clone())
                    .or_insert((r.sender_name.clone(), r.text.clone(), r.ts, ""));
                let e = by_id.get_mut(&r.msg_id).unwrap();
                let label = classify(kind, None, &e.1);
                e.3 = label;
            }
        }
    }
    if let Some(t) = thread {
        for m in &t.messages {
            let label = classify(m.kind, m.link_src.as_deref(), &m.text);
            by_id.insert(
                if m.id.is_empty() {
                    format!("ram_{}_{}", t.id, m.ts)
                } else {
                    m.id.clone()
                },
                (m.sender.clone(), m.text.clone(), m.ts, label),
            );
        }
    }

    let mut st = GroupStats::default();
    st.total = by_id.len();
    let mut sender_counts: HashMap<String, usize> = HashMap::new();
    let mut hour_counts = [0usize; 24];

    for (sender, _text, ts, label) in by_id.values() {
        let ts_ms = crate::clock::normalize_ts_ms(*ts);
        match *label {
            "photo" => st.photos += 1,
            "file" => st.files += 1,
            "link" => st.links += 1,
            "voice" => st.voices += 1,
            _ => {}
        }
        let name = if sender.trim().is_empty() {
            "Ẩn danh".to_string()
        } else {
            sender.clone()
        };
        *sender_counts.entry(name).or_insert(0) += 1;
        if ts_ms >= week_ago {
            st.last_7d += 1;
            if let Some(b) = day_bucket(ts_ms, now_ms) {
                st.daily[b] += 1;
            }
        }
        if let Some(h) = hour_of(ts_ms) {
            hour_counts[h as usize] += 1;
        }
    }

    let mut senders: Vec<(String, usize)> = sender_counts.into_iter().collect();
    senders.sort_by(|a, b| b.1.cmp(&a.1).then_with(|| a.0.cmp(&b.0)));
    senders.truncate(5);
    st.top_senders = senders;

    let (peak_h, peak_c) = hour_counts
        .iter()
        .enumerate()
        .max_by_key(|(_, c)| **c)
        .map(|(h, c)| (h as u8, *c))
        .unwrap_or((0, 0));
    if peak_c > 0 {
        st.peak_hour = Some(peak_h);
        st.peak_hour_count = peak_c;
    }
    st
}

/// Tóm tắt 1 dòng cho LLM + UI ("120 tin · 7 ngày: 34 · top: An (40) · ảnh 5 …").
pub fn summarize_thread(thread: Option<&Thread>, store: &MessageStore) -> String {
    let st = compute_group_stats(Some(store), thread);
    let top = st
        .top_senders
        .iter()
        .map(|(n, c)| format!("{n} ({c})"))
        .collect::<Vec<_>>()
        .join(", ");
    let peak = match st.peak_hour {
        Some(h) => format!("{h:02}h ({} tin)", st.peak_hour_count),
        None => "—".to_string(),
    };
    format!(
        "{} tin · 7 ngày: {} · top: {} · ảnh {} · file {} · link {} · voice {} · giờ sôi động: {}",
        st.total,
        st.last_7d,
        if top.is_empty() { "—".into() } else { top },
        st.photos,
        st.files,
        st.links,
        st.voices,
        peak,
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::chat::ChatMessage;
    use crate::store::{StoredMessage, StoredThread};

    fn thread_with_messages() -> Thread {
        let now = chrono::Local::now().timestamp_millis();
        Thread {
            id: "g1".to_string(),
            name: "G".to_string(),
            preview: String::new(),
            time: String::new(),
            avatar: None,
            is_group: true,
            messages: vec![
                ChatMessage {
                    id: "m1".into(),
                    sender: "An".into(),
                    text: "hello".into(),
                    time: "10:00".into(),
                    ts: now,
                    kind: MessageKind::Text,
                    ..Default::default()
                },
                ChatMessage {
                    id: "m2".into(),
                    sender: "An".into(),
                    text: "[Hình ảnh]".into(),
                    time: "10:01".into(),
                    ts: now,
                    kind: MessageKind::Photo,
                    link_src: Some("Hình ảnh Zalo".into()),
                    ..Default::default()
                },
                ChatMessage {
                    id: "m3".into(),
                    sender: "Bình".into(),
                    text: "https://example.com/x".into(),
                    time: "10:02".into(),
                    ts: now,
                    kind: MessageKind::Text,
                    ..Default::default()
                },
            ],
            ..Default::default()
        }
    }

    #[test]
    fn stats_from_ram_only_are_real() {
        let t = thread_with_messages();
        let st = compute_group_stats(None, Some(&t));
        assert_eq!(st.total, 3);
        assert_eq!(st.photos, 1);
        assert_eq!(st.links, 1);
        assert_eq!(st.top_senders[0], ("An".to_string(), 2));
        assert!(st.peak_hour.is_some());
        assert_eq!(st.last_7d, 3);
        assert_eq!(st.daily.iter().sum::<usize>(), 3);
    }

    #[test]
    fn stats_dedupe_db_and_ram() {
        let mut store = MessageStore::open(":memory:").unwrap();
        store
            .upsert_thread(&StoredThread {
                thread_id: "g1".into(),
                name: "G".into(),
                is_group: true,
                last_ts: 1,
                vanish_duration_sec: 0,
                vanish_started_at_sec: 0,
                last_read_msg_id: String::new(),
            })
            .unwrap();
        store
            .upsert_message(&StoredMessage {
                msg_id: "m1".into(),
                thread_id: "g1".into(),
                sender_id: "An".into(),
                sender_name: "An".into(),
                text: "hello".into(),
                msg_type: "chat.text".into(),
                ts: chrono::Local::now().timestamp_millis(),
                is_outgoing: false,
                raw_json: String::new(),
            })
            .unwrap();
        let t = thread_with_messages();
        let st = compute_group_stats(Some(&store), Some(&t));
        // m1 trùng id DB+RAM → đếm 1 lần.
        assert_eq!(st.total, 3);
    }
}
