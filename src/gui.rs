//! Complete native desktop GUI powered by `eframe` and `egui`.
//!
//! Designed with the UI/UX Pro Max Minimalism & Swiss Style system:
//! - Zero-idle-CPU reactive architecture (event-driven repaint, zero per-frame Thread cloning)
//! - Custom vector icons rendered via `egui::Painter` (zero texture/SVG bloat)
//! - High-contrast Light & Dark semantic color tokens (`#0068FF` / `#2563EB` primary, `#059669` online accent)
//! - Filterable conversation sidebar (`Tất cả`, `Cá nhân`, `Nhóm`), avatar badges, and grouped chat bubbles
//! - Built-in Zalo Sticker rendering & picker (`[Nhãn dán]`)

use std::collections::{HashMap, HashSet};
use std::sync::mpsc::{channel, Receiver, Sender};
use std::time::Duration;

use eframe::egui::{
    self, Align, Color32, CursorIcon, FontId, Id, Key, Layout, Margin, Pos2, Rect, RichText,
    Rounding, Sense, Stroke, TextureHandle, TextureOptions, Vec2,
};

use crate::chat::{ChatMessage, Thread};
use crate::logger::{self, FindingLevel, LogEntry, ScanFinding};
use crate::qr::QrLogin;
use crate::session::Session;

mod messages;
mod modals;
mod pages;
mod reactions_dialog;
mod stickers;
mod theme;
mod worker;
mod workspace;

use messages::*;
use stickers::*;
use theme::*;
pub use theme::{emoji_to_tex_key, load_app_icon, lucide, REACTION_LIST};
pub use worker::WorkerCmd;
use worker::*;

fn merge_sent_message(thread: &mut Thread, message: ChatMessage) {
    crate::chat::merge_sent_message(thread, message);
}

#[cfg_attr(not(any(target_os = "windows", test)), allow(dead_code))]
#[repr(C)]
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
struct WinRect {
    left: i32,
    top: i32,
    right: i32,
    bottom: i32,
}

impl WinRect {
    #[cfg_attr(not(any(target_os = "windows", test)), allow(dead_code))]
    fn width(self) -> i32 {
        self.right.saturating_sub(self.left)
    }

    #[cfg_attr(not(any(target_os = "windows", test)), allow(dead_code))]
    fn height(self) -> i32 {
        self.bottom.saturating_sub(self.top)
    }
}

#[cfg(target_os = "windows")]
#[derive(Clone, Copy, Debug)]
struct WinResizeDrag {
    dir: egui::ResizeDirection,
    start_cursor_x: i32,
    start_cursor_y: i32,
    start_rect: WinRect,
}

/// Compute the target outer window rectangle when dragging a border or corner edge,
/// clamping to `min_w`/`min_h` while keeping the opposite edge anchored.
#[cfg_attr(not(any(target_os = "windows", test)), allow(dead_code))]
fn compute_resized_rect(
    start: WinRect,
    dir: egui::ResizeDirection,
    dx: i32,
    dy: i32,
    min_w: i32,
    min_h: i32,
) -> WinRect {
    let min_w = min_w.max(1);
    let min_h = min_h.max(1);
    let mut r = start;

    match dir {
        egui::ResizeDirection::West
        | egui::ResizeDirection::NorthWest
        | egui::ResizeDirection::SouthWest => {
            let max_left = r.right.saturating_sub(min_w);
            r.left = start.left.saturating_add(dx).min(max_left);
        }
        egui::ResizeDirection::East
        | egui::ResizeDirection::NorthEast
        | egui::ResizeDirection::SouthEast => {
            let min_right = r.left.saturating_add(min_w);
            r.right = start.right.saturating_add(dx).max(min_right);
        }
        egui::ResizeDirection::North | egui::ResizeDirection::South => {}
    }

    match dir {
        egui::ResizeDirection::North
        | egui::ResizeDirection::NorthWest
        | egui::ResizeDirection::NorthEast => {
            let max_top = r.bottom.saturating_sub(min_h);
            r.top = start.top.saturating_add(dy).min(max_top);
        }
        egui::ResizeDirection::South
        | egui::ResizeDirection::SouthWest
        | egui::ResizeDirection::SouthEast => {
            let min_bottom = r.top.saturating_add(min_h);
            r.bottom = start.bottom.saturating_add(dy).max(min_bottom);
        }
        egui::ResizeDirection::West | egui::ResizeDirection::East => {}
    }

    r
}

#[cfg(target_os = "windows")]
mod win32_frameless {
    use super::WinRect;

    const GWL_STYLE: i32 = -16;
    const GWL_EXSTYLE: i32 = -20;

    // winit 0.30 keeps WS_CAPTION | WS_BORDER | WS_THICKFRAME and WS_EX_WINDOWEDGE even
    // for undecorated windows, which makes Intel/hybrid WGL drivers offset rendering by (7, 29)px.
    const WS_BORDER: u32 = 0x0080_0000;
    const WS_DLGFRAME: u32 = 0x0040_0000;
    const WS_CAPTION: u32 = WS_BORDER | WS_DLGFRAME;
    const WS_THICKFRAME: u32 = 0x0004_0000;
    const STRIP_STYLE_MASK: u32 = WS_CAPTION | WS_THICKFRAME;

    const WS_EX_DLGMODALFRAME: u32 = 0x0000_0001;
    const WS_EX_WINDOWEDGE: u32 = 0x0000_0100;
    const WS_EX_CLIENTEDGE: u32 = 0x0000_0200;
    const STRIP_EX_STYLE_MASK: u32 = WS_EX_DLGMODALFRAME | WS_EX_WINDOWEDGE | WS_EX_CLIENTEDGE;

    const SWP_NOSIZE: u32 = 0x0001;
    const SWP_NOMOVE: u32 = 0x0002;
    const SWP_NOZORDER: u32 = 0x0004;
    const SWP_NOACTIVATE: u32 = 0x0010;
    const SWP_FRAMECHANGED: u32 = 0x0020;

    const GW_OWNER: u32 = 4;
    const MONITOR_DEFAULTTONEAREST: u32 = 2;

    #[repr(C)]
    struct RawPoint {
        x: i32,
        y: i32,
    }

    #[repr(C)]
    struct MonitorInfo {
        cb_size: u32,
        rc_monitor: WinRect,
        rc_work: WinRect,
        dw_flags: u32,
    }

    struct EnumSearchState {
        visible_match: usize,
        any_match: usize,
    }

    #[link(name = "opengl32")]
    extern "system" {
        fn wglGetCurrentDC() -> usize;
    }

    #[link(name = "kernel32")]
    extern "system" {
        fn GetCurrentThreadId() -> u32;
    }

    #[link(name = "user32")]
    extern "system" {
        fn WindowFromDC(hdc: usize) -> usize;
        fn GetActiveWindow() -> usize;
        fn EnumThreadWindows(
            dw_thread_id: u32,
            lpfn: unsafe extern "system" fn(usize, isize) -> i32,
            l_param: isize,
        ) -> i32;
        fn GetWindow(hwnd: usize, u_cmd: u32) -> usize;
        fn IsWindow(hwnd: usize) -> i32;
        fn IsWindowVisible(hwnd: usize) -> i32;
        fn GetWindowLongW(hwnd: usize, n_index: i32) -> i32;
        fn SetWindowLongW(hwnd: usize, n_index: i32, dw_new_long: i32) -> i32;
        fn SetWindowPos(
            hwnd: usize,
            hwnd_insert_after: usize,
            x: i32,
            y: i32,
            cx: i32,
            cy: i32,
            u_flags: u32,
        ) -> i32;
        fn GetWindowRect(hwnd: usize, lp_rect: *mut WinRect) -> i32;
        fn GetCursorPos(lp_point: *mut RawPoint) -> i32;
        fn MonitorFromWindow(hwnd: usize, dw_flags: u32) -> usize;
        fn GetMonitorInfoW(h_monitor: usize, lpmi: *mut MonitorInfo) -> i32;
    }

    unsafe extern "system" fn enum_thread_window_cb(hwnd: usize, l_param: isize) -> i32 {
        // SAFETY: `l_param` points to stack-allocated `EnumSearchState` owned by `find_window_hwnd`.
        let state = unsafe { &mut *(l_param as *mut EnumSearchState) };
        // SAFETY: Win32 passes a valid thread `HWND` into `EnumThreadWindows` callback.
        let is_top_level = unsafe { GetWindow(hwnd, GW_OWNER) } == 0;
        if !is_top_level {
            return 1;
        }
        let Some(rect) = get_window_rect(hwnd) else {
            return 1;
        };
        // Skip winit/IME 4x4 hidden helper windows so only the main app window matches.
        if rect.width() < 200 || rect.height() < 200 {
            return 1;
        }
        // SAFETY: `hwnd` was enumerated by Win32 and verified non-null above.
        if unsafe { IsWindowVisible(hwnd) } != 0 {
            state.visible_match = hwnd;
            return 0;
        }
        if state.any_match == 0 {
            state.any_match = hwnd;
        }
        1
    }

    pub(super) fn is_valid_window(hwnd: usize) -> bool {
        if hwnd == 0 {
            return false;
        }
        // SAFETY: `IsWindow` safely validates arbitrary handle integers without dereferencing.
        unsafe { IsWindow(hwnd) != 0 }
    }

    pub(super) fn find_window_hwnd() -> usize {
        // SAFETY: `wglGetCurrentDC` and `WindowFromDC` operate on thread-local GL state.
        let dc_hwnd = unsafe {
            let hdc = wglGetCurrentDC();
            if hdc == 0 {
                0
            } else {
                WindowFromDC(hdc)
            }
        };
        if dc_hwnd != 0
            && get_window_rect(dc_hwnd).is_some_and(|r| r.width() >= 200 && r.height() >= 200)
        {
            return dc_hwnd;
        }

        // SAFETY: `GetActiveWindow` returns the calling thread's active window or zero.
        let active = unsafe { GetActiveWindow() };
        if active != 0 {
            // SAFETY: `active` is non-zero and owned by the calling thread.
            let is_top_level = unsafe { GetWindow(active, GW_OWNER) } == 0;
            if is_top_level
                && get_window_rect(active).is_some_and(|r| r.width() >= 200 && r.height() >= 200)
            {
                return active;
            }
        }

        let mut state = EnumSearchState {
            visible_match: 0,
            any_match: 0,
        };
        // SAFETY: `state` outlives the synchronous `EnumThreadWindows` call on this thread.
        unsafe {
            let tid = GetCurrentThreadId();
            let _ = EnumThreadWindows(
                tid,
                enum_thread_window_cb,
                (&mut state as *mut EnumSearchState) as isize,
            );
        }
        if state.visible_match != 0 {
            state.visible_match
        } else {
            state.any_match
        }
    }

    /// Strip non-client caption/border bits that winit re-injects on show/maximize while
    /// preserving taskbar/system menu capabilities (`WS_SYSMENU | WS_MINIMIZEBOX | WS_MAXIMIZEBOX`).
    pub(super) fn sync_frameless_style(hwnd: usize) -> bool {
        if !is_valid_window(hwnd) {
            return false;
        }
        // SAFETY: `hwnd` was just verified by `IsWindow` on the GUI thread.
        unsafe {
            let style = GetWindowLongW(hwnd, GWL_STYLE) as u32;
            let ex_style = GetWindowLongW(hwnd, GWL_EXSTYLE) as u32;
            if (style & STRIP_STYLE_MASK) == 0 && (ex_style & STRIP_EX_STYLE_MASK) == 0 {
                return false;
            }
            let new_style = (style & !STRIP_STYLE_MASK) as i32;
            let new_ex_style = (ex_style & !STRIP_EX_STYLE_MASK) as i32;
            let _ = SetWindowLongW(hwnd, GWL_STYLE, new_style);
            let _ = SetWindowLongW(hwnd, GWL_EXSTYLE, new_ex_style);
            let _ = SetWindowPos(
                hwnd,
                0,
                0,
                0,
                0,
                0,
                SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED,
            );
            true
        }
    }

    pub(super) fn get_window_rect(hwnd: usize) -> Option<WinRect> {
        if !is_valid_window(hwnd) {
            return None;
        }
        let mut raw = WinRect::default();
        // SAFETY: `hwnd` is a valid Win32 window and `raw` is a properly aligned output struct.
        let ok = unsafe { GetWindowRect(hwnd, &mut raw) != 0 };
        ok.then_some(raw)
    }

    pub(super) fn set_window_rect(hwnd: usize, rect: WinRect, frame_changed: bool) {
        if !is_valid_window(hwnd) {
            return;
        }
        let mut flags = SWP_NOZORDER | SWP_NOACTIVATE;
        if frame_changed {
            flags |= SWP_FRAMECHANGED;
        }
        // SAFETY: `hwnd` was verified by `IsWindow` and width/height are clamped positive.
        unsafe {
            let _ = SetWindowPos(
                hwnd,
                0,
                rect.left,
                rect.top,
                rect.width().max(1),
                rect.height().max(1),
                flags,
            );
        }
    }

    pub(super) fn get_cursor_pos() -> Option<(i32, i32)> {
        let mut pt = RawPoint { x: 0, y: 0 };
        // SAFETY: `pt` is a stack-allocated Win32 `POINT` initialized to zero.
        let ok = unsafe { GetCursorPos(&mut pt) != 0 };
        ok.then_some((pt.x, pt.y))
    }

    pub(super) fn get_monitor_work_area(hwnd: usize) -> Option<WinRect> {
        if !is_valid_window(hwnd) {
            return None;
        }
        // SAFETY: `MonitorFromWindow` accepts valid `HWND` and `MonitorInfo` sets `cb_size` first.
        unsafe {
            let mon = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
            if mon == 0 {
                return None;
            }
            let mut info = MonitorInfo {
                cb_size: std::mem::size_of::<MonitorInfo>() as u32,
                rc_monitor: WinRect::default(),
                rc_work: WinRect::default(),
                dw_flags: 0,
            };
            if GetMonitorInfoW(mon, &mut info) == 0 {
                return None;
            }
            (info.rc_work.width() > 0 && info.rc_work.height() > 0).then_some(info.rc_work)
        }
    }

    pub(super) fn active_window_work_area() -> Option<WinRect> {
        // SAFETY: `GetActiveWindow` returns the thread's active `HWND` or zero.
        let active = unsafe { GetActiveWindow() };
        get_monitor_work_area(active)
    }
}

pub enum GuiEvent {
    /// Terminal response for a Settings authorization action.
    NotificationAuthorization {
        request_id: u64,
        result: Result<
            crate::native_notifications::AuthorizationStatus,
            crate::native_notifications::NotificationError,
        >,
    },
    QrReady {
        qr_login: QrLogin,
        qr_image: egui::ColorImage,
    },
    QrScanned {
        name: String,
    },
    LoginSuccess {
        name: String,
        uin: String,
        avatar: Option<String>,
    },
    LoginFailed(String),
    ThreadsUpdated(Vec<Thread>),
    MessageSent {
        client_message_id: String,
        thread_id: String,
        text: String,
        msg_id: String,
    },
    StickerSent {
        client_message_id: String,
        thread_id: String,
        msg_id: String,
        sticker_id: u64,
        cate_id: u64,
        sticker_type: u32,
    },
    AttachmentSent {
        thread_id: String,
        msg: ChatMessage,
    },
    StickerImageReady {
        key: String,
        image: egui::ColorImage,
    },
    StickerImageFailed {
        key: String,
    },
    StickerStoreLoaded(Vec<crate::chat::StickerPackInfo>),
    StickerPackItemsLoaded {
        cate_id: u64,
        name: String,
        items: Vec<crate::chat::StickerItem>,
    },
    StickerSearchResults {
        keyword: String,
        items: Vec<crate::chat::StickerItem>,
    },
    StickerSuggestKeywordsLoaded(Vec<String>),
    ComposerStickerSuggestions {
        keyword: String,
        items: Vec<crate::chat::StickerItem>,
    },
    LinkPreviewReady(crate::chat::LinkMetadata),
    GroupMembersLoaded {
        group_id: String,
        members: Vec<crate::chat::SidebarMember>,
    },
    PhoneLookupSuccess(crate::chat::PhoneLookupResult),
    PhoneLookupFailed(String),
    FriendStatusChecked {
        user_id: String,
        status: crate::chat::FriendshipStatus,
        online: Option<(bool, String)>,
    },
    QuoteSent {
        client_message_id: String,
        thread_id: String,
        text: String,
        msg_id: String,
        quoted: ChatMessage,
    },
    Reacted {
        thread_id: String,
        msg_id: String,
        ts: i64,
        reaction: String,
    },
    ReactionEventsReceived(Vec<crate::reactions::ReactionEvent>),
    MessageDeleted {
        thread_id: String,
        msg_id: String,
        ts: i64,
    },
    MessageRecalled {
        thread_id: String,
        msg_id: String,
        ts: i64,
    },
    ForwardFinished {
        target_name: String,
        error: Option<String>,
    },
    ScreenshotCaptured {
        path: std::path::PathBuf,
        width: u32,
        height: u32,
        image: egui::ColorImage,
    },
    TypingEventsReceived(Vec<crate::chat::TypingEvent>),
    SeenEventsReceived(Vec<crate::chat::SeenEvent>),
    SendFailed {
        thread_id: String,
        text: String,
        error: String,
    },
    SessionExpired(String),
    /// The server could not be reached: the session is intact, show it and retry (#21).
    SessionUnreachable(String),
    /// `zalo_history.db` + `threads_cache.json` were removed on request (#21).
    LocalDataWiped,
    CallStateChanged(String),
    IncomingCall {
        call_id: i64,
        caller_id: String,
        caller_name: String,
        is_video: bool,
        is_group: bool,
    },
    CallRejected {
        code: i64,
        reason: String,
    },
    StatusUpdate(String),
    RefreshFinished {
        threads: usize,
        messages: usize,
        errors: Vec<String>,
        manual: bool,
    },
    ScheduledListUpdated(Vec<crate::scheduler::ScheduledMessage>),
    ScheduledItemsLoaded(Vec<crate::scheduler::ScheduledMessage>),
    ScheduleActionResult {
        ok: bool,
        message: Option<String>,
        clear_composer: bool,
    },
    HistoryImported(Result<(usize, usize, Vec<Thread>), String>),
    SyncFinished {
        added: usize,
        errors: Vec<String>,
        cancelled: bool,
    },
    UpdateCheckFinished {
        result: Result<UpdateCheckResult, String>,
        silent: bool,
    },
    UpdateDownloadStatus {
        downloading: bool,
        message: String,
    },
    UpdateDownloadProgress {
        downloaded: u64,
        total: u64,
    },
    UpdateAppliedAndRestarting(String),
    SocialProfileLoaded(Result<crate::feed::SocialUserProfile, String>),
    SocialAvatarsLoaded(Result<Vec<crate::feed::FeedMedia>, String>),
    SocialTimelineLoaded(
        Result<
            (
                Vec<crate::feed::SocialUserProfile>,
                Vec<crate::feed::FeedItem>,
            ),
            String,
        >,
    ),
    MuteSnapshotSynced(HashMap<String, i64>),
    PinnedSnapshotSynced(Vec<String>),
    MuteEventsReceived(Vec<crate::chat::MuteControlEvent>),
    PhoneSyncProgress {
        progress: f32,
        status: String,
    },
    PhoneSyncFinished {
        threads: Vec<Thread>,
        added: usize,
        active_threads: usize,
        cancelled: bool,
        error: Option<String>,
    },
    /// Result of pinning/unpinning a single chat message through the group-board API.
    MessagePinResult {
        thread_id: String,
        msg_id: String,
        pin: bool,
        topic_id: String,
        error: Option<String>,
    },
    /// Server-side pinned board items for one conversation.
    BoardPinsUpdated {
        thread_id: String,
        topics: Vec<crate::chat::BoardTopic>,
        error: Option<String>,
    },
    ProxyUpdated(Result<Option<String>, String>),
    FileDownloaded(Result<(String, String), String>),
    LoggedOut,
    HistoryReachedStart(String),
    AccountSwitched {
        uin: String,
        name: String,
        avatar: Option<String>,
        threads: Vec<Thread>,
    },
}

