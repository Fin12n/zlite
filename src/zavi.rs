//! Zavi Conference (Group Video Calling & Meeting) Module (#107).
//!
//! Provides data models, signaling helpers, and meeting lifecycle controllers
//! for Zalo PC's Zavi Conference integration.

use serde::{Deserialize, Serialize};

/// Status of a Zavi conference meeting room.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ZaviMeetingStatus {
    Waiting,
    InProgress,
    Ended,
}

impl Default for ZaviMeetingStatus {
    fn default() -> Self {
        Self::Waiting
    }
}

/// View layout mode for the conference video gallery.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ZaviViewMode {
    Gallery,
    Speaker,
}

impl Default for ZaviViewMode {
    fn default() -> Self {
        Self::Gallery
    }
}

/// Participant in a Zavi Conference meeting.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ZaviParticipant {
    pub uin: String,
    pub display_name: String,
    pub is_host: bool,
    pub is_muted: bool,
    pub is_video_off: bool,
    pub is_sharing_screen: bool,
    pub joined_at: i64,
}

/// Complete representation of a Zavi conference meeting room.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ZaviMeeting {
    pub meeting_id: String,
    pub topic: String,
    pub password: String,
    pub host_name: String,
    pub host_uin: String,
    pub created_at: i64,
    pub status: ZaviMeetingStatus,
    pub mute_mic_on_join: bool,
    pub turn_off_cam_on_join: bool,
    pub require_login: bool,
    pub participants: Vec<ZaviParticipant>,
}

impl ZaviMeeting {
    /// Generates the standard web/app join URL for this meeting.
    pub fn join_url(&self) -> String {
        let clean_id = self.meeting_id.replace(' ', "");
        format!("https://zavi.me/meeting/{clean_id}?pwd={}", self.password)
    }

    /// Formats the meeting invitation text to share into Zalo chats.
    pub fn format_invitation_text(&self) -> String {
        format!(
            "📹 [Cuộc họp Zavi] {}\n• Mã cuộc họp: {}\n• Mật khẩu: {}\n• Tham gia ngay: {}",
            self.topic,
            self.meeting_id,
            self.password,
            self.join_url()
        )
    }
}

/// Generates a randomized 9-digit Zavi Meeting ID (format `xxx xxx xxx`).
pub fn generate_meeting_id() -> String {
    use std::time::{SystemTime, UNIX_EPOCH};
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis())
        .unwrap_or(1_700_000_000_000);
    let rand_num = ((now % 899_999_999) + 100_000_000) as u32;
    let s = rand_num.to_string();
    if s.len() >= 9 {
        format!("{} {} {}", &s[0..3], &s[3..6], &s[6..9])
    } else {
        "849 123 456".to_string()
    }
}

/// Generates a randomized 6-digit numeric password for room authentication.
pub fn generate_meeting_password() -> String {
    use std::time::{SystemTime, UNIX_EPOCH};
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_micros())
        .unwrap_or(123456);
    let pass = ((now % 899_999) + 100_000) as u32;
    pass.to_string()
}

/// Parses a Zavi invitation text or URL, returning `Some((meeting_id, password))`.
pub fn parse_meeting_invite(text: &str) -> Option<(String, String)> {
    let clean = text.trim();
    if let Some(idx) = clean.find("zavi.me/meeting/") {
        let after = &clean[idx + 16..];
        let mut parts = after.split('?');
        let raw_id = parts.next().unwrap_or("").trim();
        let query = parts.next().unwrap_or("");
        let mut pwd = String::new();
        for q in query.split('&') {
            if let Some(p) = q.strip_prefix("pwd=") {
                pwd = p.to_string();
                break;
            }
        }
        if !raw_id.is_empty() {
            let id_formatted = if raw_id.len() == 9 {
                format!("{} {} {}", &raw_id[0..3], &raw_id[3..6], &raw_id[6..9])
            } else {
                raw_id.to_string()
            };
            return Some((id_formatted, pwd));
        }
    }
    None
}

/// Formats duration in seconds into `HH:MM:SS` or `MM:SS`.
pub fn format_meeting_duration(secs: u64) -> String {
    let hours = secs / 3600;
    let mins = (secs % 3600) / 60;
    let s = secs % 60;
    if hours > 0 {
        format!("{hours:02}:{mins:02}:{s:02}")
    } else {
        format!("{mins:02}:{s:02}")
    }
}