fn phone_sync_completion_message(
    added: usize,
    active_threads: usize,
    cancelled: bool,
    error: Option<&str>,
) -> String {
    if let Some(err) = error {
        return format!("{} Đồng bộ thất bại: {err}", lucide::ALERT_TRIANGLE);
    }
    let prefix = if cancelled {
        "Đã dừng"
    } else {
        "Đã hoàn tất"
    };
    format!(
        "{prefix} yêu cầu: {added} tin mới từ Cloud/Nhóm ({active_threads} hội thoại). Lịch sử điện thoại chưa được tải vào ứng dụng."
    )
}

#[derive(Debug, Clone)]
pub struct UpdateCheckResult {
    pub current_version: String,
    pub latest_version: String,
    pub has_update: bool,
    pub release_title: String,
    pub release_notes: String,
    pub html_url: String,
    pub download_url: Option<String>,
    pub asset_name: Option<String>,
    pub asset_size: u64,
    pub expected_sha256: Option<String>,
    pub published_at: String,
}

/// Compare semantic versions (`"v0.0.2"` > `"0.0.1"`).
pub(crate) fn default_quick_reply_items() -> Vec<String> {
    vec![
        "Anh/em đang bận chút, lát gọi lại nhé!".into(),
        "Đang trong cuộc họp, nhắn tin giúp mình nhé.".into(),
        "Hiện không tiện nghe máy, có việc gì gấp không ạ?".into(),
        "Đang ngoài đường ồn quá, lát về mình gọi lại nha.".into(),
    ]
}

/// Compare semantic versions (`"v0.0.2"` > `"0.0.1"`).
pub fn is_newer_semver(remote: &str, current: &str) -> bool {
    crate::updater::is_newer_semver(remote, current)
}

/// Query GitHub Releases API (`/repos/ctdoteam1110/ctdozlite/releases/latest`) for updates.
pub async fn check_github_release_cli() -> Result<UpdateCheckResult, String> {
    worker::fetch_github_latest_release().await
}

#[derive(Debug, Clone)]
struct ActiveCallOverlay {
    partner_id: String,
    partner_name: String,
    is_video: bool,
    is_group: bool,
    state_label: String,
    started_at: std::time::Instant,
    mic_muted: bool,
    cam_enabled: bool,
    is_incoming_ringing: bool,
    error_code: Option<i64>,
    error_reason: Option<String>,
    speaker_view: bool,
    pinned_tile_idx: usize,
    call_page: usize,
    members_popover_open: bool,
    invite_search_query: String,
    quick_reply_popover_open: bool,
}

#[derive(Debug, Clone)]
struct ImageViewerModal {
    tex_key: String,
    hd_tex_key: Option<String>,
    full_url: String,
    title: String,
    sender: String,
    time: String,
    zoom: f32,
    pan: Vec2,
}
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum FeedModalTab {
    Profile,
    Avatars,
    Packet50001,
}
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum ContactsSubTab {
    Friends,
    Groups,
    FriendRequests,
    GroupInvites,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum SettingsTab {
    General,
    Account,
    Privacy,
    Sync,
    Appearance,
    Notifications,
    Messages,
    Utilities,
    Update,
}
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(default)]
struct AppSettings {
    // 1. Cài đặt chung
    show_all_contacts: bool,
    language: String,
    autostart_on_boot: bool,
    remember_login: bool,
    download_dir: String,
    // 2. Quyền riêng tư
    show_birthday: String,
    show_online_status: bool,
    show_seen_status: bool,
    allow_message_from: String,
    block_typing: bool,
    block_delivered: bool,
    block_seen: bool,
    allow_call_from: String,
    allow_search_by_phone: bool,
    friend_src_qr: bool,
    friend_src_group: bool,
    friend_src_card: bool,
    // 3. Giao diện
    theme_mode: String, // "light" | "dark" | "system"
    use_avatar_as_wallpaper: bool,
    // 4. Thông báo
    enable_notifications: bool,
    play_notification_sound: bool,
    // 5. Tin nhắn
    quick_messages_enabled: bool,
    quick_reply_enabled: bool,
    quick_reply_items: Vec<String>,
    #[serde(skip)]
    quick_reply_draft: String,
    hidden_chat_pin_enabled: bool,
    split_priority_inbox: bool,
    excel_paste_mode: String, // "image" | "text" | "ask"
    double_click_to_reply: bool,
    show_typing_indicator: bool,
    send_message_key: String, // "enter" | "cmd_enter"
    // 6. Tiện ích
    suggest_stickers_while_typing: bool,
    suggest_mentions: bool,
    enable_gif_search: bool,
    enable_sticker_keyword_search: bool,
    // 7. Thiết bị cuộc gọi (Mic & Camera)
    selected_mic_device: String,
    selected_camera_device: String,
    mic_gain_percent: u32,
    // 8. Quản lý hội thoại (Context menu: Ghim, Phân loại, Tắt thông báo, Ẩn)
    pinned_threads: Vec<String>,
    muted_threads: HashMap<String, i64>,
    hidden_threads: HashSet<String>,
    thread_labels: HashMap<String, String>,
    // 9. Cập nhật tự động qua GitHub Releases API
    auto_check_updates: bool,
    skipped_update_version: String,
    // 10. Proxy & Đa tài khoản (#64)
    proxy_url: String,
    multi_profile_name: String,
    info_drawer_open: bool,
}

impl Default for AppSettings {
    fn default() -> Self {
        let default_dl = std::env::var("USERPROFILE")
            .ok()
            .map(|p| format!(r"{p}\Downloads\Zalo Received Files"))
            .or_else(|| {
                std::env::var("HOME")
                    .ok()
                    .map(|h| format!("{h}/Downloads/Zalo Received Files"))
            })
            .unwrap_or_else(|| "Downloads/Zalo Received Files".into());
        Self {
            show_all_contacts: false,
            language: "Tiếng Việt".into(),
            autostart_on_boot: true,
            remember_login: true,
            download_dir: default_dl,
            show_birthday: "Không hiện".into(),
            show_online_status: true,
            show_seen_status: true,
            block_typing: false,
            block_delivered: false,
            block_seen: false,
            allow_message_from: "Tất cả mọi người".into(),
            allow_call_from: "Bạn bè và người lạ từng liên hệ".into(),
            allow_search_by_phone: true,
            friend_src_qr: true,
            friend_src_group: true,
            friend_src_card: true,
            theme_mode: "dark".into(),
            use_avatar_as_wallpaper: false,
            enable_notifications: true,
            play_notification_sound: true,
            quick_messages_enabled: true,
            quick_reply_enabled: true,
            quick_reply_items: default_quick_reply_items(),
            quick_reply_draft: String::new(),
            hidden_chat_pin_enabled: true,
            split_priority_inbox: false,
            excel_paste_mode: "ask".into(),
            double_click_to_reply: true,
            show_typing_indicator: true,
            send_message_key: "enter".into(),
            suggest_stickers_while_typing: true,
            suggest_mentions: true,
            enable_gif_search: true,
            enable_sticker_keyword_search: true,
            selected_mic_device: String::new(),
            selected_camera_device: String::new(),
            mic_gain_percent: 100,
            pinned_threads: Vec::new(),
            muted_threads: HashMap::new(),
            hidden_threads: HashSet::new(),
            thread_labels: HashMap::new(),
            auto_check_updates: true,
            skipped_update_version: String::new(),
            proxy_url: String::new(),
            multi_profile_name: "acc2".into(),
            info_drawer_open: false,
        }
    }
}

impl AppSettings {
    fn load() -> Self {
        std::fs::read_to_string("app_settings.json")
            .ok()
            .and_then(|s| serde_json::from_str::<Self>(&s).ok())
            .unwrap_or_default()
    }

    fn save(&self) {
        if let Ok(json) = serde_json::to_string_pretty(self) {
            let _ = std::fs::write("app_settings.json", json);
        }
    }
}

/// A loaded-message jump stays bound to its conversation and exact reference.
struct QuoteJump {
    thread_id: String,
    reference: String,
    highlight_until: std::time::Instant,
    scroll_pending: bool,
}

impl QuoteJump {
    fn target_index(&self, thread_id: &str, messages: &[ChatMessage]) -> Option<usize> {
        if self.thread_id != thread_id || std::time::Instant::now() >= self.highlight_until {
            return None;
        }
        crate::message_navigation::unique_reference_index(messages, &self.reference)
    }
}

/// Bubbles rendered per step in the chat view; "Tải thêm tin nhắn cũ" adds another step.
const CHAT_RENDER_STEP: usize = 150;

/// Worker → GUI channel that wakes the UI on every send. The GUI no longer repaints on a
/// 1.2 s timer, so an event sent without a repaint would sit unseen until the next mouse move.
#[derive(Clone)]
pub struct GuiTx {
    tx: Sender<GuiEvent>,
    ctx: egui::Context,
}

impl GuiTx {
    pub fn new(tx: Sender<GuiEvent>, ctx: egui::Context) -> Self {
        Self { tx, ctx }
    }

    /// Same contract as `Sender::send` (callers already `let _ =` it), plus the wake-up.
    #[allow(clippy::result_large_err)]
    pub fn send(&self, ev: GuiEvent) -> Result<(), std::sync::mpsc::SendError<GuiEvent>> {
        let res = self.tx.send(ev);
        self.ctx.request_repaint();
        res
    }
}

#[derive(Clone)]
pub(crate) struct IncomingPopupState {
    pub(crate) thread_id: String,
    pub(crate) sender_name: String,
    pub(crate) preview_text: String,
    pub(crate) avatar_url: Option<String>,
    pub(crate) is_group: bool,
    pub(crate) unread_total: usize,
    pub(crate) created_at: std::time::Instant,
    pub(crate) reply_draft: String,
}

pub struct ZaloGuiApp {
    // Theme state
    dark_mode: bool,
    theme_dirty: bool,
    // Apply theme on the second frame so the viewport is fully ready (SetTheme cmd is ignored
    // when sent from new() before winit creates the window).
    theme_apply_pending: bool,
    cached_palette: ThemePalette,
    #[cfg(target_os = "windows")]
    win_hwnd: usize,
    #[cfg(target_os = "windows")]
    win_initial_sync_frames: u8,
    #[cfg(target_os = "windows")]
    win_maximized: bool,
    #[cfg(target_os = "windows")]
    win_restore_rect: Option<WinRect>,
    #[cfg(target_os = "windows")]
    win_resize_drag: Option<WinResizeDrag>,

    // Session state
    is_logged_in: bool,
    user_name: String,
    user_uin: String,
    user_avatar: Option<String>,

    // Login screen state
    login_tab: LoginTab,
    phone_input: String,
    password_input: String,
    login_in_progress: bool,
    login_status_msg: String,

    // QR state
    qr_texture: Option<TextureHandle>,
    qr_status: String,

    // Chat screen state
    threads: Vec<Thread>,
    /// Event ledger for reaction counts (see `reactions::ReactionInbox`).
    reaction_inbox: crate::reactions::ReactionInbox,
    selected_thread_index: usize,
    thread_filter: ThreadFilter,
    search_query: String,
    input_message: String,
    status_msg: String,

    // Reply / forward state
    replying_to: Option<ChatMessage>,
    forward_msg: Option<ChatMessage>,
    forward_filter: String,
    /// (thread id, message id) whose reaction list is open.
    reactions_dialog: Option<(String, String)>,
    /// Selected reaction type tab in that dialog (None = all).
    reactions_tab: Option<i32>,
    filter_starred_only: bool,
    pub(crate) send_hd_original: bool,
    pub(crate) typing_map: HashMap<String, (String, std::time::Instant)>,
    pub(crate) last_typing_ping_at: std::time::Instant,
    active_call: Option<ActiveCallOverlay>,
    image_viewer: Option<ImageViewerModal>,

    info_drawer_open: bool,
    profile_menu_open: bool,
    /// "Xoá dữ liệu tin nhắn cục bộ" is pending confirmation (#21).
    wipe_confirm_open: bool,
    toast_notice: Option<(String, std::time::Instant)>,
    /// Rich corner notification popup for incoming messages
    incoming_popup: Option<IncomingPopupState>,
    phone_modal_open: bool,
    phone_modal_input: String,
    phone_lookup_loading: bool,
    phone_lookup_result: Option<crate::chat::PhoneLookupResult>,
    phone_lookup_error: Option<String>,
    in_chat_search_open: bool,
    in_chat_search_query: String,
    in_chat_search_focus_pending: bool,
    // Sticker picker & image cache state
    sticker_picker_open: bool,
    sticker_tab: StickerTab,
    sticker_textures: HashMap<String, TextureHandle>,
    loading_stickers: HashSet<String>,
    emoji_textures: HashMap<String, TextureHandle>,
    app_logo_texture: Option<TextureHandle>,
    sticker_store_packs: Vec<crate::chat::StickerPackInfo>,
    sticker_store_loading: bool,
    sticker_store_filter: String,
    sticker_pack_items: HashMap<u64, Vec<crate::chat::StickerItem>>,
    loading_sticker_packs: HashSet<u64>,
    pinned_sticker_packs: Vec<(u64, String)>,
    sticker_search_query: String,
    sticker_search_results: Vec<crate::chat::StickerItem>,
    sticker_search_loading: bool,
    last_sticker_search_dispatched: String,
    last_sticker_search_edit_at: std::time::Instant,
    sticker_suggest_keywords: HashSet<String>,
    composer_sticker_cache: HashMap<String, Vec<crate::chat::StickerItem>>,
    composer_sticker_loading: HashSet<String>,
    dismissed_sticker_suggest_for: String,
    last_composer_text: String,
    last_composer_edit_at: std::time::Instant,
    composer_sticker_selected: Option<usize>,
    composer_mention_selected: usize,
    dismissed_mention_suggest_for: String,
    composer_focus_pending: bool,
    pending_clipboard_image: Option<(std::path::PathBuf, u32, u32, TextureHandle)>,
    unread_counts: HashMap<String, usize>,
    link_metadata_cache: HashMap<String, crate::chat::LinkMetadata>,
    loading_link_previews: HashSet<String>,
    dismissed_link_preview_for: String,
    friend_status_map: HashMap<String, crate::chat::FriendshipStatus>,
    checking_friend_status: HashSet<String>,
    group_members_map: HashMap<String, Vec<crate::chat::SidebarMember>>,
    fetching_group_members: HashSet<String>,
    group_member_search: String,
    user_online_map: HashMap<String, (bool, String)>,
    allow_quit: bool,
    shutting_down: bool,
    shutdown_requested_at: Option<std::time::Instant>,
    settings_modal_open: bool,
    settings_tab: SettingsTab,
    notification_authorization: crate::native_notifications::AuthorizationState,
    settings: AppSettings,
    update_checking: bool,
    update_downloading: bool,
    update_progress: Option<(u64, u64)>,
    update_status: String,
    update_info: Option<UpdateCheckResult>,
    update_modal_open: bool,
    update_banner_dismissed: bool,
    last_notified_update_version: Option<String>,
    dev_mode: bool,
    dev_panel_open: bool,
    dev_tab: DevTab,
    selected_log: Option<LogEntry>,
    scanner_findings: Vec<ScanFinding>,
    feed_modal_open: bool,
    feed_modal_tab: FeedModalTab,
    feed_target_uid: String,
    feed_loading_profile: bool,
    feed_profile: Option<crate::feed::SocialUserProfile>,
    feed_profile_error: Option<String>,
    feed_loading_avatars: bool,
    feed_avatars: Vec<crate::feed::FeedMedia>,
    feed_avatars_error: Option<String>,
    feed_loading_timeline: bool,
    feed_items: Vec<crate::feed::FeedItem>,
    feed_friend_profiles: Vec<crate::feed::SocialUserProfile>,
    feed_search_query: String,
    feed_pkt_owner_id: String,
    feed_pkt_viewer_id: String,
    feed_pkt_tab: u32,
    feed_pkt_page: u32,
    feed_pkt_count: u32,
    contacts_view_open: bool,
    contacts_sub_tab: ContactsSubTab,
    contacts_search_query: String,
    schedule_modal_open: bool,
    schedule_custom_input: String,
    schedule_editing_id: Option<i64>,
    scheduled_items: Vec<crate::scheduler::ScheduledMessage>,
    phone_sync_progress: f32,
    phone_sync_status: String,
    last_typing_sent_at: Option<(String, std::time::Instant)>,
    last_synced_icon_unread: Option<usize>,

    // Background channels
    event_rx: Receiver<GuiEvent>,
    #[allow(dead_code)]
    event_tx: Sender<GuiEvent>,
    /// (thread id, number of newest bubbles rendered) — see `CHAT_RENDER_STEP`.
    chat_render_window: (String, usize),
    quote_jump: Option<QuoteJump>,
    ime_active: bool,
    ime_just_committed: bool,
    history_reached_start: HashSet<String>,
    force_scroll_to_bottom: bool,
}

#[derive(Debug, PartialEq, Eq)]
enum LoginTab {
    QrCode,
    Password,
}

#[derive(Debug, PartialEq, Eq)]
enum DevTab {
    Logs,
    Scanner,
    CryptoState,
}

/// Every user-visible string in `threads` (names + message bodies), for font coverage checks.
fn thread_texts(threads: &[Thread]) -> impl Iterator<Item = &str> {
    threads.iter().flat_map(|t| {
        std::iter::once(t.name.as_str()).chain(t.messages.iter().map(|m| m.text.as_str()))
    })
}

impl ZaloGuiApp {
    pub fn new(
        cc: &eframe::CreationContext<'_>,
        mut session: Session,
        dev_mode: bool,
        initial_threads: Vec<Thread>,
    ) -> Self {
        setup_custom_fonts(&cc.egui_ctx);
        let mut loaded_settings = AppSettings::load();
        if session.proxy_url.is_none() && !loaded_settings.proxy_url.trim().is_empty() {
            let _ = session.set_proxy(Some(&loaded_settings.proxy_url));
        } else if let Some(ref p) = session.proxy_url {
            if loaded_settings.proxy_url.trim().is_empty() {
                loaded_settings.proxy_url = p.clone();
            }
        }
        crate::media::set_selected_mic_device(&loaded_settings.selected_mic_device);
        crate::media::set_selected_camera_device(&loaded_settings.selected_camera_device);
        crate::media::set_mic_gain_percent(loaded_settings.mic_gain_percent);
        crate::session::set_privacy_blocker(
            loaded_settings.block_typing,
            loaded_settings.block_delivered,
            loaded_settings.block_seen,
        );
        let dark_mode = loaded_settings.theme_mode != "light";
        let initial_palette = ThemePalette::load_with_custom_override(dark_mode);
        initial_palette.apply_to_ctx(&cc.egui_ctx);

        let (tx, rx) = channel();

        // A session the server already refused is not "logged in": jump straight to the
        // login prompt instead of re-testing it (#21).
        let is_logged_in = session.login.is_some() && !session.is_expired_marked();
        let (user_name, user_uin, user_avatar) = session
            .login
            .as_ref()
            .map(|l| {
                (
                    l.display_name.clone(),
                    l.uin.clone(),
                    if l.avatar.is_empty() {
                        None
                    } else {
                        Some(l.avatar.clone())
                    },
                )
            })
            .unwrap_or_default();

        // main() already read threads_cache.json and hydrated it from SQLite; reading, merging,
        // hydrating and rewriting the cache again here doubled startup I/O.
        let mut threads = initial_threads;
        if let Some(li) = session.login.as_ref() {
            if !li.send2me_id.is_empty() {
                for t in threads.iter_mut() {
                    if !t.is_group && t.name.contains("Cloud của tôi") {
                        t.id = li.send2me_id.clone();
                    }
                }
            }
        }
        let now_ts = crate::login::unix_now() as i64;
        for t in threads.iter_mut() {
            if let Some(&until) = loaded_settings.muted_threads.get(&t.id) {
                if until == -1 || until > now_ts {
                    t.presentation.muted = true;
                    t.unread.muted = true;
                    t.unread.muted_until = (until > 0).then_some(until);
                }
            } else if t.unread.is_muted() {
                t.presentation.muted = true;
            }
        }
        crate::chat::deduplicate_threads(&mut threads, None);

        let selected_thread_index = threads
            .iter()
            .enumerate()
            .max_by_key(|(_, t)| t.messages.last().map(|m| m.ts).unwrap_or(0))
            .map(|(idx, _)| idx)
            .unwrap_or(0);

        #[cfg(target_os = "windows")]
        let initial_hwnd = {
            let hwnd = win32_frameless::find_window_hwnd();
            if hwnd != 0 {
                let _ = win32_frameless::sync_frameless_style(hwnd);
            }
            hwnd
        };

        let app = Self {
            dark_mode,
            theme_dirty: false,
            theme_apply_pending: true,
            cached_palette: initial_palette,
            #[cfg(target_os = "windows")]
            win_hwnd: initial_hwnd,
            #[cfg(target_os = "windows")]
            win_initial_sync_frames: 3,
            #[cfg(target_os = "windows")]
            win_maximized: false,
            #[cfg(target_os = "windows")]
            win_restore_rect: None,
            #[cfg(target_os = "windows")]
            win_resize_drag: None,
            is_logged_in,
            user_name,
            user_uin,
            user_avatar,
            login_tab: LoginTab::QrCode,
            phone_input: String::new(),
            password_input: String::new(),
            login_in_progress: false,
            login_status_msg: String::new(),
            qr_texture: None,
            qr_status: "Đang tạo mã QR đăng nhập…".into(),
            threads,
            reaction_inbox: crate::reactions::ReactionInbox::default(),

            selected_thread_index,            thread_filter: ThreadFilter::All,
            search_query: String::new(),
            input_message: String::new(),
            replying_to: None,
            forward_msg: None,
            forward_filter: String::new(),
            reactions_dialog: None,
            reactions_tab: None,
            filter_starred_only: false,
            send_hd_original: true,
            typing_map: HashMap::new(),
            last_typing_ping_at: std::time::Instant::now(),
            active_call: None,
            image_viewer: None,
            status_msg: "Trực tuyến · Sẵn sàng".into(),
            info_drawer_open: loaded_settings.info_drawer_open,
            profile_menu_open: false,
            wipe_confirm_open: false,
            toast_notice: None,
            incoming_popup: None,
            phone_modal_open: false,
            phone_modal_input: String::new(),
            phone_lookup_loading: false,
            phone_lookup_result: None,
            phone_lookup_error: None,
            in_chat_search_open: false,
            in_chat_search_query: String::new(),
            in_chat_search_focus_pending: false,
            sticker_picker_open: false,
            sticker_tab: StickerTab::Popular,
            sticker_textures: HashMap::new(),
            loading_stickers: HashSet::new(),
            emoji_textures: load_default_emoji_textures(&cc.egui_ctx),
            app_logo_texture: load_app_logo_texture(&cc.egui_ctx),
            sticker_store_packs: Vec::new(),
            sticker_store_loading: false,
            sticker_store_filter: String::new(),
            sticker_pack_items: FEATURED_PACK_TABS
                .iter()
                .filter_map(|&(cid, _)| builtin_pack_stickers(cid).map(|items| (cid, items)))
                .collect(),
            loading_sticker_packs: HashSet::new(),
            pinned_sticker_packs: FEATURED_PACK_TABS
                .iter()
                .map(|&(cid, title)| (cid, title.to_string()))
                .collect(),
            sticker_search_query: String::new(),
            sticker_search_results: Vec::new(),
            sticker_search_loading: false,
            last_sticker_search_dispatched: String::new(),
            last_sticker_search_edit_at: std::time::Instant::now(),
            sticker_suggest_keywords: HashSet::new(),
            composer_sticker_cache: HashMap::new(),
            composer_sticker_loading: HashSet::new(),
            dismissed_sticker_suggest_for: String::new(),
            last_composer_text: String::new(),
            last_composer_edit_at: std::time::Instant::now(),
            composer_sticker_selected: None,
            composer_mention_selected: 0,
            dismissed_mention_suggest_for: String::new(),
            composer_focus_pending: false,
            pending_clipboard_image: None,
            unread_counts: HashMap::new(),
            link_metadata_cache: HashMap::new(),
            loading_link_previews: HashSet::new(),
            dismissed_link_preview_for: String::new(),
            friend_status_map: HashMap::new(),
            checking_friend_status: HashSet::new(),
            group_members_map: HashMap::new(),
            fetching_group_members: HashSet::new(),
            group_member_search: String::new(),
            user_online_map: HashMap::new(),
            allow_quit: false,
            shutting_down: false,
            shutdown_requested_at: None,
            settings_modal_open: false,
            settings_tab: SettingsTab::General,
            notification_authorization: Default::default(),
            settings: loaded_settings,
            update_checking: false,
            update_downloading: false,
            update_progress: None,
            update_status: String::new(),
            update_info: None,
            update_modal_open: false,
            update_banner_dismissed: false,
            last_notified_update_version: None,
            dev_mode,
            dev_panel_open: false,
            dev_tab: DevTab::Logs,
            selected_log: None,
            scanner_findings: Vec::new(),
            feed_modal_open: false,
            feed_modal_tab: FeedModalTab::Profile,
            feed_target_uid: String::new(),
            feed_loading_profile: false,
            feed_profile: None,
            feed_profile_error: None,
            feed_loading_avatars: false,
            feed_avatars: Vec::new(),
            feed_avatars_error: None,
            feed_loading_timeline: false,
            feed_items: Vec::new(),
            feed_friend_profiles: Vec::new(),
            feed_search_query: String::new(),
            feed_pkt_owner_id: String::new(),
            feed_pkt_viewer_id: String::new(),
            feed_pkt_tab: 0,
            feed_pkt_page: 1,
            feed_pkt_count: 20,
            contacts_view_open: false,
            contacts_sub_tab: ContactsSubTab::Friends,
            contacts_search_query: String::new(),
            schedule_modal_open: false,
            schedule_custom_input: String::new(),
            schedule_editing_id: None,
            scheduled_items: Vec::new(),
            phone_sync_progress: 0.0,
            phone_sync_status: String::new(),
            last_typing_sent_at: None,
            last_synced_icon_unread: None,
            event_rx: rx,
            event_tx: tx.clone(),
            chat_render_window: (String::new(), CHAT_RENDER_STEP),
            quote_jump: None,
            ime_active: false,
            ime_just_committed: false,
            history_reached_start: HashSet::new(),
            force_scroll_to_bottom: false,
        };
        let mut app = app;
        let _ = app.reload_custom_sticker_packs();

        // Clean up any leftover `.old` executable from a previous in-place self-update
        if let Ok(exe_path) = std::env::current_exe() {
            let old_path = exe_path.with_extension("exe.old");
            let _ = std::fs::remove_file(&old_path);
            let old_unix = exe_path.with_extension("old");
            let _ = std::fs::remove_file(&old_unix);
        }

        app.publish_known_threads();
        spawn_session_worker(
            session,
            GuiTx {
                tx,
                ctx: cc.egui_ctx.clone(),
            },
            cc.egui_ctx.clone(),
        );
        ensure_cjk_font(&cc.egui_ctx, thread_texts(&app.threads));

        if let Some(wtx) = WORKER_TX.get() {
            if is_logged_in {
                let _ = wtx.send(WorkerCmd::RefreshThreads);
            } else {
                let _ = wtx.send(WorkerCmd::RequestQr);
            }
            let _ = wtx.send(WorkerCmd::RefreshScheduledItems);
            let _ = wtx.send(WorkerCmd::CheckForUpdates { silent: true });
        }
        app
    }

    fn palette(&self) -> ThemePalette {
        self.cached_palette
    }

    pub(super) fn any_overlay_modal_open(&self) -> bool {
        self.settings_modal_open
            || self.schedule_modal_open
            || self.phone_modal_open
            || self.update_modal_open
            || self.wipe_confirm_open
            || self.forward_msg.is_some()
            || self.image_viewer.is_some()
    }

    pub(super) fn request_graceful_exit(&mut self, ctx: &egui::Context) {
        if self.shutting_down {
            return;
        }
        self.shutting_down = true;
        self.allow_quit = true;
        self.shutdown_requested_at = Some(std::time::Instant::now());
        self.settings.save();
        if let Some(tx) = WORKER_TX.get() {
            let _ = tx.send(WorkerCmd::PrepareShutdown {
                active_uin: self.user_uin.clone(),
                threads_snapshot: self.threads.clone(),
            });
        } else {
            crate::gui::worker::mark_shutdown_complete();
        }
        ctx.request_repaint();
    }

    pub(super) fn reload_custom_sticker_packs(&mut self) -> usize {
        let packs = load_custom_sticker_packs();
        let count = packs.len();
        for p in packs {
            if !self
                .pinned_sticker_packs
                .iter()
                .any(|(cid, _)| *cid == p.cate_id)
            {
                self.pinned_sticker_packs.push((p.cate_id, p.name.clone()));
            }
            if let Some(items) = builtin_pack_stickers(p.cate_id) {
                self.sticker_pack_items.insert(p.cate_id, items);
            }
        }
        count
    }

    pub(super) fn refresh_scheduled_items(&mut self) {
        if let Some(tx) = WORKER_TX.get() {
            let _ = tx.send(WorkerCmd::RefreshScheduledItems);
        }
    }

    /// Hand the worker's poll timer the thread ids/names it maps incoming messages onto.
    fn publish_known_threads(&self) {
        if let Ok(mut known) = KNOWN_THREADS.lock() {
            *known = self
                .threads
                .iter()
                .map(|t| (t.id.clone(), t.name.clone(), t.is_group))
                .collect();
        }
    }

    /// Re-read the pinned board of the open thread, throttled.
    ///
    /// Parked for now: `friendboard/list` rejects the request shapes we can build (error 114), so
    /// polling only produced a toast on every thread switch. The read-back will come from the
    /// socket control events (`pin_message` / `unpin_topic`) instead.
    fn maybe_refresh_board_pins(&mut self) {}

    fn persist_threads_async(&self) {
        self.publish_known_threads();
        let snapshot = self.threads.clone();
        if let Some(wtx) = WORKER_TX.get() {
            let _ = wtx.send(WorkerCmd::PersistThreads(snapshot));
        }
    }