/// State container for active and stored Zavi Conference meetings.
#[derive(Debug, Clone, Default)]
pub struct ZaviConferenceState {
    pub current_meeting: Option<ZaviMeeting>,
    pub meeting_history: Vec<ZaviMeeting>,
    pub is_in_meeting: bool,
    pub meeting_start_instant: Option<std::time::Instant>,
    pub my_mic_muted: bool,
    pub my_cam_off: bool,
    pub my_screen_sharing: bool,
    pub active_view_mode: ZaviViewMode,
    pub active_speaker_uin: Option<String>,
}

impl ZaviConferenceState {
    /// Starts a new meeting as host.
    pub fn start_meeting(&mut self, meeting: ZaviMeeting) {
        self.is_in_meeting = true;
        self.my_mic_muted = meeting.mute_mic_on_join;
        self.my_cam_off = meeting.turn_off_cam_on_join;
        self.my_screen_sharing = false;
        self.meeting_start_instant = Some(std::time::Instant::now());
        self.active_speaker_uin = Some(meeting.host_uin.clone());
        self.current_meeting = Some(meeting);
    }

    /// Leaves or ends the current meeting room.
    pub fn end_meeting(&mut self) {
        if let Some(mut m) = self.current_meeting.take() {
            m.status = ZaviMeetingStatus::Ended;
            self.meeting_history.insert(0, m);
        }
        self.is_in_meeting = false;
        self.meeting_start_instant = None;
        self.my_screen_sharing = false;
    }

    /// Elapsed seconds since current meeting started.
    pub fn elapsed_seconds(&self) -> u64 {
        self.meeting_start_instant
            .map(|t| t.elapsed().as_secs())
            .unwrap_or(0)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_meeting_id_and_password_generation() {
        let id = generate_meeting_id();
        assert_eq!(id.len(), 11); // "xxx xxx xxx" (9 digits + 2 spaces)
        let parts: Vec<&str> = id.split(' ').collect();
        assert_eq!(parts.len(), 3);
        for p in parts {
            assert_eq!(p.len(), 3);
            assert!(p.chars().all(|c| c.is_ascii_digit()));
        }

        let pwd = generate_meeting_password();
        assert_eq!(pwd.len(), 6);
        assert!(pwd.chars().all(|c| c.is_ascii_digit()));
    }

    #[test]
    fn test_meeting_url_and_invitation_formatting() {
        let meeting = ZaviMeeting {
            meeting_id: "849 888 999".into(),
            topic: "Họp Chiến Lược Quý 4".into(),
            password: "654321".into(),
            host_name: "Admin".into(),
            host_uin: "113355".into(),
            created_at: 1700000000,
            status: ZaviMeetingStatus::Waiting,
            mute_mic_on_join: true,
            turn_off_cam_on_join: false,
            require_login: true,
            participants: vec![],
        };

        assert_eq!(
            meeting.join_url(),
            "https://zavi.me/meeting/849888999?pwd=654321"
        );

        let inv = meeting.format_invitation_text();
        assert!(inv.contains("Họp Chiến Lược Quý 4"));
        assert!(inv.contains("849 888 999"));
        assert!(inv.contains("654321"));
        assert!(inv.contains("https://zavi.me/meeting/849888999?pwd=654321"));

        let parsed = parse_meeting_invite(&meeting.join_url()).expect("parse url");
        assert_eq!(parsed.0, "849 888 999");
        assert_eq!(parsed.1, "654321");
    }

    #[test]
    fn test_meeting_state_lifecycle() {
        let mut state = ZaviConferenceState::default();
        assert!(!state.is_in_meeting);

        let meeting = ZaviMeeting {
            meeting_id: "123 456 789".into(),
            topic: "Test Meeting".into(),
            password: "111222".into(),
            host_name: "Host".into(),
            host_uin: "9999".into(),
            created_at: 1700000000,
            status: ZaviMeetingStatus::Waiting,
            mute_mic_on_join: true,
            turn_off_cam_on_join: false,
            require_login: false,
            participants: vec![],
        };

        state.start_meeting(meeting);
        assert!(state.is_in_meeting);
        assert!(state.my_mic_muted);
        assert!(!state.my_cam_off);
        assert_eq!(state.active_speaker_uin.as_deref(), Some("9999"));

        state.end_meeting();
        assert!(!state.is_in_meeting);
        assert_eq!(state.meeting_history.len(), 1);
        assert_eq!(state.meeting_history[0].status, ZaviMeetingStatus::Ended);
    }
}