    fn check_events(&mut self, ctx: &egui::Context) {
        while let Ok(event) = self.event_rx.try_recv() {
            match event {
                GuiEvent::NotificationAuthorization { request_id, result } => {
                    self.notification_authorization.finish(request_id, result);
                }
                GuiEvent::QrReady { qr_image, .. } => {
                    self.qr_texture =
                        Some(ctx.load_texture("qr_code_tex", qr_image, TextureOptions::NEAREST));
                    self.qr_status = "Mở ứng dụng Zalo trên điện thoại và quét mã QR".into();
                    self.login_in_progress = false;
                }
                GuiEvent::QrScanned { name } => {
                    self.qr_status =
                        format!("Đã quét bởi {name} — Vui lòng bấm 'Đăng nhập' trên điện thoại…");
                }
                GuiEvent::LoginSuccess { name, uin, avatar } => {
                    // On session refresh under the same account, keep thread list & unread counts.
                    // Clearing + re-fetching counts all existing history as brand-new unread (#119).
                    let is_refresh = self.is_logged_in;
                    self.is_logged_in = true;
                    self.user_name = name;
                    self.user_uin = uin;
                    if avatar.is_some() {
                        self.user_avatar = avatar;
                    }
                    if !is_refresh {
                        self.threads.clear();
                        self.unread_counts.clear();
                        self.history_reached_start.clear();
                        self.selected_thread_index = 0;
                    }
                    self.login_in_progress = false;
                    self.composer_sticker_cache.retain(|_, v| !v.is_empty());
                    self.status_msg = "Trực tuyến · Đồng bộ thời gian thực".into();
                }
                GuiEvent::LoginFailed(err) => {
                    self.login_in_progress = false;
                    self.login_status_msg = format!("Lỗi đăng nhập: {err}");
                }
                GuiEvent::ThreadsUpdated(updates) => {
                    ensure_cjk_font(ctx, thread_texts(&updates));
                    if self.is_logged_in && !updates.is_empty() {
                        let prev_selected = self.threads.get(self.selected_thread_index).cloned();
                        let live_ids: HashSet<String> = self
                            .threads
                            .iter()
                            .chain(updates.iter())
                            .filter(|u| !u.id.is_empty() && u.id != "0")
                            .map(|u| u.id.clone())
                            .collect();
                        let update_ids: HashSet<String> = updates
                            .iter()
                            .filter(|u| !u.id.is_empty() && u.id != "0")
                            .map(|u| u.id.clone())
                            .collect();

                        let active_tid = prev_selected
                            .as_ref()
                            .map(|t| t.id.clone())
                            .unwrap_or_default();
                        let is_focused = ctx.input(|i| i.focused);
                        let mut new_incoming_alert = false;

                        let now_ts = crate::login::unix_now() as i64;
                        for mut nt in updates {
                            let settings_muted_until = self
                                .settings
                                .muted_threads
                                .get(&nt.id)
                                .copied()
                                .filter(|&u| u == -1 || u > now_ts);
                            if let Some(until) = settings_muted_until {
                                nt.presentation.muted = true;
                                nt.unread.muted = true;
                                nt.unread.muted_until = (until > 0).then_some(until);
                            } else if nt.unread.is_muted() {
                                nt.presentation.muted = true;
                            }
                            if let Some(existing) = self.threads.iter_mut().find(|t| t.id == nt.id)
                            {
                                let is_thread_muted = settings_muted_until.is_some()
                                    || existing.presentation.muted
                                    || existing.unread.is_muted()
                                    || nt.presentation.muted
                                    || nt.unread.is_muted();
                                let old_len = existing.messages.len();
                                crate::chat::merge_thread_into(existing, nt, true);
                                if is_thread_muted {
                                    existing.presentation.muted = true;
                                    existing.unread.muted = true;
                                    if let Some(until) = settings_muted_until {
                                        existing.unread.muted_until = (until > 0).then_some(until);
                                    }
                                }
                                let added = existing.messages.len().saturating_sub(old_len);
                                if added > 0 {
                                    let seen = existing.unread.last_seen_id.as_deref().unwrap_or("");
                                    let inc_cnt = existing
                                        .messages
                                        .iter()
                                        .rev()
                                        .take(added)
                                        .filter(|m| {
                                            if m.is_outgoing {
                                                return false;
                                            }
                                            if seen.is_empty() {
                                                return true;
                                            }
                                            matches!(
                                                crate::unread::compare_ids(&m.id, seen),
                                                Some(std::cmp::Ordering::Greater) | None
                                            )
                                        })
                                        .count();
                                    if inc_cnt > 0 {
                                        if !is_thread_muted {
                                            new_incoming_alert = true;
                                        }
                                        if existing.id != active_tid || !is_focused {
                                            *self
                                                .unread_counts
                                                .entry(existing.id.clone())
                                                .or_insert(0) += inc_cnt;
                                            if !is_thread_muted {
                                                if let Some(last_inc) = existing
                                                    .messages
                                                    .iter()
                                                    .rev()
                                                    .take(added)
                                                    .find(|m| !m.is_outgoing)
                                                {
                                                    let sender_label = if existing.is_group
                                                        && !last_inc.sender.is_empty()
                                                    {
                                                        format!(
                                                            "{} · {}",
                                                            last_inc.sender, existing.name
                                                        )
                                                    } else {
                                                        existing.name.clone()
                                                    };
                                                    let preview_raw = last_inc.text.trim();
                                                    let preview_short: String =
                                                        if preview_raw.chars().count() > 96 {
                                                            let s: String = preview_raw
                                                                .chars()
                                                                .take(96)
                                                                .collect();
                                                            format!("{s}…")
                                                        } else if preview_raw.is_empty() {
                                                            "[ Đính kèm / Nhãn dán ]".to_string()
                                                        } else {
                                                            preview_raw.to_string()
                                                        };
                                                    let avt_url = existing
                                                        .avatar
                                                        .clone()
                                                        .filter(|u| !u.trim().is_empty());
                                                    if let Some(ref url) = avt_url {
                                                        let tex_key = format!(
                                                            "thumb_{}",
                                                            crate::crypto::md5_hex(url)
                                                        );
                                                        if !self
                                                            .sticker_textures
                                                            .contains_key(&tex_key)
                                                            && !self
                                                                .loading_stickers
                                                                .contains(&tex_key)
                                                        {
                                                            self.loading_stickers
                                                                .insert(tex_key.clone());
                                                            if let Some(tx) = WORKER_TX.get() {
                                                                let _ = tx.send(
                                                                    WorkerCmd::FetchStickerImage {
                                                                        key: tex_key,
                                                                        url: url.clone(),
                                                                    },
                                                                );
                                                            }
                                                        }
                                                    }
                                                    let unread_for_thread = self
                                                        .unread_counts
                                                        .get(&existing.id)
                                                        .copied()
                                                        .unwrap_or(1);
                                                    self.incoming_popup =
                                                        Some(IncomingPopupState {
                                                            thread_id: existing.id.clone(),
                                                            sender_name: sender_label,
                                                            preview_text: preview_short,
                                                            avatar_url: avt_url,
                                                            is_group: existing.is_group,
                                                            unread_total: unread_for_thread,
                                                            created_at: std::time::Instant::now(),
                                                            reply_draft: String::new(),
                                                        });
                                                }
                                            }
                                        }
                                    }
                                    if existing.id == self.chat_render_window.0 {
                                        self.chat_render_window.1 += added;
                                        self.show_toast(format!("Đã tải thêm {added} tin nhắn cũ"));
                                    }
                                }
                            } else if let Some(existing) = self.threads.iter_mut().find(|t| {
                                !update_ids.contains(&t.id)
                                    && crate::chat::threads_represent_same_contact(t, &nt)
                            }) {
                                crate::chat::merge_thread_into(existing, nt, true);
                            } else if !nt.id.is_empty() && nt.id != "0" {
                                // Brand-new thread: only count incoming messages newer than the
                                // persisted read-point (#119). Without this, reopening the app
                                // counts the entire loaded history of every thread as unread.
                                let seen = nt.unread.last_seen_id.as_deref().unwrap_or("");
                                let inc_cnt = nt
                                    .messages
                                    .iter()
                                    .filter(|m| {
                                        if m.is_outgoing {
                                            return false;
                                        }
                                        if seen.is_empty() {
                                            return true;
                                        }
                                        matches!(
                                            crate::unread::compare_ids(&m.id, seen),
                                            Some(std::cmp::Ordering::Greater) | None
                                        )
                                    })
                                    .count();
                                if inc_cnt > 0 {
                                    self.unread_counts.insert(nt.id.clone(), inc_cnt);
                                }
                                self.threads.push(nt);
                            }
                        }

                        if new_incoming_alert && self.settings.enable_notifications {
                            if self.settings.play_notification_sound {
                                crate::media::play_notification_chime();
                            }
                            let total_unread: usize = self.unread_counts.values().sum();
                            let title = if total_unread > 0 {
                                format!("({total_unread}) ctdozlite")
                            } else {
                                "ctdozlite".to_string()
                            };
                            ctx.send_viewport_cmd(egui::ViewportCommand::Title(title));
                            if !is_focused {
                                ctx.send_viewport_cmd(egui::ViewportCommand::RequestUserAttention(
                                    egui::UserAttentionType::Informational,
                                ));
                            }
                        }
                        crate::chat::deduplicate_threads(&mut self.threads, Some(&live_ids));

                        // Restore selected thread by exact `id` first so contacts sharing the
                        // same Zalo display name never jump to each other's chat window (#63).
                        if let Some(prev) = prev_selected {
                            if let Some(idx) = self.threads.iter().position(|t| t.id == prev.id) {
                                self.selected_thread_index = idx;
                            } else if let Some(idx) = self
                                .threads
                                .iter()
                                .position(|t| crate::chat::threads_represent_same_contact(t, &prev))
                            {
                                self.selected_thread_index = idx;
                            }
                        }
                        if self.selected_thread_index >= self.threads.len() {
                            self.selected_thread_index = self.threads.len().saturating_sub(1);
                        }
                        // A merge may bring a stale history total; the event ledger is authoritative.
                        if !self.reaction_inbox.is_empty() {
                            for t in self.threads.iter_mut() {
                                self.reaction_inbox.apply_to(&mut t.messages);
                            }
                        }
                        self.persist_threads_async();
                        // A pin/unpin from another device arrives only as an event message, so the
                        // board has to be re-read before the banner/chips can match the server.
                        self.maybe_refresh_board_pins();
                    }
                    self.status_msg = format!("Trực tuyến · Cập nhật {}", crate::ui::clock());
                }
                GuiEvent::SessionExpired(reason) => {
                    self.is_logged_in = false;
                    self.qr_texture = None;
                    self.qr_status =
                        format!("{reason} — Quét mã QR bên dưới để khôi phục phiên trực tuyến.");
                    self.status_msg = format!("{reason} (Lịch sử tin nhắn vẫn được bảo toàn)");
                }
                GuiEvent::SessionUnreachable(reason) => {
                    // Only the network failed: stay logged in, keep the thread list, and
                    // let the next poll retry (#21).
                    self.status_msg = format!("{} {reason} — đang thử lại…", lucide::ALERT_TRIANGLE);
                }
                GuiEvent::LocalDataWiped => {
                    self.threads.clear();
                    self.selected_thread_index = 0;
                    self.status_msg = "Đã xoá dữ liệu tin nhắn cục bộ (session giữ nguyên)".into();
                }
                GuiEvent::LoggedOut => {
                    self.is_logged_in = false;
                    self.user_name.clear();
                    self.user_uin.clear();
                    self.threads.clear();
                    self.selected_thread_index = 0;
                    self.qr_texture = None;
                    self.qr_status = "Đang xin mã QR mới…".into();
                    self.status_msg = "Đã đăng xuất".into();
                }
                GuiEvent::AccountSwitched {
                    uin,
                    name,
                    avatar,
                    threads,
                } => {
                    self.is_logged_in = true;
                    self.user_uin = uin;
                    self.user_name = name.clone();
                    self.user_avatar = avatar;
                    self.threads = threads;
                    self.selected_thread_index = 0;
                    self.status_msg = format!("Đã chuyển sang tài khoản {name}");
                    self.show_toast(format!("Đã chuyển sang tài khoản {name}"));
                    self.history_reached_start.clear();
                }
                GuiEvent::MessageSent {
                    client_message_id,
                    thread_id,
                    text,
                    msg_id,
                } => {
                    if let Some(t) = self.threads.iter_mut().find(|t| t.id == thread_id) {
                        t.preview = text.clone();
                        let now = crate::ui::clock();
                        t.time = now.clone();
                        let final_id = if msg_id.is_empty() {
                            format!("out_{client_message_id}")
                        } else {
                            msg_id
                        };
                        merge_sent_message(
                            t,
                            ChatMessage {
                                id: final_id,
                                client_message_id,
                                sender: "Tôi".into(),
                                text,
                                time: now,
                                is_outgoing: true,
                                ts: (crate::login::unix_now() * 1000) as i64,
                                ..Default::default()
                            },
                        );
                        self.persist_threads_async();
                    }
                    self.status_msg = format!("Đã gửi tin nhắn lúc {}", crate::ui::clock());
                }
                GuiEvent::StickerSent {
                    client_message_id,
                    thread_id,
                    msg_id,
                    sticker_id,
                    cate_id,
                    sticker_type,
                } => {
                    if let Some(t) = self.threads.iter_mut().find(|t| t.id == thread_id) {
                        t.preview = "[Nhãn dán]".into();
                        let now = crate::ui::clock();
                        t.time = now.clone();
                        let final_id = if msg_id.is_empty() {
                            format!("out_{client_message_id}")
                        } else {
                            msg_id
                        };
                        merge_sent_message(
                            t,
                            ChatMessage {
                                id: final_id,
                                client_message_id,
                                sender: "Tôi".into(),
                                text: "[Nhãn dán]".into(),
                                time: now,
                                is_outgoing: true,
                                ts: (crate::login::unix_now() * 1000) as i64,
                                sticker_id: Some(sticker_id),
                                sticker_cate_id: Some(cate_id),
                                sticker_type: Some(sticker_type),
                                ..Default::default()
                            },
                        );
                        self.persist_threads_async();
                    }
                    self.status_msg = format!("Đã gửi nhãn dán lúc {}", crate::ui::clock());
                }
                GuiEvent::AttachmentSent { thread_id, msg } => {
                    if let Some(t) = self.threads.iter_mut().find(|t| t.id == thread_id) {
                        t.preview = msg.text.clone();
                        t.time = msg.time.clone();
                        merge_sent_message(t, msg);
                        self.persist_threads_async();
                    }
                    self.status_msg = format!("Đã gửi đính kèm lúc {}", crate::ui::clock());
                }
                GuiEvent::QuoteSent {
                    client_message_id,
                    thread_id,
                    text,
                    msg_id,
                    quoted,
                } => {
                    if let Some(t) = self.threads.iter_mut().find(|t| t.id == thread_id) {
                        t.preview = text.clone();
                        let now = crate::ui::clock();
                        t.time = now.clone();
                        let final_id = if msg_id.is_empty() {
                            format!("out_{client_message_id}")
                        } else {
                            msg_id
                        };
                        merge_sent_message(
                            t,
                            ChatMessage {
                                id: final_id,
                                client_message_id,
                                sender: "Tôi".into(),
                                text,
                                time: now,
                                is_outgoing: true,
                                ts: (crate::login::unix_now() * 1000) as i64,
                                reply_to_id: Some(quoted.id.clone()),
                                reply_to_sender: Some(quoted.sender.clone()),
                                reply_to_text: Some(quoted.text.clone()),
                                ..Default::default()
                            },
                        );
                        self.persist_threads_async();
                    }
                    self.status_msg = format!("Đã gửi trả lời lúc {}", crate::ui::clock());
                }
                GuiEvent::Reacted { .. } => {
                    // Counts come only from the `chat.reaction` echo (ReactionEventsReceived);
                    // adding here as well double-counted every click.
                    self.status_msg = "Đã thả cảm xúc".into();
                }
                GuiEvent::ReactionEventsReceived(events) => {
                    let total = events.len();
                    let pending_before = self.reaction_inbox.pending_len();
                    self.reaction_inbox.record(&events);
                    let mut changed = false;
                    for t in self.threads.iter_mut() {
                        changed |= self.reaction_inbox.apply_to(&mut t.messages);
                    }
                    crate::reactions::trace_batch(
                        total,
                        total.saturating_sub(
                            self.reaction_inbox
                                .pending_len()
                                .saturating_sub(pending_before),
                        ),
                        usize::from(changed),
                        &[],
                    );
                    if changed {
                        self.persist_threads_async();
                    }
                }
                GuiEvent::MessageDeleted {
                    thread_id,
                    msg_id,
                    ts,
                } => {
                    if let Some(t) = self.threads.iter_mut().find(|t| t.id == thread_id) {
                        t.messages.retain(|m| {
                            !((!msg_id.is_empty() && m.id == msg_id)
                                || (msg_id.is_empty() && m.ts == ts))
                        });
                        if let Some(last) = t.messages.last() {
                            t.preview = last.text.clone();
                        }
                        self.persist_threads_async();
                    }
                    self.status_msg = "Đã xóa tin nhắn ở phía bạn".into();
                }
                GuiEvent::MessageRecalled {
                    thread_id,
                    msg_id,
                    ts,
                } => {
                    if let Some(t) = self.threads.iter_mut().find(|t| t.id == thread_id) {
                        if let Some(m) = t.messages.iter_mut().find(|m| {
                            (!msg_id.is_empty() && m.id == msg_id)
                                || (msg_id.is_empty() && m.ts == ts)
                        }) {
                            if !m.text.starts_with("[Đã thu hồi]") {
                                if m.text.trim().is_empty() {
                                    m.text = "[Tin nhắn đã thu hồi]".into();
                                } else {
                                    m.text = format!("[Đã thu hồi] {}", m.text);
                                }
                            }
                            // Anti-recall: Preserve sticker_id, link_url, link_thumb so user can still see media!
                        }
                        if let Some(last) = t.messages.last() {
                            t.preview = last.text.clone();
                        }
                        self.persist_threads_async();
                    }
                    self.status_msg = "Có tin nhắn vừa bị thu hồi (đã lưu lại)".into();
                }
                GuiEvent::ForwardFinished { target_name, error } => match error {
                    None => {
                        self.show_toast(format!("Đã chuyển tiếp tới {target_name}"));
                        self.status_msg = format!("Đã chuyển tiếp tới {target_name}");
                    }
                    Some(err) => {
                        self.show_toast(format!("Chuyển tiếp tới {target_name} thất bại: {err}"));
                        self.status_msg = format!("Chuyển tiếp thất bại: {err}");
                    }
                },
                GuiEvent::ScreenshotCaptured {
                    path,
                    width,
                    height,
                    image,
                } => {
                    let tex = ctx.load_texture(
                        format!("clip_preview_{}", crate::login::unix_now()),
                        image,
                        TextureOptions::LINEAR,
                    );
                    self.pending_clipboard_image = Some((path, width, height, tex));
                    self.composer_focus_pending = true;
                    self.show_toast(format!(
                        "Đã chụp ảnh màn hình ({width}×{height} px) — nhấn Enter để gửi"
                    ));
                    self.status_msg = format!("Đã chụp ảnh màn hình ({width}×{height} px)");
                }
                GuiEvent::TypingEventsReceived(evs) => {
                    for ev in evs {
                        if ev.is_typing {
                            let name = if let Some(t) =
                                self.threads.iter().find(|t| t.id == ev.thread_id)
                            {
                                if t.is_group {
                                    self.group_members_map
                                        .get(&t.id)
                                        .and_then(|members| members.iter().find(|m| m.id == ev.uid))
                                        .map(|m| m.name.clone())
                                        .unwrap_or_else(|| {
                                            if ev.uid.is_empty() {
                                                "Thành viên".to_string()
                                            } else {
                                                format!("Người dùng {}", ev.uid)
                                            }
                                        })
                                } else {
                                    t.name.clone()
                                }
                            } else {
                                "Đối phương".to_string()
                            };
                            self.typing_map.insert(
                                ev.thread_id,
                                (
                                    name,
                                    std::time::Instant::now() + std::time::Duration::from_secs(6),
                                ),
                            );
                        } else {
                            self.typing_map.remove(&ev.thread_id);
                        }
                    }
                    ctx.request_repaint();
                }
                GuiEvent::SeenEventsReceived(evs) => {
                    for ev in evs {
                        if let Some(t) = self.threads.iter_mut().find(|t| t.id == ev.thread_id) {
                            for m in t.messages.iter_mut().filter(|m| m.is_outgoing) {
                                if ev.seen_ts == 0 || m.ts <= ev.seen_ts * 1000 + 5000 {
                                    m.delivery = crate::message_model::DeliveryState::Read;
                                }
                            }
                        }
                    }
                    ctx.request_repaint();
                }
                GuiEvent::StickerImageReady { key, image } => {
                    self.loading_stickers.remove(&key);
                    let tex = ctx.load_texture(&key, image, TextureOptions::LINEAR);
                    self.sticker_textures.insert(key, tex);
                }
                GuiEvent::StickerImageFailed { key } => {
                    if key.starts_with("call_remote_video") {
                        self.sticker_textures.remove(&key);
                        ctx.request_repaint();
                    }
                    self.loading_stickers.remove(&key);
                }
                GuiEvent::StickerStoreLoaded(packs) => {
                    self.sticker_store_loading = false;
                    let count = packs.len();
                    self.sticker_store_packs = packs;
                    self.status_msg = format!("Đã tải Kho Nhãn Dán Zalo ({count} bộ nhãn)");
                }
                GuiEvent::StickerPackItemsLoaded {
                    cate_id,
                    name,
                    items,
                } => {
                    self.loading_sticker_packs.remove(&cate_id);
                    let count = items.len();
                    if !self
                        .pinned_sticker_packs
                        .iter()
                        .any(|(id, _)| *id == cate_id)
                    {
                        self.pinned_sticker_packs.insert(0, (cate_id, name.clone()));
                    }
                    self.sticker_pack_items.insert(cate_id, items);
                    self.status_msg = format!("Đã mở bộ nhãn \"{name}\" ({count} nhãn dán)");
                }
                GuiEvent::StickerSearchResults { keyword, items } => {
                    self.sticker_search_loading = false;
                    let count = items.len();
                    self.sticker_search_results = items;
                    self.status_msg =
                        format!("Tìm thấy {count} nhãn dán cho từ khóa \"{keyword}\"");
                }
                GuiEvent::StickerSuggestKeywordsLoaded(kws) => {
                    for k in kws {
                        self.sticker_suggest_keywords.insert(k);
                    }
                }
                GuiEvent::ComposerStickerSuggestions { keyword, items } => {
                    self.composer_sticker_loading.remove(&keyword);
                    self.composer_sticker_cache.insert(keyword, items);
                }
                GuiEvent::LinkPreviewReady(meta) => {
                    self.loading_link_previews.remove(&meta.url);
                    if !meta.thumb.is_empty() {
                        let key = format!("thumb_{}", crate::crypto::md5_hex(&meta.thumb));
                        if !self.sticker_textures.contains_key(&key)
                            && self.loading_stickers.insert(key.clone())
                        {
                            if let Some(tx) = WORKER_TX.get() {
                                let _ = tx.send(WorkerCmd::FetchStickerImage {
                                    key,
                                    url: meta.thumb.clone(),
                                });
                            }
                        }
                    }
                    let mut updated_any = false;
                    for t in &mut self.threads {
                        for m in &mut t.messages {
                            let matches_url = m.link_url.as_deref() == Some(meta.url.as_str())
                                || crate::chat::extract_first_url(&m.text).as_deref()
                                    == Some(meta.url.as_str());
                            if matches_url {
                                if m.link_url.is_none() {
                                    m.link_url = Some(meta.url.clone());
                                    updated_any = true;
                                }
                                if (m.link_title.is_none()
                                    || m.link_title.as_deref() == Some(meta.url.as_str()))
                                    && !meta.title.is_empty()
                                {
                                    m.link_title = Some(meta.title.clone());
                                    updated_any = true;
                                }
                                if m.link_desc.is_none() && !meta.desc.is_empty() {
                                    m.link_desc = Some(meta.desc.clone());
                                    updated_any = true;
                                }
                                let old_thumb_expired = m
                                    .link_thumb
                                    .as_deref()
                                    .map(|th| {
                                        th.is_empty()
                                            || (th.contains("zpcloud.zdn.vn")
                                                && !self.sticker_textures.contains_key(&format!(
                                                    "thumb_{}",
                                                    crate::crypto::md5_hex(th)
                                                )))
                                    })
                                    .unwrap_or(true);
                                if old_thumb_expired && !meta.thumb.is_empty() {
                                    m.link_thumb = Some(meta.thumb.clone());
                                    updated_any = true;
                                }
                                if m.link_src.is_none() && !meta.src.is_empty() {
                                    m.link_src = Some(meta.src.clone());
                                    updated_any = true;
                                }
                            }
                        }
                    }
                    self.link_metadata_cache.insert(meta.url.clone(), meta);
                    if updated_any {
                        self.persist_threads_async();
                    }
                }
                GuiEvent::GroupMembersLoaded { group_id, members } => {
                    self.fetching_group_members.remove(&group_id);
                    for m in &members {
                        if let Some(ref ava_url) = m.avatar {
                            if ava_url.starts_with("http") {
                                let file_or_base =
                                    crate::chat::avatar_file_key(Some(ava_url.as_str()))
                                        .unwrap_or_else(|| {
                                            ava_url.split('?').next().unwrap_or(ava_url).to_string()
                                        });
                                let key = format!("ava_{}", crate::crypto::md5_hex(&file_or_base));
                                if !self.sticker_textures.contains_key(&key)
                                    && self.loading_stickers.insert(key.clone())
                                {
                                    if let Some(tx) = WORKER_TX.get() {
                                        let _ = tx.send(WorkerCmd::FetchStickerImage {
                                            key,
                                            url: ava_url.clone(),
                                        });
                                    }
                                }
                            }
                        }
                    }
                    if let Some(t) = self.threads.iter_mut().find(|th| th.id == group_id) {
                        t.presentation.members = members.clone();
                        t.presentation.member_count = Some(members.len() as u64);
                    }
                    self.group_members_map.insert(group_id, members);
                }
                GuiEvent::FriendStatusChecked {
                    user_id,
                    status,
                    online,
                } => {
                    self.checking_friend_status.remove(&user_id);
                    self.friend_status_map.insert(user_id.clone(), status);
                    if let Some(onl) = online {
                        self.user_online_map.insert(user_id.clone(), onl);
                    }
                    if let Some(ref mut prof) = self.phone_lookup_result {
                        if prof.user_id == user_id {
                            prof.friendship = status;
                        }
                    }
                }
                GuiEvent::PhoneLookupSuccess(res) => {
                    self.phone_lookup_loading = false;
                    self.phone_lookup_error = None;
                    self.phone_modal_open = true;
                    self.show_toast(format!("Đã tìm thấy tài khoản: {}", res.display_name));
                    self.friend_status_map
                        .insert(res.user_id.clone(), res.friendship);
                    self.phone_lookup_result = Some(res);
                }
                GuiEvent::PhoneLookupFailed(err) => {
                    self.phone_lookup_loading = false;
                    self.phone_lookup_result = None;
                    self.phone_modal_open = true;
                    self.phone_lookup_error = Some(err);
                }
                GuiEvent::SendFailed {
                    thread_id: _,
                    text,
                    error,
                } => {
                    if self.input_message.is_empty() && !text.is_empty() {
                        self.input_message = text;
                    }
                    self.status_msg = format!("Không gửi được: {error}");
                }
                GuiEvent::CallStateChanged(state) => {
                    if state == "free" {
                        // Keep modal open if there is a rejection reason so the user can read it
                        let has_error = self
                            .active_call
                            .as_ref()
                            .and_then(|c| c.error_reason.as_ref())
                            .is_some();
                        self.sticker_textures.remove("call_remote_video");
                        self.sticker_textures.remove("call_remote_video_1");
                        self.sticker_textures.remove("call_remote_video_2");
                        self.sticker_textures.remove("call_remote_video_3");
                        self.sticker_textures.remove("call_remote_video_4");
                        self.sticker_textures.remove("call_remote_video_5");
                        self.sticker_textures.remove("call_local_video");
                        if !has_error {
                            self.active_call = None;
                        }
                    } else if let Some(ref mut call) = self.active_call {
                        if state == "incall" || state == "connected" {
                            call.is_incoming_ringing = false;
                        }
                        if call.error_reason.is_none() {
                            call.state_label = match state.as_str() {
                                "calling" | "ringing" => "Đang đổ chuông…".into(),
                                "incoming_ringing" => "Cuộc gọi đến đang đổ chuông…".into(),
                                "connecting" => "Đang kết nối luồng âm thanh/video…".into(),
                                "incall" | "connected" => {
                                    "Đang trong cuộc gọi (Pure-Rust VoIP)".into()
                                }
                                _ => format!("Đang kết nối ({state})…"),
                            };
                        }
                    }
                }
                GuiEvent::IncomingCall {
                    call_id: _,
                    caller_id,
                    caller_name,
                    is_video,
                    is_group,
                } => {
                    let resolved_name = self
                        .threads
                        .iter()
                        .find(|t| t.id == caller_id)
                        .map(|t| t.name.clone())
                        .unwrap_or(caller_name);
                    self.status_msg = format!(
                        "{} Cuộc gọi {} đến từ {resolved_name}…",
                        lucide::PHONE_INCOMING,
                        if is_video { "video" } else { "thoại" }
                    );
                    self.active_call = Some(ActiveCallOverlay {
                        partner_id: caller_id,
                        partner_name: resolved_name,
                        is_video,
                        is_group,
                        state_label: "Cuộc gọi đến đang đổ chuông…".into(),
                        started_at: std::time::Instant::now(),
                        mic_muted: false,
                        cam_enabled: is_video,
                        is_incoming_ringing: true,
                        error_code: None,
                        error_reason: None,
                        speaker_view: false,
                        pinned_tile_idx: 0,
                        call_page: 0,
                        members_popover_open: false,
                        invite_search_query: String::new(),
                        quick_reply_popover_open: false,
                    });
                    ctx.send_viewport_cmd(egui::ViewportCommand::RequestUserAttention(
                        egui::UserAttentionType::Critical,
                    ));
                }
                GuiEvent::CallRejected { code, reason } => {
                    self.status_msg = format!(
                        "{} Từ chối cuộc gọi (mã {code}): {reason}",
                        lucide::ALERT_TRIANGLE
                    );
                    if let Some(ref mut call) = self.active_call {
                        call.state_label = "Không thể thực hiện cuộc gọi".into();
                        call.error_code = Some(code);
                        call.error_reason = Some(reason);
                    }
                }
                GuiEvent::StatusUpdate(msg) => {
                    self.status_msg = msg;
                }
                GuiEvent::HistoryReachedStart(tid) => {
                    self.history_reached_start.insert(tid);
                    self.show_toast("Đã hiển thị toàn bộ lịch sử tin nhắn của cuộc trò chuyện này");
                }
                GuiEvent::RefreshFinished {
                    threads,
                    messages,
                    errors,
                    manual,
                } => {
                    let msg = if errors.is_empty() {
                        format!(
                            "{} Đã làm mới {threads} hội thoại ({messages} tin nhắn)",
                            lucide::CHECK_CIRCLE
                        )
                    } else {
                        format!(
                            "{} Làm mới {threads} hội thoại · {} lỗi (vd. {})",
                            lucide::ALERT_TRIANGLE,
                            errors.len(),
                            errors[0]
                        )
                    };
                    self.status_msg = msg.clone();
                    if manual {
                        self.show_toast(msg);
                    }
                }
                GuiEvent::ScheduledListUpdated(items) => {
                    let prev_cnt = self.scheduled_items.len();
                    self.scheduled_items = items;
                    if self.scheduled_items.len() < prev_cnt {
                        if self.settings.enable_notifications
                            && self.settings.play_notification_sound
                        {
                            crate::media::play_notification_chime();
                        }
                        self.show_toast(format!(
                            "{} Đã gửi tự động tin nhắn hẹn giờ / nhắc hẹn",
                            lucide::ALARM_CLOCK
                        ));
                    }
                }
                GuiEvent::ScheduledItemsLoaded(items) => {
                    self.scheduled_items = items;
                }
                GuiEvent::ScheduleActionResult {
                    ok,
                    message,
                    clear_composer,
                } => {
                    if clear_composer {
                        self.input_message.clear();
                    }
                    if let Some(msg) = message {
                        let icon = if ok {
                            lucide::CHECK_CIRCLE
                        } else {
                            lucide::ALERT_TRIANGLE
                        };
                        self.show_toast(format!("{icon} {msg}"));
                    }
                }
                GuiEvent::HistoryImported(res) => match res {
                    Ok((t_cnt, m_cnt, refreshed_threads)) => {
                        for nt in refreshed_threads {
                            if let Some(existing) = self.threads.iter_mut().find(|t| t.id == nt.id)
                            {
                                crate::chat::merge_thread_into(existing, nt, false);
                            } else if !nt.id.is_empty() {
                                self.threads.push(nt);
                            }
                        }
                        self.persist_threads_async();
                        self.show_toast(format!(
                            "{} Đã nhập {m_cnt} tin nhắn từ {t_cnt} hội thoại vào kho dữ liệu cục bộ",
                            lucide::CHECK_CIRCLE
                        ));
                    }
                    Err(e) => {
                        self.show_toast(format!(
                            "{} Lỗi nhập lịch sử: {e}",
                            lucide::ALERT_TRIANGLE
                        ));
                    }
                },
                GuiEvent::SyncFinished {
                    added,
                    errors,
                    cancelled,
                } => {
                    let head = if cancelled {
                        "Đã dừng đồng bộ"
                    } else {
                        "Đồng bộ xong"
                    };
                    let mut msg = format!("{head}: lưu thêm {added} tin cũ");
                    if let Some(first) = errors.first() {
                        msg.push_str(&format!(" · {} lỗi (vd. {first})", errors.len()));
                    }
                    self.status_msg = msg.clone();
                    self.show_toast(msg);
                }
                GuiEvent::UpdateCheckFinished { result, silent } => {
                    self.update_checking = false;
                    match result {
                        Ok(info) => {
                            if info.has_update {
                                let msg = format!(
                                    "{} Có bản cập nhật mới v{} trên GitHub (hiện tại: v{})",
                                    lucide::ROCKET,
                                    info.latest_version,
                                    info.current_version
                                );
                                self.update_status = msg.clone();
                                let is_skipped = silent
                                    && !self.settings.skipped_update_version.is_empty()
                                    && self.settings.skipped_update_version == info.latest_version;
                                let already_notified = self.last_notified_update_version.as_deref()
                                    == Some(info.latest_version.as_str());
                                if !is_skipped {
                                    self.show_toast(msg);
                                    if !already_notified || !silent {
                                        self.last_notified_update_version =
                                            Some(info.latest_version.clone());
                                        self.update_modal_open = true;
                                        self.update_banner_dismissed = false;
                                        if self.settings.enable_notifications {
                                            crate::updater::notify_os_new_update(
                                                &info.latest_version,
                                                &info.current_version,
                                                &info.release_title,
                                            );
                                        }
                                    }
                                }
                            } else {
                                self.update_status = format!(
                                    "{} Bạn đang sử dụng phiên bản mới nhất (v{})",
                                    lucide::CHECK_CIRCLE,
                                    info.current_version
                                );
                                if !silent {
                                    self.show_toast(&self.update_status.clone());
                                }
                            }
                            self.update_info = Some(info);
                        }
                        Err(e) => {
                            self.update_status = format!(
                                "{} Không kiểm tra được cập nhật: {e}",
                                lucide::ALERT_TRIANGLE
                            );
                            if !silent {
                                self.show_toast(&self.update_status.clone());
                            }
                        }
                    }
                }
                GuiEvent::UpdateDownloadStatus {
                    downloading,
                    message,
                } => {
                    self.update_downloading = downloading;
                    if !downloading {
                        self.update_progress = None;
                    }
                    self.update_status = message.clone();
                    self.show_toast(message);
                }
                GuiEvent::UpdateDownloadProgress { downloaded, total } => {
                    self.update_downloading = true;
                    self.update_progress = Some((downloaded, total));
                }
                GuiEvent::UpdateAppliedAndRestarting(ver) => {
                    self.update_downloading = false;
                    self.show_toast(format!(
                        "{} Đã cập nhật lên v{ver} — Đang khởi động lại…",
                        lucide::CHECK_CIRCLE
                    ));
                    self.request_graceful_exit(ctx);
                }
                GuiEvent::SocialProfileLoaded(res) => {
                    self.feed_loading_profile = false;
                    match res {
                        Ok(prof) => {
                            self.feed_profile = Some(prof);
                            self.feed_profile_error = None;
                        }
                        Err(e) => {
                            self.feed_profile_error = Some(e);
                        }
                    }
                }
                GuiEvent::SocialAvatarsLoaded(res) => {
                    self.feed_loading_avatars = false;
                    match res {
                        Ok(photos) => {
                            self.feed_avatars = photos;
                            self.feed_avatars_error = None;
                        }
                        Err(e) => {
                            self.feed_avatars_error = Some(e);
                        }
                    }
                }
                GuiEvent::SocialTimelineLoaded(res) => {
                    self.feed_loading_timeline = false;
                    match res {
                        Ok((profiles, items)) => {
                            self.feed_friend_profiles = profiles;
                            self.feed_items = items;
                        }
                        Err(e) => {
                            self.feed_profile_error = Some(e);
                        }
                    }
                }
                GuiEvent::MuteSnapshotSynced(mute_map) => {
                    self.settings.muted_threads = mute_map.clone();
                    self.settings.save();
                    let now_ts = crate::login::unix_now() as i64;
                    for t in &mut self.threads {
                        if let Some(&until) = mute_map.get(&t.id) {
                            let active = until == -1 || until > now_ts;
                            t.presentation.muted = active;
                            t.unread.muted = active;
                            t.unread.muted_until = (until > 0).then_some(until);
                            t.unread.settings_fresh = true;
                            t.unread.fresh = true;
                        } else {
                            t.presentation.muted = false;
                            t.unread.muted = false;
                            t.unread.muted_until = None;
                            t.unread.settings_fresh = true;
                            t.unread.fresh = true;
                        }
                    }
                    self.persist_threads_async();
                }
                GuiEvent::PinnedSnapshotSynced(pinned_ids) => {
                    for pid in &pinned_ids {
                        let clean = pid
                            .trim_start_matches("group_")
                            .trim_start_matches('g')
                            .trim_start_matches('G')
                            .trim_start_matches('u')
                            .trim_start_matches('U')
                            .trim()
                            .to_string();
                        if !clean.is_empty() && !self.settings.pinned_threads.contains(&clean) {
                            self.settings.pinned_threads.push(clean);
                        }
                    }
                    crate::chat::apply_pinned_threads(&mut self.threads, &pinned_ids);
                    self.settings.save();
                    self.persist_threads_async();
                }
                GuiEvent::MuteEventsReceived(events) => {
                    let mut changed = false;
                    for ev in events {
                        if ev.muted {
                            let until_val = ev.muted_until.unwrap_or(-1);
                            self.settings
                                .muted_threads
                                .insert(ev.thread_id.clone(), until_val);
                        } else {
                            self.settings.muted_threads.remove(&ev.thread_id);
                        }
                        if let Some(t) = self.threads.iter_mut().find(|t| t.id == ev.thread_id) {
                            t.presentation.muted = ev.muted;
                            t.unread.muted = ev.muted;
                            t.unread.muted_until = ev.muted_until;
                            t.unread.settings_fresh = true;
                            t.unread.fresh = true;
                        }
                        changed = true;
                    }
                    if changed {
                        self.settings.save();
                        self.persist_threads_async();
                    }
                }
                GuiEvent::PhoneSyncProgress { progress, status } => {
                    self.phone_sync_progress = progress;
                    self.phone_sync_status = status.clone();
                    self.status_msg = status;
                }
                GuiEvent::PhoneSyncFinished {
                    threads,
                    added,
                    active_threads,
                    cancelled,
                    error,
                } => {
                    self.phone_sync_progress = 0.0;
                    if !threads.is_empty() {
                        for nt in threads {
                            let is_pinned = nt.presentation.pinned
                                || self.settings.pinned_threads.contains(&nt.id)
                                || crate::chat::is_pinned_in_list(
                                    &nt.id,
                                    nt.is_group,
                                    &self.settings.pinned_threads,
                                );
                            if is_pinned {
                                let clean = nt
                                    .id
                                    .trim_start_matches("group_")
                                    .trim_start_matches('g')
                                    .trim_start_matches('G')
                                    .trim_start_matches('u')
                                    .trim_start_matches('U')
                                    .trim()
                                    .to_string();
                                if !clean.is_empty()
                                    && !self.settings.pinned_threads.contains(&clean)
                                {
                                    self.settings.pinned_threads.push(clean);
                                }
                            }
                            if let Some(existing) = self.threads.iter_mut().find(|t| t.id == nt.id)
                            {
                                crate::chat::merge_thread_into(existing, nt, true);
                                if is_pinned {
                                    existing.presentation.pinned = true;
                                }
                            } else if !nt.id.is_empty() && nt.id != "0" {
                                self.threads.push(nt);
                            }
                        }
                        self.settings.save();
                        self.persist_threads_async();
                    }
                    let msg = phone_sync_completion_message(
                        added,
                        active_threads,
                        cancelled,
                        error.as_deref(),
                    );
                    self.phone_sync_status = msg.clone();
                    self.status_msg = msg.clone();
                    self.show_toast(msg);
                }
                GuiEvent::MessagePinResult {
                    thread_id,
                    msg_id,
                    pin,
                    topic_id,
                    error,
                } => {
                    if let Some(err) = error {
                        // The server refused the board call: roll the optimistic flip back.
                        if let Some(t) = self.threads.iter_mut().find(|t| t.id == thread_id) {
                            if let Some(m) = t.messages.iter_mut().find(|m| m.id == msg_id) {
                                m.is_pinned = !pin;
                                if !pin {
                                    m.board_topic_id.clear();
                                }
                            }
                        }
                        let msg = format!("{} Không ghim được tin nhắn: {err}", lucide::ALERT_TRIANGLE);
                        self.status_msg = msg.clone();
                        self.show_toast(msg);
                    } else if !topic_id.is_empty() {
                        if let Some(t) = self.threads.iter_mut().find(|t| t.id == thread_id) {
                            if let Some(m) = t.messages.iter_mut().find(|m| m.id == msg_id) {
                                m.board_topic_id = topic_id;
                            }
                        }
                        self.persist_threads_async();
                    }
                }
                GuiEvent::BoardPinsUpdated {
                    thread_id,
                    topics,
                    error,
                } => {
                    if let Some(_err) = error {
                        // Board read-back is parked (the list API rejects every shape we can build),
                        // so stay completely silent: a toast on each thread switch is unacceptable.
                    } else {
                        // The server is authoritative: match each topic back to its bubble and drop
                        // stale local pin flags inside this thread.
                        let pinned_ids: Vec<String> =
                            topics.iter().map(|t| t.id.clone()).collect();
                        if let Some(t) = self.threads.iter_mut().find(|t| t.id == thread_id) {
                            let mut changed = false;
                            for m in t.messages.iter_mut() {
                                let mut found: Option<&crate::chat::BoardTopic> = None;
                                for topic in &topics {
                                    if topic.msg_ids.iter().any(|id| {
                                        id == &m.id
                                            || (!m.client_message_id.is_empty()
                                                && id == &m.client_message_id)
                                    }) {
                                        found = Some(topic);
                                        break;
                                    }
                                }
                                match found {
                                    Some(topic) => {
                                        if !m.is_pinned || m.board_topic_id != topic.id {
                                            m.is_pinned = true;
                                            m.board_topic_id = topic.id.clone();
                                            changed = true;
                                        }
                                    }
                                    None => {
                                        if m.is_pinned && !pinned_ids.contains(&m.board_topic_id) {
                                            m.is_pinned = false;
                                            m.board_topic_id.clear();
                                            changed = true;
                                        }
                                    }
                                }
                            }
                            if changed {
                                self.persist_threads_async();
                            }
                        }
                    }
                }
                GuiEvent::ProxyUpdated(res) => match res {
                    Ok(Some(url)) => {
                        let redacted = crate::session::redact_proxy_url(&url);
                        self.settings.proxy_url = url;
                        self.settings.save();
                        let msg = format!("{} Đã áp dụng Proxy: {redacted}", lucide::GLOBE);
                        self.status_msg = msg.clone();
                        self.show_toast(msg);
                    }
                    Ok(None) => {
                        self.settings.proxy_url.clear();
                        self.settings.save();
                        let msg = format!("{} Đã tắt Proxy (kết nối trực tiếp)", lucide::GLOBE);
                        self.status_msg = msg.clone();
                        self.show_toast(msg);
                    }
                    Err(e) => {
                        let msg = format!("{} Lỗi cấu hình Proxy: {e}", lucide::ALERT_TRIANGLE);
                        self.status_msg = msg.clone();
                        self.show_toast(msg);
                    }
                },
                GuiEvent::FileDownloaded(res) => match res {
                    Ok((fname, path)) => {
                        let msg = format!(
                            "{} Đã lưu tập tin \"{fname}\" tại {path}",
                            lucide::CHECK_CIRCLE
                        );
                        self.status_msg = msg.clone();
                        self.show_toast(msg);
                    }
                    Err(e) => {
                        let msg = format!("{} Lỗi lưu tập tin: {e}", lucide::ALERT_TRIANGLE);
                        self.status_msg = msg.clone();
                        self.show_toast(msg);
                    }
                },
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Lightweight Background Session Worker (2-thread Tokio pool, off-UI disk I/O)
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Main eframe::App Implementation
// ---------------------------------------------------------------------------

impl eframe::App for ZaloGuiApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        self.sync_windows_frameless(ctx);

        if ctx.input(|i| i.modifiers.ctrl && i.key_pressed(Key::Q)) {
            self.request_graceful_exit(ctx);
        }
        if ctx.input(|i| i.viewport().close_requested()) {
            if !self.shutting_down {
                ctx.send_viewport_cmd(egui::ViewportCommand::CancelClose);
                self.request_graceful_exit(ctx);
            } else if !crate::gui::worker::is_shutdown_complete()
                && self
                    .shutdown_requested_at
                    .is_some_and(|t| t.elapsed() < Duration::from_millis(1500))
            {
                ctx.send_viewport_cmd(egui::ViewportCommand::CancelClose);
                ctx.request_repaint_after(Duration::from_millis(16));
            }
        }
        if self.shutting_down {
            if crate::gui::worker::is_shutdown_complete()
                || self
                    .shutdown_requested_at
                    .is_some_and(|t| t.elapsed() >= Duration::from_millis(1500))
            {
                ctx.send_viewport_cmd(egui::ViewportCommand::Close);
            } else {
                ctx.request_repaint_after(Duration::from_millis(16));
            }
        }
        if ctx.input(|i| {
            (i.modifiers.ctrl || i.modifiers.command) && i.modifiers.shift && i.key_pressed(Key::P)
        }) {
            self.settings_modal_open = true;
            self.settings_tab = SettingsTab::Privacy;
        }
        if self.theme_dirty {
            self.cached_palette = ThemePalette::load_with_custom_override(self.dark_mode);
            self.cached_palette.apply_to_ctx(ctx);
            self.theme_dirty = false;
        }
        // Re-apply theme on first real frame so ViewportCommand::SetTheme reaches the
        // already-created window (sending it from new() is too early and gets dropped).
        if self.theme_apply_pending {
            self.cached_palette.apply_to_ctx(ctx);
            self.theme_apply_pending = false;
            ctx.request_repaint();
        }

        self.check_events(ctx);

        self.ime_just_committed = false;
        ctx.input_mut(|i| {
            let mut ime_commit_in_frame = false;
            let mut ime_space_commit = false;

            #[cfg(target_os = "macos")]
            let space_is_down = {
                #[link(name = "CoreGraphics", kind = "framework")]
                extern "C" {
                    fn CGEventSourceKeyState(state_id: i32, key: u16) -> bool;
                }
                // state_id = 0 (kCGEventSourceStateCombinedSessionState), key = 49 (kVK_Space)
                unsafe { CGEventSourceKeyState(0, 49) }
            };
            #[cfg(not(target_os = "macos"))]
            let space_is_down = false;

            let space_in_events = i.events.iter().any(|e| match e {
                egui::Event::Key {
                    key: Key::Space,
                    pressed: true,
                    ..
                } => true,
                egui::Event::Text(s) if s == " " => true,
                _ => false,
            }) || i.key_down(Key::Space);

            // Check whether Enter, non-space punctuation/navigation, or a mouse click
            // occurred in the same frame so we only auto-append a trailing space when
            // Spacebar triggered the macOS Vietnamese Telex IME commit (#71).
            let enter_pressed = i.events.iter().any(|e| {
                matches!(
                    e,
                    egui::Event::Key {
                        key: Key::Enter,
                        pressed: true,
                        ..
                    }
                )
            });
            let non_space_trigger = i.events.iter().any(|e| match e {
                egui::Event::Text(s) => s != " ",
                egui::Event::Key {
                    key, pressed: true, ..
                } => !matches!(key, Key::Space | Key::Backspace),
                _ => false,
            });
            let mouse_clicked =
                i.pointer.any_pressed() || i.pointer.any_released() || i.pointer.any_click();
            let space_pressed = space_is_down || space_in_events;
            let mut was_composing = self.ime_active;

            for event in &mut i.events {
                match event {
                    egui::Event::Ime(egui::ImeEvent::Enabled) => {
                        self.ime_active = true;
                        was_composing = true;
                    }
                    egui::Event::Ime(egui::ImeEvent::Preedit(text)) => {
                        self.ime_active = !text.is_empty();
                        if !text.is_empty() {
                            was_composing = true;
                        }
                    }
                    egui::Event::Ime(egui::ImeEvent::Commit(ref mut text)) => {
                        let inferred_macos_space_commit = cfg!(target_os = "macos")
                            && was_composing
                            && !enter_pressed
                            && !non_space_trigger
                            && !mouse_clicked;
                        if (space_pressed || inferred_macos_space_commit)
                            && !text.is_empty()
                            && !text.ends_with(' ')
                            && !text.chars().any(crate::gui::theme::is_cjk)
                        {
                            text.push(' ');
                            ime_space_commit = true;
                        }
                        self.ime_active = false;
                        self.ime_just_committed = true;
                        ime_commit_in_frame = true;
                    }
                    egui::Event::Ime(egui::ImeEvent::Disabled) => {
                        self.ime_active = false;
                    }
                    _ => {}
                }
            }

            if ime_space_commit {
                // Prevent duplicate space insertion if winit also forwarded a Space event in the same frame.
                i.events.retain(|e| {
                    !matches!(e, egui::Event::Text(s) if s == " ")
                        && !matches!(
                            e,
                            egui::Event::Key {
                                key: Key::Space,
                                pressed: true,
                                ..
                            }
                        )
                });
            }

            if self.ime_active || ime_commit_in_frame {
                // Suppress Enter key events during IME composition/commit so pressing Enter
                // to accept an IME candidate does not blur TextEdit or send prematurely (#71).
                i.events.retain(|e| {
                    !matches!(
                        e,
                        egui::Event::Key {
                            key: Key::Enter,
                            ..
                        }
                    )
                });
            }
        });

        // No timer repaint: the worker owns the poll timer and every GuiTx send wakes the UI.

        let pal = self.palette();

        self.handle_frameless_resize(ctx);
        self.render_custom_title_bar(ctx, &pal);
        // Dev Inspector Panel
        if self.dev_mode && self.dev_panel_open {
            egui::TopBottomPanel::bottom("dev_inspector")
                .resizable(true)
                .default_height(250.0)
                .show(ctx, |ui| {
                    ui.horizontal(|ui| {
                        ui.strong("Dev Inspector & Protocol Scanner");
                        ui.separator();
                        ui.selectable_value(
                            &mut self.dev_tab,
                            DevTab::Logs,
                            "Lưu lượng mạng (Logs)",
                        );
                        ui.selectable_value(
                            &mut self.dev_tab,
                            DevTab::Scanner,
                            "Quét lỗi hệ thống (Scanner)",
                        );
                        ui.selectable_value(
                            &mut self.dev_tab,
                            DevTab::CryptoState,
                            "Trạng thái Crypto & Keys",
                        );

                        ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                            if ui.button("Làm mới quét").clicked() {
                                self.scanner_findings = logger::scan_logs();
                            }
                            if ui.button("Xóa log").clicked() {
                                logger::clear_entries();
                                self.selected_log = None;
                                self.scanner_findings.clear();
                            }
                        });
                    });
                    ui.separator();

                    match self.dev_tab {
                        DevTab::Logs => self.render_dev_logs(ui),
                        DevTab::Scanner => self.render_dev_scanner(ui),
                        DevTab::CryptoState => self.render_dev_crypto(ui),
                    }
                });
        }

        // Main Workspace
        if !self.is_logged_in {
            egui::CentralPanel::default()
                .frame(egui::Frame::none().fill(pal.bg_chat_canvas))
                .show(ctx, |ui| {
                    self.render_login_screen(ui, &pal);
                });
        } else {
            self.render_chat_workspace(ctx, &pal);
        }

        // Auto-notification modal for new GitHub Releases (works on both Login & Chat screens)
        self.render_update_notification_modal(ctx, &pal);

        if !self.is_window_maximized(ctx) {
            let screen = ctx.screen_rect();
            ctx.layer_painter(egui::LayerId::new(
                egui::Order::Foreground,
                Id::new("window_border_overlay"),
            ))
            .rect_stroke(
                screen.shrink(0.5),
                Rounding::ZERO,
                Stroke::new(1.0_f32, pal.border),
            );
        }
    }

    fn on_exit(&mut self, _gl: Option<&eframe::glow::Context>) {
        if !self.shutting_down {
            self.shutting_down = true;
            self.settings.save();
            if let Some(tx) = WORKER_TX.get() {
                let _ = tx.send(WorkerCmd::PrepareShutdown {
                    active_uin: self.user_uin.clone(),
                    threads_snapshot: self.threads.clone(),
                });
            } else {
                crate::gui::worker::mark_shutdown_complete();
            }
        }
        crate::gui::worker::wait_for_worker_shutdown(Duration::from_millis(800));
    }
}

// ---------------------------------------------------------------------------
// Screen Renderers
// ---------------------------------------------------------------------------

impl ZaloGuiApp {
    fn resize_cursor_for(dir: egui::ResizeDirection) -> CursorIcon {
        match dir {
            egui::ResizeDirection::NorthWest | egui::ResizeDirection::SouthEast => {
                CursorIcon::ResizeNwSe
            }
            egui::ResizeDirection::NorthEast | egui::ResizeDirection::SouthWest => {
                CursorIcon::ResizeNeSw
            }
            egui::ResizeDirection::West | egui::ResizeDirection::East => {
                CursorIcon::ResizeHorizontal
            }
            egui::ResizeDirection::North | egui::ResizeDirection::South => {
                CursorIcon::ResizeVertical
            }
        }
    }

    #[cfg(target_os = "windows")]
    fn resolve_windows_hwnd(&mut self) -> usize {
        if !win32_frameless::is_valid_window(self.win_hwnd) {
            self.win_hwnd = win32_frameless::find_window_hwnd();
        }
        self.win_hwnd
    }

    fn sync_windows_frameless(&mut self, ctx: &egui::Context) {
        #[cfg(target_os = "windows")]
        {
            let hwnd = self.resolve_windows_hwnd();
            if hwnd != 0 && win32_frameless::sync_frameless_style(hwnd) {
                ctx.request_repaint();
            }
            if self.win_initial_sync_frames > 0 {
                self.win_initial_sync_frames -= 1;
                ctx.request_repaint();
            }
        }
        #[cfg(not(target_os = "windows"))]
        let _ = ctx;
    }

    fn is_window_maximized(&self, ctx: &egui::Context) -> bool {
        #[cfg(target_os = "windows")]
        if self.win_maximized {
            return true;
        }
        ctx.input(|i| i.viewport().maximized.unwrap_or(false))
    }

    fn toggle_maximize(&mut self, ctx: &egui::Context) {
        #[cfg(target_os = "windows")]
        {
            let hwnd = self.resolve_windows_hwnd();
            if hwnd != 0 {
                if !self.win_maximized {
                    self.win_restore_rect = win32_frameless::get_window_rect(hwnd);
                    if let Some(work) = win32_frameless::get_monitor_work_area(hwnd) {
                        win32_frameless::set_window_rect(hwnd, work, true);
                        self.win_maximized = true;
                        ctx.request_repaint();
                        return;
                    }
                } else {
                    let target = self.win_restore_rect.take().unwrap_or_else(|| {
                        let ppp = ctx.pixels_per_point().max(1.0);
                        let w = (1000.0 * ppp).round() as i32;
                        let h = (640.0 * ppp).round() as i32;
                        if let Some(work) = win32_frameless::get_monitor_work_area(hwnd) {
                            let left = work.left + (work.width() - w).max(0) / 2;
                            let top = work.top + (work.height() - h).max(0) / 2;
                            WinRect {
                                left,
                                top,
                                right: left + w,
                                bottom: top + h,
                            }
                        } else {
                            WinRect {
                                left: 80,
                                top: 80,
                                right: 80 + w,
                                bottom: 80 + h,
                            }
                        }
                    });
                    win32_frameless::set_window_rect(hwnd, target, true);
                    self.win_maximized = false;
                    ctx.request_repaint();
                    return;
                }
            }
        }
        let is_max = self.is_window_maximized(ctx);
        ctx.send_viewport_cmd(egui::ViewportCommand::Maximized(!is_max));
    }

    fn restore_before_drag_if_maximized(&mut self, ctx: &egui::Context) {
        #[cfg(target_os = "windows")]
        if self.win_maximized {
            let hwnd = self.resolve_windows_hwnd();
            if hwnd != 0 {
                let ppp = ctx.pixels_per_point().max(1.0);
                let fallback_w = (1000.0 * ppp).round() as i32;
                let fallback_h = (640.0 * ppp).round() as i32;
                let min_w = (480.0 * ppp).round() as i32;
                let min_h = (360.0 * ppp).round() as i32;
                let prev = self.win_restore_rect.take();
                let rw = prev.map_or(fallback_w, |r| r.width()).max(min_w);
                let rh = prev.map_or(fallback_h, |r| r.height()).max(min_h);
                if let (Some((cx, cy)), Some(work)) = (
                    win32_frameless::get_cursor_pos(),
                    win32_frameless::get_monitor_work_area(hwnd),
                ) {
                    let frac =
                        ((cx - work.left) as f32 / work.width().max(1) as f32).clamp(0.05, 0.95);
                    let left = cx - (rw as f32 * frac).round() as i32;
                    let top = (cy - (16.0 * ppp).round() as i32).max(work.top);
                    win32_frameless::set_window_rect(
                        hwnd,
                        WinRect {
                            left,
                            top,
                            right: left + rw,
                            bottom: top + rh,
                        },
                        true,
                    );
                }
                self.win_maximized = false;
            }
        }
        #[cfg(not(target_os = "windows"))]
        let _ = ctx;
    }

    fn handle_frameless_resize(&mut self, ctx: &egui::Context) {
        if self.is_window_maximized(ctx) {
            #[cfg(target_os = "windows")]
            {
                self.win_resize_drag = None;
            }
            return;
        }

        #[cfg(target_os = "windows")]
        if let Some(drag) = self.win_resize_drag {
            if ctx.input(|i| i.pointer.primary_down()) {
                ctx.set_cursor_icon(Self::resize_cursor_for(drag.dir));
                let hwnd = self.resolve_windows_hwnd();
                if hwnd != 0 {
                    if let Some((cx, cy)) = win32_frameless::get_cursor_pos() {
                        let ppp = ctx.pixels_per_point().max(1.0);
                        let min_w = (480.0 * ppp).round() as i32;
                        let min_h = (360.0 * ppp).round() as i32;
                        let target = compute_resized_rect(
                            drag.start_rect,
                            drag.dir,
                            cx.saturating_sub(drag.start_cursor_x),
                            cy.saturating_sub(drag.start_cursor_y),
                            min_w,
                            min_h,
                        );
                        win32_frameless::set_window_rect(hwnd, target, false);
                    }
                }
                ctx.request_repaint();
                return;
            }
            self.win_resize_drag = None;
        }

        let screen = ctx.screen_rect();
        let Some(pos) = ctx.input(|i| i.pointer.hover_pos()) else {
            return;
        };
        let border = 5.0_f32;
        let corner = 9.0_f32;
        let left = (pos.x - screen.left()).abs() <= border;
        let right = (screen.right() - pos.x).abs() <= border;
        let top = (pos.y - screen.top()).abs() <= border;
        let bottom = (screen.bottom() - pos.y).abs() <= border;

        let left_c = (pos.x - screen.left()).abs() <= corner;
        let right_c = (screen.right() - pos.x).abs() <= corner;
        let top_c = (pos.y - screen.top()).abs() <= corner;
        let bottom_c = (screen.bottom() - pos.y).abs() <= corner;

        let dir = if top_c && left_c && (top || left) {
            Some(egui::ResizeDirection::NorthWest)
        } else if top_c && right_c && (top || right) {
            Some(egui::ResizeDirection::NorthEast)
        } else if bottom_c && left_c && (bottom || left) {
            Some(egui::ResizeDirection::SouthWest)
        } else if bottom_c && right_c && (bottom || right) {
            Some(egui::ResizeDirection::SouthEast)
        } else if left {
            Some(egui::ResizeDirection::West)
        } else if right {
            Some(egui::ResizeDirection::East)
        } else if top {
            Some(egui::ResizeDirection::North)
        } else if bottom {
            Some(egui::ResizeDirection::South)
        } else {
            None
        };

        if let Some(dir) = dir {
            ctx.set_cursor_icon(Self::resize_cursor_for(dir));
            if ctx.input(|i| i.pointer.button_pressed(egui::PointerButton::Primary)) {
                #[cfg(target_os = "windows")]
                {
                    let hwnd = self.resolve_windows_hwnd();
                    if let (Some((cx, cy)), Some(rect)) = (
                        win32_frameless::get_cursor_pos(),
                        win32_frameless::get_window_rect(hwnd),
                    ) {
                        self.win_resize_drag = Some(WinResizeDrag {
                            dir,
                            start_cursor_x: cx,
                            start_cursor_y: cy,
                            start_rect: rect,
                        });
                        ctx.request_repaint();
                        return;
                    }
                }
                ctx.send_viewport_cmd(egui::ViewportCommand::BeginResize(dir));
            }
        }
    }

    fn render_custom_title_bar(&mut self, ctx: &egui::Context, pal: &ThemePalette) {
        let is_maximized = self.is_window_maximized(ctx);
        let mut toggle_max_requested = false;
        let mut drag_started = false;
        #[cfg(target_os = "windows")]
        let resizing_now = self.win_resize_drag.is_some();
        #[cfg(not(target_os = "windows"))]
        let resizing_now = false;
        let total_unread: usize = self.unread_counts.values().sum();
        if self.last_synced_icon_unread != Some(total_unread) {
            self.last_synced_icon_unread = Some(total_unread);
            if let Some(icon) = crate::gui::theme::load_app_icon_with_badge(total_unread) {
                ctx.send_viewport_cmd(egui::ViewportCommand::Icon(Some(std::sync::Arc::new(icon))));
            }
        }

        egui::TopBottomPanel::top("custom_title_bar")
            .exact_height(32.0)
            .show_separator_line(false)
            .frame(
                egui::Frame::none()
                    .fill(pal.bg_app)
                    .inner_margin(Margin {
                        left: 12.0,
                        right: 0.0,
                        top: 0.0,
                        bottom: 0.0,
                    }),
            )
            .show(ctx, |ui| {
                let bar_rect = ui.max_rect();
                let mut buttons_left_x = bar_rect.right();

                ui.horizontal_centered(|ui| {
                    // 1. App Logo (20x20)
                    let (logo_rect, _) =
                        ui.allocate_exact_size(Vec2::new(20.0, 20.0), Sense::hover());
                    if let Some(tex) = &self.app_logo_texture {
                        ui.painter().image(
                            tex.id(),
                            logo_rect,
                            Rect::from_min_max(Pos2::ZERO, Pos2::new(1.0, 1.0)),
                            Color32::WHITE,
                        );
                    } else {
                        ui.painter()
                            .rect_filled(logo_rect, Rounding::same(5.0), pal.primary);
                    }

                    ui.add_space(6.0);
                    ui.label(
                        RichText::new("ctdozlite")
                            .color(pal.text_primary)
                            .size(13.5)
                            .strong(),
                    );

                    // Subtle version chip (fixed height avoids vertical stretch inside centered TopBottomPanel)
                    draw_inline_pill(
                        ui,
                        &format!("v{}", env!("CARGO_PKG_VERSION")),
                        10.5,
                        pal.text_secondary,
                        pal.bg_elevated,
                        Stroke::new(1.0_f32, pal.border),
                        4.5,
                        6.0,
                        19.0,
                        false,
                    );

                    if total_unread > 0 {
                        ui.add_space(4.0);
                        draw_inline_pill(
                            ui,
                            &format!("{total_unread} tin mới"),
                            10.5,
                            Color32::WHITE,
                            pal.danger,
                            Stroke::NONE,
                            8.5,
                            7.0,
                            19.0,
                            true,
                        );
                    } else if self.is_logged_in && !self.user_name.is_empty() {
                        ui.add_space(6.0);
                        ui.label(
                            RichText::new(format!("·  {}", self.user_name))
                                .color(pal.text_muted)
                                .size(12.0),
                        );
                    }

                    // 2. Right-side Window Control Buttons
                    ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                        ui.spacing_mut().item_spacing.x = 0.0;

                        // Close Button (46x32)
                        let (close_rect, close_resp) =
                            ui.allocate_exact_size(Vec2::new(46.0, 32.0), Sense::click());
                        if close_resp.hovered() {
                            ui.painter().rect_filled(
                                close_rect,
                                Rounding::ZERO,
                                Color32::from_rgb(232, 17, 35),
                            );
                        }
                        let close_fg = if close_resp.hovered() {
                            Color32::WHITE
                        } else {
                            pal.text_secondary
                        };
                        let cc = close_rect.center();
                        let d = 4.6_f32;
                        ui.painter().line_segment(
                            [Pos2::new(cc.x - d, cc.y - d), Pos2::new(cc.x + d, cc.y + d)],
                            Stroke::new(1.4_f32, close_fg),
                        );
                        ui.painter().line_segment(
                            [Pos2::new(cc.x + d, cc.y - d), Pos2::new(cc.x - d, cc.y + d)],
                            Stroke::new(1.4_f32, close_fg),
                        );
                        let close_resp = close_resp.on_hover_cursor(CursorIcon::PointingHand);
                        show_titlebar_tooltip(ctx, &close_resp, "Đóng (Ctrl+Q)", pal);
                        if close_resp.clicked() || close_resp.secondary_clicked() {
                            self.request_graceful_exit(ctx);
                        }

                        // Maximize / Restore Button (46x32)
                        let (max_rect, max_resp) =
                            ui.allocate_exact_size(Vec2::new(46.0, 32.0), Sense::click());
                        if max_resp.hovered() {
                            ui.painter()
                                .rect_filled(max_rect, Rounding::ZERO, pal.bg_hover);
                        }
                        let max_fg = if max_resp.hovered() {
                            pal.text_primary
                        } else {
                            pal.text_secondary
                        };
                        let mc = max_rect.center();
                        if is_maximized {
                            let back = Rect::from_center_size(
                                Pos2::new(mc.x + 1.2, mc.y - 1.2),
                                Vec2::splat(7.8),
                            );
                            let front = Rect::from_center_size(
                                Pos2::new(mc.x - 1.2, mc.y + 1.2),
                                Vec2::splat(7.8),
                            );
                            ui.painter()
                                .rect_stroke(back, Rounding::same(1.0), Stroke::new(1.25_f32, max_fg));
                            ui.painter().rect_filled(
                                front,
                                Rounding::same(1.0),
                                if max_resp.hovered() {
                                    pal.bg_hover
                                } else {
                                    pal.bg_app
                                },
                            );
                            ui.painter()
                                .rect_stroke(front, Rounding::same(1.0), Stroke::new(1.25_f32, max_fg));
                        } else {
                            let sq = Rect::from_center_size(mc, Vec2::splat(9.5));
                            ui.painter()
                                .rect_stroke(sq, Rounding::same(1.2), Stroke::new(1.3_f32, max_fg));
                        }
                        let max_resp = max_resp.on_hover_cursor(CursorIcon::PointingHand);
                        show_titlebar_tooltip(
                            ctx,
                            &max_resp,
                            if is_maximized { "Khôi phục" } else { "Phóng to" },
                            pal,
                        );
                        if max_resp.clicked() {
                            toggle_max_requested = true;
                        }

                        // Minimize Button (46x32)
                        let (min_rect, min_resp) =
                            ui.allocate_exact_size(Vec2::new(46.0, 32.0), Sense::click());
                        if min_resp.hovered() {
                            ui.painter()
                                .rect_filled(min_rect, Rounding::ZERO, pal.bg_hover);
                        }
                        let min_fg = if min_resp.hovered() {
                            pal.text_primary
                        } else {
                            pal.text_secondary
                        };
                        let mnc = min_rect.center();
                        ui.painter().line_segment(
                            [Pos2::new(mnc.x - 5.0, mnc.y), Pos2::new(mnc.x + 5.0, mnc.y)],
                            Stroke::new(1.4_f32, min_fg),
                        );
                        let min_resp = min_resp.on_hover_cursor(CursorIcon::PointingHand);
                        show_titlebar_tooltip(ctx, &min_resp, "Thu nhỏ", pal);
                        if min_resp.clicked() {
                            ctx.send_viewport_cmd(egui::ViewportCommand::Minimized(true));
                        }

                        // Quick Theme Toggle (36x32)
                        let (th_rect, th_resp) =
                            ui.allocate_exact_size(Vec2::new(36.0, 32.0), Sense::click());
                        if th_resp.hovered() {
                            ui.painter()
                                .rect_filled(th_rect, Rounding::ZERO, pal.bg_hover);
                        }
                        let th_icon = if self.dark_mode {
                            lucide::SUN
                        } else {
                            lucide::MOON
                        };
                        ui.painter().text(
                            th_rect.center(),
                            egui::Align2::CENTER_CENTER,
                            th_icon,
                            FontId::proportional(14.5),
                            if th_resp.hovered() {
                                pal.text_primary
                            } else {
                                pal.text_secondary
                            },
                        );
                        let th_resp = th_resp.on_hover_cursor(CursorIcon::PointingHand);
                        show_titlebar_tooltip(
                            ctx,
                            &th_resp,
                            if self.dark_mode {
                                "Giao diện Sáng"
                            } else {
                                "Giao diện Tối"
                            },
                            pal,
                        );
                        if th_resp.clicked() {
                            self.dark_mode = !self.dark_mode;
                            self.theme_dirty = true;
                        }

                        buttons_left_x = th_rect.left();

                        if let Some(ref upd) = self.update_info {
                            if upd.has_update {
                                ui.add_space(6.0);
                                let badge_txt = if self.update_downloading {
                                    let (dl, tot) = self.update_progress.unwrap_or((0, 0));
                                    if tot > 0 {
                                        let pct = ((dl as f64 / tot as f64) * 100.0).clamp(0.0, 100.0);
                                        format!("{} Đang cập nhật {pct:.0}%", lucide::HOURGLASS)
                                    } else {
                                        format!("{} Đang tải cập nhật…", lucide::HOURGLASS)
                                    }
                                } else {
                                    format!("{} Cập nhật mới v{}", lucide::ROCKET, upd.latest_version)
                                };
                                let upd_pill = egui::Button::new(
                                    RichText::new(badge_txt)
                                        .size(11.0)
                                        .color(Color32::WHITE)
                                        .strong(),
                                )
                                .fill(pal.accent_online)
                                .rounding(Rounding::same(5.0))
                                .min_size(Vec2::new(0.0, 22.0));
                                let r = ui
                                    .scope(|ui| {
                                        ui.spacing_mut().button_padding = Vec2::new(8.0, 3.0);
                                        ui.add(upd_pill)
                                    })
                                    .inner
                                    .on_hover_cursor(CursorIcon::PointingHand)
                                    .on_hover_text(format!(
                                        "Đã có phiên bản v{} trên GitHub Releases — Bấm để xem chi tiết & cập nhật tự động",
                                        upd.latest_version
                                    ));
                                buttons_left_x = r.rect.left() - 8.0;
                                if r.clicked() {
                                    self.update_modal_open = true;
                                    self.update_banner_dismissed = false;
                                }
                            }
                        }

                        if !self.is_logged_in && !self.threads.is_empty() {
                            ui.add_space(8.0);
                            let hist_btn = egui::Button::new(
                                RichText::new("Xem lịch sử đã lưu")
                                    .size(11.2)
                                    .color(pal.primary)
                                    .strong(),
                            )
                            .fill(pal.primary.linear_multiply(0.12))
                            .stroke(Stroke::new(1.0_f32, pal.primary))
                            .rounding(Rounding::same(5.0))
                            .min_size(Vec2::new(0.0, 22.0));
                            let r = ui
                                .scope(|ui| {
                                    ui.spacing_mut().button_padding = Vec2::new(8.0, 3.0);
                                    ui.add(hist_btn)
                                })
                                .inner
                                .on_hover_cursor(CursorIcon::PointingHand);
                            buttons_left_x = r.rect.left() - 8.0;
                            if r.clicked() {
                                self.is_logged_in = true;
                            }
                        }
                    });
                });

                // Subtle 1px bottom hairline spanning the full window width
                let screen = ctx.screen_rect();
                let line_y = bar_rect.bottom() - 0.5;
                let full_bar_clip = Rect::from_min_max(
                    Pos2::new(screen.left(), bar_rect.top()),
                    Pos2::new(screen.right(), bar_rect.bottom()),
                );
                ui.painter().with_clip_rect(full_bar_clip).line_segment(
                    [Pos2::new(screen.left(), line_y), Pos2::new(screen.right(), line_y)],
                    Stroke::new(1.0_f32, pal.border),
                );

                // 3. Interactive drag / double-click region covering everything left of the control
                // buttons, inset from top edge when unmaximized so north border resize still works.
                let drag_top = bar_rect.min.y + if is_maximized { 0.0 } else { 5.0 };
                let drag_rect = Rect::from_min_max(
                    Pos2::new(bar_rect.min.x, drag_top),
                    Pos2::new((buttons_left_x - 2.0).max(bar_rect.left() + 40.0), bar_rect.max.y),
                );
                let drag_resp = ui.interact(
                    drag_rect,
                    Id::new("custom_title_bar_drag"),
                    Sense::click_and_drag(),
                );
                if drag_resp.double_clicked() {
                    toggle_max_requested = true;
                } else if !resizing_now && drag_resp.drag_started_by(egui::PointerButton::Primary) {
                    drag_started = true;
                }
            });

        if toggle_max_requested {
            self.toggle_maximize(ctx);
        } else if drag_started {
            self.restore_before_drag_if_maximized(ctx);
            ctx.send_viewport_cmd(egui::ViewportCommand::StartDrag);
        }
    }

    fn render_login_screen(&mut self, ui: &mut egui::Ui, pal: &ThemePalette) {
        let avail_w = ui.available_width();
        let avail_h = ui.available_height();
        let compact_h = avail_h < 630.0;
        let ultra_compact = avail_h < 460.0;
        let card_w = (avail_w - 28.0).clamp(270.0, 380.0);
        let h_pad = if card_w < 330.0 { 18.0 } else { 26.0 };
        let v_pad = if ultra_compact {
            14.0
        } else if compact_h {
            18.0
        } else {
            24.0
        };
        let inner_w = (card_w - h_pad * 2.0).max(216.0);
        let logo_size = if ultra_compact {
            40.0
        } else if compact_h {
            48.0
        } else {
            58.0
        };
        let qr_outer = (avail_h - 335.0).clamp(148.0, 224.0).min(inner_w - 8.0);
        let qr_margin = if compact_h { 10.0 } else { 12.0 };
        let qr_size = (qr_outer - qr_margin * 2.0).max(116.0);

        let est_card_h = match self.login_tab {
            LoginTab::QrCode => v_pad * 2.0 + 40.0 + 14.0 + qr_outer + 76.0,
            LoginTab::Password => v_pad * 2.0 + 40.0 + 18.0 + 190.0,
        };
        let est_total_h = logo_size + 58.0 + est_card_h;
        let top_pad = ((avail_h - est_total_h) * 0.36).clamp(10.0, 56.0);

        egui::ScrollArea::vertical()
            .id_salt("login_screen_scroll")
            .auto_shrink([false, false])
            .show(ui, |ui| {
                // Zero implicit vertical item spacing so top_pad/card spacing stays exact
                // and does not trigger an unnecessary scrollbar at default window heights.
                ui.spacing_mut().item_spacing.y = 0.0;
                ui.vertical_centered(|ui| {
                    ui.add_space(top_pad);
                    if let Some(tex) = &self.app_logo_texture {
                        ui.image((tex.id(), Vec2::new(logo_size, logo_size)));
                        ui.add_space(if compact_h { 8.0 } else { 10.0 });
                    }
                    ui.label(
                        RichText::new("Đăng nhập Zalo")
                            .color(pal.primary)
                            .size(if ultra_compact { 21.0 } else { 24.0 })
                            .strong(),
                    );
                    ui.add_space(3.0);
                    ui.add(
                        egui::Label::new(
                            RichText::new(
                                "Khởi chạy nhẹ, bảo mật và đồng bộ tin nhắn thời gian thực",
                            )
                            .color(pal.text_secondary)
                            .size(if compact_h { 12.5 } else { 13.0 }),
                        )
                        .wrap(),
                    );
                    ui.add_space(if compact_h { 12.0 } else { 16.0 });

                    egui::Frame::none()
                        .fill(pal.bg_elevated)
                        .rounding(Rounding::same(16.0))
                        .stroke(Stroke::new(1.0_f32, pal.border))
                        .shadow(egui::epaint::Shadow {
                            offset: Vec2::new(0.0, 8.0),
                            blur: 24.0,
                            spread: 0.0,
                            color: Color32::from_black_alpha(if pal.is_dark { 85 } else { 24 }),
                        })
                        .inner_margin(Margin::symmetric(h_pad, v_pad))
                        .show(ui, |ui| {
                            ui.set_width(inner_w);
                            ui.vertical_centered(|ui| {
                                // Segmented Tab Switcher
                                egui::Frame::none()
                                    .fill(pal.bg_input)
                                    .rounding(Rounding::same(10.0))
                                    .inner_margin(Margin::same(4.0))
                                    .show(ui, |ui| {
                                        let seg_inner_w = (inner_w - 8.0).max(180.0);
                                        ui.set_width(seg_inner_w);
                                        ui.horizontal(|ui| {
                                            ui.spacing_mut().item_spacing.x = 4.0;
                                            let tab_w = ((seg_inner_w - 4.0) / 2.0).max(86.0);
                                            for (tab, title) in [
                                                (LoginTab::QrCode, "Quét mã QR"),
                                                (LoginTab::Password, "Số điện thoại"),
                                            ] {
                                                let active = self.login_tab == tab;
                                                let btn = egui::Button::new(
                                                    RichText::new(title)
                                                        .size(13.0)
                                                        .color(if active {
                                                            Color32::WHITE
                                                        } else {
                                                            pal.text_secondary
                                                        })
                                                        .strong(),
                                                )
                                                .fill(if active {
                                                    pal.primary
                                                } else {
                                                    Color32::TRANSPARENT
                                                })
                                                .stroke(Stroke::NONE)
                                                .rounding(Rounding::same(7.0))
                                                .min_size(Vec2::new(tab_w, 32.0));

                                                if ui
                                                    .add(btn)
                                                    .on_hover_cursor(CursorIcon::PointingHand)
                                                    .clicked()
                                                {
                                                    self.login_tab = tab;
                                                }
                                            }
                                        });
                                    });

                                ui.add_space(if compact_h { 14.0 } else { 18.0 });

                                match self.login_tab {
                                    LoginTab::QrCode => {
                                        if let Some(tex) = &self.qr_texture {
                                            egui::Frame::none()
                                                .fill(Color32::WHITE)
                                                .rounding(Rounding::same(12.0))
                                                .stroke(Stroke::new(1.0_f32, pal.border))
                                                .inner_margin(Margin::same(qr_margin))
                                                .show(ui, |ui| {
                                                    ui.image((
                                                        tex.id(),
                                                        Vec2::new(qr_size, qr_size),
                                                    ));
                                                });
                                        } else {
                                            let (rect, _) = ui.allocate_exact_size(
                                                Vec2::new(qr_outer, qr_outer),
                                                Sense::hover(),
                                            );
                                            ui.painter().rect_filled(
                                                rect,
                                                Rounding::same(12.0),
                                                pal.bg_input,
                                            );
                                            ui.painter().rect_stroke(
                                                rect,
                                                Rounding::same(12.0),
                                                Stroke::new(1.0_f32, pal.border),
                                            );
                                            ui.painter().text(
                                                rect.center(),
                                                egui::Align2::CENTER_CENTER,
                                                "Đang tải mã QR…",
                                                FontId::proportional(14.0),
                                                pal.text_secondary,
                                            );
                                        }

                                        ui.add_space(if compact_h { 10.0 } else { 14.0 });
                                        ui.add(
                                            egui::Label::new(
                                                RichText::new(&self.qr_status)
                                                    .color(pal.text_primary)
                                                    .size(13.0),
                                            )
                                            .wrap(),
                                        );
                                        ui.add_space(if compact_h { 10.0 } else { 12.0 });

                                        let refresh_btn = egui::Button::new(
                                            RichText::new(format!(
                                                "{}  Tạo / Làm mới mã QR",
                                                lucide::REFRESH
                                            ))
                                            .size(13.2)
                                            .color(Color32::WHITE)
                                            .strong(),
                                        )
                                        .fill(pal.primary)
                                        .rounding(Rounding::same(8.0))
                                        .min_size(Vec2::new(inner_w.min(230.0), 36.0));

                                        if ui
                                            .add(refresh_btn)
                                            .on_hover_cursor(CursorIcon::PointingHand)
                                            .clicked()
                                        {
                                            self.login_in_progress = true;
                                            self.qr_status = "Đang xin mã QR…".into();
                                            if let Some(tx) = WORKER_TX.get() {
                                                let _ = tx.send(WorkerCmd::RequestQr);
                                            }
                                        }
                                    }
                                    LoginTab::Password => {
                                        let mut submit_now = false;
                                        ui.with_layout(Layout::top_down(Align::Min), |ui| {
                                            ui.label(
                                                RichText::new("Số điện thoại")
                                                    .size(13.0)
                                                    .color(pal.text_secondary)
                                                    .strong(),
                                            );
                                            ui.add_space(5.0);
                                            let phone_resp = render_login_text_field(
                                                ui,
                                                &mut self.phone_input,
                                                "Ví dụ: 0912345678",
                                                inner_w,
                                                false,
                                                pal,
                                            );
                                            ui.add_space(12.0);

                                            ui.label(
                                                RichText::new("Mật khẩu")
                                                    .size(13.0)
                                                    .color(pal.text_secondary)
                                                    .strong(),
                                            );
                                            ui.add_space(5.0);
                                            let pass_resp = render_login_text_field(
                                                ui,
                                                &mut self.password_input,
                                                "Nhập mật khẩu Zalo",
                                                inner_w,
                                                true,
                                                pal,
                                            );
                                            let enter_pressed =
                                                ui.input(|i| i.key_pressed(Key::Enter));
                                            if enter_pressed
                                                && ((pass_resp.has_focus()
                                                    || pass_resp.lost_focus())
                                                    || ((phone_resp.has_focus()
                                                        || phone_resp.lost_focus())
                                                        && !self.password_input.is_empty()))
                                            {
                                                submit_now = true;
                                            }
                                            ui.add_space(14.0);

                                            if !self.login_status_msg.is_empty() {
                                                ui.add(
                                                    egui::Label::new(
                                                        RichText::new(&self.login_status_msg)
                                                            .color(pal.danger)
                                                            .size(12.5),
                                                    )
                                                    .wrap(),
                                                );
                                                ui.add_space(8.0);
                                            }
                                        });

                                        // Keep the primary submit button outside `Align::Min` so its label is centered.
                                        ui.vertical_centered(|ui| {
                                            let btn = egui::Button::new(
                                                RichText::new("Đăng nhập")
                                                    .color(Color32::WHITE)
                                                    .size(14.0)
                                                    .strong(),
                                            )
                                            .fill(pal.primary)
                                            .rounding(Rounding::same(8.0))
                                            .min_size(Vec2::new(inner_w, 38.0));

                                            let clicked = ui
                                                .add_enabled(!self.login_in_progress, btn)
                                                .on_hover_cursor(CursorIcon::PointingHand)
                                                .clicked();
                                            if (clicked || submit_now) && !self.login_in_progress {
                                                self.login_in_progress = true;
                                                self.login_status_msg = "Đang kết nối…".into();
                                                if let Some(tx) = WORKER_TX.get() {
                                                    let _ = tx.send(WorkerCmd::LoginPassword {
                                                        phone: self.phone_input.clone(),
                                                        pass: self.password_input.clone(),
                                                    });
                                                }
                                            }
                                        });
                                    }
                                }
                            });
                        });
                    ui.add_space(16.0);
                });
            });
    }

    fn show_toast(&mut self, msg: impl Into<String>) {
        let text = msg.into();
        self.status_msg = text.clone();
        self.toast_notice = Some((text, std::time::Instant::now()));
    }
}

/// Render a palette-locked single-line login field so OS light/dark theme overrides never
/// wash out input background contrast.
fn render_login_text_field(
    ui: &mut egui::Ui,
    value: &mut String,
    hint: &str,
    width: f32,
    is_password: bool,
    pal: &ThemePalette,
) -> egui::Response {
    ui.scope(|ui| {
        let vis = ui.visuals_mut();
        vis.extreme_bg_color = pal.bg_input;
        vis.override_text_color = None;
        vis.widgets.inactive.bg_stroke = Stroke::new(1.0_f32, pal.border);
        vis.widgets.hovered.bg_stroke = Stroke::new(1.2_f32, pal.primary);
        vis.widgets.active.bg_stroke = Stroke::new(1.5_f32, pal.primary);
        vis.selection.stroke = Stroke::new(1.5_f32, pal.primary);
        ui.add_sized(
            [width, 38.0],
            egui::TextEdit::singleline(value)
                .password(is_password)
                .text_color(pal.text_primary)
                .margin(Margin::symmetric(12.0, 9.0))
                .vertical_align(Align::Center)
                .hint_text(RichText::new(hint).color(pal.text_muted)),
        )
    })
    .inner
}

#[cfg(test)]
mod tests {
    use super::{compute_resized_rect, is_newer_semver, phone_sync_completion_message, WinRect};
    use eframe::egui::ResizeDirection;

    #[test]
    fn sent_message_reconciles_when_server_push_arrives_first() {
        let mut thread = crate::chat::Thread::default();
        let server = crate::chat::ChatMessage {
            id: "server-a".into(),
            client_message_id: "client-a".into(),
            text: "Server push".into(),
            is_outgoing: true,
            delivery: crate::message_model::DeliveryState::Delivered,
            ..Default::default()
        };
        super::merge_sent_message(&mut thread, server.clone());
        for local_id in ["out_client-a", "server-a"] {
            super::merge_sent_message(
                &mut thread,
                crate::chat::ChatMessage {
                    id: local_id.into(),
                    client_message_id: "client-a".into(),
                    text: "Local echo".into(),
                    is_outgoing: true,
                    ..Default::default()
                },
            );
            assert_eq!(thread.messages.len(), 1);
            assert_eq!(thread.messages[0].id, "server-a");
            assert_eq!(thread.messages[0].delivery, server.delivery);
        }
    }

    #[test]
    fn delayed_local_ack_preserves_server_chronology() {
        let mut thread = crate::chat::Thread::default();
        for (id, client, ts) in [
            ("server-a", "client-a", 1000),
            ("server-b", "client-b", 2000),
        ] {
            thread.messages.push(crate::chat::ChatMessage {
                id: id.into(),
                client_message_id: client.into(),
                ts,
                time: ts.to_string(),
                is_outgoing: true,
                ..Default::default()
            });
        }
        for ack_id in ["out_client-a", "server-a"] {
            super::merge_sent_message(
                &mut thread,
                crate::chat::ChatMessage {
                    id: ack_id.into(),
                    client_message_id: "client-a".into(),
                    ts: 3000,
                    time: "3000".into(),
                    is_outgoing: true,
                    ..Default::default()
                },
            );
            let chronology: Vec<_> = thread
                .messages
                .iter()
                .map(|message| (message.id.as_str(), message.ts, message.time.as_str()))
                .collect();
            assert_eq!(
                chronology,
                [("server-a", 1000, "1000"), ("server-b", 2000, "2000")]
            );
        }
    }

    #[test]
    fn semver_comparison_handles_v_prefix_and_prerelease() {
        assert!(is_newer_semver("v0.0.2", "0.0.1"));
        assert!(is_newer_semver("0.1.0", "0.0.9"));
        assert!(is_newer_semver("V1.0.0-beta.1", "0.9.9"));
        assert!(!is_newer_semver("v0.0.1", "0.0.1"));
        assert!(!is_newer_semver("0.0.1", "0.0.2"));
    }

    #[test]
    fn phone_sync_completion_does_not_claim_phone_messages_were_imported() {
        let none = phone_sync_completion_message(0, 0, false, None);
        assert!(none.contains("Lịch sử điện thoại chưa được tải vào ứng dụng"));
        assert!(none.contains("0 tin mới từ Cloud/Nhóm"));

        let cloud = phone_sync_completion_message(12, 3, false, None);
        assert!(cloud.contains("12 tin mới từ Cloud/Nhóm (3 hội thoại)"));
        assert!(cloud.contains("Lịch sử điện thoại chưa được tải vào ứng dụng"));

        let failed = phone_sync_completion_message(0, 0, false, Some("network"));
        assert!(failed.contains("Đồng bộ thất bại: network"));
    }

    #[test]
    fn compute_resized_rect_handles_all_eight_directions_and_clamps_without_drifting_anchor() {
        let start = WinRect {
            left: 100,
            top: 80,
            right: 1100,
            bottom: 720,
        };
        let min_w = 480;
        let min_h = 360;

        // East / South expansion & clamping keeps left/top anchored
        assert_eq!(
            compute_resized_rect(start, ResizeDirection::East, 120, 45, min_w, min_h),
            WinRect {
                left: 100,
                top: 80,
                right: 1220,
                bottom: 720
            }
        );
        assert_eq!(
            compute_resized_rect(start, ResizeDirection::East, -900, 0, min_w, min_h),
            WinRect {
                left: 100,
                top: 80,
                right: 580,
                bottom: 720
            }
        );
        assert_eq!(
            compute_resized_rect(start, ResizeDirection::South, 50, -500, min_w, min_h),
            WinRect {
                left: 100,
                top: 80,
                right: 1100,
                bottom: 440
            }
        );

        // West / North clamping keeps right/bottom anchored
        assert_eq!(
            compute_resized_rect(start, ResizeDirection::West, 900, 30, min_w, min_h),
            WinRect {
                left: 620,
                top: 80,
                right: 1100,
                bottom: 720
            }
        );
        assert_eq!(
            compute_resized_rect(start, ResizeDirection::North, 30, 500, min_w, min_h),
            WinRect {
                left: 100,
                top: 360,
                right: 1100,
                bottom: 720
            }
        );

        // Diagonal corners (NW, NE, SW, SE) including negative monitor coordinates
        let neg_monitor = WinRect {
            left: -1200,
            top: -400,
            right: -200,
            bottom: 240,
        };
        assert_eq!(
            compute_resized_rect(
                neg_monitor,
                ResizeDirection::NorthWest,
                800,
                500,
                min_w,
                min_h
            ),
            WinRect {
                left: -680,
                top: -120,
                right: -200,
                bottom: 240
            }
        );
        assert_eq!(
            compute_resized_rect(start, ResizeDirection::NorthEast, 40, -20, min_w, min_h),
            WinRect {
                left: 100,
                top: 60,
                right: 1140,
                bottom: 720
            }
        );
        assert_eq!(
            compute_resized_rect(start, ResizeDirection::SouthWest, -40, 20, min_w, min_h),
            WinRect {
                left: 60,
                top: 80,
                right: 1100,
                bottom: 740
            }
        );
        assert_eq!(
            compute_resized_rect(start, ResizeDirection::SouthEast, 60, 80, min_w, min_h),
            WinRect {
                left: 100,
                top: 80,
                right: 1160,
                bottom: 800
            }
        );
    }
}
