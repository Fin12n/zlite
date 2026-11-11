use super::*;
/// Compute optimal Zoom-style gallery tile rectangles so each tile (`aspect` width/height)
/// has maximum area and the bottom row is horizontally centered.
pub(crate) fn compute_call_gallery_tiles(
    count: usize,
    rect: Rect,
    gap: f32,
    aspect: f32,
) -> Vec<Rect> {
    let total_w = rect.width();
    let total_h = rect.height();
    if count == 0 || total_w <= 0.0 || total_h <= 0.0 {
        return Vec::new();
    }
    let aspect = if aspect > 0.05 { aspect } else { 16.0 / 9.0 };
    let mut best: Option<(usize, usize, f32, f32, f32, usize)> = None;
    for cols in 1..=count {
        let rows = count.div_ceil(cols);
        let cell_w = (total_w - ((cols - 1) as f32) * gap) / (cols as f32);
        let cell_h = (total_h - ((rows - 1) as f32) * gap) / (rows as f32);
        if cell_w <= 0.0 || cell_h <= 0.0 {
            continue;
        }
        let w = cell_w.min(cell_h * aspect);
        let h = w / aspect;
        let area = w * h;
        let waste = rows * cols - count;
        let take = match best {
            None => true,
            Some((_, _, _, _, best_area, best_waste)) => {
                area > best_area + 0.5 || ((area - best_area).abs() <= 0.5 && waste < best_waste)
            }
        };
        if take {
            best = Some((cols, rows, w.floor(), h.floor(), area, waste));
        }
    }
    let Some((cols, rows, tw, th, _, _)) = best else {
        return Vec::new();
    };
    let grid_h = (rows as f32) * th + ((rows - 1) as f32) * gap;
    let y0 = rect.top() + ((total_h - grid_h) * 0.5).max(0.0).floor();
    let mut out = Vec::with_capacity(count);
    for i in 0..count {
        let row = i / cols;
        let col = i % cols;
        let in_row = if row + 1 == rows {
            count - cols * (rows - 1)
        } else {
            cols
        };
        let row_w = (in_row as f32) * tw + ((in_row - 1) as f32) * gap;
        let x0 = rect.left() + ((total_w - row_w) * 0.5).max(0.0).floor();
        out.push(Rect::from_min_size(
            Pos2::new(
                x0 + (col as f32) * (tw + gap),
                y0 + (row as f32) * (th + gap),
            ),
            Vec2::new(tw, th),
        ));
    }
    out
}

/// Compute per-stream aspect-preserving tile rectangles (e.g. mobile portrait `9:16` next to PC landscape `16:9`).
pub(crate) fn compute_call_fit_aspects(aspects: &[f32], rect: Rect, gap: f32) -> Vec<Rect> {
    let box_w = rect.width();
    let box_h = rect.height();
    if aspects.is_empty() || box_w <= 0.0 || box_h <= 0.0 {
        return Vec::new();
    }
    let clean: Vec<f32> = aspects
        .iter()
        .map(|&a| if a > 0.05 { a } else { 16.0 / 9.0 })
        .collect();
    if clean.len() == 1 {
        let a = clean[0];
        let mut w = box_w.min(box_h * a);
        let mut h = w / a;
        if h > box_h {
            h = box_h;
            w = h * a;
        }
        return vec![Rect::from_center_size(
            rect.center(),
            Vec2::new(w.floor(), h.floor()),
        )];
    }
    if clean.len() == 2 {
        let (a0, a1) = (clean[0], clean[1]);
        if box_h * (a0 + a1) + gap <= box_w {
            let w0 = (box_h * a0).floor();
            let w1 = (box_h * a1).floor();
            let total_w = w0 + w1 + gap;
            let x0 = rect.left() + ((box_w - total_w) * 0.5).floor();
            return vec![
                Rect::from_min_size(Pos2::new(x0, rect.top()), Vec2::new(w0, box_h)),
                Rect::from_min_size(Pos2::new(x0 + w0 + gap, rect.top()), Vec2::new(w1, box_h)),
            ];
        }
        if box_w / a0 + box_w / a1 + gap <= box_h {
            let h0 = (box_w / a0).floor();
            let h1 = (box_w / a1).floor();
            let total_h = h0 + h1 + gap;
            let y0 = rect.top() + ((box_h - total_h) * 0.5).floor();
            return vec![
                Rect::from_min_size(Pos2::new(rect.left(), y0), Vec2::new(box_w, h0)),
                Rect::from_min_size(Pos2::new(rect.left(), y0 + h0 + gap), Vec2::new(box_w, h1)),
            ];
        }
        let sum_a = a0 + a1;
        let hh = ((box_w - gap) / sum_a).floor();
        let ww0 = (hh * a0).floor();
        let ww1 = (hh * a1).floor();
        let tw = ww0 + ww1 + gap;
        let xx = rect.left() + ((box_w - tw) * 0.5).max(0.0).floor();
        let yy = rect.top() + ((box_h - hh) * 0.5).max(0.0).floor();
        return vec![
            Rect::from_min_size(Pos2::new(xx, yy), Vec2::new(ww0, hh)),
            Rect::from_min_size(Pos2::new(xx + ww0 + gap, yy), Vec2::new(ww1, hh)),
        ];
    }
    let avg = clean.iter().sum::<f32>() / (clean.len() as f32);
    compute_call_gallery_tiles(clean.len(), rect, gap, avg)
}

/// Compute Speaker View layout: `(main_stage_rect, thumbnail_strip_rects)`.
pub(crate) fn compute_call_speaker_layout(
    strip_count: usize,
    rect: Rect,
    gap: f32,
    aspect: f32,
) -> (Rect, Vec<Rect>) {
    let box_w = rect.width();
    let box_h = rect.height();
    if strip_count == 0 || box_w <= 0.0 || box_h <= 0.0 {
        return (rect, Vec::new());
    }
    let aspect = if aspect > 0.05 { aspect } else { 16.0 / 9.0 };
    let wide = box_w >= box_h * 1.15;
    if wide {
        let strip_w = (box_w * 0.22).floor().clamp(140.0, 210.0);
        let tile_w = strip_w;
        let tile_h = (tile_w / aspect).floor();
        let fit = (((box_h + gap) / (tile_h + gap)).floor() as usize).max(1);
        let vis = strip_count.min(fit);
        let total_h = (vis as f32) * tile_h + ((vis.saturating_sub(1)) as f32) * gap;
        let y0 = rect.top() + ((box_h - total_h) * 0.5).max(0.0).floor();
        let mut strip = Vec::with_capacity(vis);
        for i in 0..vis {
            strip.push(Rect::from_min_size(
                Pos2::new(rect.right() - strip_w, y0 + (i as f32) * (tile_h + gap)),
                Vec2::new(tile_w, tile_h),
            ));
        }
        let main = Rect::from_min_size(
            rect.min,
            Vec2::new((box_w - strip_w - gap).max(120.0), box_h),
        );
        (main, strip)
    } else {
        let strip_h = (box_h * 0.20).floor().clamp(84.0, 128.0);
        let tile_h = strip_h;
        let tile_w = (tile_h * aspect).floor();
        let fit = (((box_w + gap) / (tile_w + gap)).floor() as usize).max(1);
        let vis = strip_count.min(fit);
        let total_w = (vis as f32) * tile_w + ((vis.saturating_sub(1)) as f32) * gap;
        let x0 = rect.left() + ((box_w - total_w) * 0.5).max(0.0).floor();
        let mut strip = Vec::with_capacity(vis);
        for i in 0..vis {
            strip.push(Rect::from_min_size(
                Pos2::new(x0 + (i as f32) * (tile_w + gap), rect.bottom() - strip_h),
                Vec2::new(tile_w, tile_h),
            ));
        }
        let main = Rect::from_min_size(
            rect.min,
            Vec2::new(box_w, (box_h - strip_h - gap).max(120.0)),
        );
        (main, strip)
    }
}

/// Compute maximum remote tiles per page in Gallery View based on minimum readable tile width (`170px`).
pub(crate) fn compute_call_per_page(stage_w: f32) -> usize {
    let min_tile_w = 170.0_f32;
    let cols = (stage_w / min_tile_w).floor().clamp(1.0, 4.0) as usize;
    (cols * 2).max(2)
}

impl ZaloGuiApp {
    pub(super) fn render_profile_popover(&mut self, ctx: &egui::Context, pal: &ThemePalette) {
        if !self.profile_menu_open {
            return;
        }
        if ctx.input(|i| i.key_pressed(Key::Escape)) {
            self.profile_menu_open = false;
            return;
        }

        let mut close_menu = false;
        let mut do_logout = false;
        let mut do_wipe = false;
        let max_menu_h = (ctx.screen_rect().height() - 60.0).max(200.0);
        let area_resp = egui::Area::new(Id::new("left_rail_profile_popover"))
            .order(egui::Order::Foreground)
            .fixed_pos(Pos2::new(68.0, 44.0))
            .show(ctx, |ui| {
                egui::Frame::none()
                    .fill(pal.bg_elevated)
                    .stroke(Stroke::new(1.0_f32, pal.border))
                    .rounding(Rounding::same(12.0))
                    .inner_margin(Margin::same(10.0))
                    .show(ui, |ui| {
                        ui.set_width(220.0);
                        egui::ScrollArea::vertical()
                            .id_salt("profile_popover_scroll")
                            .max_height(max_menu_h)
                            .show(ui, |ui| {
                                ui.set_width(208.0);
                        let display_user = if self.user_name.is_empty() {
                            "Người dùng Zalo"
                        } else {
                            &self.user_name
                        };
                        ui.label(
                            RichText::new(display_user)
                                .size(14.0)
                                .color(pal.text_primary)
                                .strong(),
                        );
                        ui.horizontal(|ui| {
                            let (dr, _) = ui.allocate_exact_size(Vec2::splat(8.0), Sense::hover());
                            ui.painter()
                                .circle_filled(dr.center(), 3.8, pal.accent_online);
                            ui.label(
                                RichText::new("Đang hoạt động")
                                    .size(11.5)
                                    .color(pal.text_secondary),
                            );
                        });
                        if !self.user_uin.is_empty() {
                            ui.label(
                                RichText::new(format!("UIN: {}", self.user_uin))
                                    .size(10.5)
                                    .color(pal.text_muted),
                            );
                        }

                        ui.add_space(6.0);
                        ui.separator();
                        ui.add_space(4.0);
                        if ui
                            .add_sized(
                                [200.0, 28.0],
                                egui::Button::new(
                                    RichText::new(format!("{}  Quản lý & Đổi tài khoản", lucide::USER))
                                        .size(12.2)
                                        .color(pal.text_primary),
                                )
                                .fill(Color32::TRANSPARENT),
                            )
                            .on_hover_cursor(CursorIcon::PointingHand)
                            .clicked()
                        {
                            self.settings_modal_open = true;
                            self.settings_tab = SettingsTab::Account;
                            close_menu = true;
                        }

                        if ui
                            .add_sized(
                                [200.0, 28.0],
                                egui::Button::new(
                                    RichText::new(format!("{}  Nhật ký & Hồ sơ Social", lucide::NEWSPAPER))
                                        .size(12.2)
                                        .color(pal.text_primary),
                                )
                                .fill(Color32::TRANSPARENT),
                            )
                            .on_hover_cursor(CursorIcon::PointingHand)
                            .clicked()
                        {
                            self.feed_modal_open = true;
                            self.trigger_feed_timeline_load();
                            close_menu = true;
                        }

                        if ui
                            .add_sized(
                                [200.0, 28.0],
                                egui::Button::new(
                                    RichText::new(format!("{}  Làm mới hội thoại", lucide::REFRESH))
                                        .size(12.2)
                                        .color(pal.text_primary),
                                )
                                .fill(Color32::TRANSPARENT),
                            )
                            .on_hover_cursor(CursorIcon::PointingHand)
                            .on_hover_text("Làm mới danh bạ, nhóm và tin nhắn mới từ máy chủ Zalo")
                            .clicked()
                        {
                            if let Some(tx) = WORKER_TX.get() {
                                let _ = tx.send(WorkerCmd::RefreshThreadsManual);
                            }
                            self.status_msg = format!(
                                "{} Đang làm mới danh sách hội thoại…",
                                lucide::HOURGLASS
                            );
                            close_menu = true;
                        }

                        let theme_lbl = if self.dark_mode {
                            format!("{}  Chuyển giao diện Sáng", lucide::SUN)
                        } else {
                            format!("{}  Chuyển giao diện Tối", lucide::MOON)
                        };
                        if ui
                            .add_sized(
                                [200.0, 28.0],
                                egui::Button::new(
                                    RichText::new(theme_lbl).size(12.2).color(pal.text_primary),
                                )
                                .fill(Color32::TRANSPARENT),
                            )
                            .on_hover_cursor(CursorIcon::PointingHand)
                            .clicked()
                        {
                            self.dark_mode = !self.dark_mode;
                            self.theme_dirty = true;
                            close_menu = true;
                        }
                        let has_upd = self
                            .update_info
                            .as_ref()
                            .map(|u| u.has_update)
                            .unwrap_or(false);
                        let upd_lbl = if has_upd {
                            format!(
                                "{}  Cập nhật mới (v{})",
                                lucide::SPARKLES,
                                self.update_info
                                    .as_ref()
                                    .map(|u| u.latest_version.as_str())
                                    .unwrap_or("")
                            )
                        } else {
                            format!(
                                "{}  Kiểm tra cập nhật (v{})",
                                lucide::REFRESH,
                                env!("CARGO_PKG_VERSION")
                            )
                        };
                        if ui
                            .add_sized(
                                [200.0, 28.0],
                                egui::Button::new(
                                    RichText::new(upd_lbl).size(12.2).color(if has_upd {
                                        pal.accent_online
                                    } else {
                                        pal.text_primary
                                    }),
                                )
                                .fill(Color32::TRANSPARENT),
                            )
                            .on_hover_cursor(CursorIcon::PointingHand)
                            .clicked()
                        {
                            self.settings_modal_open = true;
                            self.settings_tab = SettingsTab::Update;
                            self.update_checking = true;
                            self.update_status = format!(
                                "{} Đang kiểm tra bản cập nhật mới trên GitHub Releases…",
                                lucide::HOURGLASS
                            );
                            if let Some(tx) = WORKER_TX.get() {
                                let _ = tx.send(WorkerCmd::CheckForUpdates { silent: false });
                            }
                            close_menu = true;
                        }

                        if self.dev_mode {
                            let dev_lbl = if self.dev_panel_open {
                                "Đóng Dev Inspector"
                            } else {
                                "Mở Dev Inspector"
                            };
                            if ui
                                .add_sized(
                                    [200.0, 28.0],
                                    egui::Button::new(
                                        RichText::new(dev_lbl).size(12.2).color(pal.warning),
                                    )
                                    .fill(Color32::TRANSPARENT),
                                )
                                .on_hover_cursor(CursorIcon::PointingHand)
                                .clicked()
                            {
                                self.dev_panel_open = !self.dev_panel_open;
                                if self.dev_panel_open {
                                    self.scanner_findings = logger::scan_logs();
                                }
                                close_menu = true;
                            }
                        }

                        ui.add_space(4.0);
                        ui.separator();
                        ui.add_space(4.0);

                        if ui
                            .add_sized(
                                [200.0, 30.0],
                                egui::Button::new(
                                    RichText::new("Xoá dữ liệu tin nhắn cục bộ")
                                        .size(12.0)
                                        .color(pal.text_secondary),
                                )
                                .fill(pal.bg_input)
                                .stroke(Stroke::new(1.0_f32, pal.border))
                                .rounding(Rounding::same(7.0)),
                            )
                            .on_hover_text(
                                "Xoá zalo_history.db và threads_cache.json. Phiên đăng nhập giữ nguyên.",
                            )
                            .on_hover_cursor(CursorIcon::PointingHand)
                            .clicked()
                        {
                            do_wipe = true;
                            close_menu = true;
                        }
                        ui.add_space(4.0);
                        ui.separator();
                        ui.add_space(4.0);

                        if ui
                            .add_sized(
                                [200.0, 30.0],
                                egui::Button::new(
                                    RichText::new("Đăng xuất tài khoản")
                                        .size(12.5)
                                        .color(pal.danger)
                                        .strong(),
                                )
                                .fill(pal.danger.linear_multiply(0.12))
                                .rounding(Rounding::same(7.0)),
                            )
                            .on_hover_cursor(CursorIcon::PointingHand)
                            .clicked()
                        {
                            do_logout = true;
                            close_menu = true;
                        }
                        ui.add_space(4.0);
                        if ui
                            .add_sized(
                                [200.0, 28.0],
                                egui::Button::new(
                                    RichText::new(format!(
                                        "{}  Thoát hoàn toàn (Ctrl+Q)",
                                        lucide::X
                                    ))
                                    .size(12.0)
                                    .color(pal.text_secondary),
                                )
                                .fill(pal.bg_input)
                                .stroke(Stroke::new(1.0_f32, pal.border))
                                .rounding(Rounding::same(7.0)),
                            )
                            .on_hover_cursor(CursorIcon::PointingHand)
                            .clicked()
                        {
                            self.request_graceful_exit(ctx);
                            close_menu = true;
                        }
                            });
                    });
            });

        if ctx.input(|i| i.pointer.any_click())
            && !area_resp.response.hovered()
            && ctx
                .input(|i| i.pointer.interact_pos())
                .map(|p| p.x > 64.0 || p.y > 60.0)
                .unwrap_or(false)
        {
            close_menu = true;
        }

        if do_logout {
            self.is_logged_in = false;
            self.user_name.clear();
            self.user_uin.clear();
            self.threads.clear();
            self.selected_thread_index = 0;
            self.qr_texture = None;
            self.login_status_msg.clear();
            self.qr_status = "Đang xin mã QR mới…".into();
            self.status_msg = "Đã đăng xuất".into();
            // `WorkerCmd::Logout` owns the file side: it removes `session.json` and
            // `threads_cache.json` but keeps `zalo_history.db` (#21).
            if let Some(tx) = WORKER_TX.get() {
                let _ = tx.send(WorkerCmd::Logout);
                let _ = tx.send(WorkerCmd::RequestQr);
            }
        }
        if do_wipe {
            // Destructive and irreversible, so it asks first.
            self.wipe_confirm_open = true;
        }
        if close_menu {
            self.profile_menu_open = false;
        }
    }

    pub(super) fn render_toast_overlay(&mut self, ctx: &egui::Context, pal: &ThemePalette) {
        fn get_desktop_bottom_right_pos(ctx: &egui::Context, popup_w: f32, popup_h: f32) -> Pos2 {
            #[cfg(target_os = "windows")]
            {
                use super::WinRect;
                #[link(name = "user32")]
                extern "system" {
                    fn SystemParametersInfoW(
                        ui_action: u32,
                        ui_param: u32,
                        pv_param: *mut WinRect,
                        f_win_ini: u32,
                    ) -> i32;
                    fn GetDC(hwnd: usize) -> usize;
                    fn ReleaseDC(hwnd: usize, hdc: usize) -> i32;
                }
                #[link(name = "gdi32")]
                extern "system" {
                    fn GetDeviceCaps(hdc: usize, index: i32) -> i32;
                }
                let mut work = super::win32_frameless::active_window_work_area().unwrap_or_default();
                let mut got_work = work.width() > 0 && work.height() > 0;
                if !got_work {
                    // SAFETY: `work` is a zero-initialized stack `WinRect` passed to SPI_GETWORKAREA.
                    got_work = unsafe { SystemParametersInfoW(0x0030, 0, &mut work, 0) } != 0
                        && work.width() > 0
                        && work.height() > 0;
                }
                if got_work {
                    let hdc = unsafe { GetDC(0) };
                    let dpi_x = if hdc != 0 {
                        let d = unsafe { GetDeviceCaps(hdc, 88) };
                        unsafe { ReleaseDC(0, hdc) };
                        d
                    } else {
                        96
                    };
                    let scale = if dpi_x > 0 {
                        (dpi_x as f32 / 96.0).max(ctx.pixels_per_point()).max(1.0)
                    } else {
                        ctx.pixels_per_point().max(1.0)
                    };
                    let right_pt = work.right as f32 / scale;
                    let bottom_pt = work.bottom as f32 / scale;
                    return Pos2::new(
                        (right_pt - popup_w - 18.0).max(16.0),
                        (bottom_pt - popup_h - 18.0).max(16.0),
                    );
                }
            }
            if let Some(mon) = ctx.input(|i| i.viewport().monitor_size) {
                if mon.x > popup_w && mon.y > popup_h {
                    return Pos2::new(
                        (mon.x - popup_w - 18.0).max(16.0),
                        (mon.y - popup_h - 48.0).max(16.0),
                    );
                }
            }
            Pos2::new(1120.0, 680.0)
        }
        let screen = ctx.screen_rect();

        // 1. Native desktop corner mini popup (`show_viewport_immediate`, zero PowerShell latency)
        let mut jump_to_tid: Option<String> = None;
        let mut quick_reply_send: Option<(String, bool, String)> = None;
        let mut close_popup = false;

        if let Some(ref mut popup) = self.incoming_popup {
            const POPUP_DURATION_MS: u64 = 6500;
            let elapsed_ms = popup.created_at.elapsed().as_millis() as u64;
            if elapsed_ms >= POPUP_DURATION_MS || !self.settings.enable_notifications {
                close_popup = true;
            } else {
                ctx.request_repaint_after(Duration::from_millis(200));
                let popup_w = 380.0_f32;
                let popup_h = 156.0_f32;
                let corner_pos = get_desktop_bottom_right_pos(ctx, popup_w, popup_h);
                let vp_id = egui::ViewportId::from_hash_of("zalo_corner_notification_popup");
                let builder = egui::ViewportBuilder::default()
                    .with_title("ctdozlite — Tin nhắn mới")
                    .with_decorations(false)
                    .with_always_on_top()
                    .with_taskbar(false)
                    .with_resizable(false)
                    .with_position(corner_pos)
                    .with_inner_size([popup_w, popup_h]);

                let tid_cl = popup.thread_id.clone();
                let s_name = popup.sender_name.clone();
                let p_text = popup.preview_text.clone();
                let is_grp = popup.is_group;
                let unread_cnt = popup.unread_total;
                let avt_tex = popup
                    .avatar_url
                    .as_ref()
                    .map(|u| format!("thumb_{}", crate::crypto::md5_hex(u)))
                    .and_then(|k| self.sticker_textures.get(&k).cloned());
                let logo_tex = self.app_logo_texture.clone();
                let mut draft_local = popup.reply_draft.clone();
                let mut paused = !draft_local.trim().is_empty();

                ctx.show_viewport_immediate(vp_id, builder, |vp_ctx, _class| {
                    let theme_sig = (pal.is_dark, pal.primary.to_array(), pal.bg_elevated.to_array());
                    let needs_style = vp_ctx.data(|d| {
                        d.get_temp::<(bool, [u8; 4], [u8; 4])>(Id::new("popup_theme_sig"))
                            != Some(theme_sig)
                    });
                    if needs_style {
                        pal.apply_to_ctx(vp_ctx);
                        vp_ctx.data_mut(|d| {
                            d.insert_temp(Id::new("popup_theme_sig"), theme_sig);
                        });
                    }
                    vp_ctx.request_repaint_after(Duration::from_millis(200));
                    if vp_ctx.input(|i| i.pointer.has_pointer()) {
                        paused = true;
                    }
                    if vp_ctx.input(|i| i.key_pressed(Key::Escape)) {
                        close_popup = true;
                    }

                    let card_bg = pal.bg_elevated;
                    egui::CentralPanel::default()
                        .frame(
                            egui::Frame::none()
                                .fill(card_bg)
                                .stroke(Stroke::new(1.0_f32, pal.primary))
                                .rounding(Rounding::same(12.0))
                                .inner_margin(Margin::symmetric(14.0, 10.0)),
                        )
                        .show(vp_ctx, |ui| {
                            let full_rect = ui.max_rect();
                            // Top accent line
                            ui.painter().rect_filled(
                                Rect::from_min_size(
                                    Pos2::new(full_rect.left() - 12.0, full_rect.top() - 10.0),
                                    Vec2::new(popup_w, 3.0),
                                ),
                                Rounding {
                                    nw: 12.0,
                                    ne: 12.0,
                                    sw: 0.0,
                                    se: 0.0,
                                },
                                pal.primary,
                            );

                            // Header row
                            ui.horizontal(|ui| {
                                if let Some(ref ltex) = logo_tex {
                                    ui.add(
                                        egui::Image::from_texture((ltex.id(), Vec2::splat(15.0)))
                                            .rounding(Rounding::same(6.0)),
                                    );
                                } else {
                                    let (dr, _) =
                                        ui.allocate_exact_size(Vec2::splat(8.0), Sense::hover());
                                    ui.painter().circle_filled(dr.center(), 4.0, pal.primary);
                                }
                                ui.label(
                                    RichText::new("ctdozlite · Tin nhắn mới")
                                        .size(11.5)
                                        .color(pal.primary)
                                        .strong(),
                                );
                                if unread_cnt > 1 {
                                    egui::Frame::none()
                                        .fill(pal.primary.linear_multiply(0.18))
                                        .rounding(Rounding::same(11.0))
                                        .inner_margin(Margin::symmetric(6.0, 1.5))
                                        .show(ui, |ui| {
                                            ui.label(
                                                RichText::new(format!("{unread_cnt} chưa đọc"))
                                                    .size(11.0)
                                                    .color(pal.primary)
                                                    .strong(),
                                            );
                                        });
                                }
                                ui.with_layout(
                                    egui::Layout::right_to_left(egui::Align::Center),
                                    |ui| {
                                        let close_btn = egui::Button::new(
                                            RichText::new(lucide::X)
                                                .size(12.5)
                                                .color(pal.text_muted),
                                        )
                                        .frame(false);
                                        if ui
                                            .add(close_btn)
                                            .on_hover_cursor(CursorIcon::PointingHand)
                                            .on_hover_text("Đóng thông báo (Esc)")
                                            .clicked()
                                        {
                                            close_popup = true;
                                        }
                                        ui.add_space(4.0);
                                        let open_btn = egui::Button::new(
                                            RichText::new("Mở chat")
                                                .size(11.5)
                                                .color(pal.primary)
                                                .strong(),
                                        )
                                        .fill(pal.primary.linear_multiply(0.14))
                                        .rounding(Rounding::same(6.0));
                                        if ui
                                            .add(open_btn)
                                            .on_hover_cursor(CursorIcon::PointingHand)
                                            .clicked()
                                        {
                                            jump_to_tid = Some(tid_cl.clone());
                                            close_popup = true;
                                        }
                                    },
                                );
                            });

                            ui.add_space(6.0);

                            // Body row: Avatar + Sender + Message Preview (clickable to jump to chat)
                            let body_resp = ui
                                .horizontal(|ui| {
                                    let (av_rect, _) =
                                        ui.allocate_exact_size(Vec2::splat(42.0), Sense::hover());
                                    if let Some(ref tex) = avt_tex {
                                        let mut mesh = egui::Mesh::with_texture(tex.id());
                                        let center = av_rect.center();
                                        let r = 21.0_f32;
                                        let segs = 28usize;
                                        mesh.vertices.push(egui::epaint::Vertex {
                                            pos: center,
                                            uv: Pos2::new(0.5, 0.5),
                                            color: Color32::WHITE,
                                        });
                                        for i in 0..=segs {
                                            let a =
                                                (i as f32 / segs as f32) * std::f32::consts::TAU;
                                            let (s, c) = a.sin_cos();
                                            mesh.vertices.push(egui::epaint::Vertex {
                                                pos: Pos2::new(center.x + c * r, center.y + s * r),
                                                uv: Pos2::new(0.5 + c * 0.5, 0.5 + s * 0.5),
                                                color: Color32::WHITE,
                                            });
                                        }
                                        for i in 1..=segs {
                                            mesh.indices.extend_from_slice(&[
                                                0,
                                                i as u32,
                                                (i + 1) as u32,
                                            ]);
                                        }
                                        ui.painter().add(egui::Shape::mesh(mesh));
                                    } else {
                                        ui.painter().circle_filled(
                                            av_rect.center(),
                                            21.0,
                                            avatar_color_for(&s_name, is_grp),
                                        );
                                        let ch = s_name
                                            .chars()
                                            .find(|c| c.is_alphanumeric())
                                            .unwrap_or('Z')
                                            .to_uppercase()
                                            .to_string();
                                        ui.painter().text(
                                            av_rect.center(),
                                            egui::Align2::CENTER_CENTER,
                                            ch,
                                            FontId::proportional(16.0),
                                            Color32::WHITE,
                                        );
                                    }
                                    // Online indicator dot
                                    let dot_pos =
                                        Pos2::new(av_rect.right() - 4.0, av_rect.bottom() - 4.0);
                                    ui.painter().circle_filled(dot_pos, 5.5, card_bg);
                                    ui.painter().circle_filled(dot_pos, 4.0, pal.accent_online);

                                    ui.add_space(8.0);
                                    ui.vertical(|ui| {
                                        ui.set_max_width(popup_w - 86.0);
                                        let s_short: String = if s_name.chars().count() > 36 {
                                            let t: String = s_name.chars().take(36).collect();
                                            format!("{t}…")
                                        } else {
                                            s_name.clone()
                                        };
                                        ui.label(
                                            RichText::new(s_short)
                                                .size(13.5)
                                                .color(pal.text_primary)
                                                .strong(),
                                        );
                                        ui.add_space(2.0);
                                        ui.label(
                                            RichText::new(&p_text)
                                                .size(12.0)
                                                .color(pal.text_secondary),
                                        );
                                    });
                                })
                                .response;

                            let body_click = ui.interact(
                                body_resp.rect,
                                Id::new("popup_body_jump_click"),
                                Sense::click(),
                            );
                            if body_click.hovered() {
                                vp_ctx.set_cursor_icon(egui::CursorIcon::PointingHand);
                            }
                            if body_click.clicked() {
                                jump_to_tid = Some(tid_cl.clone());
                                close_popup = true;
                            }

                            ui.add_space(6.0);

                            // Quick Reply bar right inside the corner popup
                            ui.horizontal(|ui| {
                                let input_w = (ui.available_width() - 58.0).max(160.0);
                                let te_resp = ui.add_sized(
                                    [input_w, 29.0],
                                    egui::TextEdit::singleline(&mut draft_local)
                                        .hint_text("Trả lời nhanh… (Enter để gửi)")
                                        .margin(Margin::symmetric(8.0, 5.0))
                                        .font(FontId::proportional(12.0)),
                                );
                                if te_resp.has_focus() {
                                    paused = true;
                                }
                                let enter_send = te_resp.lost_focus()
                                    && vp_ctx.input(|i| i.key_pressed(Key::Enter));
                                let btn_send = ui
                                    .add_sized(
                                        [50.0, 29.0],
                                        egui::Button::new(
                                            RichText::new("Gửi")
                                                .size(12.0)
                                                .color(Color32::WHITE)
                                                .strong(),
                                        )
                                        .fill(pal.primary)
                                        .rounding(Rounding::same(6.0)),
                                    )
                                    .on_hover_cursor(CursorIcon::PointingHand)
                                    .clicked();
                                if (enter_send || btn_send) && !draft_local.trim().is_empty() {
                                    quick_reply_send = Some((
                                        tid_cl.clone(),
                                        is_grp,
                                        draft_local.trim().to_string(),
                                    ));
                                    draft_local.clear();
                                    close_popup = true;
                                }
                            });

                            // Countdown progress bar at bottom edge
                            let frac = if paused {
                                1.0_f32
                            } else {
                                (1.0 - (elapsed_ms as f32 / POPUP_DURATION_MS as f32))
                                    .clamp(0.0, 1.0)
                            };
                            let bar_y = full_rect.bottom() + 7.0;
                            ui.painter().rect_filled(
                                Rect::from_min_size(
                                    Pos2::new(full_rect.left() - 12.0, bar_y),
                                    Vec2::new(popup_w * frac, 2.5),
                                ),
                                Rounding::ZERO,
                                pal.primary.linear_multiply(0.75),
                            );
                        });
                });

                popup.reply_draft = draft_local;
                if paused {
                    popup.created_at = std::time::Instant::now();
                }
            }
        }
        if close_popup {
            self.incoming_popup = None;
            ctx.request_repaint();
        }
        if let Some((tid, is_group, text)) = quick_reply_send {
            let now_ts = crate::login::unix_now() as i64;
            let now_time = crate::ui::clock();
            if let Some(t) = self.threads.iter_mut().find(|t| t.id == tid) {
                t.preview = format!("Bạn: {text}");
                t.time = now_time.clone();
                t.messages.push(ChatMessage {
                    id: format!("local_{now_ts}"),
                    sender: "Bạn".into(),
                    text: text.clone(),
                    time: now_time,
                    is_outgoing: true,
                    ts: now_ts,
                    ..Default::default()
                });
            }
            self.unread_counts.remove(&tid);
            if let Some(tx) = WORKER_TX.get() {
                let _ = tx.send(WorkerCmd::SendMessage {
                    to_id: tid,
                    text,
                    is_group,
                });
            }
            self.show_toast(format!("{} Đã gửi trả lời nhanh", lucide::CHECK));
        }
        if let Some(tid) = jump_to_tid {
            if let Some(idx) = self.threads.iter().position(|t| t.id == tid) {
                self.selected_thread_index = idx;
                self.unread_counts.remove(&tid);
            }
            ctx.send_viewport_cmd(egui::ViewportCommand::Minimized(false));
            ctx.send_viewport_cmd(egui::ViewportCommand::Focus);
        }

        // 2. Standard toast notice
        let Some((ref text, ts)) = self.toast_notice else {
            return;
        };
        if ts.elapsed() > Duration::from_millis(2500) {
            self.toast_notice = None;
            return;
        }
        ctx.request_repaint_after(Duration::from_millis(200));
        egui::Area::new(Id::new("floating_toast_notice"))
            .order(egui::Order::Tooltip)
            .fixed_pos(Pos2::new(
                (screen.right() - 320.0).max(80.0),
                screen.bottom() - 54.0,
            ))
            .interactable(false)
            .show(ctx, |ui| {
                egui::Frame::none()
                    .fill(pal.bg_elevated)
                    .stroke(Stroke::new(1.0_f32, pal.border))
                    .rounding(Rounding::same(10.0))
                    .inner_margin(Margin::symmetric(14.0, 9.0))
                    .show(ui, |ui| {
                        ui.horizontal(|ui| {
                            let (dr, _) = ui.allocate_exact_size(Vec2::splat(8.0), Sense::hover());
                            ui.painter()
                                .circle_filled(dr.center(), 4.0, pal.accent_online);
                            ui.label(
                                RichText::new(text)
                                    .size(12.0)
                                    .color(pal.text_primary)
                                    .strong(),
                            );
                        });
                    });
            });
    }

    pub(super) fn render_phone_lookup_modal(&mut self, ctx: &egui::Context, pal: &ThemePalette) {
        if !self.phone_modal_open {
            return;
        }
        if ctx.input(|i| i.key_pressed(Key::Escape)) {
            self.phone_modal_open = false;
            return;
        }

        let mut open = true;
        let mut trigger_lookup: Option<String> = None;
        let mut open_chat_user: Option<crate::chat::PhoneLookupResult> = None;
        let mut add_friend_user: Option<(String, String)> = None;

        let screen = ctx.screen_rect();
        let mut backdrop_clicked_pos: Option<Pos2> = None;
        egui::Area::new(Id::new("phone_lookup_backdrop"))
            .order(egui::Order::Middle)
            .fixed_pos(screen.min)
            .show(ctx, |ui| {
                let (r, resp) = ui.allocate_exact_size(screen.size(), Sense::click());
                ui.painter().rect_filled(
                    r,
                    Rounding::ZERO,
                    Color32::from_rgba_unmultiplied(0, 0, 0, if pal.is_dark { 155 } else { 95 }),
                );
                if resp.clicked() {
                    backdrop_clicked_pos = resp.interact_pointer_pos();
                }
            });

        let card_w = (screen.width() - 24.0).clamp(290.0, 420.0);
        let card_area = egui::Area::new(Id::new("phone_lookup_card"))
            .order(egui::Order::Foreground)
            .anchor(egui::Align2::CENTER_CENTER, Vec2::ZERO)
            .show(ctx, |ui| {
                egui::Frame::none()
                    .fill(pal.bg_elevated)
                    .rounding(Rounding::same(14.0))
                    .stroke(Stroke::new(1.0_f32, pal.border))
                    .shadow(egui::epaint::Shadow {
                        offset: Vec2::new(0.0, 10.0),
                        blur: 28.0,
                        spread: 0.0,
                        color: Color32::from_black_alpha(if pal.is_dark { 130 } else { 42 }),
                    })
                    .inner_margin(Margin::symmetric(18.0, 16.0))
                    .show(ui, |ui| {
                        let inner_w = (card_w - 36.0).max(240.0);
                        ui.set_width(inner_w);

                        ui.horizontal(|ui| {
                            ui.label(
                                RichText::new(format!(
                                    "{}  Tìm bạn qua số điện thoại",
                                    lucide::USER_PLUS
                                ))
                                .size(15.0)
                                .color(pal.text_primary)
                                .strong(),
                            );
                            ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                let (cr, c_resp) =
                                    ui.allocate_exact_size(Vec2::splat(26.0), Sense::click());
                                if c_resp.hovered() {
                                    ui.painter().rect_filled(cr, Rounding::same(6.0), pal.bg_hover);
                                }
                                draw_lucide_icon(
                                    ui.painter(),
                                    cr.center(),
                                    lucide::X,
                                    14.0,
                                    if c_resp.hovered() {
                                        pal.text_primary
                                    } else {
                                        pal.text_secondary
                                    },
                                );
                                if c_resp
                                    .on_hover_cursor(CursorIcon::PointingHand)
                                    .on_hover_text("Đóng (Esc)")
                                    .clicked()
                                {
                                    open = false;
                                }
                            });
                        });
                        ui.add_space(6.0);
                        ui.separator();
                        ui.add_space(8.0);

                        egui::ScrollArea::vertical()
                            .id_salt("phone_lookup_scroll")
                            .max_height((screen.height() - 110.0).max(160.0))
                            .show(ui, |ui| {
                                ui.set_width(inner_w);

                        ui.label(
                            RichText::new(
                                "Nhập số điện thoại để tìm tài khoản Zalo (VD: 0912345678 hoặc +84...):",
                            )
                            .size(12.2)
                            .color(pal.text_secondary),
                        );
                        ui.add_space(6.0);

                        ui.horizontal(|ui| {
                            let btn_w = 88.0_f32;
                            let input_w = (inner_w - btn_w - 10.0).max(130.0);
                            let te = egui::TextEdit::singleline(&mut self.phone_modal_input)
                                .hint_text("Số điện thoại Zalo...")
                                .margin(Margin::symmetric(10.0, 7.0))
                                .desired_width(input_w);
                            let resp = ui.add(te);
                            let enter = (resp.lost_focus() || resp.has_focus())
                                && ui.input(|i| i.key_pressed(Key::Enter));

                            let search_btn = egui::Button::new(
                                RichText::new("Tìm kiếm")
                                    .size(12.8)
                                    .color(Color32::WHITE)
                                    .strong(),
                            )
                            .fill(pal.primary)
                            .rounding(Rounding::same(8.0))
                            .min_size(Vec2::new(btn_w, 32.0));

                            if (ui
                                .add(search_btn)
                                .on_hover_cursor(CursorIcon::PointingHand)
                                .clicked()
                                || enter)
                                && !self.phone_modal_input.trim().is_empty()
                            {
                                trigger_lookup = Some(self.phone_modal_input.trim().to_string());
                            }
                        });

                ui.add_space(12.0);

                if self.phone_lookup_loading {
                    ui.vertical_centered(|ui| {
                        ui.add_space(16.0);
                        ui.spinner();
                        ui.add_space(6.0);
                        ui.label(
                            RichText::new("Đang tra cứu hồ sơ Zalo theo số điện thoại…")
                                .size(12.5)
                                .color(pal.text_secondary),
                        );
                        ui.add_space(12.0);
                    });
                } else if let Some(ref err) = self.phone_lookup_error {
                    egui::Frame::none()
                        .fill(pal.danger.linear_multiply(0.14))
                        .stroke(Stroke::new(1.0_f32, pal.danger))
                        .rounding(Rounding::same(10.0))
                        .inner_margin(Margin::symmetric(12.0, 10.0))
                        .show(ui, |ui| {
                            ui.label(
                                RichText::new(format!("Không tìm thấy: {err}"))
                                    .size(12.5)
                                    .color(pal.text_primary)
                                    .strong(),
                            );
                        });
                } else if let Some(ref prof) = self.phone_lookup_result {
                    egui::Frame::none()
                        .fill(pal.bg_input)
                        .stroke(Stroke::new(1.0_f32, pal.border))
                        .rounding(Rounding::same(12.0))
                        .inner_margin(Margin::symmetric(14.0, 12.0))
                        .show(ui, |ui| {
                            ui.horizontal(|ui| {
                                let (av_rect, _) =
                                    ui.allocate_exact_size(Vec2::splat(54.0), Sense::hover());
                                paint_user_avatar(
                                    ui.painter(),
                                    av_rect.center(),
                                    27.0,
                                    &prof.display_name,
                                    false,
                                    Some(prof.avatar.as_str()),
                                    &self.sticker_textures,
                                    &mut self.loading_stickers,
                                );

                                ui.add_space(6.0);
                                ui.vertical(|ui| {
                                    ui.horizontal(|ui| {
                                        ui.label(
                                            RichText::new(&prof.display_name)
                                                .size(15.0)
                                                .color(pal.text_primary)
                                                .strong(),
                                        );
                                        let (f_lbl, f_col) = match prof.friendship {
                                            crate::chat::FriendshipStatus::Friend => {
                                                (format!("{} Bạn bè", lucide::CHECK), pal.accent_online)
                                            }
                                            crate::chat::FriendshipStatus::IncomingPending => {
                                                ("Chờ bạn đồng ý".to_string(), pal.primary_hover)
                                            }
                                            crate::chat::FriendshipStatus::OutgoingPending => {
                                                ("Đã gửi lời mời".to_string(), pal.warning)
                                            }
                                            crate::chat::FriendshipStatus::Stranger => {
                                                ("Chưa kết bạn".to_string(), Color32::from_rgb(249, 115, 22))
                                            }
                                            crate::chat::FriendshipStatus::Unknown => {
                                                ("Đang kiểm tra…".to_string(), pal.text_muted)
                                            }
                                        };
                                        egui::Frame::none()
                                            .fill(f_col.linear_multiply(0.15))
                                            .rounding(Rounding::same(5.0))
                                            .inner_margin(Margin::symmetric(6.0, 2.0))
                                            .show(ui, |ui| {
                                                ui.label(
                                                    RichText::new(f_lbl)
                                                        .size(10.5)
                                                        .color(f_col)
                                                        .strong(),
                                                );
                                            });
                                    });
                                    ui.label(
                                        RichText::new(format!(
                                            "SĐT: {} · UID: {}",
                                            prof.phone, prof.user_id
                                        ))
                                        .size(11.5)
                                        .color(pal.text_secondary),
                                    );
                                    if !prof.status.is_empty() {
                                        ui.label(
                                            RichText::new(&prof.status)
                                                .size(11.5)
                                                .color(pal.text_muted),
                                        );
                                    }
                                });
                            });

                            ui.add_space(12.0);
                            ui.horizontal(|ui| {
                                let chat_btn = egui::Button::new(
                                    RichText::new("Nhắn tin ngay")
                                        .size(12.5)
                                        .color(Color32::WHITE)
                                        .strong(),
                                )
                                .fill(pal.primary)
                                .rounding(Rounding::same(8.0))
                                .min_size(Vec2::new(155.0, 32.0));
                                if ui
                                    .add(chat_btn)
                                    .on_hover_cursor(CursorIcon::PointingHand)
                                    .clicked()
                                {
                                    open_chat_user = Some(prof.clone());
                                }

                                match prof.friendship {
                                    crate::chat::FriendshipStatus::Friend => {
                                        let badge_btn = egui::Button::new(
                                            RichText::new(format!(
                                                "{} Đã là bạn bè",
                                                lucide::CHECK
                                            ))
                                            .size(12.2)
                                            .color(pal.accent_online)
                                            .strong(),
                                        )
                                        .fill(pal.accent_online.linear_multiply(0.14))
                                        .stroke(Stroke::new(1.0_f32, pal.accent_online))
                                        .rounding(Rounding::same(8.0))
                                        .min_size(Vec2::new(155.0, 32.0));
                                        ui.add_enabled(false, badge_btn);
                                    }
                                    crate::chat::FriendshipStatus::OutgoingPending => {
                                        let pending_btn = egui::Button::new(
                                            RichText::new("Đã gửi lời mời")
                                                .size(12.2)
                                                .color(pal.warning)
                                                .strong(),
                                        )
                                        .fill(pal.warning.linear_multiply(0.14))
                                        .stroke(Stroke::new(1.0_f32, pal.warning))
                                        .rounding(Rounding::same(8.0))
                                        .min_size(Vec2::new(155.0, 32.0));
                                        ui.add_enabled(false, pending_btn);
                                    }
                                    crate::chat::FriendshipStatus::IncomingPending => {
                                        let accept_btn = egui::Button::new(
                                            RichText::new(format!(
                                                "{} Đồng ý kết bạn",
                                                lucide::CHECK
                                            ))
                                            .size(12.5)
                                            .color(Color32::WHITE)
                                            .strong(),
                                        )
                                        .fill(pal.accent_online)
                                        .rounding(Rounding::same(8.0))
                                        .min_size(Vec2::new(155.0, 32.0));
                                        if ui
                                            .add(accept_btn)
                                            .on_hover_cursor(CursorIcon::PointingHand)
                                            .clicked()
                                        {
                                            add_friend_user = Some((
                                                prof.user_id.clone(),
                                                prof.display_name.clone(),
                                            ));
                                        }
                                    }
                                    _ => {
                                        let friend_btn = egui::Button::new(
                                            RichText::new(format!(
                                                "{} Kết bạn Zalo",
                                                lucide::USER_PLUS
                                            ))
                                            .size(12.5)
                                            .color(pal.accent_online)
                                            .strong(),
                                        )
                                        .fill(pal.accent_online.linear_multiply(0.15))
                                        .stroke(Stroke::new(1.0_f32, pal.accent_online))
                                        .rounding(Rounding::same(8.0))
                                        .min_size(Vec2::new(155.0, 32.0));
                                        if ui
                                            .add(friend_btn)
                                            .on_hover_cursor(CursorIcon::PointingHand)
                                            .clicked()
                                        {
                                            add_friend_user = Some((
                                                prof.user_id.clone(),
                                                prof.display_name.clone(),
                                            ));
                                        }
                                    }
                                }
                            });
                        });
                }
                            });
                    });
            });
        if let Some(pos) = backdrop_clicked_pos {
            if !card_area.response.rect.contains(pos) {
                open = false;
            }
        }

        if let Some(phone_q) = trigger_lookup {
            self.phone_lookup_loading = true;
            self.phone_lookup_error = None;
            self.phone_lookup_result = None;
            if let Some(tx) = WORKER_TX.get() {
                let _ = tx.send(WorkerCmd::LookupPhone { phone: phone_q });
            }
        }

        if let Some(prof) = open_chat_user {
            if let Some(idx) = self.threads.iter().position(|t| t.id == prof.user_id) {
                self.selected_thread_index = idx;
            } else {
                self.threads.insert(
                    0,
                    Thread {
                        presentation: Default::default(),
                        unread: Default::default(),
                        id: prof.user_id.clone(),
                        name: prof.display_name.clone(),
                        preview: format!("SĐT: {}", prof.phone),
                        time: crate::ui::clock(),
                        avatar: if prof.avatar.is_empty() {
                            None
                        } else {
                            Some(prof.avatar)
                        },
                        is_group: false,
                        messages: Vec::new(),
                    },
                );
                self.selected_thread_index = 0;
                self.persist_threads_async();
            }
            self.search_query.clear();
            self.phone_modal_open = false;
            self.show_toast(format!("Đã mở cuộc trò chuyện với {}", prof.display_name));
        }

        if let Some((uid, uname)) = add_friend_user {
            if let Some(tx) = WORKER_TX.get() {
                let _ = tx.send(WorkerCmd::AddFriend {
                    user_id: uid,
                    user_name: uname.clone(),
                });
            }
            self.show_toast(format!("Đang gửi lời mời kết bạn tới {uname}…"));
        }

        if !open {
            self.phone_modal_open = false;
        }
    }
}

#[derive(Default)]
struct SettingsActions {
    open: bool,
    theme_switched: bool,
    trigger_sync: bool,
    trigger_phone_sync: bool,
    apply_proxy_now: bool,
    clear_proxy_now: bool,
    spawn_multi_zalo: bool,
    pick_dl_dir: bool,
    open_dl_dir: bool,
    pick_migrate_file: bool,
    export_theme_tpl: bool,
    reload_theme_json: bool,
    export_sticker_tpl: bool,
    reload_sticker_json: bool,
    export_autoreply_tpl: bool,
    do_logout: bool,
    switch_to_uin: Option<String>,
    add_new_account: bool,
}

impl ZaloGuiApp {
    pub(super) fn render_settings_modal(&mut self, ctx: &egui::Context, pal: &ThemePalette) {
        if !self.settings_modal_open {
            return;
        }
        if ctx.input(|i| i.key_pressed(Key::Escape)) {
            self.settings_modal_open = false;
            self.settings.save();
            return;
        }

        let mut act = SettingsActions {
            open: true,
            ..Default::default()
        };
        let screen = ctx.screen_rect();
        let win_w = (screen.width() - 20.0).clamp(320.0, 780.0);
        let win_h = (screen.height() - 24.0).clamp(280.0, 600.0);
        let compact = win_w < 580.0;
        let mut backdrop_clicked_pos: Option<Pos2> = None;

        egui::Area::new(Id::new("settings_modal_backdrop"))
            .order(egui::Order::Middle)
            .fixed_pos(screen.min)
            .show(ctx, |ui| {
                let (bg_rect, bg_resp) = ui.allocate_exact_size(screen.size(), Sense::click());
                ui.painter().rect_filled(
                    bg_rect,
                    Rounding::ZERO,
                    Color32::from_rgba_unmultiplied(0, 0, 0, if pal.is_dark { 155 } else { 95 }),
                );
                if bg_resp.clicked() {
                    backdrop_clicked_pos = bg_resp.interact_pointer_pos();
                }
            });

        let tabs = [
            (SettingsTab::General, lucide::SETTINGS, "Cài đặt chung"),
            (SettingsTab::Account, lucide::USER, "Tài khoản"),
            (SettingsTab::Privacy, lucide::LOCK, "Quyền riêng tư"),
            (SettingsTab::Sync, lucide::REFRESH, "Đồng bộ tin nhắn"),
            (SettingsTab::Appearance, lucide::PAINTBRUSH, "Giao diện"),
            (SettingsTab::Notifications, lucide::BELL, "Thông báo"),
            (SettingsTab::Messages, lucide::MESSAGE_SQUARE, "Tin nhắn"),
            (SettingsTab::Utilities, lucide::SLIDERS, "Tiện ích"),
            (SettingsTab::Update, lucide::SPARKLES, "Cập nhật"),
        ];

        let tab_title = match self.settings_tab {
            SettingsTab::General => "Cài đặt chung",
            SettingsTab::Account => "Tài khoản & Đa tài khoản",
            SettingsTab::Privacy => "Quyền riêng tư",
            SettingsTab::Sync => "Đồng bộ tin nhắn",
            SettingsTab::Appearance => "Cài đặt giao diện",
            SettingsTab::Notifications => "Cài đặt thông báo",
            SettingsTab::Messages => "Cài đặt tin nhắn",
            SettingsTab::Utilities => "Tiện ích & Gợi ý",
            SettingsTab::Update => "Cập nhật phần mềm",
        };

        let card_area = egui::Area::new(Id::new("settings_modal_card"))
            .order(egui::Order::Foreground)
            .anchor(egui::Align2::CENTER_CENTER, Vec2::ZERO)
            .show(ctx, |ui| {
                egui::Frame::none()
                    .fill(pal.bg_chat_canvas)
                    .stroke(Stroke::new(1.0_f32, pal.border))
                    .rounding(Rounding::same(14.0))
                    .shadow(egui::epaint::Shadow {
                        offset: Vec2::new(0.0, 12.0),
                        blur: 32.0,
                        spread: 0.0,
                        color: Color32::from_black_alpha(if pal.is_dark { 145 } else { 48 }),
                    })
                    .inner_margin(Margin::ZERO)
                    .show(ui, |ui| {
                        ui.set_width(win_w);
                        ui.set_height(win_h);
                        ui.visuals_mut().widgets.inactive.bg_stroke =
                            Stroke::new(1.4_f32, pal.text_muted);
                        ui.visuals_mut().widgets.hovered.bg_stroke =
                            Stroke::new(1.6_f32, pal.primary_hover);

                        if compact {
                            // Compact responsive layout for narrow windows down to 480x360.
                            egui::Frame::none()
                                .fill(pal.bg_sidebar)
                                .inner_margin(Margin::symmetric(14.0, 10.0))
                                .show(ui, |ui| {
                                    ui.set_width(win_w - 28.0);
                                    ui.horizontal(|ui| {
                                        ui.label(
                                            RichText::new("Cài đặt")
                                                .size(16.0)
                                                .color(pal.text_primary)
                                                .strong(),
                                        );
                                        ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                            let (cr, c_resp) = ui.allocate_exact_size(
                                                Vec2::splat(26.0),
                                                Sense::click(),
                                            );
                                            if c_resp.hovered() {
                                                ui.painter().rect_filled(
                                                    cr,
                                                    Rounding::same(6.0),
                                                    pal.bg_hover,
                                                );
                                            }
                                            draw_lucide_icon(
                                                ui.painter(),
                                                cr.center(),
                                                lucide::X,
                                                14.0,
                                                if c_resp.hovered() {
                                                    pal.text_primary
                                                } else {
                                                    pal.text_secondary
                                                },
                                            );
                                            if c_resp
                                                .on_hover_cursor(CursorIcon::PointingHand)
                                                .clicked()
                                            {
                                                act.open = false;
                                            }
                                            let lo_btn = egui::Button::new(
                                                RichText::new(format!("{} Đăng xuất", lucide::LOG_OUT))
                                                    .size(11.5)
                                                    .color(pal.danger),
                                            )
                                            .fill(pal.danger.linear_multiply(0.12))
                                            .rounding(Rounding::same(6.0));
                                            if ui
                                                .add(lo_btn)
                                                .on_hover_cursor(CursorIcon::PointingHand)
                                                .clicked()
                                            {
                                                act.do_logout = true;
                                            }
                                        });
                                    });
                                    ui.add_space(6.0);
                                    egui::ScrollArea::horizontal()
                                        .id_salt("settings_compact_tabs_scroll")
                                        .show(ui, |ui| {
                                            ui.horizontal(|ui| {
                                                ui.spacing_mut().item_spacing.x = 6.0;
                                                for (tab, icon, title) in tabs {
                                                    let is_active = self.settings_tab == tab;
                                                    let pill = egui::Button::new(
                                                        RichText::new(format!("{icon}  {title}"))
                                                            .size(12.0)
                                                            .color(if is_active {
                                                                Color32::WHITE
                                                            } else {
                                                                pal.text_secondary
                                                            })
                                                            .strong(),
                                                    )
                                                    .fill(if is_active {
                                                        pal.primary
                                                    } else {
                                                        pal.bg_elevated
                                                    })
                                                    .stroke(Stroke::new(
                                                        1.0_f32,
                                                        if is_active {
                                                            pal.primary
                                                        } else {
                                                            pal.border
                                                        },
                                                    ))
                                                    .rounding(Rounding::same(8.0));
                                                    if ui
                                                        .add(pill)
                                                        .on_hover_cursor(CursorIcon::PointingHand)
                                                        .clicked()
                                                    {
                                                        self.settings_tab = tab;
                                                    }
                                                }
                                            });
                                        });
                                });

                            let content_w = (win_w - 28.0).max(240.0);
                            let inner_w = (content_w - 6.0).max(220.0);
                            egui::Frame::none()
                                .fill(pal.bg_chat_canvas)
                                .inner_margin(Margin::symmetric(14.0, 10.0))
                                .show(ui, |ui| {
                                    ui.set_width(content_w);
                                    ui.label(
                                        RichText::new(tab_title)
                                            .size(14.5)
                                            .color(pal.text_primary)
                                            .strong(),
                                    );
                                    ui.add_space(6.0);
                                    egui::ScrollArea::vertical()
                                        .id_salt("settings_tab_scroll")
                                        .max_width(content_w)
                                        .max_height((win_h - 148.0).max(120.0))
                                        .auto_shrink([false, false])
                                        .show(ui, |ui| {
                                            ui.vertical(|ui| {
                                                ui.set_min_width(inner_w);
                                                ui.set_max_width(inner_w);
                                                self.render_settings_tab_body(
                                                    ui,
                                                    pal,
                                                    inner_w,
                                                    &mut act,
                                                );
                                            });
                                        });
                                });
                        } else {
                            // Standard two-column desktop layout.
                            ui.horizontal(|ui| {
                                ui.spacing_mut().item_spacing.x = 0.0;
                                egui::Frame::none()
                                    .fill(pal.bg_sidebar)
                                    .inner_margin(Margin::symmetric(10.0, 16.0))
                                    .show(ui, |ui| {
                                        ui.set_width(196.0);
                                        ui.set_height(win_h - 32.0);
                                        ui.vertical(|ui| {
                                            ui.add_space(4.0);
                                            ui.label(
                                                RichText::new("Cài đặt")
                                                    .size(17.5)
                                                    .color(pal.text_primary)
                                                    .strong(),
                                            );
                                            ui.add_space(14.0);

                                            for (tab, icon, title) in tabs {
                                                let is_active = self.settings_tab == tab;
                                                let text_col = if is_active {
                                                    pal.primary_hover
                                                } else {
                                                    pal.text_secondary
                                                };

                                                let (rect, resp) = ui.allocate_exact_size(
                                                    Vec2::new(192.0, 36.0),
                                                    Sense::click(),
                                                );
                                                if is_active || resp.hovered() {
                                                    ui.painter().rect_filled(
                                                        rect,
                                                        Rounding::same(8.0),
                                                        if is_active {
                                                            pal.bg_selected
                                                        } else {
                                                            pal.bg_hover
                                                        },
                                                    );
                                                }
                                                let icon_pt =
                                                    Pos2::new(rect.left() + 18.0, rect.center().y);
                                                draw_lucide_icon(
                                                    ui.painter(),
                                                    icon_pt,
                                                    icon,
                                                    14.5,
                                                    text_col,
                                                );
                                                let text_pt =
                                                    Pos2::new(rect.left() + 38.0, rect.center().y);
                                                ui.painter().text(
                                                    text_pt,
                                                    egui::Align2::LEFT_CENTER,
                                                    title,
                                                    FontId::proportional(13.2),
                                                    if is_active {
                                                        pal.text_primary
                                                    } else {
                                                        text_col
                                                    },
                                                );

                                                if resp
                                                    .on_hover_cursor(CursorIcon::PointingHand)
                                                    .clicked()
                                                {
                                                    self.settings_tab = tab;
                                                }
                                                ui.add_space(2.0);
                                            }
                                            ui.add_space(8.0);
                                            ui.separator();
                                            ui.add_space(8.0);

                                            let (lo_rect, lo_resp) = ui.allocate_exact_size(
                                                Vec2::new(192.0, 36.0),
                                                Sense::click(),
                                            );
                                            if lo_resp.hovered() {
                                                ui.painter().rect_filled(
                                                    lo_rect,
                                                    Rounding::same(8.0),
                                                    pal.danger.linear_multiply(0.18),
                                                );
                                            }
                                            let lo_icon_pt = Pos2::new(
                                                lo_rect.left() + 18.0,
                                                lo_rect.center().y,
                                            );
                                            draw_lucide_icon(
                                                ui.painter(),
                                                lo_icon_pt,
                                                lucide::LOG_OUT,
                                                14.5,
                                                pal.danger,
                                            );
                                            let lo_text_pt = Pos2::new(
                                                lo_rect.left() + 38.0,
                                                lo_rect.center().y,
                                            );
                                            ui.painter().text(
                                                lo_text_pt,
                                                egui::Align2::LEFT_CENTER,
                                                "Đăng xuất",
                                                FontId::proportional(13.2),
                                                pal.danger,
                                            );
                                            if lo_resp
                                                .on_hover_cursor(CursorIcon::PointingHand)
                                                .on_hover_text("Đăng xuất khỏi tài khoản Zalo hiện tại")
                                                .clicked()
                                            {
                                                act.do_logout = true;
                                            }
                                        });
                                    });

                                let content_w = (win_w - 264.0).max(280.0);
                                let inner_w = (content_w - 8.0).max(260.0);
                                egui::Frame::none()
                                    .fill(pal.bg_chat_canvas)
                                    .inner_margin(Margin::symmetric(24.0, 16.0))
                                    .show(ui, |ui| {
                                        ui.vertical(|ui| {
                                            ui.set_min_width(content_w);
                                            ui.set_max_width(content_w);
                                            ui.set_height(win_h - 32.0);

                                            ui.horizontal(|ui| {
                                                ui.label(
                                                    RichText::new(tab_title)
                                                        .size(15.5)
                                                        .color(pal.text_primary)
                                                        .strong(),
                                                );
                                                ui.with_layout(
                                                    Layout::right_to_left(Align::Center),
                                                    |ui| {
                                                        let (cr, c_resp) = ui.allocate_exact_size(
                                                            Vec2::splat(26.0),
                                                            Sense::click(),
                                                        );
                                                        if c_resp.hovered() {
                                                            ui.painter().rect_filled(
                                                                cr,
                                                                Rounding::same(6.0),
                                                                pal.bg_hover,
                                                            );
                                                        }
                                                        draw_lucide_icon(
                                                            ui.painter(),
                                                            cr.center(),
                                                            lucide::X,
                                                            14.0,
                                                            if c_resp.hovered() {
                                                                pal.text_primary
                                                            } else {
                                                                pal.text_secondary
                                                            },
                                                        );
                                                        if c_resp
                                                            .on_hover_cursor(
                                                                CursorIcon::PointingHand,
                                                            )
                                                            .clicked()
                                                        {
                                                            act.open = false;
                                                        }
                                                    },
                                                );
                                            });

                                            ui.add_space(8.0);
                                            ui.separator();
                                            ui.add_space(8.0);

                                            egui::ScrollArea::vertical()
                                                .id_salt("settings_tab_scroll")
                                                .max_width(content_w)
                                                .max_height((win_h - 86.0).max(180.0))
                                                .auto_shrink([false, false])
                                                .show(ui, |ui| {
                                                    ui.vertical(|ui| {
                                                        ui.set_min_width(inner_w);
                                                        ui.set_max_width(inner_w);
                                                        self.render_settings_tab_body(
                                                            ui,
                                                            pal,
                                                            inner_w,
                                                            &mut act,
                                                        );
                                                    });
                                                });
                                        });
                                    });
                            });
                        }
                    });
            });

        if let Some(pos) = backdrop_clicked_pos {
            if !card_area.response.rect.contains(pos) {
                act.open = false;
            }
        }
        self.apply_settings_actions(ctx, act);
    }

    fn render_settings_tab_body(
        &mut self,
        ui: &mut egui::Ui,
        pal: &ThemePalette,
        inner_w: f32,
        act: &mut SettingsActions,
    ) {
        match self.settings_tab {
                                                SettingsTab::General => {
                                                    ui.label(RichText::new("Danh bạ").color(pal.text_primary).size(13.5).strong());
                                                    ui.add_space(2.0);
                                                    ui.label(RichText::new("Hiển thị danh bạ trong Zalo, bạn có thể chọn hiển thị tất cả danh bạ hoặc chỉ những bạn bè đang sử dụng Zalo").color(pal.text_secondary).size(12.0));
                                                    ui.add_space(6.0);
                                                    egui::Frame::none()
                                                        .fill(pal.bg_elevated)
                                                        .stroke(Stroke::new(1.0_f32, pal.border))
                                                        .rounding(Rounding::same(8.0))
                                                        .inner_margin(Margin::symmetric(14.0, 10.0))
                                                        .show(ui, |ui| {
                                                            ui.vertical(|ui| {
                                                                ui.set_min_width((inner_w - 28.0).max(180.0));
                                                                ui.radio_value(&mut self.settings.show_all_contacts, true, "Hiển thị tất cả danh bạ");
                                                                ui.add_space(4.0);
                                                                ui.radio_value(&mut self.settings.show_all_contacts, false, "Chỉ hiển thị bạn bè đang sử dụng Zalo");
                                                            });
                                                        });
                                            ui.add_space(14.0);

                                            ui.label(RichText::new("Ngôn ngữ").color(pal.text_primary).size(13.5).strong());
                                            ui.add_space(6.0);
                                            egui::Frame::none()
                                                .fill(pal.bg_elevated)
                                                .stroke(Stroke::new(1.0_f32, pal.border))
                                                .rounding(Rounding::same(8.0))
                                                .inner_margin(Margin::symmetric(14.0, 10.0))
                                                .show(ui, |ui| {
                                                    ui.horizontal(|ui| {
                                                        ui.label(RichText::new("Thay đổi ngôn ngữ").color(pal.text_primary).size(13.2));
                                                        ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                                            egui::ComboBox::from_id_salt("setting_lang_combo")
                                                                .selected_text(&self.settings.language)
                                                                .width(130.0)
                                                                .show_ui(ui, |ui| {
                                                                    ui.selectable_value(&mut self.settings.language, "Tiếng Việt".into(), "Tiếng Việt");
                                                                    ui.selectable_value(&mut self.settings.language, "English".into(), "English");
                                                                });
                                                        });
                                                    });
                                                });
                                            ui.add_space(14.0);

                                            ui.label(RichText::new("Khởi động & Lưu File").color(pal.text_primary).size(13.5).strong());
                                            ui.add_space(6.0);
                                            egui::Frame::none()
                                                .fill(pal.bg_elevated)
                                                .stroke(Stroke::new(1.0_f32, pal.border))
                                                .rounding(Rounding::same(8.0))
                                                .inner_margin(Margin::symmetric(14.0, 10.0))
                                                .show(ui, |ui| {
                                                    ui.horizontal(|ui| {
                                                        ui.label(RichText::new("Khởi động Zalo khi mở máy").color(pal.text_primary).size(13.2));
                                                        ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                                            render_toggle_switch(ui, &mut self.settings.autostart_on_boot, pal);
                                                        });
                                                    });
                                                    ui.add_space(8.0);
                                                    ui.horizontal(|ui| {
                                                        ui.label(RichText::new("Ghi nhớ tài khoản đăng nhập lần trước").color(pal.text_primary).size(13.2));
                                                        ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                                            render_toggle_switch(ui, &mut self.settings.remember_login, pal);
                                                        });
                                                    });
                                                    ui.add_space(10.0);
                                                    ui.separator();
                                                    ui.add_space(6.0);
                                                    ui.label(RichText::new("File được lưu tại:").color(pal.text_secondary).size(12.2));
                                                    ui.add_space(4.0);
                                                    ui.horizontal(|ui| {
                                                        ui.label(
                                                            RichText::new(truncate_chars(&self.settings.download_dir, 36))
                                                                .size(12.0)
                                                                .color(pal.text_muted),
                                                        );
                                                        ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                                            if ui.button("Thay đổi").clicked() {
                                                                act.pick_dl_dir = true;
                                                            }
                                                            if ui.button("Mở thư mục").clicked() {
                                                                act.open_dl_dir = true;
                                                            }
                                                        });
                                                    });
                                                });
                                            ui.add_space(14.0);

                                            ui.label(RichText::new("Thiết bị Âm thanh & Video (Cuộc gọi)").color(pal.text_primary).size(13.5).strong());
                                            ui.add_space(6.0);
                                            egui::Frame::none()
                                                .fill(pal.bg_elevated)
                                                .stroke(Stroke::new(1.0_f32, pal.border))
                                                .rounding(Rounding::same(8.0))
                                                .inner_margin(Margin::symmetric(14.0, 10.0))
                                                .show(ui, |ui| {
                                                    let (mics, cams) = crate::media::list_media_devices(false);
                                                    ui.horizontal(|ui| {
                                                        ui.label(RichText::new(format!("{} Đầu vào Mic:", lucide::MIC)).color(pal.text_primary).size(13.0));
                                                        ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                                            let cur_mic_lbl = if self.settings.selected_mic_device.is_empty() {
                                                                "Mặc định hệ thống"
                                                            } else {
                                                                &self.settings.selected_mic_device
                                                            };
                                                            egui::ComboBox::from_id_salt("setting_mic_device_combo")
                                                                .selected_text(truncate_chars(cur_mic_lbl, 30))
                                                                .width((inner_w * 0.50).clamp(130.0, 230.0))
                                                                .show_ui(ui, |ui| {
                                                                    if ui.selectable_label(self.settings.selected_mic_device.is_empty(), "Mặc định hệ thống").clicked() {
                                                                        self.settings.selected_mic_device.clear();
                                                                        crate::media::set_selected_mic_device("");
                                                                        self.settings.save();
                                                                    }
                                                                    for m in &mics {
                                                                        if ui.selectable_label(self.settings.selected_mic_device == *m, m).clicked() {
                                                                            self.settings.selected_mic_device = m.clone();
                                                                            crate::media::set_selected_mic_device(m);
                                                                            self.settings.save();
                                                                        }
                                                                    }
                                                                });
                                                        });
                                                    });
                                                    ui.add_space(8.0);
                                                    ui.horizontal(|ui| {
                                                        ui.label(RichText::new(format!("{} Máy ảnh (Camera):", lucide::VIDEO)).color(pal.text_primary).size(13.0));
                                                        ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                                            let cur_cam_lbl = if self.settings.selected_camera_device.is_empty() {
                                                                cams.first().map(String::as_str).unwrap_or("Mặc định hệ thống")
                                                            } else {
                                                                &self.settings.selected_camera_device
                                                            };
                                                            egui::ComboBox::from_id_salt("setting_cam_device_combo")
                                                                .selected_text(truncate_chars(cur_cam_lbl, 30))
                                                                .width((inner_w * 0.50).clamp(130.0, 230.0))
                                                                .show_ui(ui, |ui| {
                                                                    if ui.selectable_label(self.settings.selected_camera_device.is_empty(), "Tự động (Camera đầu tiên)").clicked() {
                                                                        self.settings.selected_camera_device.clear();
                                                                        crate::media::set_selected_camera_device("");
                                                                        self.settings.save();
                                                                    }
                                                                    for c in &cams {
                                                                        if ui.selectable_label(self.settings.selected_camera_device == *c, c).clicked() {
                                                                            self.settings.selected_camera_device = c.clone();
                                                                            crate::media::set_selected_camera_device(c);
                                                                            self.settings.save();
                                                                        }
                                                                    }
                                                                });
                                                        });
                                                    });
                                                    ui.add_space(6.0);
                                                    ui.add_space(8.0);
                                                    ui.horizontal(|ui| {
                                                        ui.label(RichText::new("Độ nhạy Micro (Gain):").color(pal.text_primary).size(12.8));
                                                        let mut gain_val = self.settings.mic_gain_percent;
                                                        if ui.add(egui::Slider::new(&mut gain_val, 0..=200).suffix("%")).changed() {
                                                            self.settings.mic_gain_percent = gain_val;
                                                            crate::media::set_mic_gain_percent(gain_val);
                                                            self.settings.save();
                                                        }
                                                    });
                                                    ui.add_space(4.0);
                                                    ui.horizontal(|ui| {
                                                        ui.label(RichText::new("Mức tín hiệu Mic:").color(pal.text_secondary).size(12.0));
                                                        let lvl = (crate::media::mic_level_permille() as f32 / 1000.0).clamp(0.0, 1.0);
                                                        let (m_rect, _) = ui.allocate_exact_size(Vec2::new(180.0, 8.0), Sense::hover());
                                                        ui.painter().rect_filled(m_rect, Rounding::same(4.0), pal.bg_input);
                                                        if lvl > 0.005 {
                                                            let fill_w = (m_rect.width() * lvl).max(4.0);
                                                            let fill_col = if lvl > 0.85 {
                                                                pal.danger
                                                            } else if lvl > 0.6 {
                                                                pal.warning
                                                            } else {
                                                                pal.accent_online
                                                            };
                                                            ui.painter().rect_filled(
                                                                Rect::from_min_size(m_rect.min, Vec2::new(fill_w, m_rect.height())),
                                                                Rounding::same(4.0),
                                                                fill_col,
                                                            );
                                                        }
                                                    });
                                                    ui.horizontal_wrapped(|ui| {
                                                        if ui
                                                            .small_button(format!(
                                                                "{} Mẫu phản hồi nhanh khi từ chối cuộc gọi",
                                                                lucide::MESSAGE_CIRCLE
                                                            ))
                                                            .on_hover_cursor(CursorIcon::PointingHand)
                                                            .clicked()
                                                        {
                                                            self.settings_tab = SettingsTab::Messages;
                                                        }
                                                        if ui
                                                            .small_button(format!(
                                                                "{} Quét lại thiết bị",
                                                                lucide::REFRESH
                                                            ))
                                                            .on_hover_cursor(CursorIcon::PointingHand)
                                                            .clicked()
                                                        {
                                                            let _ = crate::media::list_media_devices(true);
                                                        }
                                                    });
                                                });
                                            ui.add_space(14.0);

                                            ui.label(
                                                RichText::new(format!(
                                                    "{} Cấu hình Proxy & Đa tài khoản (Multi-Zalo PC)",
                                                    lucide::GLOBE
                                                ))
                                                .color(pal.text_primary)
                                                .size(13.5)
                                                .strong(),
                                            );
                                            ui.add_space(6.0);
                                            egui::Frame::none()
                                                .fill(pal.bg_elevated)
                                                .stroke(Stroke::new(1.0_f32, pal.border))
                                                .rounding(Rounding::same(8.0))
                                                .inner_margin(Margin::symmetric(14.0, 10.0))
                                                .show(ui, |ui| {
                                                    ui.vertical(|ui| {
                                                        ui.label(
                                                            RichText::new(
                                                                "Định tuyến lưu lượng Zalo qua Proxy (http://, https://, socks5://) và mở nhiều cửa sổ Zalo độc lập với thư mục dữ liệu riêng (--profile <tên>).",
                                                            )
                                                            .color(pal.text_secondary)
                                                            .size(12.0),
                                                        );
                                                        ui.add_space(8.0);
                                                        ui.label(RichText::new("Địa chỉ Proxy (để trống nếu kết nối trực tiếp):").color(pal.text_primary).size(12.6));
                                                        ui.add_space(4.0);
                                                        ui.horizontal_wrapped(|ui| {
                                                            ui.add(
                                                                egui::TextEdit::singleline(&mut self.settings.proxy_url)
                                                                    .hint_text("http://user:pass@ip:port hoặc socks5://127.0.0.1:1080")
                                                                    .desired_width((inner_w - 190.0).max(140.0)),
                                                            );
                                                            if ui.button("Áp dụng Proxy").clicked() {
                                                                act.apply_proxy_now = true;
                                                            }
                                                            if ui.button("Tắt").clicked() {
                                                                act.clear_proxy_now = true;
                                                            }
                                                        });
                                                        ui.add_space(10.0);
                                                        ui.separator();
                                                        ui.add_space(6.0);
                                                        ui.label(RichText::new("Chạy thêm tài khoản Zalo mới trên PC (Multi-Profile):").color(pal.text_primary).size(12.6));
                                                        ui.add_space(4.0);
                                                        ui.horizontal_wrapped(|ui| {
                                                            ui.label(RichText::new("Tên Profile:").color(pal.text_secondary).size(12.2));
                                                            ui.add(
                                                                egui::TextEdit::singleline(&mut self.settings.multi_profile_name)
                                                                    .hint_text("acc2, work, shop1…")
                                                                    .desired_width(120.0),
                                                            );
                                                            if ui
                                                                .button(RichText::new(format!("{} Mở thêm cửa sổ Zalo mới", lucide::PLUS)).strong())
                                                                .clicked()
                                                            {
                                                                act.spawn_multi_zalo = true;
                                                            }
                                                        });
                                                    });
                                                });
                                        }
                                        SettingsTab::Account => {
                                            ui.label(RichText::new("Tài khoản đang đăng nhập").color(pal.text_primary).size(13.5).strong());
                                            ui.add_space(6.0);
                                            egui::Frame::none()
                                                .fill(pal.bg_elevated)
                                                .stroke(Stroke::new(1.0_f32, pal.border))
                                                .rounding(Rounding::same(10.0))
                                                .inner_margin(Margin::same(14.0))
                                                .show(ui, |ui| {
                                                    ui.horizontal(|ui| {
                                                        let (av_r, _) = ui.allocate_exact_size(Vec2::splat(46.0), Sense::hover());
                                                        let user_disp = if self.user_name.is_empty() {
                                                            "Người dùng Zalo"
                                                        } else {
                                                            &self.user_name
                                                        };
                                                        paint_user_avatar(
                                                            ui.painter(),
                                                            av_r.center(),
                                                            23.0,
                                                            user_disp,
                                                            false,
                                                            self.user_avatar.as_deref(),
                                                            &self.sticker_textures,
                                                            &mut self.loading_stickers,
                                                        );
                                                        ui.add_space(10.0);
                                                        ui.vertical(|ui| {
                                                            ui.label(RichText::new(user_disp).size(15.0).color(pal.text_primary).strong());
                                                            ui.horizontal(|ui| {
                                                                let (dr, _) = ui.allocate_exact_size(Vec2::splat(8.0), Sense::hover());
                                                                ui.painter().circle_filled(dr.center(), 3.5, pal.accent_online);
                                                                ui.label(RichText::new("Đang hoạt động").size(11.5).color(pal.accent_online));
                                                                if !self.user_uin.is_empty() {
                                                                    ui.label(RichText::new(format!("· UIN: {}", self.user_uin)).size(11.0).color(pal.text_muted));
                                                                }
                                                            });
                                                        });
                                                        ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                                            let lo_btn = egui::Button::new(
                                                                RichText::new("Đăng xuất tài khoản này")
                                                                    .size(12.0)
                                                                    .color(pal.danger)
                                                                    .strong(),
                                                            )
                                                            .fill(pal.danger.linear_multiply(0.12))
                                                            .stroke(Stroke::new(1.0_f32, pal.danger.linear_multiply(0.35)))
                                                            .rounding(Rounding::same(7.0));
                                                            if ui.add(lo_btn).on_hover_cursor(CursorIcon::PointingHand).clicked() {
                                                                act.do_logout = true;
                                                            }
                                                        });
                                                    });
                                                });

                                            ui.add_space(18.0);
                                            ui.horizontal(|ui| {
                                                ui.label(RichText::new("Danh sách tài khoản (Đa tài khoản)").color(pal.text_primary).size(13.5).strong());
                                                ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                                    let add_btn = egui::Button::new(
                                                        RichText::new(format!("{} Thêm tài khoản mới (Quét QR)", lucide::PLUS))
                                                            .size(11.8)
                                                            .color(pal.primary_hover)
                                                            .strong(),
                                                    )
                                                    .fill(pal.primary.linear_multiply(0.14))
                                                    .stroke(Stroke::new(1.0_f32, pal.primary.linear_multiply(0.4)))
                                                    .rounding(Rounding::same(7.0));
                                                    if ui.add(add_btn).on_hover_cursor(CursorIcon::PointingHand).clicked() {
                                                        act.add_new_account = true;
                                                    }
                                                });
                                            });
                                            ui.add_space(2.0);
                                            ui.label(
                                                RichText::new("Chuyển đổi tức thì giữa các tài khoản Zalo đã lưu trên máy mà không cần quét lại mã QR.")
                                                    .size(11.8)
                                                    .color(pal.text_secondary),
                                            );
                                            ui.add_space(10.0);

                                            let saved = crate::account_manager::list_saved_accounts(&self.user_uin);
                                            let mut delete_target: Option<String> = None;

                                            for acc in &saved {
                                                egui::Frame::none()
                                                    .fill(if acc.is_current { pal.bg_selected } else { pal.bg_elevated })
                                                    .stroke(Stroke::new(1.0_f32, if acc.is_current { pal.primary } else { pal.border }))
                                                    .rounding(Rounding::same(8.0))
                                                    .inner_margin(Margin::symmetric(14.0, 10.0))
                                                    .show(ui, |ui| {
                                                        ui.horizontal(|ui| {
                                                            let (av_r, _) = ui.allocate_exact_size(Vec2::splat(34.0), Sense::hover());
                                                            paint_user_avatar(
                                                                ui.painter(),
                                                                av_r.center(),
                                                                17.0,
                                                                &acc.display_name,
                                                                false,
                                                                acc.avatar.as_deref(),
                                                                &self.sticker_textures,
                                                                &mut self.loading_stickers,
                                                            );
                                                            ui.add_space(8.0);
                                                            ui.vertical(|ui| {
                                                                ui.label(RichText::new(&acc.display_name).size(13.2).color(pal.text_primary).strong());
                                                                ui.label(RichText::new(format!("UIN: {}", acc.uin)).size(10.8).color(pal.text_muted));
                                                            });
                                                            ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                                                if acc.is_current {
                                                                    ui.label(RichText::new(format!("{} Đang sử dụng", lucide::CHECK)).size(11.5).color(pal.accent_online).strong());
                                                                } else {
                                                                    let del_btn = egui::Button::new(
                                                                        RichText::new(lucide::X).size(12.0).color(pal.text_muted)
                                                                    )
                                                                    .fill(Color32::TRANSPARENT);
                                                                    if ui.add(del_btn).on_hover_cursor(CursorIcon::PointingHand).on_hover_text("Xoá tài khoản này khỏi danh sách lưu").clicked() {
                                                                        delete_target = Some(acc.uin.clone());
                                                                    }
                                                                    let sw_btn = egui::Button::new(
                                                                        RichText::new(format!("{} Chuyển sang", lucide::REFRESH))
                                                                            .size(11.5)
                                                                            .color(pal.primary_hover)
                                                                            .strong(),
                                                                    )
                                                                    .fill(pal.primary.linear_multiply(0.12))
                                                                    .stroke(Stroke::new(1.0_f32, pal.primary.linear_multiply(0.35)))
                                                                    .rounding(Rounding::same(6.0));
                                                                    if ui.add(sw_btn).on_hover_cursor(CursorIcon::PointingHand).clicked() {
                                                                        act.switch_to_uin = Some(acc.uin.clone());
                                                                    }
                                                                }
                                                            });
                                                        });
                                                    });
                                                ui.add_space(6.0);
                                            }

                                            if let Some(target) = delete_target {
                                                let _ = crate::account_manager::delete_saved_account(&target);
                                            }

                                            ui.add_space(14.0);
                                            ui.separator();
                                            ui.add_space(10.0);
                                            ui.label(
                                                RichText::new(format!(
                                                    "{} Chạy song song nhiều cửa sổ (Multi-Instance)",
                                                    lucide::ROCKET
                                                ))
                                                .color(pal.text_primary)
                                                .size(13.0)
                                                .strong(),
                                            );
                                            ui.add_space(2.0);
                                            ui.label(RichText::new("Mở thêm một cửa sổ Zalo độc lập với hồ sơ riêng (hoạt động song song cùng lúc trên màn hình).").color(pal.text_secondary).size(11.8));
                                            ui.add_space(6.0);
                                            ui.horizontal_wrapped(|ui| {
                                                ui.label(RichText::new("Tên hồ sơ:").color(pal.text_secondary).size(12.0));
                                                ui.add(
                                                    egui::TextEdit::singleline(&mut self.settings.multi_profile_name)
                                                        .hint_text("acc2, work, shop…")
                                                        .desired_width(130.0),
                                                );
                                                if ui.button(RichText::new(format!("{} Mở cửa sổ Zalo mới", lucide::PLUS)).strong()).clicked() {
                                                    act.spawn_multi_zalo = true;
                                                }
                                            });
                                        }
                                        SettingsTab::Privacy => {
                                            ui.label(RichText::new("Cá nhân").color(pal.text_primary).size(13.5).strong());
                                            ui.add_space(6.0);
                                            egui::Frame::none()
                                                .fill(pal.bg_elevated)
                                                .stroke(Stroke::new(1.0_f32, pal.border))
                                                .rounding(Rounding::same(8.0))
                                                .inner_margin(Margin::symmetric(14.0, 10.0))
                                                .show(ui, |ui| {
                                                    ui.horizontal(|ui| {
                                                        ui.label(RichText::new("Hiện ngày sinh").color(pal.text_primary).size(13.2));
                                                        ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                                            egui::ComboBox::from_id_salt("setting_bday_combo")
                                                                .selected_text(&self.settings.show_birthday)
                                                                .width(170.0)
                                                                .show_ui(ui, |ui| {
                                                                    ui.selectable_value(&mut self.settings.show_birthday, "Không hiện".into(), "Không hiện");
                                                                    ui.selectable_value(&mut self.settings.show_birthday, "Hiện ngày, tháng, năm".into(), "Hiện ngày, tháng, năm");
                                                                    ui.selectable_value(&mut self.settings.show_birthday, "Hiện ngày, tháng".into(), "Hiện ngày, tháng");
                                                                });
                                                        });
                                                    });
                                                    ui.add_space(8.0);
                                                    ui.horizontal(|ui| {
                                                        ui.label(RichText::new("Hiển thị trạng thái truy cập").color(pal.text_primary).size(13.2));
                                                        ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                                            render_toggle_switch(ui, &mut self.settings.show_online_status, pal);
                                                        });
                                                    });
                                                });
                                            ui.add_space(14.0);
                                            ui.label(RichText::new("Chủ động Quyền riêng tư (Chặn gửi trạng thái lên máy chủ — Ctrl+Shift+P)").color(pal.text_primary).size(13.5).strong());
                                            ui.add_space(6.0);
                                            egui::Frame::none()
                                                .fill(pal.bg_elevated)
                                                .stroke(Stroke::new(1.0_f32, pal.border))
                                                .rounding(Rounding::same(8.0))
                                                .inner_margin(Margin::symmetric(14.0, 10.0))
                                                .show(ui, |ui| {
                                                    let mut priv_changed = false;
                                                    ui.horizontal(|ui| {
                                                        ui.vertical(|ui| {
                                                            ui.label(RichText::new("Ẩn trạng thái \"Đang soạn tin\" (Block Typing)").color(pal.text_primary).size(13.2).strong());
                                                            ui.label(RichText::new("Chặn gửi gói tin /api/message/typing & /api/group/typing khi bạn gõ phím (bạn vẫn thấy khi người khác đang gõ).").color(pal.text_secondary).size(11.5));
                                                        });
                                                        ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                                            if render_toggle_switch(ui, &mut self.settings.block_typing, pal).changed() {
                                                                priv_changed = true;
                                                            }
                                                        });
                                                    });
                                                    ui.add_space(6.0);
                                                    ui.separator();
                                                    ui.add_space(6.0);
                                                    ui.horizontal(|ui| {
                                                        ui.vertical(|ui| {
                                                            ui.label(RichText::new("Ẩn trạng thái \"Đã nhận\" (Block Delivered)").color(pal.text_primary).size(13.2).strong());
                                                            ui.label(RichText::new("Chặn gửi xác nhận /api/message/deliveredv2 & /api/group/deliveredv2 về máy chủ.").color(pal.text_secondary).size(11.5));
                                                        });
                                                        ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                                            if render_toggle_switch(ui, &mut self.settings.block_delivered, pal).changed() {
                                                                priv_changed = true;
                                                            }
                                                        });
                                                    });
                                                    ui.add_space(6.0);
                                                    ui.separator();
                                                    ui.add_space(6.0);
                                                    ui.horizontal(|ui| {
                                                        ui.vertical(|ui| {
                                                            ui.label(RichText::new("Ẩn trạng thái \"Đã xem\" (Block Seen)").color(pal.text_primary).size(13.2).strong());
                                                            ui.label(RichText::new("Đọc tin nhắn thoải mái mà không gửi xác nhận /api/message/seenv2 & /api/group/seenv2.").color(pal.text_secondary).size(11.5));
                                                        });
                                                        ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                                            if render_toggle_switch(ui, &mut self.settings.block_seen, pal).changed() {
                                                                priv_changed = true;
                                                            }
                                                        });
                                                    });
                                                    if priv_changed {
                                                        self.settings.show_seen_status = !self.settings.block_seen;
                                                        crate::session::set_privacy_blocker(
                                                            self.settings.block_typing,
                                                            self.settings.block_delivered,
                                                            self.settings.block_seen,
                                                        );
                                                        self.settings.save();
                                                    }
                                                });
                                            ui.add_space(14.0);

                                            ui.label(RichText::new("Tin nhắn và cuộc gọi").color(pal.text_primary).size(13.5).strong());
                                            ui.add_space(6.0);
                                            egui::Frame::none()
                                                .fill(pal.bg_elevated)
                                                .stroke(Stroke::new(1.0_f32, pal.border))
                                                .rounding(Rounding::same(8.0))
                                                .inner_margin(Margin::symmetric(14.0, 10.0))
                                                .show(ui, |ui| {
                                                    ui.horizontal(|ui| {
                                                        ui.label(RichText::new("Hiện trạng thái \"Đã xem\"").color(pal.text_primary).size(13.2));
                                                        ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                                            render_toggle_switch(ui, &mut self.settings.show_seen_status, pal);
                                                        });
                                                    });
                                                    ui.add_space(8.0);
                                                    ui.horizontal(|ui| {
                                                        ui.label(RichText::new("Cho phép nhắn tin").color(pal.text_primary).size(13.2));
                                                        ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                                            egui::ComboBox::from_id_salt("setting_msg_stranger_combo")
                                                                .selected_text(&self.settings.allow_message_from)
                                                                .width(170.0)
                                                                .show_ui(ui, |ui| {
                                                                    ui.selectable_value(&mut self.settings.allow_message_from, "Tất cả mọi người".into(), "Tất cả mọi người");
                                                                    ui.selectable_value(&mut self.settings.allow_message_from, "Chỉ bạn bè".into(), "Chỉ bạn bè");
                                                                });
                                                        });
                                                    });
                                                    ui.add_space(8.0);
                                                    ui.horizontal(|ui| {
                                                        ui.label(RichText::new("Cho phép gọi điện").color(pal.text_primary).size(13.2));
                                                        ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                                            egui::ComboBox::from_id_salt("setting_call_stranger_combo")
                                                                .selected_text(&self.settings.allow_call_from)
                                                                .width(220.0)
                                                                .show_ui(ui, |ui| {
                                                                    ui.selectable_value(&mut self.settings.allow_call_from, "Bạn bè và người lạ từng liên hệ".into(), "Bạn bè và người lạ từng liên hệ");
                                                                    ui.selectable_value(&mut self.settings.allow_call_from, "Tất cả mọi người".into(), "Tất cả mọi người");
                                                                    ui.selectable_value(&mut self.settings.allow_call_from, "Chỉ bạn bè".into(), "Chỉ bạn bè");
                                                                });
                                                        });
                                                    });
                                                });
                                            ui.add_space(14.0);

                                            ui.label(RichText::new("Nguồn tìm kiếm").color(pal.text_primary).size(13.5).strong());
                                            ui.add_space(6.0);
                                            egui::Frame::none()
                                                .fill(pal.bg_elevated)
                                                .stroke(Stroke::new(1.0_f32, pal.border))
                                                .rounding(Rounding::same(8.0))
                                                .inner_margin(Margin::symmetric(14.0, 10.0))
                                                .show(ui, |ui| {
                                                    ui.horizontal(|ui| {
                                                        ui.label(RichText::new("Cho phép người lạ tìm thấy và kết bạn qua số điện thoại").color(pal.text_primary).size(13.0));
                                                        ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                                            render_toggle_switch(ui, &mut self.settings.allow_search_by_phone, pal);
                                                        });
                                                    });
                                                    ui.add_space(8.0);
                                                    ui.separator();
                                                    ui.add_space(6.0);
                                                    ui.label(RichText::new("Cho phép người lạ kết bạn").color(pal.text_secondary).size(12.2));
                                                    ui.add_space(4.0);
                                                    ui.checkbox(&mut self.settings.friend_src_qr, "Mã QR của tôi");
                                                    ui.checkbox(&mut self.settings.friend_src_group, "Nhóm chung");
                                                    ui.checkbox(&mut self.settings.friend_src_card, "Danh thiếp Zalo");
                                                });
                                        }
                                        SettingsTab::Sync => {
                                            ui.label(
                                                RichText::new(format!(
                                                    "{} Đồng bộ tin nhắn từ điện thoại (1-1 & Nhóm)",
                                                    lucide::SMARTPHONE
                                                ))
                                                .color(pal.text_primary)
                                                .size(13.5)
                                                .strong(),
                                            );
                                            ui.add_space(6.0);
                                            egui::Frame::none()
                                                .fill(pal.bg_elevated)
                                                .stroke(Stroke::new(1.0_f32, pal.border))
                                                .rounding(Rounding::same(10.0))
                                                .inner_margin(Margin::same(14.0))
                                                .show(ui, |ui| {
                                                    ui.vertical(|ui| {
                                                        ui.label(
                                                            RichText::new(
                                                                "Gửi yêu cầu đồng bộ trực tiếp tới ứng dụng Zalo trên điện thoại (pull_mobile_msg / transfer-sync-v2) để kéo toàn bộ tin nhắn 1-1 và nhóm gần đây từ điện thoại về máy tính.",
                                                            )
                                                            .color(pal.text_primary)
                                                            .size(13.0),
                                                        );
                                                        ui.add_space(4.0);
                                                        ui.label(
                                                            RichText::new(
                                                                "Lưu ý: Kéo tin nhắn 1-1 trực tiếp từ điện thoại qua mạng phụ thuộc giao thức xác thực thiết bị Zalo. Với tin nhắn nhóm và Cloud của tôi, bạn có thể bấm 'Đồng bộ Nhóm & Cloud ngay' bên dưới; hoặc dùng mục 'Nhập lịch sử' từ file sao lưu Zalo.",
                                                            )
                                                            .color(pal.text_secondary)
                                                            .size(12.2),
                                                        );
                                                        ui.add_space(10.0);
                                                        if crate::history_sync::PHONE_SYNC_RUNNING
                                                            .load(std::sync::atomic::Ordering::Relaxed)
                                                        {
                                                            ui.add(
                                                                egui::ProgressBar::new(
                                                                    self.phone_sync_progress.clamp(0.05, 1.0),
                                                                )
                                                                .text(&self.phone_sync_status)
                                                                .animate(true),
                                                            );
                                                            ui.add_space(6.0);
                                                            if ui
                                                                .button(RichText::new("Dừng đồng bộ điện thoại").size(13.0))
                                                                .clicked()
                                                            {
                                                                crate::history_sync::PHONE_SYNC_CANCEL.store(
                                                                    true,
                                                                    std::sync::atomic::Ordering::Relaxed,
                                                                );
                                                            }
                                                        } else {
                                                            if ui
                                                                .button(
                                                                    RichText::new(format!(
                                                                        "{} Đồng bộ tin nhắn từ điện thoại ngay",
                                                                        lucide::REFRESH
                                                                    ))
                                                                    .size(13.0)
                                                                    .strong(),
                                                                )
                                                                .clicked()
                                                            {
                                                                act.trigger_phone_sync = true;
                                                            }
                                                            if !self.phone_sync_status.is_empty() {
                                                                ui.add_space(6.0);
                                                                ui.label(
                                                                    RichText::new(&self.phone_sync_status)
                                                                        .color(pal.text_secondary)
                                                                        .size(12.0),
                                                                );
                                                            }
                                                        }
                                                    });
                                                });
                                            ui.add_space(16.0);
                                            ui.label(
                                                RichText::new(format!(
                                                    "{} Đồng bộ lịch sử Nhóm & Cloud từ máy chủ",
                                                    lucide::CLOUD_DOWNLOAD
                                                ))
                                                .color(pal.text_primary)
                                                .size(13.5)
                                                .strong(),
                                            );
                                            ui.add_space(6.0);
                                            egui::Frame::none()
                                                .fill(pal.bg_elevated)
                                                .stroke(Stroke::new(1.0_f32, pal.border))
                                                .rounding(Rounding::same(10.0))
                                                .inner_margin(Margin::same(14.0))
                                                .show(ui, |ui| {
                                                    ui.vertical(|ui| {
                                                        ui.label(RichText::new("Tải lịch sử cũ của các nhóm và Cloud của tôi từ máy chủ Zalo về zalo_history.db, mỗi lần tối đa 1.000 tin/hội thoại; bấm lần nữa để lùi xa hơn.").color(pal.text_primary).size(13.0));
                                                        ui.add_space(4.0);
                                                        if ui
                                                            .add(
                                                                egui::Label::new(
                                                                    RichText::new(format!(
                                                                        "Tìm hiểu chi tiết cơ chế đồng bộ trong docs/TINH_NANG.md {}",
                                                                        lucide::EXTERNAL_LINK
                                                                    ))
                                                                    .size(11.8)
                                                                    .color(pal.primary_hover),
                                                                )
                                                                .sense(Sense::click()),
                                                            )
                                                            .on_hover_cursor(CursorIcon::PointingHand)
                                                            .clicked()
                                                        {
                                                            open_external_url("https://github.com/ctdoteam1110/ctdozlite/blob/main/docs/TINH_NANG.md");
                                                        }
                                                        ui.add_space(4.0);
                                                        let total_msgs: usize = self.threads.iter().map(|t| t.messages.len()).sum();
                                                        ui.label(RichText::new(format!("Hiện có {} hội thoại ({total_msgs} tin nhắn) trong bộ nhớ.", self.threads.len())).color(pal.text_secondary).size(12.2));
                                                        ui.add_space(10.0);
                                                        if crate::history_sync::RUNNING.load(std::sync::atomic::Ordering::Relaxed) {
                                                            ui.label(RichText::new(&self.status_msg).color(pal.primary_hover).size(12.5));
                                                            if ui.button(RichText::new("Dừng").size(13.0)).clicked() {
                                                                crate::history_sync::CANCEL.store(true, std::sync::atomic::Ordering::Relaxed);
                                                            }
                                                        } else if ui.button(RichText::new(format!("{} Đồng bộ Nhóm & Cloud ngay", lucide::REFRESH)).size(13.0).strong()).clicked() {
                                                            act.trigger_sync = true;
                                                        }
                                                    });
                                                });
                                            ui.add_space(16.0);
                                            ui.label(RichText::new("Di chuyển / Nhập lịch sử tin nhắn có sẵn (Migrate)").color(pal.text_primary).size(13.5).strong());
                                            ui.add_space(6.0);
                                            egui::Frame::none()
                                                .fill(pal.bg_elevated)
                                                .stroke(Stroke::new(1.0_f32, pal.border))
                                                .rounding(Rounding::same(10.0))
                                                .inner_margin(Margin::same(14.0))
                                                .show(ui, |ui| {
                                                    ui.vertical(|ui| {
                                                        ui.label(RichText::new("Nhập lịch sử tin nhắn từ bản sao lưu SQLite (.db / .sqlite) hoặc JSON (threads_cache.json / bản xuất lịch sử) vào kho lịch sử hiện tại mà không làm mất tin nhắn đang có.").color(pal.text_secondary).size(12.2));
                                                        ui.add_space(8.0);
                                                        if ui.button(RichText::new("Chọn file lịch sử (.db / .sqlite / .json) để nhập…").size(12.8).strong()).clicked() {
                                                            act.pick_migrate_file = true;
                                                        }
                                                    });
                                                });
                                        }
                                        SettingsTab::Appearance => {
                                            ui.label(RichText::new("Cài đặt giao diện").color(pal.text_primary).size(13.5).strong());
                                            ui.add_space(8.0);
                                            egui::Frame::none()
                                                .fill(pal.bg_elevated)
                                                .stroke(Stroke::new(1.0_f32, pal.border))
                                                .rounding(Rounding::same(10.0))
                                                .inner_margin(Margin::symmetric(14.0, 14.0))
                                                .show(ui, |ui| {
                                                    let card_avail_w = (inner_w - 28.0).max(200.0);
                                                    ui.set_min_width(card_avail_w);
                                                    ui.set_max_width(card_avail_w);
                                                    ui.horizontal_wrapped(|ui| {
                                                        let col_w = 132.0_f32;
                                                        let gap = 14.0_f32;
                                                        ui.spacing_mut().item_spacing = Vec2::splat(gap);
                                                        for (mode_key, label, is_dark_val) in [
                                                            ("light", "Sáng", false),
                                                            ("dark", "Tối", true),
                                                            ("system", "Hệ Thống", true),
                                                        ] {
                                                            let selected =
                                                                self.settings.theme_mode == mode_key;
                                                            ui.allocate_ui_with_layout(
                                                                Vec2::new(col_w, 114.0),
                                                                Layout::top_down(Align::Center),
                                                                |ui| {
                                                                    let (card_r, c_resp) =
                                                                        ui.allocate_exact_size(
                                                                            Vec2::new(132.0, 84.0),
                                                                            Sense::click(),
                                                                        );
                                                                    let stroke_col = if selected {
                                                                        pal.primary_hover
                                                                    } else if c_resp.hovered() {
                                                                        pal.text_secondary
                                                                    } else {
                                                                        pal.border
                                                                    };
                                                                    if mode_key == "system" {
                                                                        let left_half =
                                                                            Rect::from_min_max(
                                                                                card_r.min,
                                                                                Pos2::new(
                                                                                    card_r.center().x,
                                                                                    card_r.max.y,
                                                                                ),
                                                                            );
                                                                        let right_half =
                                                                            Rect::from_min_max(
                                                                                Pos2::new(
                                                                                    card_r.center().x,
                                                                                    card_r.min.y,
                                                                                ),
                                                                                card_r.max,
                                                                            );
                                                                        ui.painter().rect_filled(
                                                                            left_half,
                                                                            Rounding {
                                                                                nw: 8.0,
                                                                                sw: 8.0,
                                                                                ne: 0.0,
                                                                                se: 0.0,
                                                                            },
                                                                            Color32::from_rgb(
                                                                                235, 242, 252,
                                                                            ),
                                                                        );
                                                                        ui.painter().rect_filled(
                                                                            right_half,
                                                                            Rounding {
                                                                                nw: 0.0,
                                                                                sw: 0.0,
                                                                                ne: 8.0,
                                                                                se: 8.0,
                                                                            },
                                                                            Color32::from_rgb(
                                                                                24, 26, 31,
                                                                            ),
                                                                        );
                                                                    } else {
                                                                        ui.painter().rect_filled(
                                                                            card_r,
                                                                            Rounding::same(8.0),
                                                                            if is_dark_val {
                                                                                Color32::from_rgb(
                                                                                    24, 26, 31,
                                                                                )
                                                                            } else {
                                                                                Color32::from_rgb(
                                                                                    235, 242, 252,
                                                                                )
                                                                            },
                                                                        );
                                                                    }
                                                                    ui.painter().rect_stroke(
                                                                        card_r,
                                                                        Rounding::same(8.0),
                                                                        Stroke::new(
                                                                            if selected {
                                                                                2.0_f32
                                                                            } else {
                                                                                1.0_f32
                                                                            },
                                                                            stroke_col,
                                                                        ),
                                                                    );
                                                                    ui.painter().circle_filled(
                                                                        Pos2::new(
                                                                            card_r.left() + 18.0,
                                                                            card_r.top() + 22.0,
                                                                        ),
                                                                        5.5,
                                                                        Color32::from_rgb(
                                                                            82, 139, 255,
                                                                        ),
                                                                    );
                                                                    let mock_in = Rect::from_min_size(
                                                                        Pos2::new(
                                                                            card_r.left() + 30.0,
                                                                            card_r.top() + 15.0,
                                                                        ),
                                                                        Vec2::new(62.0, 22.0),
                                                                    );
                                                                    ui.painter().rect_filled(
                                                                        mock_in,
                                                                        Rounding::same(4.0),
                                                                        if is_dark_val
                                                                            && mode_key != "light"
                                                                        {
                                                                            Color32::from_rgb(
                                                                                76, 82, 94,
                                                                            )
                                                                        } else {
                                                                            Color32::WHITE
                                                                        },
                                                                    );
                                                                    let mock_out =
                                                                        Rect::from_min_size(
                                                                            Pos2::new(
                                                                                card_r.right() - 56.0,
                                                                                card_r.bottom() - 28.0,
                                                                            ),
                                                                            Vec2::new(44.0, 18.0),
                                                                        );
                                                                    ui.painter().rect_filled(
                                                                        mock_out,
                                                                        Rounding::same(4.0),
                                                                        Color32::from_rgb(
                                                                            82, 139, 255,
                                                                        ),
                                                                    );

                                                                    ui.add_space(6.0);
                                                                    let r_clicked =
                                                                        ui.radio(selected, label).clicked();
                                                                    if c_resp
                                                                        .on_hover_cursor(
                                                                            CursorIcon::PointingHand,
                                                                        )
                                                                        .clicked()
                                                                        || r_clicked
                                                                    {
                                                                        self.settings.theme_mode =
                                                                            mode_key.into();
                                                                        self.dark_mode = is_dark_val;
                                                                        act.theme_switched = true;
                                                                    }
                                                                },
                                                            );
                                                        }
                                                    });
                                                });
                                            ui.add_space(16.0);

                                            ui.label(RichText::new("Hình nền chat").color(pal.text_primary).size(13.5).strong());
                                            ui.add_space(6.0);
                                            egui::Frame::none()
                                                .fill(pal.bg_elevated)
                                                .stroke(Stroke::new(1.0_f32, pal.border))
                                                .rounding(Rounding::same(8.0))
                                                .inner_margin(Margin::symmetric(14.0, 10.0))
                                                .show(ui, |ui| {
                                                    ui.horizontal(|ui| {
                                                        ui.label(RichText::new("Sử dụng Avatar làm hình nền").color(pal.text_primary).size(13.2));
                                                        ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                                            render_toggle_switch(ui, &mut self.settings.use_avatar_as_wallpaper, pal);
                                                        });
                                                    });
                                                });
                                            ui.add_space(16.0);
                                            ui.label(RichText::new("Theme & Sticker Pack tùy chỉnh (Plugin JSON)").color(pal.text_primary).size(13.5).strong());
                                            ui.add_space(6.0);
                                            egui::Frame::none()
                                                .fill(pal.bg_elevated)
                                                .stroke(Stroke::new(1.0_f32, pal.border))
                                                .rounding(Rounding::same(8.0))
                                                .inner_margin(Margin::symmetric(14.0, 10.0))
                                                .show(ui, |ui| {
                                                    ui.label(RichText::new("Tùy biến bảng màu qua file theme.json hoặc nạp bộ nhãn dán riêng qua custom_stickers.json.").color(pal.text_secondary).size(12.0));
                                                    ui.add_space(8.0);
                                                    ui.horizontal_wrapped(|ui| {
                                                        if ui.button("Xuất mẫu theme.json").clicked() {
                                                            act.export_theme_tpl = true;
                                                        }
                                                        if ui.button("Tải lại theme.json").clicked() {
                                                            act.reload_theme_json = true;
                                                        }
                                                        if ui.button("Xuất mẫu custom_stickers.json").clicked() {
                                                            act.export_sticker_tpl = true;
                                                        }
                                                        if ui.button("Nạp lại Sticker Pack").clicked() {
                                                            act.reload_sticker_json = true;
                                                        }
                                                    });
                                                });
                                        }
                                        SettingsTab::Notifications => {
                                            #[cfg(target_os = "macos")]
                                            {
                                                ui.label(RichText::new("Quyền thông báo macOS").strong());
                                                let authorization = &self.notification_authorization;
                                                ui.label(if authorization.pending.is_some() {
                                                    "Đang kiểm tra quyền…".to_owned()
                                                } else {
                                                    match &authorization.result {
                                                        Some(Ok(status)) => status.label().to_owned(),
                                                        Some(Err(error)) => error.to_string(),
                                                        None => "Chưa kiểm tra quyền thông báo".to_owned(),
                                                    }
                                                });
                                                ui.label("Quyền hệ điều hành tách biệt với cài đặt Bật/Tắt bên dưới. Chưa bật gửi thông báo native.");
                                                let ready = authorization.pending.is_none();
                                                ui.horizontal(|ui| {
                                                    let refresh = ui.add_enabled(ready, egui::Button::new("Đọc lại quyền")).clicked();
                                                    let request = ui.add_enabled(ready, egui::Button::new("Yêu cầu quyền macOS")).clicked();
                                                    if refresh || request {
                                                        if let Some(request_id) = self.notification_authorization.begin() {
                                                            let command = if request {
                                                                WorkerCmd::RequestNotificationAuthorization { request_id }
                                                            } else {
                                                                WorkerCmd::ReadNotificationAuthorization { request_id }
                                                            };
                                                            if worker::WORKER_TX.get().map(|tx| tx.send(command).is_ok()) != Some(true) {
                                                                self.notification_authorization.finish(request_id, Err(crate::native_notifications::NotificationError::Io));
                                                            }
                                                        }
                                                    }
                                                });
                                                ui.add_space(16.0);
                                            }

                                            ui.label(RichText::new("Cài đặt thông báo").color(pal.text_primary).size(13.5).strong());
                                            ui.add_space(2.0);
                                            ui.label(RichText::new("Nhận được thông báo mỗi khi có tin nhắn mới").color(pal.text_secondary).size(12.2));
                                            ui.add_space(8.0);
                                            egui::Frame::none()
                                                .fill(pal.bg_elevated)
                                                .stroke(Stroke::new(1.0_f32, pal.border))
                                                .rounding(Rounding::same(10.0))
                                                .inner_margin(Margin::symmetric(14.0, 14.0))
                                                .show(ui, |ui| {
                                                    let card_avail_w = (inner_w - 28.0).max(200.0);
                                                    ui.set_min_width(card_avail_w);
                                                    ui.set_max_width(card_avail_w);
                                                    ui.horizontal_wrapped(|ui| {
                                                        let col_w = 152.0_f32;
                                                        let gap = 16.0_f32;
                                                        ui.spacing_mut().item_spacing = Vec2::splat(gap);
                                                        for (en_val, label) in
                                                            [(true, "Bật"), (false, "Tắt")]
                                                        {
                                                            let selected = self
                                                                .settings
                                                                .enable_notifications
                                                                == en_val;
                                                            ui.allocate_ui_with_layout(
                                                                Vec2::new(col_w, 122.0),
                                                                Layout::top_down(Align::Center),
                                                                |ui| {
                                                                    let (lap_r, l_resp) =
                                                                        ui.allocate_exact_size(
                                                                            Vec2::new(148.0, 92.0),
                                                                            Sense::click(),
                                                                        );
                                                                    let stroke_c = if selected {
                                                                        pal.primary_hover
                                                                    } else {
                                                                        pal.border
                                                                    };
                                                                    let scr_r = Rect::from_min_max(
                                                                        Pos2::new(
                                                                            lap_r.left() + 14.0,
                                                                            lap_r.top() + 6.0,
                                                                        ),
                                                                        Pos2::new(
                                                                            lap_r.right() - 14.0,
                                                                            lap_r.bottom() - 16.0,
                                                                        ),
                                                                    );
                                                                    ui.painter().rect_stroke(
                                                                        scr_r,
                                                                        Rounding::same(4.0),
                                                                        Stroke::new(1.8_f32, stroke_c),
                                                                    );
                                                                    let base_r = Rect::from_min_max(
                                                                        Pos2::new(
                                                                            lap_r.left() + 6.0,
                                                                            lap_r.bottom() - 16.0,
                                                                        ),
                                                                        Pos2::new(
                                                                            lap_r.right() - 6.0,
                                                                            lap_r.bottom() - 6.0,
                                                                        ),
                                                                    );
                                                                    ui.painter().rect_stroke(
                                                                        base_r,
                                                                        Rounding::same(4.0),
                                                                        Stroke::new(1.8_f32, stroke_c),
                                                                    );
                                                                    if en_val {
                                                                        let toast_r =
                                                                            Rect::from_min_size(
                                                                                Pos2::new(
                                                                                    scr_r.right()
                                                                                        - 62.0,
                                                                                    scr_r.top() + 8.0,
                                                                                ),
                                                                                Vec2::new(54.0, 22.0),
                                                                            );
                                                                        ui.painter().rect_filled(
                                                                            toast_r,
                                                                            Rounding::same(3.0),
                                                                            pal.bg_selected,
                                                                        );
                                                                    }
                                                                    ui.add_space(6.0);
                                                                    let r_click =
                                                                        ui.radio(selected, label).clicked();
                                                                    if l_resp
                                                                        .on_hover_cursor(
                                                                            CursorIcon::PointingHand,
                                                                        )
                                                                        .clicked()
                                                                        || r_click
                                                                    {
                                                                        self.settings
                                                                            .enable_notifications =
                                                                            en_val;
                                                                    }
                                                                },
                                                            );
                                                        }
                                                    });
                                                });
                                            ui.add_space(16.0);

                                            ui.label(RichText::new("Âm thanh thông báo").color(pal.text_primary).size(13.5).strong());
                                            ui.add_space(6.0);
                                            egui::Frame::none()
                                                .fill(pal.bg_elevated)
                                                .stroke(Stroke::new(1.0_f32, pal.border))
                                                .rounding(Rounding::same(8.0))
                                                .inner_margin(Margin::symmetric(14.0, 10.0))
                                                .show(ui, |ui| {
                                                    ui.horizontal(|ui| {
                                                        ui.label(RichText::new("Phát âm thanh khi có tin nhắn & thông báo mới").color(pal.text_primary).size(13.2));
                                                        ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                                            render_toggle_switch(ui, &mut self.settings.play_notification_sound, pal);
                                                        });
                                                    });
                                                });
                                        }
                                        SettingsTab::Messages => {
                                            egui::Frame::none()
                                                .fill(pal.bg_elevated)
                                                .stroke(Stroke::new(1.0_f32, pal.border))
                                                .rounding(Rounding::same(8.0))
                                                .inner_margin(Margin::symmetric(14.0, 10.0))
                                                .show(ui, |ui| {
                                                    ui.horizontal(|ui| {
                                                        ui.label(RichText::new("Tin nhắn nhanh").color(pal.text_primary).size(13.2));
                                                        ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                                            render_toggle_switch(ui, &mut self.settings.quick_messages_enabled, pal);
                                                        });
                                                    });
                                                });
                                            ui.add_space(14.0);

                                            ui.horizontal(|ui| {
                                                ui.label(
                                                    RichText::new("Phản hồi nhanh khi từ chối cuộc gọi")
                                                        .color(pal.text_primary)
                                                        .size(13.5)
                                                        .strong(),
                                                );
                                                ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                                    if ui
                                                        .small_button("Khôi phục mặc định")
                                                        .on_hover_cursor(CursorIcon::PointingHand)
                                                        .clicked()
                                                    {
                                                        self.settings.quick_reply_items =
                                                            crate::gui::default_quick_reply_items();
                                                        self.settings.save();
                                                    }
                                                });
                                            });
                                            ui.add_space(2.0);
                                            ui.label(
                                                RichText::new(
                                                    "Từ chối cuộc gọi đến kèm tin nhắn soạn sẵn (tối đa 5 mẫu)",
                                                )
                                                .color(pal.text_secondary)
                                                .size(12.0),
                                            );
                                            ui.add_space(6.0);
                                            egui::Frame::none()
                                                .fill(pal.bg_elevated)
                                                .stroke(Stroke::new(1.0_f32, pal.border))
                                                .rounding(Rounding::same(8.0))
                                                .inner_margin(Margin::symmetric(14.0, 10.0))
                                                .show(ui, |ui| {
                                                    ui.horizontal(|ui| {
                                                        ui.label(
                                                            RichText::new("Bật phản hồi nhanh trên màn hình cuộc gọi đến")
                                                                .color(pal.text_primary)
                                                                .size(13.0),
                                                        );
                                                        ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                                            render_toggle_switch(
                                                                ui,
                                                                &mut self.settings.quick_reply_enabled,
                                                                pal,
                                                            );
                                                        });
                                                    });
                                                    ui.add_space(8.0);
                                                    let mut remove_idx: Option<usize> = None;
                                                    let mut qr_changed = false;
                                                    for (idx, item) in
                                                        self.settings.quick_reply_items.iter_mut().enumerate()
                                                    {
                                                        ui.horizontal(|ui| {
                                                            let w = (ui.available_width() - 34.0).max(120.0);
                                                            if ui
                                                                .add_sized(
                                                                    [w, 26.0],
                                                                    egui::TextEdit::singleline(item)
                                                                        .char_limit(120),
                                                                )
                                                                .changed()
                                                            {
                                                                qr_changed = true;
                                                            }
                                                            if ui
                                                                .add(
                                                                    egui::Button::new(
                                                                        RichText::new("×")
                                                                            .color(pal.danger)
                                                                            .size(13.5)
                                                                            .strong(),
                                                                    )
                                                                    .min_size(Vec2::new(24.0, 24.0)),
                                                                )
                                                                .on_hover_text("Xóa mẫu này")
                                                                .clicked()
                                                            {
                                                                remove_idx = Some(idx);
                                                            }
                                                        });
                                                        ui.add_space(4.0);
                                                    }
                                                    if qr_changed {
                                                        self.settings.save();
                                                    }
                                                    if let Some(ri) = remove_idx {
                                                        if ri < self.settings.quick_reply_items.len() {
                                                            self.settings.quick_reply_items.remove(ri);
                                                            self.settings.save();
                                                        }
                                                    }
                                                    if self.settings.quick_reply_items.len() < 5 {
                                                        ui.horizontal(|ui| {
                                                            let w = (ui.available_width() - 68.0).max(110.0);
                                                            let resp = ui.add_sized(
                                                                [w, 26.0],
                                                                egui::TextEdit::singleline(
                                                                    &mut self.settings.quick_reply_draft,
                                                                )
                                                                .hint_text("Nhập mẫu phản hồi nhanh mới…")
                                                                .char_limit(120),
                                                            );
                                                            let enter = resp.lost_focus()
                                                                && ui.input(|i| i.key_pressed(Key::Enter));
                                                            if (ui.button("+ Thêm").clicked() || enter)
                                                                && !self
                                                                    .settings
                                                                    .quick_reply_draft
                                                                    .trim()
                                                                    .is_empty()
                                                            {
                                                                let text = self
                                                                    .settings
                                                                    .quick_reply_draft
                                                                    .trim()
                                                                    .chars()
                                                                    .take(120)
                                                                    .collect::<String>();
                                                                self.settings.quick_reply_items.push(text);
                                                                self.settings.quick_reply_draft.clear();
                                                                self.settings.save();
                                                            }
                                                        });
                                                    }
                                                });
                                            ui.add_space(14.0);

                                            ui.label(RichText::new("Thiết lập ẩn trò chuyện").color(pal.text_primary).size(13.5).strong());
                                            ui.add_space(2.0);
                                            ui.label(RichText::new("Đặt mã PIN cho các cuộc trò chuyện riêng tư để tránh người khác nhìn thấy trên máy của bạn").color(pal.text_secondary).size(12.0));
                                            ui.add_space(6.0);
                                            egui::Frame::none()
                                                .fill(pal.bg_elevated)
                                                .stroke(Stroke::new(1.0_f32, pal.border))
                                                .rounding(Rounding::same(8.0))
                                                .inner_margin(Margin::symmetric(14.0, 10.0))
                                                .show(ui, |ui| {
                                                    ui.horizontal(|ui| {
                                                        ui.label(RichText::new("Mã PIN").color(pal.text_primary).size(13.2));
                                                        ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                                            render_toggle_switch(ui, &mut self.settings.hidden_chat_pin_enabled, pal);
                                                        });
                                                    });
                                                });
                                            ui.add_space(14.0);

                                            ui.label(RichText::new("Chia mục Ưu tiên và Khác").color(pal.text_primary).size(13.5).strong());
                                            ui.add_space(2.0);
                                            ui.label(RichText::new("Tách riêng trò chuyện không ưu tiên và chuyển sang mục Khác để tập trung hơn").color(pal.text_secondary).size(12.0));
                                            ui.add_space(6.0);
                                            egui::Frame::none()
                                                .fill(pal.bg_elevated)
                                                .stroke(Stroke::new(1.0_f32, pal.border))
                                                .rounding(Rounding::same(8.0))
                                                .inner_margin(Margin::symmetric(14.0, 10.0))
                                                .show(ui, |ui| {
                                                    ui.horizontal(|ui| {
                                                        ui.label(RichText::new("Chia mục Ưu tiên").color(pal.text_primary).size(13.2));
                                                        ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                                            render_toggle_switch(ui, &mut self.settings.split_priority_inbox, pal);
                                                        });
                                                    });
                                                });
                                            ui.add_space(14.0);

                                            ui.label(RichText::new("Hiển thị nội dung file Excel").color(pal.text_primary).size(13.5).strong());
                                            ui.add_space(2.0);
                                            ui.label(RichText::new("Định dạng khi sao chép file Excel sau đó dán vào Zalo").color(pal.text_secondary).size(12.0));
                                            ui.add_space(6.0);
                                            egui::Frame::none()
                                                .fill(pal.bg_elevated)
                                                .stroke(Stroke::new(1.0_f32, pal.border))
                                                .rounding(Rounding::same(8.0))
                                                .inner_margin(Margin::symmetric(14.0, 10.0))
                                                .show(ui, |ui| {
                                                    for (val, lbl) in [("image", "Dạng hình"), ("text", "Dạng chữ"), ("ask", "Luôn hỏi")] {
                                                        ui.horizontal(|ui| {
                                                            ui.label(RichText::new(lbl).color(pal.text_primary).size(13.0));
                                                            ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                                                ui.radio_value(&mut self.settings.excel_paste_mode, val.into(), "");
                                                            });
                                                        });
                                                        ui.add_space(4.0);
                                                    }
                                                });
                                            ui.add_space(14.0);

                                            ui.label(RichText::new("Phím tắt gửi tin nhắn").color(pal.text_primary).size(13.5).strong());
                                            ui.add_space(6.0);
                                            egui::Frame::none()
                                                .fill(pal.bg_elevated)
                                                .stroke(Stroke::new(1.0_f32, pal.border))
                                                .rounding(Rounding::same(8.0))
                                                .inner_margin(Margin::symmetric(14.0, 10.0))
                                                .show(ui, |ui| {
                                                    for (val, lbl) in [
                                                        ("enter", "Nhấn Enter để gửi (Shift + Enter để xuống dòng)"),
                                                        ("cmd_enter", "Nhấn Cmd/Ctrl + Enter để gửi (Enter để xuống dòng)"),
                                                    ] {
                                                        ui.horizontal(|ui| {
                                                            ui.label(RichText::new(lbl).color(pal.text_primary).size(13.0));
                                                            ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                                                ui.radio_value(&mut self.settings.send_message_key, val.into(), "");
                                                            });
                                                        });
                                                        ui.add_space(4.0);
                                                    }
                                                });
                                            ui.add_space(14.0);

                                            ui.label(RichText::new("Cài đặt khác").color(pal.text_primary).size(13.5).strong());
                                            ui.add_space(6.0);
                                            egui::Frame::none()
                                                .fill(pal.bg_elevated)
                                                .stroke(Stroke::new(1.0_f32, pal.border))
                                                .rounding(Rounding::same(8.0))
                                                .inner_margin(Margin::symmetric(14.0, 10.0))
                                                .show(ui, |ui| {
                                                    ui.horizontal(|ui| {
                                                        ui.label(RichText::new("Bấm đúp vào vùng cạnh tin nhắn để trả lời").color(pal.text_primary).size(13.2));
                                                        ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                                            render_toggle_switch(ui, &mut self.settings.double_click_to_reply, pal);
                                                        });
                                                    });
                                                    ui.add_space(8.0);
                                                    ui.horizontal(|ui| {
                                                        ui.label(RichText::new("Bạn sẽ thấy bạn bè bạn đang soạn tin nhắn").color(pal.text_primary).size(13.2));
                                                        ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                                            render_toggle_switch(ui, &mut self.settings.show_typing_indicator, pal);
                                                        });
                                                    });
                                                });
                                        }
                                        SettingsTab::Utilities => {
                                            ui.label(RichText::new("Gợi ý Sticker").color(pal.text_primary).size(13.5).strong());
                                            ui.add_space(6.0);
                                            egui::Frame::none()
                                                .fill(pal.bg_elevated)
                                                .stroke(Stroke::new(1.0_f32, pal.border))
                                                .rounding(Rounding::same(8.0))
                                                .inner_margin(Margin::symmetric(14.0, 10.0))
                                                .show(ui, |ui| {
                                                    ui.horizontal(|ui| {
                                                        ui.label(RichText::new("Hiện gợi ý Sticker phù hợp với nội dung tin nhắn đang soạn").color(pal.text_primary).size(13.2));
                                                        ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                                            render_toggle_switch(ui, &mut self.settings.suggest_stickers_while_typing, pal);
                                                        });
                                                    });
                                                });
                                            ui.add_space(16.0);

                                            ui.label(RichText::new("Gợi ý @").color(pal.text_primary).size(13.5).strong());
                                            ui.add_space(6.0);
                                            egui::Frame::none()
                                                .fill(pal.bg_elevated)
                                                .stroke(Stroke::new(1.0_f32, pal.border))
                                                .rounding(Rounding::same(8.0))
                                                .inner_margin(Margin::symmetric(14.0, 12.0))
                                                .show(ui, |ui| {
                                                    // Row 1: Gợi ý nhắc tên
                                                    ui.horizontal(|ui| {
                                                        let (b_rect, _) = ui.allocate_exact_size(Vec2::splat(32.0), Sense::hover());
                                                        ui.painter().circle_filled(b_rect.center(), 15.0, Color32::from_rgb(224, 108, 117));
                                                        draw_lucide_icon(ui.painter(), b_rect.center(), lucide::USER, 15.0, Color32::WHITE);
                                                        ui.vertical(|ui| {
                                                            ui.label(RichText::new("Gợi ý nhắc tên").color(pal.text_primary).size(13.2).strong());
                                                            ui.label(RichText::new("Gợi ý nhắc tên theo nội dung đang soạn").color(pal.text_secondary).size(11.8));
                                                        });
                                                        ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                                            render_toggle_switch(ui, &mut self.settings.suggest_mentions, pal);
                                                        });
                                                    });
                                                    ui.add_space(10.0);
                                                    // Row 2: Tìm kiếm GIF
                                                    ui.horizontal(|ui| {
                                                        let (b_rect, _) = ui.allocate_exact_size(Vec2::splat(32.0), Sense::hover());
                                                        ui.painter().circle_filled(b_rect.center(), 15.0, Color32::from_rgb(82, 139, 255));
                                                        ui.painter().text(b_rect.center(), egui::Align2::CENTER_CENTER, "GIF", FontId::proportional(10.5), Color32::WHITE);
                                                        ui.vertical(|ui| {
                                                            ui.label(RichText::new("Tìm kiếm GIF").color(pal.text_primary).size(13.2).strong());
                                                            ui.label(RichText::new("Gõ từ khóa để tìm GIF").color(pal.text_secondary).size(11.8));
                                                        });
                                                        ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                                            render_toggle_switch(ui, &mut self.settings.enable_gif_search, pal);
                                                        });
                                                    });
                                                    ui.add_space(10.0);
                                                    // Row 3: Tìm sticker
                                                    ui.horizontal(|ui| {
                                                        let (b_rect, _) = ui.allocate_exact_size(Vec2::splat(32.0), Sense::hover());
                                                        ui.painter().circle_filled(b_rect.center(), 15.0, Color32::from_rgb(152, 88, 178));
                                                        draw_lucide_icon(ui.painter(), b_rect.center(), lucide::SMILE, 15.5, Color32::WHITE);
                                                        ui.vertical(|ui| {
                                                            ui.label(RichText::new("Tìm sticker").color(pal.text_primary).size(13.2).strong());
                                                            ui.label(RichText::new("Gõ từ khóa để tìm Sticker").color(pal.text_secondary).size(11.8));
                                                        });
                                                        ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                                            render_toggle_switch(ui, &mut self.settings.enable_sticker_keyword_search, pal);
                                                        });
                                                    });
                                                });
                                            ui.add_space(16.0);
                                            ui.label(RichText::new("Tự động trả lời (Auto-Reply) & REST API / MCP").color(pal.text_primary).size(13.5).strong());
                                            ui.add_space(6.0);
                                            egui::Frame::none()
                                                .fill(pal.bg_elevated)
                                                .stroke(Stroke::new(1.0_f32, pal.border))
                                                .rounding(Rounding::same(8.0))
                                                .inner_margin(Margin::symmetric(14.0, 12.0))
                                                .show(ui, |ui| {
                                                    let rules = crate::api_mcp::load_autoreply_rules();
                                                    let active_cnt = rules.iter().filter(|r| r.enabled).count();
                                                    ui.label(RichText::new(format!("Quy tắc Auto-Reply đang bật: {active_cnt}/{} (cấu hình trong autoreply_rules.json)", rules.len())).color(pal.text_primary).size(12.6).strong());
                                                    ui.add_space(4.0);
                                                    ui.label(RichText::new("Khởi chạy REST API cục bộ với `--api-port 3789` hoặc chế độ MCP Server chuẩn JSON-RPC 2.0 với `--mcp` để kết nối Claude Desktop / Cursor / AI Agent.").color(pal.text_secondary).size(11.8));
                                                    ui.add_space(8.0);
                                                    if ui.button("Tạo / Xuất mẫu autoreply_rules.json").clicked() {
                                                        act.export_autoreply_tpl = true;
                                                    }
                                                });
                                        }
                                        SettingsTab::Update => {
                                            let cur_ver = env!("CARGO_PKG_VERSION");
                                            let info_opt = self.update_info.clone();
                                            let has_update = info_opt
                                                .as_ref()
                                                .map(|u| u.has_update)
                                                .unwrap_or(false);
                                            let border_col = if has_update {
                                                pal.accent_online
                                            } else {
                                                pal.border
                                            };

                                            egui::Frame::none()
                                                .fill(pal.bg_elevated)
                                                .stroke(Stroke::new(1.0_f32, border_col))
                                                .rounding(Rounding::same(10.0))
                                                .inner_margin(Margin::symmetric(18.0, 16.0))
                                                .show(ui, |ui| {
                                                    let card_avail_w =
                                                        (inner_w - 36.0).max(280.0);
                                                    ui.set_min_width(card_avail_w);
                                                    ui.set_max_width(card_avail_w);

                                                    // 1) Header Row: App Icon + Title/Status + Action Button on the right
                                                    ui.horizontal(|ui| {
                                                        let (icon_r, _) = ui.allocate_exact_size(
                                                            Vec2::splat(44.0),
                                                            Sense::hover(),
                                                        );
                                                        if let Some(ref logo) =
                                                            self.app_logo_texture
                                                        {
                                                            ui.painter().image(
                                                                logo.id(),
                                                                icon_r,
                                                                Rect::from_min_max(
                                                                    Pos2::ZERO,
                                                                    Pos2::new(1.0, 1.0),
                                                                ),
                                                                Color32::WHITE,
                                                            );
                                                        } else {
                                                            ui.painter().rect_filled(
                                                                icon_r,
                                                                Rounding::same(11.0),
                                                                pal.primary.linear_multiply(0.20),
                                                            );
                                                            draw_lucide_icon(
                                                                ui.painter(),
                                                                icon_r.center(),
                                                                lucide::SPARKLES,
                                                                20.0,
                                                                pal.primary_hover,
                                                            );
                                                        }

                                                        ui.add_space(6.0);
                                                        ui.vertical(|ui| {
                                                            ui.horizontal(|ui| {
                                                                ui.label(
                                                                    RichText::new("Zalo Lite")
                                                                        .size(15.0)
                                                                        .color(pal.text_primary)
                                                                        .strong(),
                                                                );
                                                                egui::Frame::none()
                                                                    .fill(
                                                                        pal.primary
                                                                            .linear_multiply(0.18),
                                                                    )
                                                                    .rounding(Rounding::same(6.0))
                                                                    .inner_margin(
                                                                        Margin::symmetric(7.0, 2.0),
                                                                    )
                                                                    .show(ui, |ui| {
                                                                        ui.label(
                                                                            RichText::new(format!(
                                                                                "v{cur_ver}"
                                                                            ))
                                                                            .size(11.2)
                                                                            .color(
                                                                                pal.primary_hover,
                                                                            )
                                                                            .strong(),
                                                                        );
                                                                    });
                                                            });
                                                            ui.add_space(2.0);
                                                            let sub_txt = if self.update_checking {
                                                                "Đang kiểm tra bản cập nhật mới…"
                                                                    .to_string()
                                                            } else if let Some(ref info) = info_opt
                                                            {
                                                                if info.has_update {
                                                                    let mb = (info.asset_size
                                                                        as f64)
                                                                        / (1024.0 * 1024.0);
                                                                    if mb > 0.1 {
                                                                        format!(
                                                                            "Đã có bản cập nhật mới v{} ({mb:.1} MB)",
                                                                            info.latest_version
                                                                        )
                                                                    } else {
                                                                        format!(
                                                                            "Đã có bản cập nhật mới v{}",
                                                                            info.latest_version
                                                                        )
                                                                    }
                                                                } else {
                                                                    "Bạn đang sử dụng phiên bản mới nhất"
                                                                        .to_string()
                                                                }
                                                            } else {
                                                                "Tự động nhận bản cập nhật qua GitHub Releases"
                                                                    .to_string()
                                                            };
                                                            let sub_col = if has_update {
                                                                pal.accent_online
                                                            } else {
                                                                pal.text_secondary
                                                            };
                                                            ui.label(
                                                                RichText::new(sub_txt)
                                                                    .size(12.2)
                                                                    .color(sub_col),
                                                            );
                                                        });

                                                        ui.with_layout(
                                                            Layout::right_to_left(Align::Center),
                                                            |ui| {
                                                                if let Some(ref info) = info_opt {
                                                                    if info.has_update {
                                                                        if let (
                                                                            Some(dl_url),
                                                                            Some(asset_name),
                                                                        ) = (
                                                                            info.download_url
                                                                                .clone(),
                                                                            info.asset_name.clone(),
                                                                        ) {
                                                                            let upd_lbl = if self
                                                                                .update_downloading
                                                                            {
                                                                                "Đang cập nhật…"
                                                                                    .to_string()
                                                                            } else {
                                                                                format!(
                                                                                    "Cập nhật v{}",
                                                                                    info.latest_version
                                                                                )
                                                                            };
                                                                            let upd_btn =
                                                                                egui::Button::new(
                                                                                    RichText::new(
                                                                                        upd_lbl,
                                                                                    )
                                                                                    .size(12.5)
                                                                                    .color(
                                                                                        Color32::WHITE,
                                                                                    )
                                                                                    .strong(),
                                                                                )
                                                                                .fill(
                                                                                    pal.accent_online,
                                                                                )
                                                                                .rounding(
                                                                                    Rounding::same(
                                                                                        8.0,
                                                                                    ),
                                                                                )
                                                                                .min_size(
                                                                                    Vec2::new(
                                                                                        132.0, 34.0,
                                                                                    ),
                                                                                );
                                                                            if ui
                                                                                .add_enabled(
                                                                                    !self.update_downloading,
                                                                                    upd_btn,
                                                                                )
                                                                                .on_hover_cursor(
                                                                                    CursorIcon::PointingHand,
                                                                                )
                                                                                .clicked()
                                                                            {
                                                                                self.update_downloading =
                                                                                    true;
                                                                                self.update_progress =
                                                                                    Some((
                                                                                        0,
                                                                                        info.asset_size,
                                                                                    ));
                                                                                if let Some(tx) =
                                                                                    WORKER_TX.get()
                                                                                {
                                                                                    let _ = tx.send(
                                                                                        WorkerCmd::DownloadAndApplyUpdate {
                                                                                            download_url: dl_url,
                                                                                            asset_name,
                                                                                            target_version: info.latest_version.clone(),
                                                                                            expected_sha256: info.expected_sha256.clone(),
                                                                                        },
                                                                                    );
                                                                                }
                                                                            }
                                                                            return;
                                                                        }
                                                                    }
                                                                }

                                                                let chk_lbl = if self.update_checking
                                                                {
                                                                    "Đang kiểm tra…".to_string()
                                                                } else {
                                                                    format!(
                                                                        "{} Kiểm tra cập nhật",
                                                                        lucide::REFRESH
                                                                    )
                                                                };
                                                                let chk_btn = egui::Button::new(
                                                                    RichText::new(chk_lbl)
                                                                        .size(12.2)
                                                                        .color(pal.text_primary),
                                                                )
                                                                .fill(pal.bg_input)
                                                                .stroke(Stroke::new(
                                                                    1.0_f32, pal.border,
                                                                ))
                                                                .rounding(Rounding::same(8.0))
                                                                .min_size(Vec2::new(142.0, 32.0));
                                                                if ui
                                                                    .add_enabled(
                                                                        !self.update_checking
                                                                            && !self
                                                                                .update_downloading,
                                                                        chk_btn,
                                                                    )
                                                                    .on_hover_cursor(
                                                                        CursorIcon::PointingHand,
                                                                    )
                                                                    .clicked()
                                                                {
                                                                    self.update_checking = true;
                                                                    self.update_status.clear();
                                                                    if let Some(tx) =
                                                                        WORKER_TX.get()
                                                                    {
                                                                        let _ = tx.send(
                                                                            WorkerCmd::CheckForUpdates {
                                                                                silent: false,
                                                                            },
                                                                        );
                                                                    }
                                                                }
                                                            },
                                                        );
                                                    });

                                                    // 2) Live Download Progress Bar
                                                    if self.update_downloading {
                                                        ui.add_space(12.0);
                                                        let (dl_bytes, tot_bytes) =
                                                            self.update_progress.unwrap_or((0, 0));
                                                        let frac = if tot_bytes > 0 {
                                                            (dl_bytes as f32 / tot_bytes as f32)
                                                                .clamp(0.0, 1.0)
                                                        } else {
                                                            0.35
                                                        };
                                                        let dl_mb =
                                                            dl_bytes as f64 / (1024.0 * 1024.0);
                                                        let tot_mb =
                                                            tot_bytes as f64 / (1024.0 * 1024.0);
                                                        let p_txt = if tot_bytes > 0 {
                                                            format!(
                                                                "Đang tải gói cập nhật: {dl_mb:.1} / {tot_mb:.1} MB ({:.0}%)",
                                                                frac * 100.0
                                                            )
                                                        } else {
                                                            format!(
                                                                "Đang tải gói cập nhật: {dl_mb:.1} MB…"
                                                            )
                                                        };
                                                        ui.add(
                                                            egui::ProgressBar::new(frac)
                                                                .text(p_txt)
                                                                .animate(true),
                                                        );
                                                        ui.add_space(4.0);
                                                        ui.label(
                                                            RichText::new(
                                                                "Ứng dụng sẽ tự động xác thực SHA-256 và khởi động lại ngay khi tải xong.",
                                                            )
                                                            .size(11.2)
                                                            .color(pal.text_muted),
                                                        );
                                                    } else if self
                                                        .update_status
                                                        .starts_with("Lỗi")
                                                        || self
                                                            .update_status
                                                            .starts_with(lucide::ALERT_TRIANGLE)
                                                    {
                                                        ui.add_space(10.0);
                                                        ui.label(
                                                            RichText::new(&self.update_status)
                                                                .size(12.0)
                                                                .color(pal.danger),
                                                        );
                                                    }

                                                    // 3) Concise Changelog Summary (bullet items only, no images/tables)
                                                    if let Some(ref info) = info_opt {
                                                        let bullets = extract_concise_changelog(
                                                            &info.release_notes,
                                                        );
                                                        if !bullets.is_empty() {
                                                            ui.add_space(12.0);
                                                            egui::Frame::none()
                                                                .fill(pal.bg_input)
                                                                .stroke(Stroke::new(
                                                                    1.0_f32, pal.border,
                                                                ))
                                                                .rounding(Rounding::same(8.0))
                                                                .inner_margin(Margin::symmetric(
                                                                    14.0, 10.0,
                                                                ))
                                                                .show(ui, |ui| {
                                                                    ui.set_min_width(
                                                                        card_avail_w - 28.0,
                                                                    );
                                                                    ui.set_max_width(
                                                                        card_avail_w - 28.0,
                                                                    );
                                                                    let hdr = if info.has_update {
                                                                        format!(
                                                                            "Điểm mới trong phiên bản v{}:",
                                                                            info.latest_version
                                                                        )
                                                                    } else {
                                                                        format!(
                                                                            "Có gì mới ở phiên bản v{}:",
                                                                            info.latest_version
                                                                        )
                                                                    };
                                                                    ui.label(
                                                                        RichText::new(hdr)
                                                                            .size(12.2)
                                                                            .color(pal.text_primary)
                                                                            .strong(),
                                                                    );
                                                                    ui.add_space(4.0);
                                                                    for b in bullets.iter().take(16)
                                                                    {
                                                                        render_markdown_bullet_line(
                                                                            ui,
                                                                            b,
                                                                            11.8,
                                                                            pal.primary_hover,
                                                                            pal.text_secondary,
                                                                            pal,
                                                                        );
                                                                        ui.add_space(3.0);
                                                                    }
                                                                });
                                                        }

                                                        // 4) Clean Footer Row
                                                        ui.add_space(10.0);
                                                        ui.horizontal(|ui| {
                                                            if !info.published_at.is_empty() {
                                                                ui.label(
                                                                    RichText::new(format!(
                                                                        "Phát hành: {}",
                                                                        info.published_at
                                                                    ))
                                                                    .size(11.2)
                                                                    .color(pal.text_muted),
                                                                );
                                                            }
                                                            ui.with_layout(
                                                                Layout::right_to_left(
                                                                    Align::Center,
                                                                ),
                                                                |ui| {
                                                                    let link_resp = ui.add(
                                                                        egui::Label::new(
                                                                            RichText::new(format!(
                                                                                "Xem trên GitHub {}",
                                                                                lucide::EXTERNAL_LINK
                                                                            ))
                                                                            .size(11.5)
                                                                            .color(
                                                                                pal.primary_hover,
                                                                            ),
                                                                        )
                                                                        .sense(Sense::click()),
                                                                    );
                                                                    if link_resp
                                                                        .on_hover_cursor(
                                                                            CursorIcon::PointingHand,
                                                                        )
                                                                        .clicked()
                                                                    {
                                                                        open_external_url(
                                                                            &info.html_url,
                                                                        );
                                                                    }
                                                                },
                                                            );
                                                        });
                                                    }
                                                });
                                        }
        }
    }

    fn apply_settings_actions(&mut self, ctx: &egui::Context, act: SettingsActions) {
        if act.do_logout {
            self.settings_modal_open = false;
            self.is_logged_in = false;
            self.user_name.clear();
            self.user_uin.clear();
            self.threads.clear();
            self.selected_thread_index = 0;
            self.qr_texture = None;
            self.login_status_msg.clear();
            self.qr_status = "Đang xin mã QR mới…".into();
            self.status_msg = "Đã đăng xuất".into();
            if let Some(tx) = WORKER_TX.get() {
                let _ = tx.send(WorkerCmd::Logout);
                let _ = tx.send(WorkerCmd::RequestQr);
            }
        }
        if let Some(target) = act.switch_to_uin {
            self.settings_modal_open = false;
            if let Some(tx) = WORKER_TX.get() {
                let _ = tx.send(WorkerCmd::SwitchAccount { target_uin: target });
            }
        }
        if act.add_new_account {
            self.settings_modal_open = false;
            let _ = crate::account_manager::save_current_account_snapshot(&self.user_uin);
            self.is_logged_in = false;
            self.user_name.clear();
            self.user_uin.clear();
            self.threads.clear();
            self.selected_thread_index = 0;
            self.qr_texture = None;
            self.login_status_msg.clear();
            self.qr_status = "Đang xin mã QR mới…".into();
            self.status_msg = "Đang xin mã QR đăng nhập tài khoản mới…".into();
            if let Some(tx) = WORKER_TX.get() {
                let _ = tx.send(WorkerCmd::Logout);
                let _ = tx.send(WorkerCmd::RequestQr);
            }
        }
        if act.theme_switched {
            self.theme_dirty = true;
            self.settings.save();
            self.show_toast(if self.dark_mode {
                "Đã chuyển sang giao diện Tối (Atom One Dark)"
            } else {
                "Đã chuyển sang giao diện Sáng (Zalo Light)"
            });
        }
        if act.trigger_sync {
            let threads: Vec<(String, String, bool)> = self
                .threads
                .iter()
                .filter(|t| t.is_group || t.name.contains("Cloud của tôi"))
                .map(|t| (t.id.clone(), t.name.clone(), t.is_group))
                .collect();
            let n = threads.len();
            if let Some(tx) = WORKER_TX.get() {
                let _ = tx.send(WorkerCmd::SyncHistory { threads });
            }
            self.show_toast(format!("Bắt đầu đồng bộ lịch sử {n} hội thoại nhóm/Cloud…"));
        }
        if act.trigger_phone_sync {
            self.phone_sync_progress = 0.05;
            self.phone_sync_status = format!(
                "{} Đang gửi yêu cầu đồng bộ tin nhắn tới điện thoại…",
                lucide::SMARTPHONE
            );
            let threads = self.threads.clone();
            if let Some(tx) = WORKER_TX.get() {
                let _ = tx.send(WorkerCmd::SyncPhoneMessages {
                    threads,
                    send_phone_prompt: true,
                });
            }
            self.show_toast(format!(
                "{} Đang yêu cầu đồng bộ tin nhắn từ điện thoại…",
                lucide::SMARTPHONE
            ));
            ctx.request_repaint();
        }
        if act.apply_proxy_now {
            let proxy_url = self.settings.proxy_url.trim().to_string();
            if let Some(tx) = WORKER_TX.get() {
                let _ = tx.send(WorkerCmd::SetProxy { proxy_url });
            }
        }
        if act.clear_proxy_now {
            self.settings.proxy_url.clear();
            self.settings.save();
            if let Some(tx) = WORKER_TX.get() {
                let _ = tx.send(WorkerCmd::SetProxy {
                    proxy_url: String::new(),
                });
            }
        }
        if act.spawn_multi_zalo {
            let profile = self.settings.multi_profile_name.trim().to_string();
            if profile.is_empty() {
                self.show_toast(format!(
                    "{} Vui lòng nhập tên Profile (ví dụ: acc2)",
                    lucide::ALERT_TRIANGLE
                ));
            } else if let Ok(exe) = std::env::current_exe() {
                let mut cmd = std::process::Command::new(exe);
                cmd.arg("--gui").arg("--profile").arg(&profile);
                if !self.settings.proxy_url.trim().is_empty() {
                    cmd.arg("--proxy").arg(self.settings.proxy_url.trim());
                }
                match cmd.spawn() {
                    Ok(_) => {
                        self.settings.save();
                        self.show_toast(format!(
                            "{} Đã mở cửa sổ Zalo mới (Profile: {profile})",
                            lucide::ROCKET
                        ));
                    }
                    Err(e) => {
                        self.show_toast(format!(
                            "{} Không mở được cửa sổ mới: {e}",
                            lucide::ALERT_TRIANGLE
                        ));
                    }
                }
            }
        }
        if act.pick_dl_dir {
            if let Some(folder) = pick_native_folder_dialog() {
                self.settings.download_dir = folder.display().to_string();
                self.settings.save();
                self.show_toast(format!(
                    "Đã đổi thư mục lưu file: {}",
                    self.settings.download_dir
                ));
            }
        }
        if act.open_dl_dir {
            let p = std::path::PathBuf::from(&self.settings.download_dir);
            let _ = std::fs::create_dir_all(&p);
            #[cfg(target_os = "windows")]
            {
                let _ = std::process::Command::new("explorer").arg(&p).spawn();
            }
            #[cfg(target_os = "macos")]
            {
                let _ = std::process::Command::new("open").arg(&p).spawn();
            }
            #[cfg(not(any(target_os = "windows", target_os = "macos")))]
            {
                let _ = std::process::Command::new("xdg-open").arg(&p).spawn();
            }
        }

        if act.pick_migrate_file {
            if let Some(src_path) = pick_native_file_dialog(false) {
                if let Some(tx) = WORKER_TX.get() {
                    let _ = tx.send(WorkerCmd::ImportHistory {
                        src_path,
                        current_threads: self.threads.clone(),
                    });
                    self.show_toast("Đang nhập lịch sử tin nhắn…");
                }
            }
        }
        if act.export_theme_tpl {
            match ThemePalette::export_template("theme.json") {
                Ok(_) => self.show_toast("Đã xuất mẫu theme.json tại thư mục ứng dụng"),
                Err(e) => self.show_toast(format!("Lỗi xuất theme.json: {e}")),
            }
        }
        if act.reload_theme_json {
            self.theme_dirty = true;
            self.show_toast("Đã áp dụng lại bảng màu từ theme.json");
        }
        if act.export_sticker_tpl {
            match export_custom_stickers_template("custom_stickers.json") {
                Ok(_) => self.show_toast("Đã xuất mẫu custom_stickers.json tại thư mục ứng dụng"),
                Err(e) => self.show_toast(format!("Lỗi xuất custom_stickers.json: {e}")),
            }
        }
        if act.reload_sticker_json {
            let n = self.reload_custom_sticker_packs();
            self.show_toast(format!(
                "Đã nạp {n} bộ Sticker Pack tùy chỉnh từ custom_stickers.json"
            ));
        }
        if act.export_autoreply_tpl {
            let mut rules = crate::api_mcp::load_autoreply_rules();
            if rules.is_empty() {
                rules.push(crate::api_mcp::AutoReplyRule {
                    id: "default_busy".into(),
                    keyword: "/busy".into(),
                    match_mode: "contains".into(),
                    reply_text: "Hiện mình đang bận, mình sẽ phản hồi sớm nhé!".into(),
                    enabled: false,
                    scope: "direct".into(),
                });
            }
            let _ = crate::api_mcp::save_autoreply_rules(&rules);
            self.show_toast("Đã lưu cấu hình mẫu autoreply_rules.json");
        }

        if !act.open {
            self.settings_modal_open = false;
            self.settings.save();
        }
    }

    pub(super) fn render_update_notification_modal(
        &mut self,
        ctx: &egui::Context,
        pal: &ThemePalette,
    ) {
        if !self.update_modal_open {
            return;
        }
        let Some(info) = self.update_info.clone().filter(|u| u.has_update) else {
            self.update_modal_open = false;
            return;
        };
        if ctx.input(|i| i.key_pressed(Key::Escape)) && !self.update_downloading {
            self.update_modal_open = false;
            return;
        }

        let mut open = true;
        let mut trigger_download = false;
        let mut skip_this_version = false;
        let mut remind_later = false;

        let screen = ctx.screen_rect();
        egui::Area::new(Id::new("update_modal_backdrop"))
            .order(egui::Order::Middle)
            .fixed_pos(screen.min)
            .show(ctx, |ui| {
                let (r, resp) = ui.allocate_exact_size(screen.size(), Sense::click());
                ui.painter().rect_filled(
                    r,
                    Rounding::ZERO,
                    Color32::from_rgba_unmultiplied(0, 0, 0, if pal.is_dark { 155 } else { 95 }),
                );
                if resp.clicked() && !self.update_downloading {
                    open = false;
                }
            });

        let card_w = (screen.width() - 24.0).clamp(290.0, 560.0);
        egui::Area::new(Id::new("update_modal_card"))
            .order(egui::Order::Foreground)
            .anchor(egui::Align2::CENTER_CENTER, Vec2::ZERO)
            .show(ctx, |ui| {
                egui::Frame::none()
                    .fill(pal.bg_elevated)
                    .rounding(Rounding::same(14.0))
                    .stroke(Stroke::new(1.2_f32, pal.border))
                    .shadow(egui::epaint::Shadow {
                        offset: Vec2::new(0.0, 12.0),
                        blur: 32.0,
                        spread: 0.0,
                        color: Color32::from_rgba_unmultiplied(0, 0, 0, 130),
                    })
                    .inner_margin(Margin::symmetric(22.0, 18.0))
                    .show(ui, |ui| {
                        let inner_w = card_w - 44.0;
                        ui.set_width(inner_w);

                        // 1. Top Header Bar: Title + Close button
                        ui.horizontal(|ui| {
                            ui.label(
                                RichText::new(format!(
                                    "{}  Có bản cập nhật mới từ GitHub Releases",
                                    lucide::SPARKLES
                                ))
                                .size(15.5)
                                .color(pal.text_primary)
                                .strong(),
                            );
                            ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                let (x_r, x_resp) =
                                    ui.allocate_exact_size(Vec2::splat(28.0), Sense::click());
                                if x_resp.hovered() {
                                    ui.painter().rect_filled(
                                        x_r,
                                        Rounding::same(6.0),
                                        pal.bg_hover,
                                    );
                                }
                                draw_lucide_icon(
                                    ui.painter(),
                                    x_r.center(),
                                    lucide::X,
                                    15.0,
                                    if x_resp.hovered() {
                                        pal.text_primary
                                    } else {
                                        pal.text_secondary
                                    },
                                );
                                if x_resp
                                    .on_hover_cursor(CursorIcon::PointingHand)
                                    .on_hover_text("Đóng (Esc)")
                                    .clicked()
                                    && !self.update_downloading
                                {
                                    open = false;
                                }
                            });
                        });

                        ui.add_space(8.0);
                        ui.separator();
                        ui.add_space(10.0);

                        // 2. App Logo + Release Title + Version Transition Pill + Metadata
                        ui.horizontal(|ui| {
                            let (icon_r, _) =
                                ui.allocate_exact_size(Vec2::splat(46.0), Sense::hover());
                            if let Some(ref logo) = self.app_logo_texture {
                                ui.painter().image(
                                    logo.id(),
                                    icon_r,
                                    Rect::from_min_max(Pos2::ZERO, Pos2::new(1.0, 1.0)),
                                    Color32::WHITE,
                                );
                            } else {
                                ui.painter().rect_filled(
                                    icon_r,
                                    Rounding::same(11.0),
                                    pal.primary.linear_multiply(0.20),
                                );
                            }
                            ui.add_space(8.0);
                            ui.vertical(|ui| {
                                ui.set_max_width((inner_w - 62.0).max(200.0));
                                ui.add(
                                    egui::Label::new(
                                        RichText::new(&info.release_title)
                                            .size(14.2)
                                            .color(pal.text_primary)
                                            .strong(),
                                    )
                                    .wrap(),
                                );
                                ui.add_space(5.0);
                                ui.horizontal_wrapped(|ui| {
                                    ui.spacing_mut().item_spacing.x = 6.0;
                                    egui::Frame::none()
                                        .fill(pal.primary.linear_multiply(0.18))
                                        .stroke(Stroke::new(
                                            1.0_f32,
                                            pal.primary.linear_multiply(0.45),
                                        ))
                                        .rounding(Rounding::same(6.0))
                                        .inner_margin(Margin::symmetric(8.0, 2.0))
                                        .show(ui, |ui| {
                                            ui.label(
                                                RichText::new(format!(
                                                    "v{}  ->  v{}",
                                                    info.current_version, info.latest_version
                                                ))
                                                .size(11.5)
                                                .color(pal.primary_hover)
                                                .strong(),
                                            );
                                        });

                                    let mut meta_parts = Vec::new();
                                    if !info.published_at.is_empty() {
                                        meta_parts.push(format!("Phát hành: {}", info.published_at));
                                    }
                                    if info.asset_size > 0 {
                                        let mb = (info.asset_size as f64) / (1024.0 * 1024.0);
                                        meta_parts.push(format!("Dung lượng: {mb:.1} MB"));
                                    }
                                    if info.expected_sha256.is_some() {
                                        meta_parts.push(format!(
                                            "{} Đã xác thực SHA-256",
                                            lucide::SHIELD_CHECK
                                        ));
                                    }
                                    if !meta_parts.is_empty() {
                                        ui.label(
                                            RichText::new(meta_parts.join("  ·  "))
                                                .size(11.5)
                                                .color(pal.text_secondary),
                                        );
                                    }
                                });
                            });
                        });

                        // 3. Scrollable Release Notes Box (padded top & bottom so text is never clipped)
                        let bullets = extract_concise_changelog(&info.release_notes);
                        if !bullets.is_empty() {
                            ui.add_space(12.0);
                            egui::Frame::none()
                                .fill(pal.bg_input)
                                .stroke(Stroke::new(1.0_f32, pal.border))
                                .rounding(Rounding::same(10.0))
                                .inner_margin(Margin::symmetric(14.0, 12.0))
                                .show(ui, |ui| {
                                    ui.set_width(inner_w - 28.0);
                                    ui.label(
                                        RichText::new(format!(
                                            "Chi tiết cập nhật & sửa lỗi trong v{} (từ GitHub Releases API):",
                                            info.latest_version
                                        ))
                                        .size(12.2)
                                        .color(pal.text_primary)
                                        .strong(),
                                    );
                                    ui.add_space(8.0);
                                    egui::ScrollArea::vertical()
                                        .id_salt("update_modal_notes_scroll")
                                        .max_height((screen.height() - 250.0).clamp(90.0, 215.0))
                                        .auto_shrink([false, false])
                                        .show(ui, |ui| {
                                            ui.add_space(2.0);
                                            for b in bullets.iter().take(20) {
                                                render_markdown_bullet_line(
                                                    ui,
                                                    b,
                                                    12.2,
                                                    pal.accent_online,
                                                    pal.text_secondary,
                                                    pal,
                                                );
                                                ui.add_space(6.0);
                                            }
                                            ui.add_space(2.0);
                                        });
                                });
                        }

                        if self.update_downloading {
                            ui.add_space(12.0);
                            let (dl_bytes, tot_bytes) = self.update_progress.unwrap_or((0, 0));
                            let frac = if tot_bytes > 0 {
                                (dl_bytes as f32 / tot_bytes as f32).clamp(0.0, 1.0)
                            } else {
                                0.35
                            };
                            let dl_mb = dl_bytes as f64 / (1024.0 * 1024.0);
                            let tot_mb = tot_bytes as f64 / (1024.0 * 1024.0);
                            let p_txt = if tot_bytes > 0 {
                                format!(
                                    "Đang tải bản cập nhật: {dl_mb:.1} / {tot_mb:.1} MB ({:.0}%)",
                                    frac * 100.0
                                )
                            } else {
                                format!("Đang tải bản cập nhật: {dl_mb:.1} MB…")
                            };
                            ui.add(egui::ProgressBar::new(frac).text(p_txt).animate(true));
                            ui.add_space(4.0);
                            ui.label(
                                RichText::new(
                                    "Ứng dụng sẽ tự động xác thực SHA-256 và khởi động lại ngay khi tải xong.",
                                )
                                .size(11.2)
                                .color(pal.text_muted),
                            );
                        } else if self.update_status.starts_with("Lỗi")
                            || self.update_status.starts_with(lucide::ALERT_TRIANGLE)
                        {
                            ui.add_space(8.0);
                            ui.label(
                                RichText::new(&self.update_status)
                                    .size(12.0)
                                    .color(pal.danger),
                            );
                        }

                        // 4. Bottom Action Bar (Crisp high-contrast emerald primary button)
                        ui.add_space(14.0);
                        ui.horizontal(|ui| {
                            if info.download_url.is_some() && info.asset_name.is_some() {
                                let btn_lbl = if self.update_downloading {
                                    "Đang cập nhật…".to_string()
                                } else {
                                    format!("Cập nhật ngay (v{})", info.latest_version)
                                };
                                let upd_btn = egui::Button::new(
                                    RichText::new(btn_lbl)
                                        .size(12.8)
                                        .color(Color32::WHITE)
                                        .strong(),
                                )
                                .fill(Color32::from_rgb(22, 163, 74))
                                .stroke(Stroke::new(1.0_f32, Color32::from_rgb(34, 197, 94)))
                                .rounding(Rounding::same(8.0))
                                .min_size(Vec2::new(168.0, 36.0));
                                if ui
                                    .add_enabled(!self.update_downloading, upd_btn)
                                    .on_hover_cursor(CursorIcon::PointingHand)
                                    .clicked()
                                {
                                    trigger_download = true;
                                }
                            }

                            if ui
                                .add(
                                    egui::Button::new(
                                        RichText::new(format!("{}  Xem trên GitHub", lucide::GLOBE))
                                            .size(12.2)
                                            .color(pal.text_primary),
                                    )
                                    .fill(pal.bg_input)
                                    .stroke(Stroke::new(1.0_f32, pal.border))
                                    .rounding(Rounding::same(8.0))
                                    .min_size(Vec2::new(134.0, 36.0)),
                                )
                                .on_hover_cursor(CursorIcon::PointingHand)
                                .clicked()
                            {
                                open_external_url(&info.html_url);
                            }

                            ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                if ui
                                    .add_enabled(
                                        !self.update_downloading,
                                        egui::Button::new(
                                            RichText::new("Để sau")
                                                .size(12.2)
                                                .color(pal.text_primary),
                                        )
                                        .fill(pal.bg_input)
                                        .stroke(Stroke::new(1.0_f32, pal.border))
                                        .rounding(Rounding::same(8.0))
                                        .min_size(Vec2::new(68.0, 34.0)),
                                    )
                                    .on_hover_cursor(CursorIcon::PointingHand)
                                    .clicked()
                                {
                                    remind_later = true;
                                }
                                if ui
                                    .add_enabled(
                                        !self.update_downloading,
                                        egui::Button::new(
                                            RichText::new("Bỏ qua bản này")
                                                .size(11.8)
                                                .color(pal.text_secondary),
                                        )
                                        .fill(Color32::TRANSPARENT)
                                        .rounding(Rounding::same(8.0))
                                        .min_size(Vec2::new(104.0, 34.0)),
                                    )
                                    .on_hover_cursor(CursorIcon::PointingHand)
                                    .clicked()
                                {
                                    skip_this_version = true;
                                }
                            });
                        });
                    });
            });
        if trigger_download {
            if let (Some(dl_url), Some(asset_name)) =
                (info.download_url.clone(), info.asset_name.clone())
            {
                self.update_downloading = true;
                self.update_progress = Some((0, info.asset_size));
                if let Some(tx) = WORKER_TX.get() {
                    let _ = tx.send(WorkerCmd::DownloadAndApplyUpdate {
                        download_url: dl_url,
                        asset_name,
                        target_version: info.latest_version.clone(),
                        expected_sha256: info.expected_sha256.clone(),
                    });
                }
            }
        }
        if skip_this_version {
            self.settings.skipped_update_version = info.latest_version;
            self.settings.save();
            self.update_modal_open = false;
            self.update_banner_dismissed = true;
        }
        if remind_later || !open {
            self.update_modal_open = false;
        }
    }

    pub(super) fn render_schedule_modal(&mut self, ctx: &egui::Context, pal: &ThemePalette) {
        if !self.schedule_modal_open {
            return;
        }
        if ctx.input(|i| i.key_pressed(Key::Escape)) {
            self.schedule_modal_open = false;
            self.schedule_editing_id = None;
            return;
        }

        let mut open = true;
        let cur_thread = self
            .threads
            .get(self.selected_thread_index)
            .map(|t| (t.id.clone(), t.name.clone(), t.is_group));
        let now_ts = crate::login::unix_now() as i64;
        let mut schedule_at: Option<i64> = None;
        let mut action_send_now: Option<crate::scheduler::ScheduledMessage> = None;
        let mut action_cancel: Option<i64> = None;
        let mut action_edit: Option<crate::scheduler::ScheduledMessage> = None;

        let screen = ctx.screen_rect();
        let mut backdrop_clicked_pos: Option<Pos2> = None;
        egui::Area::new(Id::new("schedule_modal_backdrop"))
            .order(egui::Order::Middle)
            .fixed_pos(screen.min)
            .show(ctx, |ui| {
                let (r, resp) = ui.allocate_exact_size(screen.size(), Sense::click());
                ui.painter().rect_filled(
                    r,
                    Rounding::ZERO,
                    Color32::from_rgba_unmultiplied(0, 0, 0, if pal.is_dark { 155 } else { 95 }),
                );
                if resp.clicked() {
                    backdrop_clicked_pos = resp.interact_pointer_pos();
                }
            });

        let card_w = (screen.width() - 24.0).clamp(290.0, 520.0);
        let card_area = egui::Area::new(Id::new("schedule_modal_card"))
            .order(egui::Order::Foreground)
            .anchor(egui::Align2::CENTER_CENTER, Vec2::ZERO)
            .show(ctx, |ui| {
                egui::Frame::none()
                    .fill(pal.bg_elevated)
                    .rounding(Rounding::same(14.0))
                    .stroke(Stroke::new(1.0_f32, pal.border))
                    .shadow(egui::epaint::Shadow {
                        offset: Vec2::new(0.0, 8.0),
                        blur: 24.0,
                        spread: 0.0,
                        color: Color32::from_black_alpha(if pal.is_dark { 120 } else { 40 }),
                    })
                    .inner_margin(Margin::symmetric(20.0, 16.0))
                    .show(ui, |ui| {
                        let inner_w = card_w - 40.0;
                        ui.set_width(inner_w);

                        // 1. Header Row
                        ui.horizontal(|ui| {
                            ui.label(
                                RichText::new(format!(
                                    "{} Hẹn giờ gửi tin nhắn & Nhắc hẹn",
                                    lucide::CALENDAR_CLOCK
                                ))
                                .size(15.5)
                                .color(pal.text_primary)
                                .strong(),
                            );
                            ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                let (close_r, close_resp) =
                                    ui.allocate_exact_size(Vec2::splat(28.0), Sense::click());
                                if close_resp.hovered() {
                                    ui.painter().rect_filled(
                                        close_r,
                                        Rounding::same(7.0),
                                        pal.bg_hover,
                                    );
                                }
                                draw_lucide_icon(
                                    ui.painter(),
                                    close_r.center(),
                                    lucide::X,
                                    14.0,
                                    if close_resp.hovered() {
                                        pal.text_primary
                                    } else {
                                        pal.text_secondary
                                    },
                                );
                                if close_resp
                                    .on_hover_cursor(CursorIcon::PointingHand)
                                    .on_hover_text("Đóng (Esc)")
                                    .clicked()
                                {
                                    open = false;
                                }
                            });
                        });

                        ui.add_space(6.0);
                        ui.separator();
                        ui.add_space(8.0);

                        egui::ScrollArea::vertical()
                            .id_salt("schedule_modal_scroll")
                            .max_height((screen.height() - 105.0).max(160.0))
                            .show(ui, |ui| {
                                ui.set_width(inner_w);

                        // Notice Banner: Client-side scheduling only (no remote server)
                        let (warn_bg, warn_border, warn_fg) = if pal.is_dark {
                            (
                                Color32::from_rgb(52, 41, 22),
                                Color32::from_rgb(245, 158, 11),
                                Color32::from_rgb(254, 243, 199),
                            )
                        } else {
                            (
                                Color32::from_rgb(255, 251, 235),
                                Color32::from_rgb(217, 119, 6),
                                Color32::from_rgb(146, 64, 14),
                            )
                        };
                        egui::Frame::none()
                            .fill(warn_bg)
                            .stroke(Stroke::new(1.2_f32, warn_border))
                            .rounding(Rounding::same(8.0))
                            .inner_margin(Margin::symmetric(12.0, 9.0))
                            .show(ui, |ui| {
                                ui.set_width(inner_w - 24.0);
                                ui.add(
                                    egui::Label::new(
                                        RichText::new(format!(
                                            "{} Lưu ý: Hiện tại ứng dụng không sử dụng máy chủ trung gian, nên chức năng hẹn giờ gửi tin nhắn chỉ khả dụng khi đang chạy ctdozlite.",
                                            lucide::ALERT_TRIANGLE
                                        ))
                                        .size(12.5)
                                        .color(warn_fg)
                                        .strong(),
                                    )
                                    .wrap(),
                                );
                            });
                        ui.add_space(8.0);

                        // 2. Target Conversation Badge
                        if let Some((_, ref tname, is_grp)) = cur_thread {
                            egui::Frame::none()
                                .fill(pal.bg_input)
                                .stroke(Stroke::new(1.0_f32, pal.border))
                                .rounding(Rounding::same(8.0))
                                .inner_margin(Margin::symmetric(12.0, 7.0))
                                .show(ui, |ui| {
                                    ui.set_width(inner_w - 24.0);
                                    ui.horizontal(|ui| {
                                        ui.label(
                                            RichText::new(if is_grp {
                                                format!("{} Nhóm đích:", lucide::USERS)
                                            } else {
                                                format!("{} Người nhận:", lucide::USER)
                                            })
                                            .size(12.0)
                                            .color(pal.text_secondary),
                                        );
                                        ui.label(
                                            RichText::new(truncate_chars(tname, 38))
                                                .size(12.8)
                                                .color(pal.primary_hover)
                                                .strong(),
                                        );
                                    });
                                });
                            ui.add_space(10.0);
                        }

                        // 3. Message Content Input
                        ui.label(
                            RichText::new("Nội dung tin nhắn sẽ gửi:")
                                .size(12.2)
                                .color(pal.text_secondary)
                                .strong(),
                        );
                        ui.add_space(4.0);
                        egui::Frame::none()
                            .fill(pal.bg_input)
                            .stroke(Stroke::new(1.0_f32, pal.border))
                            .rounding(Rounding::same(9.0))
                            .inner_margin(Margin::symmetric(10.0, 8.0))
                            .show(ui, |ui| {
                                ui.add(
                                    egui::TextEdit::multiline(&mut self.input_message)
                                        .desired_rows(3)
                                        .frame(false)
                                        .desired_width(inner_w - 20.0)
                                        .hint_text(
                                            "Nhập nội dung tin nhắn hẹn giờ hoặc lời nhắc...",
                                        ),
                                );
                            });

                        // 4. Quick Time Presets (Balanced 4-column grid)
                        ui.add_space(12.0);
                        ui.label(
                            RichText::new("Chọn mốc thời gian nhanh:")
                                .size(12.2)
                                .color(pal.text_secondary)
                                .strong(),
                        );
                        ui.add_space(5.0);
                        ui.horizontal_wrapped(|ui| {
                            ui.spacing_mut().item_spacing = Vec2::splat(6.0);
                            let btn_w = ((inner_w - 18.0) / 4.0).max(96.0);
                            for (preset, short_lbl) in [
                                (
                                    crate::scheduler::SchedulePreset::In15Minutes,
                                    format!("{} +15 phút", lucide::ZAP),
                                ),
                                (
                                    crate::scheduler::SchedulePreset::In1Hour,
                                    format!("{} +1 giờ", lucide::TIMER),
                                ),
                                (
                                    crate::scheduler::SchedulePreset::Today18h,
                                    format!("{} Tối nay 18:00", lucide::SUNSET),
                                ),
                                (
                                    crate::scheduler::SchedulePreset::Tomorrow08h,
                                    format!("{} Mai 08:00", lucide::SUNRISE),
                                ),
                            ] {
                                let btn = egui::Button::new(
                                    RichText::new(short_lbl)
                                        .size(12.0)
                                        .color(pal.text_primary)
                                        .strong(),
                                )
                                .fill(pal.bg_input)
                                .stroke(Stroke::new(1.0_f32, pal.border))
                                .rounding(Rounding::same(8.0))
                                .min_size(Vec2::new(btn_w, 32.0));
                                if ui
                                    .add(btn)
                                    .on_hover_cursor(CursorIcon::PointingHand)
                                    .on_hover_text(preset.label())
                                    .clicked()
                                {
                                    schedule_at = Some(preset.resolve_unix_ts(now_ts));
                                }
                            }
                        });

                        // 5. Custom Time Input + Primary Schedule Button
                        ui.add_space(12.0);
                        ui.label(
                            RichText::new("Hoặc nhập giờ tùy chỉnh:")
                                .size(12.2)
                                .color(pal.text_secondary)
                                .strong(),
                        );
                        ui.add_space(5.0);
                        ui.horizontal(|ui| {
                            let action_btn_w = 114.0_f32;
                            let custom_w = (inner_w - action_btn_w - 8.0).max(160.0);
                            let te_resp = ui.add_sized(
                                [custom_w, 34.0],
                                egui::TextEdit::singleline(&mut self.schedule_custom_input)
                                    .hint_text("VD: +30m, 18:30, 25/12/2026 09:00")
                                    .margin(Margin::symmetric(10.0, 7.0)),
                            );
                            let enter_custom = te_resp.lost_focus()
                                && ui.input(|i| i.key_pressed(Key::Enter));
                            let sub_btn = egui::Button::new(
                                RichText::new(if self.schedule_editing_id.is_some() {
                                    "Cập nhật lịch".to_string()
                                } else {
                                    format!("{} Đặt lịch", lucide::ALARM_CLOCK)
                                })
                                .size(12.5)
                                .color(Color32::WHITE)
                                .strong(),
                            )
                            .fill(pal.primary)
                            .rounding(Rounding::same(8.0))
                            .min_size(Vec2::new(action_btn_w, 34.0));
                            if ui
                                .add(sub_btn)
                                .on_hover_cursor(CursorIcon::PointingHand)
                                .clicked()
                                || enter_custom
                            {
                                match crate::scheduler::parse_custom_schedule_input(
                                    &self.schedule_custom_input,
                                    now_ts,
                                ) {
                                    Ok(ts) => schedule_at = Some(ts),
                                    Err(e) => self.show_toast(format!(
                                        "{} {e}",
                                        lucide::ALERT_TRIANGLE
                                    )),
                                }
                            }
                        });

                        // 6. Pending Scheduled Messages List
                        if !self.scheduled_items.is_empty() {
                            ui.add_space(12.0);
                            ui.separator();
                            ui.add_space(6.0);
                            ui.label(
                                RichText::new(format!(
                                    "Danh sách tin nhắn đang chờ gửi ({})",
                                    self.scheduled_items.len()
                                ))
                                .size(12.5)
                                .color(pal.text_primary)
                                .strong(),
                            );
                            ui.add_space(4.0);
                            egui::ScrollArea::vertical()
                                .max_height(150.0)
                                .show(ui, |ui| {
                                    for item in &self.scheduled_items {
                                        egui::Frame::none()
                                            .fill(pal.bg_input)
                                            .stroke(Stroke::new(1.0_f32, pal.border))
                                            .rounding(Rounding::same(8.0))
                                            .inner_margin(Margin::symmetric(10.0, 7.0))
                                            .show(ui, |ui| {
                                                ui.set_width(inner_w - 20.0);
                                                ui.horizontal(|ui| {
                                                    ui.vertical(|ui| {
                                                        ui.label(
                                                            RichText::new(format!(
                                                                "{} · {} {}",
                                                                truncate_chars(
                                                                    &item.thread_name,
                                                                    24
                                                                ),
                                                                lucide::ALARM_CLOCK,
                                                                crate::scheduler::format_schedule_time(
                                                                    item.deliver_at
                                                                )
                                                            ))
                                                            .size(11.5)
                                                            .color(pal.primary_hover)
                                                            .strong(),
                                                        );
                                                        ui.label(
                                                            RichText::new(truncate_chars(
                                                                &item.text, 42,
                                                            ))
                                                            .size(12.0)
                                                            .color(pal.text_primary),
                                                        );
                                                    });
                                                    ui.with_layout(
                                                        Layout::right_to_left(Align::Center),
                                                        |ui| {
                                                            if ui.small_button("Hủy").clicked() {
                                                                action_cancel = Some(item.id);
                                                            }
                                                            if ui.small_button("Sửa").clicked() {
                                                                action_edit = Some(item.clone());
                                                            }
                                                            if ui.small_button("Gửi ngay").clicked()
                                                            {
                                                                action_send_now =
                                                                    Some(item.clone());
                                                            }
                                                        },
                                                    );
                                                });
                                            });
                                        ui.add_space(4.0);
                                    }
                                });
                        }
                            });
                    });
            });
        if let Some(pos) = backdrop_clicked_pos {
            if !card_area.response.rect.contains(pos) {
                open = false;
            }
        }
        if let Some(target_ts) = schedule_at {
            let text = self.input_message.trim().to_string();
            if text.is_empty() {
                self.show_toast("Vui lòng nhập nội dung tin nhắn trước khi hẹn giờ");
            } else if let Some((tid, tname, is_group)) = cur_thread {
                if let Some(edit_id) = self.schedule_editing_id.take() {
                    if let Some(tx) = WORKER_TX.get() {
                        let _ = tx.send(WorkerCmd::UpdateScheduledMessage {
                            id: edit_id,
                            text,
                            deliver_at: target_ts,
                        });
                    }
                } else if let Some(tx) = WORKER_TX.get() {
                    let _ = tx.send(WorkerCmd::ScheduleMessage {
                        thread_id: tid,
                        thread_name: tname,
                        is_group,
                        text,
                        deliver_at: target_ts,
                        now_ts,
                    });
                }
            }
        }
        if let Some(id) = action_cancel {
            if let Some(tx) = WORKER_TX.get() {
                let _ = tx.send(WorkerCmd::CancelScheduledMessage { id, silent: false });
            }
        }
        if let Some(item) = action_edit {
            self.input_message = item.text;
            self.schedule_editing_id = Some(item.id);
            self.schedule_custom_input = crate::scheduler::format_schedule_time(item.deliver_at);
        }
        if let Some(item) = action_send_now {
            if let Some(tx) = WORKER_TX.get() {
                let _ = tx.send(WorkerCmd::CancelScheduledMessage {
                    id: item.id,
                    silent: true,
                });
                let _ = tx.send(WorkerCmd::SendMessage {
                    to_id: item.thread_id,
                    text: item.text,
                    is_group: item.is_group,
                });
            }
            self.show_toast("Đang gửi ngay tin nhắn hẹn giờ…");
        }
        if !open {
            self.schedule_modal_open = false;
            self.schedule_editing_id = None;
        }
    }

    pub(super) fn render_call_overlay(&mut self, ctx: &egui::Context, pal: &ThemePalette) {
        let Some(mut call) = self.active_call.clone() else {
            return;
        };
        // Keep timer and video textures updating smoothly while call window is open
        ctx.request_repaint_after(Duration::from_millis(66));

        let elapsed_f = call.started_at.elapsed().as_secs_f32();
        let elapsed = elapsed_f as u64;
        let mins = elapsed / 60;
        let secs = elapsed % 60;
        let timer_str = format!("{mins:02}:{secs:02}");

        let mut hangup_clicked = false;
        let mut retry_clicked = false;

        let has_err = call.error_reason.is_some();
        let is_video_stage = (call.is_video || call.is_group) && !has_err;
        let default_w = if call.is_video || call.is_group {
            860.0
        } else {
            560.0
        };
        let default_h = if call.is_video || call.is_group {
            660.0
        } else {
            520.0
        };
        let win_title = if call.is_group {
            format!("Họp nhóm Zavi — {}", call.partner_name)
        } else if call.is_video {
            format!("Zalo Video Call — {}", call.partner_name)
        } else {
            format!("Zalo Voice Call — {}", call.partner_name)
        };

        let call_ava = self
            .threads
            .iter()
            .find(|t| !call.partner_id.is_empty() && t.id == call.partner_id)
            .or_else(|| self.threads.iter().find(|t| t.name == call.partner_name))
            .and_then(|t| t.avatar.clone());

        if call.is_group
            && !self.group_members_map.contains_key(&call.partner_id)
            && self.fetching_group_members.insert(call.partner_id.clone())
        {
            if let Some(tx) = WORKER_TX.get() {
                let _ = tx.send(WorkerCmd::FetchGroupMembers {
                    group_id: call.partner_id.clone(),
                });
            }
        }
        // Extract participants for Zavi SFU group call multi-tile view (tile 0 = local user `(Bạn)`, followed by remote members)
        let mut group_remotes: Vec<(String, Option<String>)> = Vec::new();
        if call.is_group || self.sticker_textures.contains_key("call_remote_video_1") {
            let self_disp = if self.user_name.trim().is_empty() {
                "Tôi".to_string()
            } else {
                self.user_name.trim().to_string()
            };
            group_remotes.push((format!("{self_disp} (Bạn)"), self.user_avatar.clone()));
            let my_low = self.user_name.trim().to_lowercase();
            let my_tokens: Vec<&str> = my_low.split_whitespace().collect();
            let is_me = |cand: &str| -> bool {
                let c_low = cand.trim().to_lowercase();
                if c_low.is_empty() || my_low.is_empty() {
                    return false;
                }
                c_low == my_low
                    || (c_low.split_whitespace().count() >= 2
                        && c_low.split_whitespace().all(|t| my_tokens.contains(&t)))
            };
            for part in call
                .partner_name
                .split(',')
                .map(str::trim)
                .filter(|s| !s.is_empty())
            {
                if !is_me(part) {
                    let p_low = part.to_lowercase();
                    let matched_ava = self
                        .threads
                        .iter()
                        .find(|t| !t.is_group && t.name.to_lowercase().contains(&p_low))
                        .and_then(|t| t.avatar.clone());
                    group_remotes.push((part.to_string(), matched_ava));
                }
            }
            if group_remotes.len() < 3 {
                if let Some(members) = self.group_members_map.get(&call.partner_id) {
                    for m in members {
                        if m.id != self.user_uin
                            && !is_me(&m.name)
                            && !group_remotes.iter().any(|(n, _)| n == &m.name)
                        {
                            group_remotes.push((m.name.clone(), m.avatar.clone()));
                        }
                    }
                }
            }
            if group_remotes.len() < 3 {
                if let Some(rest) = call_ava.as_deref().and_then(|s| s.strip_prefix("multi:")) {
                    for (idx, seg) in rest.split(';').enumerate() {
                        if idx == 0 && !seg.contains('|') {
                            continue;
                        }
                        if let Some((m_name, m_url)) = seg.split_once('|') {
                            let mn = m_name.trim();
                            if !mn.is_empty()
                                && !is_me(mn)
                                && !group_remotes.iter().any(|(n, _)| n == mn)
                            {
                                let url_opt = if m_url.trim().is_empty() {
                                    None
                                } else {
                                    Some(m_url.trim().to_string())
                                };
                                group_remotes.push((mn.to_string(), url_opt));
                            }
                        }
                    }
                }
            }
            while group_remotes.len() < 2 {
                let n = group_remotes.len();
                group_remotes.push((format!("Thành viên {n}"), None));
            }
        }
        let viewport_id = egui::ViewportId::from_hash_of("zalo_dedicated_call_window");
        let builder = egui::ViewportBuilder::default()
            .with_title(win_title)
            .with_inner_size([default_w, default_h])
            .with_min_inner_size([520.0, 460.0]);

        ctx.show_viewport_immediate(viewport_id, builder, |vp_ctx, _class| {
            if vp_ctx.input(|i| i.viewport().close_requested()) {
                hangup_clicked = true;
            }
            if vp_ctx.input(|i| i.key_pressed(Key::Escape)) && call.error_reason.is_some() {
                hangup_clicked = true;
            }

            let vp_w = vp_ctx.screen_rect().width();

            // 1. TOP TOOLBAR PANEL: Badge · Mic · Camera · Refresh (vertically centered, responsive width)
            egui::TopBottomPanel::top("call_vp_top_panel")
                .resizable(false)
                .exact_height(60.0)
                .show_separator_line(false)
                .frame(
                    egui::Frame::none()
                        .fill(pal.bg_sidebar)
                        .inner_margin(Margin {
                            left: 16.0,
                            right: 16.0,
                            top: 12.0,
                            bottom: 4.0,
                        }),
                )
                .show(vp_ctx, |ui| {
                    let max_bar_w = (vp_w - 32.0).max(320.0);
                    let badge_w = 132.0_f32;
                    let ref_w = 28.0_f32;
                    let gap = 8.0_f32;
                    let pad_x = 10.0_f32;
                    let combo_w = ((max_bar_w - badge_w - ref_w - gap * 3.0 - pad_x * 2.0) * 0.5)
                        .clamp(110.0, 195.0);
                    let bar_w = badge_w + combo_w * 2.0 + ref_w + gap * 3.0 + pad_x * 2.0;
                    let combo_chars = if combo_w < 145.0 { 13 } else { 20 };

                    ui.vertical_centered(|ui| {
                        let (bar_rect, _) =
                            ui.allocate_exact_size(Vec2::new(bar_w, 40.0), Sense::hover());
                        ui.painter().rect_filled(
                            bar_rect,
                            Rounding::same(14.0),
                            pal.bg_elevated,
                        );
                        ui.painter().rect_stroke(
                            bar_rect,
                            Rounding::same(14.0),
                            Stroke::new(1.0_f32, pal.border),
                        );

                        let item_cy = bar_rect.center().y;
                        let item_h = 28.0_f32;
                        let x0 = bar_rect.left() + pad_x;
                        let x1 = x0 + badge_w + gap;
                        let x2 = x1 + combo_w + gap;
                        let x3 = x2 + combo_w + gap;

                        let badge_rect = Rect::from_center_size(
                            Pos2::new(x0 + badge_w * 0.5, item_cy),
                            Vec2::new(badge_w, item_h),
                        );
                        let mic_rect = Rect::from_center_size(
                            Pos2::new(x1 + combo_w * 0.5, item_cy),
                            Vec2::new(combo_w, item_h),
                        );
                        let cam_rect = Rect::from_center_size(
                            Pos2::new(x2 + combo_w * 0.5, item_cy),
                            Vec2::new(combo_w, item_h),
                        );
                        let ref_rect = Rect::from_center_size(
                            Pos2::new(x3 + ref_w * 0.5, item_cy),
                            Vec2::new(ref_w, item_h),
                        );

                        // 1) Status Badge (`Zalo Video · ZRTP`)
                        let pill_col = if has_err {
                            pal.danger.linear_multiply(0.18)
                        } else {
                            pal.accent_online.linear_multiply(0.16)
                        };
                        let pill_fg = if has_err {
                            Color32::from_rgb(252, 165, 165)
                        } else {
                            Color32::from_rgb(110, 231, 183)
                        };
                        let badge_txt = if call.is_group {
                            format!("{} Họp Zavi", lucide::VIDEO)
                        } else if call.is_video {
                            format!("{} Zalo Video · ZRTP", lucide::VIDEO)
                        } else {
                            format!("{} Zalo Voice · ZRTP", lucide::SHIELD_CHECK)
                        };
                        ui.painter()
                            .rect_filled(badge_rect, Rounding::same(8.0), pill_col);
                        ui.painter().text(
                            badge_rect.center(),
                            egui::Align2::CENTER_CENTER,
                            badge_txt,
                            FontId::proportional(11.5),
                            pill_fg,
                        );

                        let (mics, cams) = crate::media::list_media_devices(false);

                        // 2) Microphone selector button + popup menu
                        let cur_mic_lbl = if self.settings.selected_mic_device.is_empty() {
                            mics.first().map(String::as_str).unwrap_or("Mic mặc định")
                        } else {
                            &self.settings.selected_mic_device
                        };
                        let mic_id = Id::new("call_vp_mic_popup");
                        let mic_resp = ui.interact(mic_rect, mic_id, Sense::click());
                        if mic_resp.clicked() {
                            ui.memory_mut(|m| m.toggle_popup(mic_id));
                        }
                        ui.painter().rect_filled(
                            mic_rect,
                            Rounding::same(8.0),
                            if mic_resp.hovered() {
                                pal.bg_hover
                            } else {
                                pal.bg_input
                            },
                        );
                        ui.painter().rect_stroke(
                            mic_rect,
                            Rounding::same(8.0),
                            Stroke::new(1.0_f32, pal.border),
                        );
                        ui.painter().text(
                            Pos2::new(mic_rect.left() + 10.0, item_cy),
                            egui::Align2::LEFT_CENTER,
                            format!(
                                "{} {}",
                                lucide::MIC,
                                truncate_chars(cur_mic_lbl, combo_chars)
                            ),
                            FontId::proportional(11.5),
                            pal.text_primary,
                        );
                        draw_lucide_icon(
                            ui.painter(),
                            Pos2::new(mic_rect.right() - 12.0, item_cy),
                            lucide::CHEVRON_DOWN,
                            11.5,
                            pal.text_secondary,
                        );
                        egui::popup::popup_below_widget(
                            ui,
                            mic_id,
                            &mic_resp,
                            egui::PopupCloseBehavior::CloseOnClick,
                            |ui| {
                                ui.set_min_width(combo_w.max(190.0));
                                if ui
                                    .selectable_label(
                                        self.settings.selected_mic_device.is_empty(),
                                        "Mặc định hệ thống",
                                    )
                                    .clicked()
                                {
                                    self.settings.selected_mic_device.clear();
                                    crate::media::set_selected_mic_device("");
                                    self.settings.save();
                                }
                                for m in &mics {
                                    if ui
                                        .selectable_label(
                                            self.settings.selected_mic_device == *m,
                                            m,
                                        )
                                        .clicked()
                                    {
                                        self.settings.selected_mic_device = m.clone();
                                        crate::media::set_selected_mic_device(m);
                                        self.settings.save();
                                    }
                                }
                            },
                        );

                        // 3) Camera selector button + popup menu
                        let cur_cam_lbl = if self.settings.selected_camera_device.is_empty() {
                            cams.first()
                                .map(String::as_str)
                                .unwrap_or("Camera mặc định")
                        } else {
                            &self.settings.selected_camera_device
                        };
                        let cam_id = Id::new("call_vp_cam_popup");
                        let cam_resp = ui.interact(cam_rect, cam_id, Sense::click());
                        if cam_resp.clicked() {
                            ui.memory_mut(|m| m.toggle_popup(cam_id));
                        }
                        ui.painter().rect_filled(
                            cam_rect,
                            Rounding::same(8.0),
                            if cam_resp.hovered() {
                                pal.bg_hover
                            } else {
                                pal.bg_input
                            },
                        );
                        ui.painter().rect_stroke(
                            cam_rect,
                            Rounding::same(8.0),
                            Stroke::new(1.0_f32, pal.border),
                        );
                        ui.painter().text(
                            Pos2::new(cam_rect.left() + 10.0, item_cy),
                            egui::Align2::LEFT_CENTER,
                            format!(
                                "{} {}",
                                lucide::VIDEO,
                                truncate_chars(cur_cam_lbl, combo_chars)
                            ),
                            FontId::proportional(11.5),
                            pal.text_primary,
                        );
                        draw_lucide_icon(
                            ui.painter(),
                            Pos2::new(cam_rect.right() - 12.0, item_cy),
                            lucide::CHEVRON_DOWN,
                            11.5,
                            pal.text_secondary,
                        );
                        egui::popup::popup_below_widget(
                            ui,
                            cam_id,
                            &cam_resp,
                            egui::PopupCloseBehavior::CloseOnClick,
                            |ui| {
                                ui.set_min_width(combo_w.max(190.0));
                                if ui
                                    .selectable_label(
                                        self.settings.selected_camera_device.is_empty(),
                                        "Tự động (Camera đầu tiên)",
                                    )
                                    .clicked()
                                {
                                    self.settings.selected_camera_device.clear();
                                    crate::media::set_selected_camera_device("");
                                    self.settings.save();
                                }
                                for c in &cams {
                                    if ui
                                        .selectable_label(
                                            self.settings.selected_camera_device == *c,
                                            c,
                                        )
                                        .clicked()
                                    {
                                        self.settings.selected_camera_device = c.clone();
                                        crate::media::set_selected_camera_device(c);
                                        self.settings.save();
                                    }
                                }
                            },
                        );

                        // 4) Refresh Devices Button
                        let ref_resp =
                            ui.interact(ref_rect, Id::new("call_vp_ref_btn"), Sense::click());
                        ui.painter().rect_filled(
                            ref_rect,
                            Rounding::same(8.0),
                            if ref_resp.hovered() {
                                pal.bg_hover
                            } else {
                                pal.bg_input
                            },
                        );
                        ui.painter().rect_stroke(
                            ref_rect,
                            Rounding::same(8.0),
                            Stroke::new(1.0_f32, pal.border),
                        );
                        draw_icon_refresh(
                            ui.painter(),
                            ref_rect.center(),
                            13.5,
                            if ref_resp.hovered() {
                                pal.text_primary
                            } else {
                                pal.text_secondary
                            },
                        );
                        if ref_resp
                            .on_hover_cursor(CursorIcon::PointingHand)
                            .on_hover_text("Quét lại danh sách Mic & Camera")
                            .clicked()
                        {
                            let _ = crate::media::list_media_devices(true);
                        }
                    });
                });

            // 2. BOTTOM STATUS PILL + ACTION DOCK PANEL (never clipped at bottom edge)
            let bottom_panel_h = if has_err {
                142.0
            } else if call.is_incoming_ringing {
                132.0
            } else {
                138.0
            };
            egui::TopBottomPanel::bottom("call_vp_bottom_panel")
                .resizable(false)
                .exact_height(bottom_panel_h)
                .show_separator_line(false)
                .frame(
                    egui::Frame::none()
                        .fill(pal.bg_sidebar)
                        .inner_margin(Margin {
                            left: 20.0,
                            right: 20.0,
                            top: 4.0,
                            bottom: 16.0,
                        }),
                )
                .show(vp_ctx, |ui| {
                    let max_bot_w = (vp_w - 40.0).max(280.0);
                    ui.set_max_width(max_bot_w);
                    ui.vertical_centered(|ui| {
                        if let Some(err_msg) = &call.error_reason {
                            ui.label(
                                RichText::new("Cuộc gọi chưa kết nối được")
                                    .size(12.5)
                                    .color(Color32::from_rgb(248, 113, 113))
                                    .strong(),
                            );
                            ui.add_space(6.0);
                            let clean_err = err_msg
                                .strip_prefix("Lỗi khởi tạo cuộc gọi (401): ")
                                .unwrap_or(err_msg);
                            let banner_w = max_bot_w.min(440.0);
                            let (err_rect, _) = ui.allocate_exact_size(
                                Vec2::new(banner_w, 34.0),
                                Sense::hover(),
                            );
                            ui.painter().rect_filled(
                                err_rect,
                                Rounding::same(10.0),
                                Color32::from_rgba_unmultiplied(127, 29, 29, 68),
                            );
                            ui.painter().rect_stroke(
                                err_rect,
                                Rounding::same(10.0),
                                Stroke::new(
                                    1.0_f32,
                                    Color32::from_rgba_unmultiplied(239, 68, 68, 110),
                                ),
                            );
                            ui.painter().text(
                                err_rect.center(),
                                egui::Align2::CENTER_CENTER,
                                truncate_chars(clean_err, 58),
                                FontId::proportional(12.0),
                                Color32::from_rgb(254, 226, 226),
                            );
                        } else {
                            let status_full = format!("{}  ·  {}", call.state_label, timer_str);
                            let text_w = ui.fonts(|f| {
                                f.layout_no_wrap(
                                    status_full,
                                    FontId::proportional(13.0),
                                    Color32::WHITE,
                                )
                                .size()
                                .x
                            });
                            let pill_w = (text_w + 32.0).clamp(180.0, max_bot_w);
                            let (pill_rect, _) = ui.allocate_exact_size(
                                Vec2::new(pill_w, 28.0),
                                Sense::hover(),
                            );
                            ui.painter().rect_filled(
                                pill_rect,
                                Rounding::same(14.0),
                                Color32::from_rgb(30, 41, 59),
                            );
                            ui.painter().rect_stroke(
                                pill_rect,
                                Rounding::same(14.0),
                                Stroke::new(1.0_f32, pal.border),
                            );
                            let mut job = egui::text::LayoutJob::default();
                            job.append(
                                &call.state_label,
                                0.0,
                                egui::TextFormat {
                                    font_id: FontId::proportional(12.5),
                                    color: Color32::from_rgb(203, 213, 225),
                                    ..Default::default()
                                },
                            );
                            job.append(
                                "  ·  ",
                                0.0,
                                egui::TextFormat {
                                    font_id: FontId::proportional(12.5),
                                    color: pal.text_muted,
                                    ..Default::default()
                                },
                            );
                            job.append(
                                &timer_str,
                                0.0,
                                egui::TextFormat {
                                    font_id: FontId::monospace(13.0),
                                    color: pal.accent_online,
                                    ..Default::default()
                                },
                            );
                            let galley = ui.fonts(|f| f.layout_job(job));
                            ui.painter().galley(
                                Pos2::new(
                                    pill_rect.center().x - galley.size().x * 0.5,
                                    pill_rect.center().y - galley.size().y * 0.5,
                                ),
                                galley,
                                Color32::WHITE,
                            );
                        }

                        ui.add_space(10.0);

                        if has_err {
                            let dock_w = 216.0_f32;
                            let (dock_rect, _) =
                                ui.allocate_exact_size(Vec2::new(dock_w, 40.0), Sense::hover());
                            ui.allocate_new_ui(egui::UiBuilder::new().max_rect(dock_rect), |ui| {
                                ui.horizontal_centered(|ui| {
                                    ui.spacing_mut().item_spacing.x = 12.0;
                                    let retry_btn = egui::Button::new(
                                        RichText::new(format!("{} Gọi lại", lucide::PHONE_CALL))
                                            .size(12.8)
                                            .color(Color32::WHITE)
                                            .strong(),
                                    )
                                    .fill(pal.primary)
                                    .rounding(Rounding::same(18.0))
                                    .min_size(Vec2::new(104.0, 36.0));
                                    if ui
                                        .add(retry_btn)
                                        .on_hover_cursor(CursorIcon::PointingHand)
                                        .clicked()
                                    {
                                        retry_clicked = true;
                                    }

                                    let close_btn = egui::Button::new(
                                        RichText::new(format!("{} Đóng", lucide::X))
                                            .size(12.8)
                                            .color(Color32::from_rgb(226, 232, 240))
                                            .strong(),
                                    )
                                    .fill(Color32::from_rgb(30, 41, 59))
                                    .stroke(Stroke::new(1.0_f32, Color32::from_rgb(51, 65, 85)))
                                    .rounding(Rounding::same(18.0))
                                    .min_size(Vec2::new(100.0, 36.0));
                                    if ui
                                        .add(close_btn)
                                        .on_hover_cursor(CursorIcon::PointingHand)
                                        .clicked()
                                    {
                                        hangup_clicked = true;
                                    }
                                });
                            });
                        } else if call.is_incoming_ringing {
                            let can_quick_reply = !call.is_group
                                && self.settings.quick_reply_enabled
                                && !self.settings.quick_reply_items.is_empty();
                            if can_quick_reply && call.quick_reply_popover_open {
                                let mut picked_tpl: Option<String> = None;
                                egui::Frame::none()
                                    .fill(Color32::from_rgb(17, 24, 39))
                                    .rounding(Rounding::same(10.0))
                                    .stroke(Stroke::new(1.0_f32, pal.border))
                                    .inner_margin(Margin::symmetric(10.0, 8.0))
                                    .show(ui, |ui| {
                                        ui.set_max_width(340.0);
                                        ui.label(
                                            RichText::new("Chọn tin nhắn để từ chối & gửi ngay:")
                                                .size(11.5)
                                                .color(pal.text_muted),
                                        );
                                        ui.add_space(4.0);
                                        for tpl in &self.settings.quick_reply_items {
                                            let btn = egui::Button::new(
                                                RichText::new(tpl.as_str())
                                                    .size(12.5)
                                                    .color(pal.text_primary),
                                            )
                                            .fill(Color32::from_rgb(30, 41, 59))
                                            .rounding(Rounding::same(6.0))
                                            .min_size(Vec2::new(320.0, 28.0));
                                            if ui
                                                .add(btn)
                                                .on_hover_cursor(CursorIcon::PointingHand)
                                                .clicked()
                                            {
                                                picked_tpl = Some(tpl.clone());
                                            }
                                            ui.add_space(2.0);
                                        }
                                    });
                                ui.add_space(6.0);
                                if let Some(tpl) = picked_tpl {
                                    if let Some(tx) = WORKER_TX.get() {
                                        let _ = tx.send(WorkerCmd::AnswerCall {
                                            accept: false,
                                            cam_start_off: false,
                                        });
                                        let _ = tx.send(WorkerCmd::SendMessage {
                                            to_id: call.partner_id.clone(),
                                            text: tpl,
                                            is_group: false,
                                        });
                                    }
                                    self.show_toast("Đã từ chối và gửi phản hồi nhanh");
                                    self.active_call = None;
                                }
                            }

                            let n_btns = 2
                                + usize::from(call.is_video)
                                + usize::from(can_quick_reply);
                            let dock_w = match n_btns {
                                4 => 320.0_f32,
                                3 => 248.0_f32,
                                _ => 156.0_f32,
                            };
                            let (dock_rect, _) =
                                ui.allocate_exact_size(Vec2::new(dock_w, 74.0), Sense::hover());
                            ui.allocate_new_ui(egui::UiBuilder::new().max_rect(dock_rect), |ui| {
                                ui.horizontal_centered(|ui| {
                                    ui.spacing_mut().item_spacing.x = match n_btns {
                                        4 => 22.0,
                                        3 => 28.0,
                                        _ => 44.0,
                                    };
                                    // 1) Decline button
                                    ui.vertical_centered(|ui| {
                                        let (dec_r, dec_resp) = ui.allocate_exact_size(
                                            Vec2::splat(52.0),
                                            Sense::click(),
                                        );
                                        ui.painter().circle_filled(
                                            dec_r.center(),
                                            25.0,
                                            pal.danger,
                                        );
                                        draw_lucide_icon(
                                            ui.painter(),
                                            dec_r.center(),
                                            lucide::PHONE_OFF,
                                            20.0,
                                            Color32::WHITE,
                                        );
                                        if dec_resp
                                            .on_hover_cursor(CursorIcon::PointingHand)
                                            .on_hover_text("Từ chối cuộc gọi (Esc)")
                                            .clicked()
                                            || vp_ctx.input(|i| i.key_pressed(Key::Escape))
                                        {
                                            if let Some(tx) = WORKER_TX.get() {
                                                let _ = tx.send(WorkerCmd::AnswerCall {
                                                    accept: false,
                                                    cam_start_off: false,
                                                });
                                            }
                                            self.active_call = None;
                                        }
                                        ui.label(
                                            RichText::new("Từ chối")
                                                .size(11.0)
                                                .color(pal.text_secondary),
                                        );
                                    });

                                    // 1b) Quick Reply on Call Reject button (`Phản hồi nhanh`)
                                    if can_quick_reply {
                                        ui.vertical_centered(|ui| {
                                            let (qr_r, qr_resp) = ui.allocate_exact_size(
                                                Vec2::splat(52.0),
                                                Sense::click(),
                                            );
                                            let qr_bg = if call.quick_reply_popover_open {
                                                pal.primary.linear_multiply(0.38)
                                            } else if qr_resp.hovered() {
                                                Color32::from_rgb(51, 65, 85)
                                            } else {
                                                Color32::from_rgb(30, 41, 59)
                                            };
                                            ui.painter().circle_filled(qr_r.center(), 25.0, qr_bg);
                                            ui.painter().circle_stroke(
                                                qr_r.center(),
                                                25.0,
                                                Stroke::new(1.2_f32, pal.border),
                                            );
                                            draw_lucide_icon(
                                                ui.painter(),
                                                qr_r.center(),
                                                lucide::MESSAGE_SQUARE,
                                                19.0,
                                                Color32::WHITE,
                                            );
                                            if qr_resp
                                                .on_hover_cursor(CursorIcon::PointingHand)
                                                .on_hover_text("Từ chối & gửi tin nhắn phản hồi nhanh")
                                                .clicked()
                                            {
                                                call.quick_reply_popover_open =
                                                    !call.quick_reply_popover_open;
                                            }
                                            ui.label(
                                                RichText::new("Phản hồi")
                                                    .size(11.0)
                                                    .color(pal.text_primary),
                                            );
                                        });
                                    }

                                    // 2) Answer Video Call with Camera Off (`camStartOff`)
                                    if call.is_video {
                                        ui.vertical_centered(|ui| {
                                            let (nc_r, nc_resp) = ui.allocate_exact_size(
                                                Vec2::splat(52.0),
                                                Sense::click(),
                                            );
                                            ui.painter().circle_filled(
                                                nc_r.center(),
                                                25.0,
                                                Color32::from_rgb(51, 65, 85),
                                            );
                                            ui.painter().circle_stroke(
                                                nc_r.center(),
                                                25.0,
                                                Stroke::new(1.2_f32, pal.primary_hover),
                                            );
                                            draw_lucide_icon(
                                                ui.painter(),
                                                nc_r.center(),
                                                lucide::VIDEO_OFF,
                                                19.5,
                                                Color32::WHITE,
                                            );
                                            if nc_resp
                                                .on_hover_cursor(CursorIcon::PointingHand)
                                                .on_hover_text("Trả lời không mở camera")
                                                .clicked()
                                            {
                                                call.is_incoming_ringing = false;
                                                call.cam_enabled = false;
                                                call.state_label = "Đang kết nối cuộc gọi…".into();
                                                if let Some(tx) = WORKER_TX.get() {
                                                    let _ = tx.send(WorkerCmd::AnswerCall {
                                                        accept: true,
                                                        cam_start_off: true,
                                                    });
                                                }
                                            }
                                            ui.label(
                                                RichText::new("Tắt sẵn cam")
                                                    .size(11.0)
                                                    .color(pal.text_primary),
                                            );
                                        });
                                    }

                                    // 3) Accept Call (with camera on if video call)
                                    ui.vertical_centered(|ui| {
                                        let (acc_r, acc_resp) = ui.allocate_exact_size(
                                            Vec2::splat(52.0),
                                            Sense::click(),
                                        );
                                        ui.painter().circle_filled(
                                            acc_r.center(),
                                            25.0,
                                            pal.accent_online,
                                        );
                                        draw_lucide_icon(
                                            ui.painter(),
                                            acc_r.center(),
                                            if call.is_video {
                                                lucide::VIDEO
                                            } else {
                                                lucide::PHONE_CALL
                                            },
                                            20.0,
                                            Color32::WHITE,
                                        );
                                        if acc_resp
                                            .on_hover_cursor(CursorIcon::PointingHand)
                                            .on_hover_text("Nghe máy (Enter)")
                                            .clicked()
                                            || vp_ctx.input(|i| i.key_pressed(Key::Enter))
                                        {
                                            call.is_incoming_ringing = false;
                                            call.state_label = "Đang kết nối cuộc gọi…".into();
                                            if let Some(tx) = WORKER_TX.get() {
                                                let _ = tx.send(WorkerCmd::AnswerCall {
                                                    accept: true,
                                                    cam_start_off: false,
                                                });
                                            }
                                        }
                                        ui.label(
                                            RichText::new(if call.is_video {
                                                "Bật cam"
                                            } else {
                                                "Nghe máy"
                                            })
                                            .size(11.0)
                                            .color(pal.accent_online),
                                        );
                                    });
                                });
                            });
                        } else {
                            let is_multi_dock = call.is_group
                                || self.sticker_textures.contains_key("call_remote_video_1");
                            let dock_w = if call.is_group {
                                320.0_f32
                            } else if is_multi_dock {
                                260.0_f32
                            } else {
                                196.0_f32
                            };
                            let (dock_rect, _) =
                                ui.allocate_exact_size(Vec2::new(dock_w, 58.0), Sense::hover());
                            ui.allocate_new_ui(egui::UiBuilder::new().max_rect(dock_rect), |ui| {
                                ui.with_layout(Layout::left_to_right(Align::Center), |ui| {
                                    ui.spacing_mut().item_spacing.x = 20.0;

                                    // 1) Circular Mic Button
                                    let (mic_r, mic_resp) =
                                        ui.allocate_exact_size(Vec2::splat(48.0), Sense::click());
                                    let mic_bg = if call.mic_muted {
                                        pal.warning.linear_multiply(0.28)
                                    } else if mic_resp.hovered() {
                                        Color32::from_rgb(51, 65, 85)
                                    } else {
                                        Color32::from_rgb(30, 41, 59)
                                    };
                                    ui.painter().circle_filled(mic_r.center(), 23.0, mic_bg);
                                    ui.painter().circle_stroke(
                                        mic_r.center(),
                                        23.0,
                                        Stroke::new(
                                            1.0_f32,
                                            if call.mic_muted {
                                                pal.warning
                                            } else {
                                                Color32::from_rgb(71, 85, 105)
                                            },
                                        ),
                                    );
                                    draw_lucide_icon(
                                        ui.painter(),
                                        mic_r.center(),
                                        if call.mic_muted {
                                            lucide::MIC_OFF
                                        } else {
                                            lucide::MIC
                                        },
                                        18.5,
                                        if call.mic_muted {
                                            pal.warning
                                        } else {
                                            Color32::WHITE
                                        },
                                    );
                                    if mic_resp
                                        .on_hover_cursor(CursorIcon::PointingHand)
                                        .on_hover_text(if call.mic_muted {
                                            "Bật Mic"
                                        } else {
                                            "Tắt Mic"
                                        })
                                        .clicked()
                                    {
                                        call.mic_muted = !call.mic_muted;
                                        if let Some(tx) = WORKER_TX.get() {
                                            let _ = tx.send(WorkerCmd::SetCallMediaState {
                                                is_on_mic: !call.mic_muted,
                                                is_on_cam: call.cam_enabled,
                                            });
                                        }
                                    }

                                    // 2) Prominent Circular Red Hangup Button (dead-center of window)
                                    let (end_r, end_resp) =
                                        ui.allocate_exact_size(Vec2::splat(56.0), Sense::click());
                                    ui.painter().circle_filled(
                                        end_r.center(),
                                        27.0,
                                        if end_resp.hovered() {
                                            Color32::from_rgb(220, 38, 38)
                                        } else {
                                            pal.danger
                                        },
                                    );
                                    draw_lucide_icon(
                                        ui.painter(),
                                        end_r.center(),
                                        lucide::PHONE_OFF,
                                        21.0,
                                        Color32::WHITE,
                                    );
                                    if end_resp
                                        .on_hover_cursor(CursorIcon::PointingHand)
                                        .on_hover_text("Kết thúc cuộc gọi")
                                        .clicked()
                                    {
                                        hangup_clicked = true;
                                    }

                                    // 3) Circular Camera Button
                                    let (cam_r, cam_resp) =
                                        ui.allocate_exact_size(Vec2::splat(48.0), Sense::click());
                                    let cam_bg = if call.cam_enabled {
                                        pal.primary.linear_multiply(0.32)
                                    } else if cam_resp.hovered() {
                                        Color32::from_rgb(51, 65, 85)
                                    } else {
                                        Color32::from_rgb(30, 41, 59)
                                    };
                                    ui.painter().circle_filled(cam_r.center(), 23.0, cam_bg);
                                    ui.painter().circle_stroke(
                                        cam_r.center(),
                                        23.0,
                                        Stroke::new(
                                            1.0_f32,
                                            if call.cam_enabled {
                                                pal.primary_hover
                                            } else {
                                                Color32::from_rgb(71, 85, 105)
                                            },
                                        ),
                                    );
                                    draw_lucide_icon(
                                        ui.painter(),
                                        cam_r.center(),
                                        if call.cam_enabled {
                                            lucide::VIDEO
                                        } else {
                                            lucide::VIDEO_OFF
                                        },
                                        18.5,
                                        Color32::WHITE,
                                    );
                                    if cam_resp
                                        .on_hover_cursor(CursorIcon::PointingHand)
                                        .on_hover_text(if call.cam_enabled {
                                            "Tắt Camera"
                                        } else {
                                            "Bật Camera"
                                        })
                                        .clicked()
                                    {
                                        if !call.cam_enabled {
                                            if !crate::media::is_ffmpeg_available() {
                                                self.show_toast(format!(
                                                    "{} Cần cài đặt ffmpeg trong PATH để bật Camera (winget install Gyan.FFmpeg)",
                                                    lucide::ALERT_TRIANGLE
                                                ));
                                            } else if crate::media::list_media_devices(false).1.is_empty() {
                                                self.show_toast(format!(
                                                    "{} Không tìm thấy thiết bị Camera nào trên máy",
                                                    lucide::ALERT_TRIANGLE
                                                ));
                                            } else {
                                                call.cam_enabled = true;
                                                call.is_video = true;
                                            }
                                        } else {
                                            call.cam_enabled = false;
                                            self.sticker_textures.remove("call_local_video");
                                        }
                                        if let Some(tx) = WORKER_TX.get() {
                                            let _ = tx.send(WorkerCmd::SetCallMediaState {
                                                is_on_mic: !call.mic_muted,
                                                is_on_cam: call.cam_enabled,
                                            });
                                        }
                                    }
                                    // 4) Layout Switcher (Gallery <-> Speaker View)
                                    if is_multi_dock {
                                        let (lay_r, lay_resp) =
                                            ui.allocate_exact_size(Vec2::splat(42.0), Sense::click());
                                        let lay_bg = if call.speaker_view {
                                            pal.primary.linear_multiply(0.32)
                                        } else if lay_resp.hovered() {
                                            Color32::from_rgb(51, 65, 85)
                                        } else {
                                            Color32::from_rgb(30, 41, 59)
                                        };
                                        ui.painter().circle_filled(lay_r.center(), 20.0, lay_bg);
                                        ui.painter().circle_stroke(
                                            lay_r.center(),
                                            20.0,
                                            Stroke::new(1.0_f32, pal.border),
                                        );
                                        draw_lucide_icon(
                                            ui.painter(),
                                            lay_r.center(),
                                            lucide::PANEL_RIGHT,
                                            16.5,
                                            Color32::WHITE,
                                        );
                                        if lay_resp
                                            .on_hover_cursor(CursorIcon::PointingHand)
                                            .on_hover_text(if call.speaker_view {
                                                "Chế độ Người nói (Bấm để chuyển sang Lưới Gallery)"
                                            } else {
                                                "Chế độ Lưới Gallery (Bấm để chuyển sang Người nói)"
                                            })
                                            .clicked()
                                        {
                                            call.speaker_view = !call.speaker_view;
                                        }
                                    }

                                    // 5) Group Call Members & Invite Popover Toggle (`👥`)
                                    if call.is_group {
                                        let (mem_r, mem_resp) =
                                            ui.allocate_exact_size(Vec2::splat(42.0), Sense::click());
                                        let mem_bg = if call.members_popover_open {
                                            pal.primary.linear_multiply(0.35)
                                        } else if mem_resp.hovered() {
                                            Color32::from_rgb(51, 65, 85)
                                        } else {
                                            Color32::from_rgb(30, 41, 59)
                                        };
                                        ui.painter().circle_filled(mem_r.center(), 20.0, mem_bg);
                                        ui.painter().circle_stroke(
                                            mem_r.center(),
                                            20.0,
                                            Stroke::new(1.0_f32, pal.border),
                                        );
                                        draw_lucide_icon(
                                            ui.painter(),
                                            mem_r.center(),
                                            lucide::USERS,
                                            16.0,
                                            Color32::WHITE,
                                        );
                                        let cnt_pos = Pos2::new(mem_r.right() - 6.0, mem_r.top() + 6.0);
                                        ui.painter().circle_filled(cnt_pos, 8.5, pal.primary);
                                        ui.painter().text(
                                            cnt_pos,
                                            egui::Align2::CENTER_CENTER,
                                            group_remotes.len().to_string(),
                                            FontId::proportional(9.5),
                                            Color32::WHITE,
                                        );
                                        if mem_resp
                                            .on_hover_cursor(CursorIcon::PointingHand)
                                            .on_hover_text(format!(
                                                "Thành viên cuộc gọi Zavi ({}) & Mời thêm",
                                                group_remotes.len()
                                            ))
                                            .clicked()
                                        {
                                            call.members_popover_open = !call.members_popover_open;
                                        }
                                    }
                                });
                            });

                            // Live Mic Level Bar + Quick Gain Slider + Stage Pagination under dock
                            ui.add_space(4.0);
                            ui.horizontal(|ui| {
                                let lvl = (crate::media::mic_level_permille() as f32 / 1000.0).clamp(0.0, 1.0);
                                let (bar_r, _) = ui.allocate_exact_size(Vec2::new(76.0, 5.0), Sense::hover());
                                ui.painter().rect_filled(bar_r, Rounding::same(2.5), Color32::from_rgb(30, 41, 59));
                                if !call.mic_muted && lvl > 0.005 {
                                    let fw = (bar_r.width() * lvl).max(3.0);
                                    let fcol = if lvl > 0.85 {
                                        pal.danger
                                    } else if lvl > 0.6 {
                                        pal.warning
                                    } else {
                                        pal.accent_online
                                    };
                                    ui.painter().rect_filled(
                                        Rect::from_min_size(bar_r.min, Vec2::new(fw, bar_r.height())),
                                        Rounding::same(2.5),
                                        fcol,
                                    );
                                }
                                let mut g = self.settings.mic_gain_percent;
                                if ui
                                    .add_sized(
                                        [92.0, 16.0],
                                        egui::Slider::new(&mut g, 0..=200)
                                            .show_value(true)
                                            .suffix("%"),
                                    )
                                    .on_hover_text("Độ nhạy Micro (0% – 200%)")
                                    .changed()
                                {
                                    self.settings.mic_gain_percent = g;
                                    crate::media::set_mic_gain_percent(g);
                                    self.settings.save();
                                }

                                let per_page = compute_call_per_page((vp_w - 64.0).max(280.0));
                                let total_pages = group_remotes.len().div_ceil(per_page).max(1);
                                if total_pages > 1 {
                                    ui.add_space(10.0);
                                    if ui
                                        .add_enabled(
                                            call.call_page > 0,
                                            egui::Button::new(
                                                RichText::new("‹").size(13.0).color(pal.text_primary),
                                            )
                                            .min_size(Vec2::new(22.0, 18.0)),
                                        )
                                        .on_hover_text("Trang trước")
                                        .clicked()
                                    {
                                        call.call_page = call.call_page.saturating_sub(1);
                                    }
                                    ui.label(
                                        RichText::new(format!(
                                            "{}/{}",
                                            (call.call_page + 1).min(total_pages),
                                            total_pages
                                        ))
                                        .size(11.5)
                                        .color(pal.text_secondary),
                                    );
                                    if ui
                                        .add_enabled(
                                            call.call_page + 1 < total_pages,
                                            egui::Button::new(
                                                RichText::new("›").size(13.0).color(pal.text_primary),
                                            )
                                            .min_size(Vec2::new(22.0, 18.0)),
                                        )
                                        .on_hover_text("Trang sau")
                                        .clicked()
                                    {
                                        call.call_page = (call.call_page + 1).min(total_pages - 1);
                                    }
                                }
                            });
                        }
                    });
                });

            // 2b. FLOATING GROUP CALL MEMBERS & INVITE POPOVER
            if call.is_group && call.members_popover_open {
                let mut popover_open = call.members_popover_open;
                let mut invited_member: Option<(String, String)> = None;
                egui::Window::new(format!(
                    "Thành viên cuộc gọi ({})",
                    group_remotes.len()
                ))
                .id(Id::new("group_call_members_popover"))
                .open(&mut popover_open)
                .collapsible(false)
                .resizable(false)
                .default_width(300.0)
                .anchor(egui::Align2::RIGHT_BOTTOM, Vec2::new(-20.0, -110.0))
                .show(vp_ctx, |ui| {
                    ui.label(
                        RichText::new("Đang trong cuộc gọi")
                            .size(11.5)
                            .color(pal.text_muted)
                            .strong(),
                    );
                    ui.add_space(4.0);
                    egui::ScrollArea::vertical()
                        .id_salt("group_call_in_call_scroll")
                        .max_height(130.0)
                        .show(ui, |ui| {
                            for (p_name, p_ava) in &group_remotes {
                                ui.horizontal(|ui| {
                                    let (av_r, _) = ui.allocate_exact_size(
                                        Vec2::splat(26.0),
                                        Sense::hover(),
                                    );
                                    paint_user_avatar(
                                        ui.painter(),
                                        av_r.center(),
                                        12.0,
                                        p_name,
                                        false,
                                        p_ava.as_deref(),
                                        &self.sticker_textures,
                                        &mut self.loading_stickers,
                                    );
                                    ui.label(
                                        RichText::new(p_name.as_str())
                                            .size(12.5)
                                            .color(pal.text_primary),
                                    );
                                });
                                ui.add_space(2.0);
                            }
                        });

                    ui.separator();
                    ui.label(
                        RichText::new("Mời thêm thành viên nhóm")
                            .size(11.5)
                            .color(pal.text_muted)
                            .strong(),
                    );
                    ui.add_space(4.0);
                    ui.add(
                        egui::TextEdit::singleline(&mut call.invite_search_query)
                            .hint_text("Tìm tên thành viên…")
                            .desired_width(f32::INFINITY),
                    );
                    ui.add_space(4.0);

                    let q_fold = call.invite_search_query.trim().to_lowercase();
                    let active_names: Vec<String> =
                        group_remotes.iter().map(|(n, _)| n.clone()).collect();
                    let members_list = self
                        .group_members_map
                        .get(&call.partner_id)
                        .cloned()
                        .unwrap_or_default();

                    egui::ScrollArea::vertical()
                        .id_salt("group_call_invite_scroll")
                        .max_height(160.0)
                        .show(ui, |ui| {
                            let mut any_shown = false;
                            for m in &members_list {
                                if m.id == self.user_uin
                                    || active_names.iter().any(|n| n == &m.name)
                                {
                                    continue;
                                }
                                if !q_fold.is_empty() && !m.name.to_lowercase().contains(&q_fold) {
                                    continue;
                                }
                                any_shown = true;
                                ui.horizontal(|ui| {
                                    let (av_r, _) = ui.allocate_exact_size(
                                        Vec2::splat(26.0),
                                        Sense::hover(),
                                    );
                                    paint_user_avatar(
                                        ui.painter(),
                                        av_r.center(),
                                        12.0,
                                        &m.name,
                                        false,
                                        m.avatar.as_deref(),
                                        &self.sticker_textures,
                                        &mut self.loading_stickers,
                                    );
                                    ui.label(
                                        RichText::new(truncate_chars(&m.name, 20))
                                            .size(12.5)
                                            .color(pal.text_primary),
                                    );
                                    ui.with_layout(
                                        Layout::right_to_left(Align::Center),
                                        |ui| {
                                            let btn = egui::Button::new(
                                                RichText::new("Mời gọi")
                                                    .size(11.5)
                                                    .color(Color32::WHITE),
                                            )
                                            .fill(pal.primary)
                                            .rounding(Rounding::same(5.0));
                                            if ui
                                                .add(btn)
                                                .on_hover_cursor(CursorIcon::PointingHand)
                                                .clicked()
                                            {
                                                invited_member =
                                                    Some((m.id.clone(), m.name.clone()));
                                            }
                                        },
                                    );
                                });
                                ui.add_space(2.0);
                            }
                            if !any_shown {
                                ui.label(
                                    RichText::new("Không còn thành viên nào phù hợp")
                                        .size(11.5)
                                        .color(pal.text_muted),
                                );
                            }
                        });
                });
                call.members_popover_open = popover_open;
                if let Some((uid, uname)) = invited_member {
                    if let Some(tx) = WORKER_TX.get() {
                        let _ = tx.send(WorkerCmd::InviteGroupCallMembers {
                            user_ids: vec![uid],
                        });
                    }
                    if !call.partner_name.contains(&uname) {
                        call.partner_name = format!("{}, {}", call.partner_name, uname);
                    }
                    self.show_toast(format!("Đã gửi lời mời gọi nhóm tới {uname}"));
                }
            }

            // 3. CENTRAL VIDEO / AVATAR STAGE PANEL (uses exact remaining height between top & bottom panels)
            egui::CentralPanel::default()
                .frame(
                    egui::Frame::none()
                        .fill(pal.bg_sidebar)
                        .inner_margin(Margin::symmetric(20.0, 8.0)),
                )
                .show(vp_ctx, |ui| {
                    let stage_avail_w = (vp_w - 40.0).max(280.0);
                    let stage_avail_h = ui.available_height().max(180.0);
                    ui.set_max_width(stage_avail_w);

                    ui.vertical_centered(|ui| {
                        if is_video_stage {
                            let (stage_rect, _) = ui.allocate_exact_size(
                                Vec2::new(stage_avail_w, stage_avail_h),
                                Sense::hover(),
                            );
                            let painter = ui.painter();
                            painter.rect_filled(
                                stage_rect,
                                Rounding::same(16.0),
                                Color32::from_rgb(15, 20, 30),
                            );
                            painter.rect_stroke(
                                stage_rect,
                                Rounding::same(16.0),
                                Stroke::new(1.0_f32, pal.border),
                            );

                            let is_multi_stage =
                                call.is_group || self.sticker_textures.contains_key("call_remote_video_1");
                            if is_multi_stage {
                                let inner = stage_rect.shrink(12.0);
                                let per_page = compute_call_per_page(inner.width());
                                let total_pages = group_remotes.len().div_ceil(per_page).max(1);
                                if call.call_page >= total_pages {
                                    call.call_page = total_pages - 1;
                                }
                                let page_start = call.call_page * per_page;
                                let page_end = (page_start + per_page).min(group_remotes.len());
                                let page_remotes = &group_remotes[page_start..page_end];
                                let n_tiles = page_remotes.len().clamp(1, 6);
                                let gap = 10.0_f32;
                                let mut aspects = Vec::with_capacity(n_tiles);
                                for idx in 0..n_tiles {
                                    let global_idx = page_start + idx;
                                    let tk = if global_idx == 0 {
                                        "call_local_video".to_string()
                                    } else if global_idx == 1 {
                                        "call_remote_video".to_string()
                                    } else {
                                        format!("call_remote_video_{}", global_idx - 1)
                                    };
                                    let a = self
                                        .sticker_textures
                                        .get(&tk)
                                        .map(|t| {
                                            let s = t.size_vec2();
                                            if s.y > 0.0 { s.x / s.y } else { 16.0 / 9.0 }
                                        })
                                        .unwrap_or(16.0 / 9.0);
                                    aspects.push(a);
                                }
                                let tile_rects: Vec<Rect> = if call.speaker_view && n_tiles >= 2 {
                                    let (main_r, strip_rs) = compute_call_speaker_layout(
                                        n_tiles - 1,
                                        inner,
                                        gap,
                                        16.0 / 9.0,
                                    );
                                    let pinned = call.pinned_tile_idx.min(n_tiles - 1);
                                    let mut out = vec![Rect::NOTHING; n_tiles];
                                    out[pinned] = main_r;
                                    let mut s_i = 0;
                                    for i in 0..n_tiles {
                                        if i == pinned {
                                            continue;
                                        }
                                        if let Some(sr) = strip_rs.get(s_i).copied() {
                                            out[i] = sr;
                                        } else {
                                            out[i] = main_r;
                                        }
                                        s_i += 1;
                                    }
                                    out
                                } else if n_tiles <= 2 {
                                    compute_call_fit_aspects(&aspects, inner, gap)
                                } else {
                                    compute_call_gallery_tiles(n_tiles, inner, gap, 16.0 / 9.0)
                                };
                                let remote_speaking = crate::media::is_remote_speaking();
                                let local_speaking =
                                    !call.mic_muted && crate::media::mic_level_permille() > 45;

                                for idx in 0..n_tiles {
                                    let Some(tile_rect) = tile_rects.get(idx).copied() else {
                                        continue;
                                    };
                                    let global_idx = page_start + idx;
                                    let is_self_tile = global_idx == 0;
                                    let tile_resp = ui.interact(
                                        tile_rect,
                                        Id::new(("call_group_tile", global_idx)),
                                        Sense::click(),
                                    );
                                    if tile_resp
                                        .on_hover_cursor(CursorIcon::PointingHand)
                                        .on_hover_text("Bấm để ghim người này lên khung chính (Speaker View)")
                                        .clicked()
                                    {
                                        call.pinned_tile_idx = idx;
                                        call.speaker_view = true;
                                    }
                                    painter.rect_filled(
                                        tile_rect,
                                        Rounding::same(14.0),
                                        Color32::from_rgb(10, 14, 22),
                                    );
                                    let is_active_speaker = if is_self_tile {
                                        local_speaking
                                    } else {
                                        global_idx == 1 && remote_speaking
                                    };
                                    painter.rect_stroke(
                                        tile_rect,
                                        Rounding::same(14.0),
                                        Stroke::new(
                                            if is_active_speaker { 2.4_f32 } else { 1.0_f32 },
                                            if is_active_speaker {
                                                pal.accent_online
                                            } else {
                                                pal.border
                                            },
                                        ),
                                    );

                                    let tex_key = if is_self_tile {
                                        "call_local_video".to_string()
                                    } else if global_idx == 1 {
                                        "call_remote_video".to_string()
                                    } else {
                                        format!("call_remote_video_{}", global_idx - 1)
                                    };
                                    let (ref p_name, ref p_ava) = page_remotes[idx];
                                    let show_tex = (!is_self_tile || call.cam_enabled)
                                        && self.sticker_textures.contains_key(&tex_key);
                                    let has_vid = if show_tex {
                                        if let Some(vtex) = self.sticker_textures.get(&tex_key) {
                                            let t_inner = tile_rect.shrink(6.0);
                                            let tex_size = vtex.size_vec2();
                                            let tex_aspect = if tex_size.y > 0.0 {
                                                tex_size.x / tex_size.y
                                            } else {
                                                4.0 / 3.0
                                            };
                                            let box_aspect =
                                                t_inner.width() / t_inner.height().max(1.0);
                                            let draw_size = if box_aspect > tex_aspect {
                                                Vec2::new(
                                                    t_inner.height() * tex_aspect,
                                                    t_inner.height(),
                                                )
                                            } else {
                                                Vec2::new(
                                                    t_inner.width(),
                                                    t_inner.width() / tex_aspect,
                                                )
                                            };
                                            let draw_rect =
                                                Rect::from_center_size(t_inner.center(), draw_size);
                                            painter.image(
                                                vtex.id(),
                                                draw_rect,
                                                Rect::from_min_max(Pos2::ZERO, Pos2::new(1.0, 1.0)),
                                                Color32::WHITE,
                                            );
                                            true
                                        } else {
                                            false
                                        }
                                    } else {
                                        let center = Pos2::new(
                                            tile_rect.center().x,
                                            tile_rect.center().y - 16.0,
                                        );
                                        let pulse = ((elapsed_f * 2.6 + idx as f32).sin() * 0.5
                                            + 0.5)
                                            .clamp(0.0, 1.0);
                                        painter.circle_filled(
                                            center,
                                            40.0 + pulse * 5.0,
                                            pal.primary.linear_multiply(0.12),
                                        );
                                        painter.circle_stroke(
                                            center,
                                            37.0,
                                            Stroke::new(
                                                1.6_f32,
                                                pal.primary_hover.linear_multiply(0.8),
                                            ),
                                        );
                                        paint_user_avatar(
                                            painter,
                                            center,
                                            34.0,
                                            p_name,
                                            false,
                                            p_ava.as_deref(),
                                            &self.sticker_textures,
                                            &mut self.loading_stickers,
                                        );
                                        painter.text(
                                            Pos2::new(tile_rect.center().x, center.y + 52.0),
                                            egui::Align2::CENTER_CENTER,
                                            p_name,
                                            FontId::proportional(15.5),
                                            pal.text_primary,
                                        );
                                        let sub_status = if is_self_tile {
                                            "Trong cuộc gọi"
                                        } else {
                                            &call.state_label
                                        };
                                        painter.text(
                                            Pos2::new(tile_rect.center().x, center.y + 72.0),
                                            egui::Align2::CENTER_CENTER,
                                            sub_status,
                                            FontId::proportional(11.5),
                                            if is_self_tile {
                                                pal.accent_online
                                            } else {
                                                pal.text_muted
                                            },
                                        );
                                        false
                                    };

                                    // Participant Name Badge in bottom-left of tile
                                    let lbl_w = (p_name.chars().count() as f32 * 7.2 + 34.0)
                                        .clamp(76.0, tile_rect.width() - 20.0);
                                    let tag_rect = Rect::from_min_size(
                                        Pos2::new(
                                            tile_rect.left() + 10.0,
                                            tile_rect.bottom() - 30.0,
                                        ),
                                        Vec2::new(lbl_w, 22.0),
                                    );
                                    painter.rect_filled(
                                        tag_rect,
                                        Rounding::same(11.0),
                                        Color32::from_rgba_unmultiplied(8, 11, 18, 195),
                                    );
                                    painter.circle_filled(
                                        Pos2::new(tag_rect.left() + 11.0, tag_rect.center().y),
                                        3.8,
                                        if has_vid {
                                            pal.accent_online
                                        } else {
                                            pal.warning
                                        },
                                    );
                                    painter.text(
                                        Pos2::new(tag_rect.left() + 20.0, tag_rect.center().y),
                                        egui::Align2::LEFT_CENTER,
                                        truncate_chars(p_name, 18),
                                        FontId::proportional(11.5),
                                        Color32::WHITE,
                                    );
                                }
                            } else if let Some(vtex) =
                                self.sticker_textures.get("call_remote_video")
                            {
                                let inner = stage_rect.shrink(10.0);
                                let tex_size = vtex.size_vec2();
                                let tex_aspect = if tex_size.y > 0.0 {
                                    tex_size.x / tex_size.y
                                } else {
                                    4.0 / 3.0
                                };
                                let box_aspect = inner.width() / inner.height().max(1.0);
                                let draw_size = if box_aspect > tex_aspect {
                                    Vec2::new(inner.height() * tex_aspect, inner.height())
                                } else {
                                    Vec2::new(inner.width(), inner.width() / tex_aspect)
                                };
                                let draw_rect =
                                    Rect::from_center_size(inner.center(), draw_size);
                                painter.rect_filled(
                                    draw_rect.expand(2.0),
                                    Rounding::same(12.0),
                                    Color32::from_rgb(8, 11, 18),
                                );
                                painter.image(
                                    vtex.id(),
                                    draw_rect,
                                    Rect::from_min_max(Pos2::ZERO, Pos2::new(1.0, 1.0)),
                                    Color32::WHITE,
                                );
                                painter.rect_stroke(
                                    draw_rect.expand(1.0),
                                    Rounding::same(12.0),
                                    Stroke::new(
                                        1.2_f32,
                                        Color32::from_rgba_unmultiplied(148, 163, 184, 70),
                                    ),
                                );
                            } else {
                                let center = Pos2::new(
                                    stage_rect.center().x,
                                    stage_rect.center().y - 16.0,
                                );
                                let pulse =
                                    ((elapsed_f * 2.6).sin() * 0.5 + 0.5).clamp(0.0, 1.0);
                                painter.circle_filled(
                                    center,
                                    46.0 + pulse * 6.0,
                                    pal.primary.linear_multiply(0.12),
                                );
                                painter.circle_stroke(
                                    center,
                                    43.0,
                                    Stroke::new(1.8_f32, pal.primary_hover.linear_multiply(0.8)),
                                );
                                paint_user_avatar(
                                    painter,
                                    center,
                                    40.0,
                                    &call.partner_name,
                                    call.is_group,
                                    call_ava.as_deref(),
                                    &self.sticker_textures,
                                    &mut self.loading_stickers,
                                );
                                painter.text(
                                    Pos2::new(stage_rect.center().x, center.y + 58.0),
                                    egui::Align2::CENTER_CENTER,
                                    &call.partner_name,
                                    FontId::proportional(17.5),
                                    pal.text_primary,
                                );
                            }

                            // Local Camera Picture-in-Picture (PIP) preview in bottom-right corner (1:1 calls only; multi-stage renders self tile inside grid)
                            if !is_multi_stage {
                                let pip_w = 184.0_f32;
                                let pip_h = 138.0_f32;
                                let pip_rect = Rect::from_min_size(
                                    Pos2::new(
                                        stage_rect.right() - pip_w - 16.0,
                                        stage_rect.bottom() - pip_h - 16.0,
                                    ),
                                    Vec2::new(pip_w, pip_h),
                                );
                                painter.rect_filled(
                                    pip_rect,
                                    Rounding::same(12.0),
                                    pal.bg_elevated,
                                );
                                if call.cam_enabled {
                                    if let Some(ltex) = self.sticker_textures.get("call_local_video") {
                                        let inner_pip = pip_rect.shrink(2.0);
                                        let lsize = ltex.size_vec2();
                                        let laspect = if lsize.y > 0.0 {
                                            lsize.x / lsize.y
                                        } else {
                                            4.0 / 3.0
                                        };
                                        let paspect = inner_pip.width() / inner_pip.height().max(1.0);
                                        let uv = if laspect > paspect {
                                            let frac = paspect / laspect;
                                            let m = (1.0 - frac) * 0.5;
                                            Rect::from_min_max(Pos2::new(m, 0.0), Pos2::new(1.0 - m, 1.0))
                                        } else {
                                            let frac = laspect / paspect;
                                            let m = (1.0 - frac) * 0.5;
                                            Rect::from_min_max(Pos2::new(0.0, m), Pos2::new(1.0, 1.0 - m))
                                        };
                                        painter.image(
                                            ltex.id(),
                                            inner_pip,
                                            uv,
                                            Color32::WHITE,
                                        );
                                    } else {
                                        let self_disp = if self.user_name.is_empty() {
                                            "Tôi"
                                        } else {
                                            &self.user_name
                                        };
                                        paint_user_avatar(
                                            painter,
                                            Pos2::new(pip_rect.center().x, pip_rect.center().y - 10.0),
                                            20.0,
                                            self_disp,
                                            false,
                                            self.user_avatar.as_deref(),
                                            &self.sticker_textures,
                                            &mut self.loading_stickers,
                                        );
                                    }
                                } else {
                                    let self_disp = if self.user_name.is_empty() {
                                        "Tôi"
                                    } else {
                                        &self.user_name
                                    };
                                    paint_user_avatar(
                                        painter,
                                        Pos2::new(pip_rect.center().x, pip_rect.center().y - 10.0),
                                        20.0,
                                        self_disp,
                                        false,
                                        self.user_avatar.as_deref(),
                                        &self.sticker_textures,
                                        &mut self.loading_stickers,
                                    );
                                }
                                let pip_badge_rect = Rect::from_center_size(
                                    Pos2::new(pip_rect.center().x, pip_rect.bottom() - 14.0),
                                    Vec2::new(124.0, 20.0),
                                );
                                painter.rect_filled(
                                    pip_badge_rect,
                                    Rounding::same(10.0),
                                    Color32::from_rgba_unmultiplied(8, 11, 18, 185),
                                );
                                let pip_status = if call.cam_enabled {
                                    format!("{} Camera đang bật", lucide::VIDEO)
                                } else {
                                    format!("{} Camera đã tắt", lucide::VIDEO_OFF)
                                };
                                painter.text(
                                    pip_badge_rect.center(),
                                    egui::Align2::CENTER_CENTER,
                                    pip_status,
                                    FontId::proportional(10.5),
                                    if call.cam_enabled {
                                        pal.accent_online
                                    } else {
                                        pal.text_muted
                                    },
                                );
                                painter.rect_stroke(
                                    pip_rect,
                                    Rounding::same(12.0),
                                    Stroke::new(
                                        1.4_f32,
                                        if call.cam_enabled {
                                            pal.primary_hover
                                        } else {
                                            pal.border
                                        },
                                    ),
                                );
                            }
                        } else {
                            let top_pad = ((stage_avail_h - 150.0) * 0.45).max(16.0);
                            ui.add_space(top_pad);
                            let (av_rect, _) =
                                ui.allocate_exact_size(Vec2::splat(96.0), Sense::hover());
                            let center = av_rect.center();
                            let ring_col = if has_err {
                                pal.danger
                            } else if call.is_incoming_ringing {
                                pal.accent_online
                            } else {
                                pal.primary_hover
                            };
                            let pulse = ((elapsed_f * 2.6).sin() * 0.5 + 0.5).clamp(0.0, 1.0);
                            ui.painter().circle_filled(
                                center,
                                44.0 + pulse * 5.0,
                                ring_col.linear_multiply(0.10),
                            );
                            ui.painter().circle_stroke(
                                center,
                                42.0,
                                Stroke::new(1.8_f32, ring_col.linear_multiply(0.75)),
                            );
                            paint_user_avatar(
                                ui.painter(),
                                center,
                                38.0,
                                &call.partner_name,
                                call.is_group,
                                call_ava.as_deref(),
                                &self.sticker_textures,
                                &mut self.loading_stickers,
                            );

                            ui.add_space(12.0);
                            ui.label(
                                RichText::new(&call.partner_name)
                                    .size(18.5)
                                    .color(pal.text_primary)
                                    .strong(),
                            );
                        }
                    });
                });
        });

        if retry_clicked {
            self.sticker_textures.remove("call_remote_video");
            self.sticker_textures.remove("call_remote_video_1");
            self.sticker_textures.remove("call_remote_video_2");
            self.sticker_textures.remove("call_remote_video_3");
            self.sticker_textures.remove("call_remote_video_4");
            self.sticker_textures.remove("call_remote_video_5");
            call.error_code = None;
            call.error_reason = None;
            call.started_at = std::time::Instant::now();
            call.state_label = if call.is_video {
                "Đang kết nối cuộc gọi video…".into()
            } else {
                "Đang kết nối cuộc gọi thoại…".into()
            };
            if let Some(tx) = WORKER_TX.get() {
                let _ = tx.send(WorkerCmd::StartCall {
                    partner_id: call.partner_id.clone(),
                    partner_name: call.partner_name.clone(),
                    partner_avatar: None,
                    is_video: call.is_video,
                    is_group: call.is_group,
                });
            }
            self.active_call = Some(call);
        } else if hangup_clicked {
            self.active_call = None;
            self.sticker_textures.remove("call_remote_video");
            self.sticker_textures.remove("call_remote_video_1");
            self.sticker_textures.remove("call_remote_video_2");
            self.sticker_textures.remove("call_remote_video_3");
            self.sticker_textures.remove("call_remote_video_4");
            self.sticker_textures.remove("call_remote_video_5");
            self.sticker_textures.remove("call_local_video");
            if let Some(tx) = WORKER_TX.get() {
                let _ = tx.send(WorkerCmd::EndCall);
            }
        } else if self.active_call.is_some() {
            self.active_call = Some(call);
        }
    }

    pub(super) fn render_wipe_confirm(&mut self, ctx: &egui::Context, pal: &ThemePalette) {
        if !self.wipe_confirm_open {
            return;
        }
        if ctx.input(|i| i.key_pressed(Key::Escape)) {
            self.wipe_confirm_open = false;
            return;
        }
        let mut open = true;
        let mut confirm = false;
        let mut cancel = false;

        let screen = ctx.screen_rect();
        let mut backdrop_clicked_pos: Option<Pos2> = None;
        egui::Area::new(Id::new("wipe_confirm_backdrop"))
            .order(egui::Order::Foreground)
            .fixed_pos(screen.min)
            .show(ctx, |ui| {
                let (r, resp) = ui.allocate_exact_size(screen.size(), Sense::click());
                ui.painter().rect_filled(
                    r,
                    Rounding::ZERO,
                    Color32::from_rgba_unmultiplied(0, 0, 0, if pal.is_dark { 155 } else { 95 }),
                );
                if resp.clicked() {
                    backdrop_clicked_pos = resp.interact_pointer_pos();
                }
            });

        let card_w = (screen.width() - 24.0).clamp(290.0, 410.0);
        let card_area = egui::Area::new(Id::new("wipe_confirm_card"))
            .order(egui::Order::Tooltip)
            .anchor(egui::Align2::CENTER_CENTER, Vec2::ZERO)
            .show(ctx, |ui| {
                egui::Frame::none()
                    .fill(pal.bg_elevated)
                    .rounding(Rounding::same(14.0))
                    .stroke(Stroke::new(1.0_f32, pal.border))
                    .shadow(egui::epaint::Shadow {
                        offset: Vec2::new(0.0, 10.0),
                        blur: 28.0,
                        spread: 0.0,
                        color: Color32::from_black_alpha(if pal.is_dark { 130 } else { 42 }),
                    })
                    .inner_margin(Margin::symmetric(20.0, 16.0))
                    .show(ui, |ui| {
                        let inner_w = (card_w - 40.0).max(240.0);
                        ui.set_width(inner_w);

                        ui.horizontal(|ui| {
                            ui.label(
                                RichText::new(format!(
                                    "{}  Xoá dữ liệu tin nhắn cục bộ",
                                    lucide::TRASH_2
                                ))
                                .size(15.0)
                                .color(pal.danger)
                                .strong(),
                            );
                            ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                let (cr, c_resp) =
                                    ui.allocate_exact_size(Vec2::splat(26.0), Sense::click());
                                if c_resp.hovered() {
                                    ui.painter().rect_filled(cr, Rounding::same(6.0), pal.bg_hover);
                                }
                                draw_lucide_icon(
                                    ui.painter(),
                                    cr.center(),
                                    lucide::X,
                                    14.0,
                                    if c_resp.hovered() {
                                        pal.text_primary
                                    } else {
                                        pal.text_secondary
                                    },
                                );
                                if c_resp
                                    .on_hover_cursor(CursorIcon::PointingHand)
                                    .on_hover_text("Đóng (Esc)")
                                    .clicked()
                                {
                                    open = false;
                                }
                            });
                        });
                        ui.add_space(6.0);
                        ui.separator();
                        ui.add_space(8.0);

                        ui.label(
                            RichText::new(
                                "Xoá lịch sử tin nhắn cục bộ (CSDL lịch sử & threads_cache.json) trên máy này. \
                                 Không thể hoàn tác, và tin nhắn cũ chỉ tải lại được từ đám mây Zalo.",
                            )
                            .size(12.5)
                            .color(pal.text_secondary),
                        );
                        ui.add_space(4.0);
                        ui.label(
                            RichText::new("Phiên đăng nhập trong session.json giữ nguyên.")
                                .size(12.0)
                                .color(pal.text_muted),
                        );
                        ui.add_space(14.0);
                        ui.horizontal(|ui| {
                            if ui
                                .add_sized(
                                    [136.0, 32.0],
                                    egui::Button::new(
                                        RichText::new("Xoá dữ liệu")
                                            .size(12.5)
                                            .color(pal.danger)
                                            .strong(),
                                    )
                                    .fill(pal.danger.linear_multiply(0.14))
                                    .stroke(Stroke::new(1.0_f32, pal.danger.linear_multiply(0.45)))
                                    .rounding(Rounding::same(8.0)),
                                )
                                .on_hover_cursor(CursorIcon::PointingHand)
                                .clicked()
                            {
                                confirm = true;
                            }
                            if ui
                                .add_sized(
                                    [96.0, 32.0],
                                    egui::Button::new(
                                        RichText::new("Huỷ").size(12.5).color(pal.text_secondary),
                                    )
                                    .fill(pal.bg_input)
                                    .stroke(Stroke::new(1.0_f32, pal.border))
                                    .rounding(Rounding::same(8.0)),
                                )
                                .on_hover_cursor(CursorIcon::PointingHand)
                                .clicked()
                            {
                                cancel = true;
                            }
                        });
                    });
            });
        if let Some(pos) = backdrop_clicked_pos {
            if !card_area.response.rect.contains(pos) {
                open = false;
            }
        }
        if confirm {
            self.wipe_confirm_open = false;
            if let Some(tx) = WORKER_TX.get() {
                let _ = tx.send(WorkerCmd::WipeLocalData);
            }
        } else if cancel || !open {
            self.wipe_confirm_open = false;
        }
    }

    pub(super) fn render_forward_dialog(&mut self, ctx: &egui::Context, pal: &ThemePalette) {
        if self.forward_msg.is_none() {
            return;
        }
        if ctx.input(|i| i.key_pressed(Key::Escape)) {
            self.forward_msg = None;
            return;
        }
        let preview = self
            .forward_msg
            .as_ref()
            .map(|m| {
                if m.sticker_id.is_some() {
                    "[Nhãn dán]".to_string()
                } else {
                    truncate_chars(&m.text, 80).into_owned()
                }
            })
            .unwrap_or_default();
        let query = self.forward_filter.to_lowercase();
        let candidates: Vec<(String, String, bool)> = self
            .threads
            .iter()
            .filter(|t| query.is_empty() || t.name.to_lowercase().contains(&query))
            .map(|t| (t.id.clone(), t.name.clone(), t.is_group))
            .collect();
        let mut open = true;
        let mut chosen: Option<(String, bool, String)> = None;

        let screen = ctx.screen_rect();
        let mut backdrop_clicked_pos: Option<Pos2> = None;
        egui::Area::new(Id::new("forward_dialog_backdrop"))
            .order(egui::Order::Middle)
            .fixed_pos(screen.min)
            .show(ctx, |ui| {
                let (r, resp) = ui.allocate_exact_size(screen.size(), Sense::click());
                ui.painter().rect_filled(
                    r,
                    Rounding::ZERO,
                    Color32::from_rgba_unmultiplied(0, 0, 0, if pal.is_dark { 155 } else { 95 }),
                );
                if resp.clicked() {
                    backdrop_clicked_pos = resp.interact_pointer_pos();
                }
            });

        let card_w = (screen.width() - 24.0).clamp(290.0, 390.0);
        let list_h = (screen.height() - 180.0).clamp(140.0, 310.0);
        let card_area = egui::Area::new(Id::new("forward_dialog_card"))
            .order(egui::Order::Foreground)
            .anchor(egui::Align2::CENTER_CENTER, Vec2::ZERO)
            .show(ctx, |ui| {
                egui::Frame::none()
                    .fill(pal.bg_elevated)
                    .rounding(Rounding::same(14.0))
                    .stroke(Stroke::new(1.0_f32, pal.border))
                    .shadow(egui::epaint::Shadow {
                        offset: Vec2::new(0.0, 10.0),
                        blur: 28.0,
                        spread: 0.0,
                        color: Color32::from_black_alpha(if pal.is_dark { 130 } else { 42 }),
                    })
                    .inner_margin(Margin::symmetric(18.0, 14.0))
                    .show(ui, |ui| {
                        let inner_w = (card_w - 36.0).max(240.0);
                        ui.set_width(inner_w);

                        ui.horizontal(|ui| {
                            ui.label(
                                RichText::new(format!(
                                    "{}  Chuyển tiếp tin nhắn",
                                    lucide::FORWARD
                                ))
                                .size(15.0)
                                .color(pal.text_primary)
                                .strong(),
                            );
                            ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                let (cr, c_resp) =
                                    ui.allocate_exact_size(Vec2::splat(26.0), Sense::click());
                                if c_resp.hovered() {
                                    ui.painter().rect_filled(cr, Rounding::same(6.0), pal.bg_hover);
                                }
                                draw_lucide_icon(
                                    ui.painter(),
                                    cr.center(),
                                    lucide::X,
                                    14.0,
                                    if c_resp.hovered() {
                                        pal.text_primary
                                    } else {
                                        pal.text_secondary
                                    },
                                );
                                if c_resp
                                    .on_hover_cursor(CursorIcon::PointingHand)
                                    .on_hover_text("Đóng (Esc)")
                                    .clicked()
                                {
                                    open = false;
                                }
                            });
                        });
                        ui.add_space(6.0);
                        ui.separator();
                        ui.add_space(6.0);

                        ui.label(
                            RichText::new(format!("Nội dung: {preview}"))
                                .size(12.2)
                                .color(pal.text_secondary),
                        );
                        ui.add_space(6.0);
                        ui.add(
                            egui::TextEdit::singleline(&mut self.forward_filter)
                                .hint_text("Tìm hội thoại…")
                                .margin(Margin::symmetric(10.0, 6.0))
                                .desired_width(f32::INFINITY),
                        );
                        ui.add_space(6.0);
                        egui::ScrollArea::vertical()
                            .id_salt("forward_candidates_scroll")
                            .max_height(list_h)
                            .show(ui, |ui| {
                                for (id, name, is_group) in &candidates {
                                    let icon = if *is_group {
                                        lucide::USERS
                                    } else {
                                        lucide::USER
                                    };
                                    let label = format!("{icon}  {name}");
                                    let btn = egui::Button::new(
                                        RichText::new(label).size(13.0).color(pal.text_primary),
                                    )
                                    .fill(pal.bg_input)
                                    .stroke(Stroke::new(1.0_f32, pal.border))
                                    .rounding(Rounding::same(8.0));
                                    if ui
                                        .add_sized([ui.available_width(), 32.0], btn)
                                        .on_hover_cursor(CursorIcon::PointingHand)
                                        .clicked()
                                    {
                                        chosen = Some((id.clone(), *is_group, name.clone()));
                                    }
                                    ui.add_space(4.0);
                                }
                            });
                    });
            });
        if let Some(pos) = backdrop_clicked_pos {
            if !card_area.response.rect.contains(pos) {
                open = false;
            }
        }
        if let Some((target_id, target_is_group, target_name)) = chosen {
            if let (Some(msg), Some(tx)) = (self.forward_msg.take(), WORKER_TX.get()) {
                let _ = tx.send(WorkerCmd::Forward {
                    target_id,
                    target_is_group,
                    msg,
                    target_name: target_name.clone(),
                });
                self.show_toast(format!("Đang chuyển tiếp tới {target_name}…"));
                self.status_msg = format!("Đang chuyển tiếp tới {target_name}…");
                ctx.request_repaint();
            }
        } else if !open {
            self.forward_msg = None;
        }
    }

    pub(super) fn render_image_viewer_modal(&mut self, ctx: &egui::Context, pal: &ThemePalette) {
        let Some(mut viewer) = self.image_viewer.clone() else {
            return;
        };

        if ctx.input(|i| i.key_pressed(Key::Escape)) {
            self.image_viewer = None;
            return;
        }

        let screen_rect = ctx.screen_rect();
        // Start below the 32px custom frameless title bar so window controls stay accessible
        let viewer_top = (screen_rect.top() + 32.0).min(screen_rect.bottom());
        let toolbar_h = 46.0_f32;
        let toolbar_rect = Rect::from_min_max(
            Pos2::new(screen_rect.left(), viewer_top),
            Pos2::new(
                screen_rect.right(),
                (viewer_top + toolbar_h).min(screen_rect.bottom()),
            ),
        );
        let stage_area_rect = Rect::from_min_max(
            Pos2::new(screen_rect.left(), toolbar_rect.bottom()),
            screen_rect.max,
        );
        let mut should_close = false;

        let active_tex = viewer
            .hd_tex_key
            .as_ref()
            .and_then(|hk| self.sticker_textures.get(hk))
            .or_else(|| self.sticker_textures.get(&viewer.tex_key))
            .cloned();

        let max_stage_w = (stage_area_rect.width() - 48.0).max(160.0);
        let max_stage_h = (stage_area_rect.height() - 36.0).max(120.0);

        let (base_w, base_h, natural_dims) = if let Some(ref tex) = active_tex {
            let [tw, th] = tex.size();
            let tw_f = (tw.max(1)) as f32;
            let th_f = (th.max(1)) as f32;
            let fit_scale = (max_stage_w / tw_f).min(max_stage_h / th_f).min(1.5);
            (tw_f * fit_scale, th_f * fit_scale, Some((tw, th)))
        } else {
            (340.0_f32.min(max_stage_w), 220.0_f32.min(max_stage_h), None)
        };

        // Mouse-wheel zoom (zooms smoothly around cursor without clamping disp_w/disp_h to max_stage)
        let scroll_y = ctx.input(|i| {
            if i.raw_scroll_delta.y.abs() > 0.1 {
                i.raw_scroll_delta.y
            } else {
                i.smooth_scroll_delta.y
            }
        });
        if scroll_y.abs() > 0.1 {
            let old_zoom = viewer.zoom;
            let factor = if scroll_y > 0.0 { 1.15 } else { 1.0 / 1.15 };
            let new_zoom = (old_zoom * factor).clamp(0.25, 8.0);
            if let Some(ptr) = ctx.input(|i| i.pointer.hover_pos()) {
                if stage_area_rect.contains(ptr) {
                    let rel = ptr - (stage_area_rect.center() + viewer.pan);
                    viewer.pan -= rel * (new_zoom / old_zoom - 1.0);
                }
            }
            viewer.zoom = new_zoom;
        }

        let disp_w = (base_w * viewer.zoom).max(48.0);
        let disp_h = (base_h * viewer.zoom).max(48.0);

        // Clamp pan so the image stays centered when <= stage size, and pans within bounds when enlarged
        let max_pan_x = ((disp_w - stage_area_rect.width() + 40.0) * 0.5).max(0.0);
        let max_pan_y = ((disp_h - stage_area_rect.height() + 40.0) * 0.5).max(0.0);
        viewer.pan.x = viewer.pan.x.clamp(-max_pan_x, max_pan_x);
        viewer.pan.y = viewer.pan.y.clamp(-max_pan_y, max_pan_y);

        // 1. Unified Clipped Stage Canvas (never uses a floating Area at img_pos so it NEVER shifts left!)
        egui::Area::new(Id::new("image_viewer_backdrop"))
            .order(egui::Order::Middle)
            .constrain(false)
            .fixed_pos(stage_area_rect.min)
            .show(ctx, |ui| {
                let (bg_rect, bg_resp) =
                    ui.allocate_exact_size(stage_area_rect.size(), Sense::click_and_drag());
                let painter = ui.painter().with_clip_rect(bg_rect);
                let bg_col = if pal.is_dark {
                    Color32::from_rgba_unmultiplied(24, 26, 31, 244)
                } else {
                    Color32::from_rgba_unmultiplied(24, 28, 36, 228)
                };
                painter.rect_filled(bg_rect, Rounding::ZERO, bg_col);

                let img_center = bg_rect.center() + viewer.pan;
                let img_rect = Rect::from_center_size(img_center, Vec2::new(disp_w, disp_h));

                if let Some(ref tex) = active_tex {
                    painter.image(
                        tex.id(),
                        img_rect,
                        Rect::from_min_max(Pos2::ZERO, Pos2::new(1.0, 1.0)),
                        Color32::WHITE,
                    );
                    painter.rect_stroke(img_rect, Rounding::ZERO, Stroke::new(1.0_f32, pal.border));

                    if bg_resp.dragged_by(egui::PointerButton::Primary) {
                        viewer.pan += bg_resp.drag_delta();
                        viewer.pan.x = viewer.pan.x.clamp(-max_pan_x, max_pan_x);
                        viewer.pan.y = viewer.pan.y.clamp(-max_pan_y, max_pan_y);
                        ctx.set_cursor_icon(CursorIcon::Grabbing);
                    } else if let Some(ptr) = bg_resp.hover_pos() {
                        if img_rect.contains(ptr) && (max_pan_x > 1.0 || max_pan_y > 1.0) {
                            ctx.set_cursor_icon(CursorIcon::Grab);
                        }
                    }

                    if bg_resp.double_clicked() {
                        if (viewer.zoom - 1.0).abs() < 0.05 {
                            viewer.zoom = 2.0;
                        } else {
                            viewer.zoom = 1.0;
                            viewer.pan = Vec2::ZERO;
                        }
                    } else if bg_resp.clicked() {
                        let ptr = bg_resp
                            .interact_pointer_pos()
                            .or_else(|| ctx.input(|i| i.pointer.latest_pos()));
                        if ptr.map(|p| !img_rect.contains(p)).unwrap_or(false) {
                            should_close = true;
                        }
                    }
                } else {
                    painter.rect_filled(img_rect, Rounding::same(8.0), pal.bg_elevated);
                    painter.rect_stroke(
                        img_rect,
                        Rounding::same(8.0),
                        Stroke::new(1.0_f32, pal.border),
                    );
                    painter.text(
                        img_rect.center(),
                        egui::Align2::CENTER_CENTER,
                        "Đang tải hình ảnh…",
                        FontId::proportional(13.0),
                        pal.text_primary,
                    );
                    if bg_resp.clicked() {
                        should_close = true;
                    }
                }
            });
        // 3. Clean Unified Top Toolbar Bar (docked under custom title bar, matching Atom One Dark pal.bg_sidebar)
        let clean_title = {
            let mut t = viewer.title.trim().trim_start_matches(lucide::IMAGE).trim();
            if let Some(paren_idx) = t.rfind(" (") {
                if t[paren_idx..].contains('×')
                    || t[paren_idx..].contains("KB")
                    || t[paren_idx..].contains("MB")
                {
                    t = t[..paren_idx].trim();
                }
            }
            if t.is_empty() {
                "Hình ảnh đính kèm"
            } else {
                t
            }
        };

        egui::Area::new(Id::new("image_viewer_top_bar"))
            .order(egui::Order::Foreground)
            .fixed_pos(toolbar_rect.min)
            .show(ctx, |ui| {
                egui::Frame::none()
                    .fill(pal.bg_sidebar)
                    .stroke(Stroke::new(1.0_f32, pal.border))
                    .inner_margin(Margin::symmetric(16.0, 6.0))
                    .show(ui, |ui| {
                        ui.set_min_size(Vec2::new(
                            (toolbar_rect.width() - 32.0).max(200.0),
                            toolbar_h - 12.0,
                        ));
                        ui.set_max_size(Vec2::new(
                            (toolbar_rect.width() - 32.0).max(200.0),
                            toolbar_h - 12.0,
                        ));
                        ui.horizontal_centered(|ui| {
                            // Left: Subtle icon badge + filename + sender/time/dimensions
                            let (badge_r, _) =
                                ui.allocate_exact_size(Vec2::splat(28.0), Sense::hover());
                            ui.painter()
                                .rect_filled(badge_r, Rounding::same(6.0), pal.bg_elevated);
                            draw_icon_image(
                                ui.painter(),
                                badge_r.center(),
                                15.0,
                                pal.primary_hover,
                            );
                            ui.add_space(4.0);
                            ui.vertical(|ui| {
                                ui.spacing_mut().item_spacing.y = 1.0;
                                ui.label(
                                    RichText::new(truncate_chars(clean_title, 44))
                                        .size(13.0)
                                        .color(pal.text_primary)
                                        .strong(),
                                );
                                let dim_str = match natural_dims {
                                    Some((tw, th)) => format!(" · {tw}×{th} px"),
                                    None => String::new(),
                                };
                                let sub = if viewer.time.is_empty() {
                                    format!("{}{dim_str}", viewer.sender)
                                } else {
                                    format!(
                                        "Gửi bởi {} lúc {}{dim_str}",
                                        viewer.sender, viewer.time
                                    )
                                };
                                ui.label(RichText::new(sub).size(11.0).color(pal.text_muted));
                            });

                            // Right: Unified Zoom + Actions + Close
                            ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                ui.spacing_mut().item_spacing.x = 6.0;

                                // Close button (30x28, Atom One Dark style)
                                let (close_r, close_resp) =
                                    ui.allocate_exact_size(Vec2::new(30.0, 28.0), Sense::click());
                                ui.painter().rect_filled(
                                    close_r,
                                    Rounding::same(6.0),
                                    if close_resp.hovered() {
                                        pal.danger
                                    } else {
                                        pal.bg_elevated
                                    },
                                );
                                ui.painter().rect_stroke(
                                    close_r,
                                    Rounding::same(6.0),
                                    Stroke::new(1.0_f32, pal.border),
                                );
                                draw_lucide_icon(
                                    ui.painter(),
                                    close_r.center(),
                                    lucide::X,
                                    14.5,
                                    if close_resp.hovered() {
                                        Color32::WHITE
                                    } else {
                                        pal.text_secondary
                                    },
                                );
                                if close_resp
                                    .on_hover_cursor(CursorIcon::PointingHand)
                                    .on_hover_text("Đóng xem ảnh (Esc)")
                                    .clicked()
                                {
                                    should_close = true;
                                }

                                if !viewer.full_url.is_empty() {
                                    let ext_btn = egui::Button::new(
                                        RichText::new(format!("{} Mở gốc", lucide::EXTERNAL_LINK))
                                            .size(11.8)
                                            .color(pal.text_primary),
                                    )
                                    .fill(pal.bg_elevated)
                                    .stroke(Stroke::new(1.0_f32, pal.border))
                                    .rounding(Rounding::same(6.0))
                                    .min_size(Vec2::new(72.0, 28.0));
                                    if ui
                                        .add(ext_btn)
                                        .on_hover_cursor(CursorIcon::PointingHand)
                                        .on_hover_text(&viewer.full_url)
                                        .clicked()
                                    {
                                        open_external_url(&viewer.full_url);
                                    }

                                    let copy_btn = egui::Button::new(
                                        RichText::new(format!("{} Sao chép", lucide::COPY))
                                            .size(11.8)
                                            .color(pal.text_secondary),
                                    )
                                    .fill(pal.bg_elevated)
                                    .stroke(Stroke::new(1.0_f32, pal.border))
                                    .rounding(Rounding::same(6.0))
                                    .min_size(Vec2::new(78.0, 28.0));
                                    if ui
                                        .add(copy_btn)
                                        .on_hover_cursor(CursorIcon::PointingHand)
                                        .clicked()
                                    {
                                        ui.ctx().copy_text(viewer.full_url.clone());
                                        self.show_toast("Đã sao chép đường dẫn ảnh vào bộ nhớ tạm");
                                    }
                                }

                                // Zoom In (+)
                                let zin_btn = egui::Button::new(
                                    RichText::new(lucide::PLUS)
                                        .size(12.5)
                                        .color(pal.text_secondary),
                                )
                                .fill(pal.bg_elevated)
                                .stroke(Stroke::new(1.0_f32, pal.border))
                                .rounding(Rounding::same(6.0))
                                .min_size(Vec2::new(28.0, 28.0));
                                if ui
                                    .add(zin_btn)
                                    .on_hover_cursor(CursorIcon::PointingHand)
                                    .on_hover_text("Phóng to (+25%)")
                                    .clicked()
                                {
                                    viewer.zoom = (viewer.zoom + 0.25).min(8.0);
                                }

                                // Zoom Percentage Reset
                                let zoom_pct = format!("{:.0}%", viewer.zoom * 100.0);
                                let zreset_btn = egui::Button::new(
                                    RichText::new(zoom_pct)
                                        .size(11.8)
                                        .color(pal.primary_hover)
                                        .strong(),
                                )
                                .fill(pal.bg_input)
                                .stroke(Stroke::new(1.0_f32, pal.border))
                                .rounding(Rounding::same(6.0))
                                .min_size(Vec2::new(50.0, 28.0));
                                if ui
                                    .add(zreset_btn)
                                    .on_hover_cursor(CursorIcon::PointingHand)
                                    .on_hover_text("Đặt lại 100% (hoặc nhấp đúp vào ảnh)")
                                    .clicked()
                                {
                                    viewer.zoom = 1.0;
                                    viewer.pan = Vec2::ZERO;
                                }

                                // Zoom Out (-)
                                let zout_btn = egui::Button::new(
                                    RichText::new(lucide::MINUS)
                                        .size(12.5)
                                        .color(pal.text_secondary),
                                )
                                .fill(pal.bg_elevated)
                                .stroke(Stroke::new(1.0_f32, pal.border))
                                .rounding(Rounding::same(6.0))
                                .min_size(Vec2::new(28.0, 28.0));
                                if ui
                                    .add(zout_btn)
                                    .on_hover_cursor(CursorIcon::PointingHand)
                                    .on_hover_text("Thu nhỏ (-25%)")
                                    .clicked()
                                {
                                    viewer.zoom = (viewer.zoom - 0.25).max(0.25);
                                    if viewer.zoom <= 1.0 {
                                        viewer.pan = Vec2::ZERO;
                                    }
                                }
                            });
                        });
                    });
            });

        if should_close {
            self.image_viewer = None;
        } else {
            self.image_viewer = Some(viewer);
        }
    }

    /// Detect an `http://` or `https://` URL in `self.input_message` and asynchronously fetch its
    /// OpenGraph / Zalo `parselink` metadata (`title`, `desc`, `thumb`, `src`).
    pub(super) fn resolve_composer_link_preview(
        &mut self,
        ctx: &egui::Context,
    ) -> Option<crate::chat::LinkMetadata> {
        let Some(url) = crate::chat::extract_first_url(&self.input_message) else {
            self.dismissed_link_preview_for.clear();
            return None;
        };
        if self.dismissed_link_preview_for == url {
            return None;
        }
        let elapsed = self.last_composer_edit_at.elapsed();
        let debounce = Duration::from_millis(200);
        if elapsed < debounce {
            ctx.request_repaint_after(debounce - elapsed + Duration::from_millis(15));
            return self.link_metadata_cache.get(&url).cloned();
        }
        if let Some(cached) = self.link_metadata_cache.get(&url).cloned() {
            return Some(cached);
        }
        if self.loading_link_previews.insert(url.clone()) {
            if let Some(tx) = WORKER_TX.get() {
                let _ = tx.send(WorkerCmd::ParseLinkPreview { url: url.clone() });
            }
        }
        let domain = url
            .split("://")
            .nth(1)
            .and_then(|r| r.split('/').next())
            .unwrap_or("Liên kết")
            .to_string();
        Some(crate::chat::LinkMetadata {
            url,
            title: "Đang tải thông tin liên kết…".into(),
            desc: String::new(),
            thumb: String::new(),
            src: domain,
        })
    }

    /// Render a floating Link Preview card (`egui::Area`) anchored directly above `composer_rect`
    /// when the user types or pastes a URL into the composer input.
    pub(super) fn render_composer_link_preview_popover(
        &mut self,
        ctx: &egui::Context,
        composer_rect: Rect,
        meta: &crate::chat::LinkMetadata,
        pal: &ThemePalette,
    ) {
        let strip_h = 72.0_f32;
        let strip_w = composer_rect.width().max(220.0);
        let pos = Pos2::new(
            composer_rect.left(),
            (composer_rect.top() - strip_h).max(48.0),
        );
        let mut dismiss_clicked = false;

        egui::Area::new(Id::new("zalo_composer_link_preview_popover"))
            .order(egui::Order::Foreground)
            .fixed_pos(pos)
            .show(ctx, |ui| {
                egui::Frame::none()
                    .fill(if pal.is_dark {
                        Color32::from_rgba_unmultiplied(33, 37, 43, 248)
                    } else {
                        Color32::from_rgba_unmultiplied(255, 255, 255, 250)
                    })
                    .stroke(Stroke::new(1.0_f32, pal.border))
                    .rounding(Rounding {
                        nw: 12.0,
                        ne: 12.0,
                        sw: 0.0,
                        se: 0.0,
                    })
                    .shadow(egui::epaint::Shadow {
                        offset: Vec2::new(0.0, -3.0),
                        blur: 12.0,
                        spread: 0.0,
                        color: Color32::from_black_alpha(if pal.is_dark { 85 } else { 24 }),
                    })
                    .inner_margin(Margin::symmetric(14.0, 8.0))
                    .show(ui, |ui| {
                        let inner_w = (strip_w - 28.0).max(160.0);
                        ui.set_min_width(inner_w);
                        ui.set_max_width(inner_w);
                        ui.set_max_height(54.0);
                        ui.horizontal(|ui| {
                            let thumb_key = if !meta.thumb.is_empty() {
                                Some(format!("thumb_{}", crate::crypto::md5_hex(&meta.thumb)))
                            } else {
                                None
                            };
                            if let Some(tkey) = thumb_key.as_deref() {
                                if let Some(tex) = self.sticker_textures.get(tkey) {
                                    ui.add(
                                        egui::Image::new(tex)
                                            .fit_to_exact_size(Vec2::new(48.0, 48.0))
                                            .rounding(Rounding::same(7.0)),
                                    );
                                    ui.add_space(6.0);
                                }
                            }
                            let text_w = (inner_w - 94.0).max(100.0);
                            ui.vertical(|ui| {
                                ui.set_max_width(text_w);
                                ui.label(
                                    RichText::new(format!(
                                        "{} {}",
                                        lucide::GLOBE,
                                        truncate_chars(&meta.title, 54)
                                    ))
                                    .size(12.5)
                                    .color(pal.primary_hover)
                                    .strong(),
                                );
                                let sub = if !meta.desc.is_empty() {
                                    truncate_chars(&meta.desc, 68).into_owned()
                                } else {
                                    clean_display_url(&meta.url, 48)
                                };
                                ui.label(RichText::new(sub).size(11.3).color(pal.text_secondary));
                            });
                            ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                                if ui
                                    .small_button(lucide::X)
                                    .on_hover_cursor(CursorIcon::PointingHand)
                                    .on_hover_text("Ẩn xem trước liên kết")
                                    .clicked()
                                {
                                    dismiss_clicked = true;
                                }
                            });
                        });
                    });
            });

        if dismiss_clicked {
            self.dismissed_link_preview_for = meta.url.clone();
        }
    }

    pub(super) fn render_dev_logs(&mut self, ui: &mut egui::Ui) {
        let entries = logger::get_entries();
        ui.horizontal(|ui| {
            ui.vertical(|ui| {
                ui.set_width(360.0);
                egui::ScrollArea::vertical()
                    .id_salt("dev_logs_list_scroll")
                    .show(ui, |ui| {
                        for e in entries.iter().rev() {
                            let st_str = e
                                .status
                                .map(|s| s.to_string())
                                .unwrap_or_else(|| "ERR".into());
                            let row = ui.selectable_label(
                                self.selected_log
                                    .as_ref()
                                    .map(|s| s.id == e.id)
                                    .unwrap_or(false),
                                format!(
                                    "[{}] {} {} ({}ms)",
                                    e.timestamp, e.method, st_str, e.latency_ms
                                ),
                            );
                            if row.clicked() {
                                self.selected_log = Some(e.clone());
                            }
                        }
                    });
            });

            ui.separator();

            ui.vertical(|ui| {
                if let Some(e) = &self.selected_log {
                    ui.strong(format!("{} {}", e.method, e.url));
                    ui.label(format!(
                        "Thời gian: {} · Độ trễ: {}ms · HTTP: {:?}",
                        e.timestamp, e.latency_ms, e.status
                    ));
                    if let Some(err) = &e.error_msg {
                        ui.colored_label(Color32::RED, format!("Lỗi: {err}"));
                    }
                    ui.separator();

                    egui::ScrollArea::vertical()
                        .id_salt("dev_logs_detail_scroll")
                        .show(ui, |ui| {
                            if let Some(dec) = &e.decrypted_preview {
                                ui.label("Dữ liệu giải mã (Decrypted Payload):");
                                ui.code(dec);
                            } else {
                                ui.label("Payload:");
                                ui.code(&e.payload_preview);
                            }
                        });
                } else {
                    ui.label("Chọn một request bên trái để kiểm tra chi tiết.");
                }
            });
        });
    }

    pub(super) fn render_dev_scanner(&mut self, ui: &mut egui::Ui) {
        egui::ScrollArea::vertical()
            .id_salt("dev_scanner_scroll")
            .show(ui, |ui| {
                ui.heading("Báo cáo quét chẩn đoán tự động:");
                ui.add_space(6.0);

                if self.scanner_findings.is_empty() {
                    ui.label("Bấm 'Làm mới quét' để chạy kiểm tra.");
                }

                for f in &self.scanner_findings {
                    let (badge_text, color) = match f.level {
                        FindingLevel::Info => ("INFO", Color32::from_rgb(40, 167, 69)),
                        FindingLevel::Warning => ("CẢNH BÁO", Color32::from_rgb(255, 193, 7)),
                        FindingLevel::Critical => ("NGHIÊM TRỌNG", Color32::RED),
                    };

                    egui::Frame::group(ui.style())
                        .stroke(Stroke::new(1.0_f32, color))
                        .inner_margin(8.0)
                        .show(ui, |ui| {
                            ui.horizontal(|ui| {
                                ui.colored_label(color, format!("[{badge_text}]"));
                                ui.strong(&f.title);
                            });
                            ui.label(&f.detail);
                            ui.label(
                                RichText::new(format!("Khắc phục: {}", f.suggestion))
                                    .color(Color32::from_rgb(0, 104, 255)),
                            );
                        });
                    ui.add_space(6.0);
                }
            });
    }

    pub(super) fn render_dev_crypto(&mut self, ui: &mut egui::Ui) {
        egui::ScrollArea::vertical()
            .id_salt("dev_crypto_scroll")
            .show(ui, |ui| {
                ui.heading("Thông số mật mã & Khung giao thức:");
                ui.add_space(8.0);

                egui::Grid::new("crypto_grid").striped(true).show(ui, |ui| {
                    ui.label("API Version (zpw_ver):");
                    ui.code(crate::session::ZPW_VER);
                    ui.end_row();

                    ui.label("API Type (zpw_type):");
                    ui.code(crate::session::ZPW_TYPE);
                    ui.end_row();

                    ui.label("ParamCipher Master Key:");
                    ui.code(format!("{:02X?}", crate::param_cipher::PARAM_CIPHER_KEY));
                    ui.end_row();

                    ui.label("Zero IV:");
                    ui.code("00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 (16 zero bytes)");
                    ui.end_row();

                    ui.label("Thuật toán mã hoá:");
                    ui.label("AES-128-CBC / AES-256-CBC with PKCS7 padding");
                    ui.end_row();

                    ui.label("Chữ ký SignKey:");
                    ui.code("md5('zsecure' + tag + sorted_values)");
                    ui.end_row();
                });
            });
    }
}

/// Extract up to 6 concise changelog bullet lines from a GitHub Release body,
/// skipping images (`![...]`), tables (`|...|`), code blocks (` ``` `), and OS install instructions.
fn extract_concise_changelog(markdown: &str) -> Vec<String> {
    let mut bullets: Vec<String> = Vec::new();
    let mut in_code = false;
    let mut in_install_section = false;

    for line in markdown.lines() {
        let trimmed = line.trim();
        if trimmed.starts_with("```") {
            in_code = !in_code;
            continue;
        }
        if in_code || trimmed.is_empty() {
            continue;
        }
        if trimmed.starts_with('#') {
            let h_low = trimmed.to_lowercase();
            in_install_section = h_low.contains("bản cài đặt")
                || h_low.contains("hướng dẫn cài")
                || h_low.contains("installation");
            continue;
        }
        if in_install_section {
            continue;
        }
        if let Some(b) = trimmed
            .strip_prefix("- ")
            .or_else(|| trimmed.strip_prefix("* "))
        {
            let b_clean = b.trim();
            let b_low = b_clean.to_lowercase();
            if b_clean.is_empty()
                || b_low.starts_with("bộ cài đặt:")
                || b_low.starts_with("bản chạy ngay")
                || b_low.contains("sudo apt")
                || b_low.contains("sudo dnf")
                || b_low.contains(".deb")
                || b_low.contains(".rpm")
                || b_low.contains(".dmg")
                || b_low.contains(".appimage")
            {
                continue;
            }
            bullets.push(b_clean.to_string());
        }
    }
    bullets
}

/// Render a single bullet item containing `**bold**`, `` `code` ``, and `[label](url)` links
/// into one unified wrapped `LayoutJob` so the bullet `• ` and text never collide or clip.
fn render_markdown_bullet_line(
    ui: &mut egui::Ui,
    text: &str,
    size: f32,
    bullet_color: Color32,
    base_color: Color32,
    pal: &ThemePalette,
) {
    let mut job = egui::text::LayoutJob::default();
    job.append(
        "•  ",
        0.0,
        egui::TextFormat {
            font_id: FontId::proportional(size + 0.5),
            color: bullet_color,
            ..Default::default()
        },
    );
    let first_link = append_markdown_inline_to_job(&mut job, text, size, base_color, pal);
    if let Some(url) = first_link {
        let resp = ui.add(egui::Label::new(job).wrap().sense(Sense::click()));
        if resp
            .on_hover_cursor(CursorIcon::PointingHand)
            .on_hover_text(&url)
            .clicked()
        {
            open_external_url(&url);
        }
    } else {
        ui.add(egui::Label::new(job).wrap());
    }
}

fn find_next_markdown_link(s: &str) -> Option<(usize, usize, usize)> {
    let mut search_from = 0;
    while let Some(rel_lb) = s[search_from..].find('[') {
        let lb = search_from + rel_lb;
        let after_lb = &s[lb + 1..];
        if let Some(rb) = after_lb.find("](") {
            let label_part = &after_lb[..rb];
            if !label_part.contains('[') && !label_part.contains('\n') {
                let after_rb = &after_lb[rb + 2..];
                if let Some(rp) = after_rb.find(')') {
                    let url_part = &after_rb[..rp];
                    if !url_part.contains(' ') && !url_part.contains('\n') {
                        return Some((lb, lb + 1 + rb, lb + 1 + rb + 2 + rp));
                    }
                }
            }
        }
        search_from = lb + 1;
    }
    None
}

fn append_markdown_inline_to_job(
    job: &mut egui::text::LayoutJob,
    text: &str,
    size: f32,
    base_color: Color32,
    pal: &ThemePalette,
) -> Option<String> {
    let mut first_link: Option<String> = None;
    let mut rest = text;

    while !rest.is_empty() {
        let next_bold = rest.find("**");
        let next_code = rest.find('`');
        let next_link = find_next_markdown_link(rest);

        let min_pos = [next_bold, next_code, next_link.map(|(lb, _, _)| lb)]
            .into_iter()
            .flatten()
            .min();

        let Some(pos) = min_pos else {
            job.append(
                rest,
                0.0,
                egui::TextFormat {
                    font_id: FontId::proportional(size),
                    color: base_color,
                    ..Default::default()
                },
            );
            break;
        };

        if pos > 0 {
            job.append(
                &rest[..pos],
                0.0,
                egui::TextFormat {
                    font_id: FontId::proportional(size),
                    color: base_color,
                    ..Default::default()
                },
            );
            rest = &rest[pos..];
            continue;
        }

        if let Some((0, rb_idx, rp_idx)) = next_link {
            let label = &rest[1..rb_idx];
            let url = &rest[rb_idx + 2..rp_idx];
            if first_link.is_none() && (url.starts_with("http://") || url.starts_with("https://")) {
                first_link = Some(url.to_string());
            }
            let clean_lbl = label.trim_matches('*').trim_matches('`');
            job.append(
                clean_lbl,
                0.0,
                egui::TextFormat {
                    font_id: FontId::proportional(size),
                    color: pal.primary_hover,
                    underline: Stroke::new(1.0_f32, pal.primary_hover),
                    ..Default::default()
                },
            );
            rest = &rest[rp_idx + 1..];
            continue;
        }

        if rest.starts_with("**") {
            let after = &rest[2..];
            if let Some(end_b) = after.find("**") {
                let bold_txt = &after[..end_b];
                let clean_bold = extract_markdown_links_inline(bold_txt);
                job.append(
                    &clean_bold,
                    0.0,
                    egui::TextFormat {
                        font_id: FontId::proportional(size + 0.3),
                        color: pal.text_primary,
                        ..Default::default()
                    },
                );
                rest = &after[end_b + 2..];
                continue;
            }
        }

        if rest.starts_with('`') {
            let after = &rest[1..];
            if let Some(end_c) = after.find('`') {
                let code_txt = &after[..end_c];
                job.append(
                    code_txt,
                    0.0,
                    egui::TextFormat {
                        font_id: FontId::monospace((size - 0.6).max(10.5)),
                        color: pal.primary_hover,
                        background: pal.bg_input,
                        ..Default::default()
                    },
                );
                rest = &after[end_c + 1..];
                continue;
            }
        }

        let mut chars = rest.chars();
        if let Some(ch) = chars.next() {
            let mut buf = [0u8; 4];
            job.append(
                ch.encode_utf8(&mut buf),
                0.0,
                egui::TextFormat {
                    font_id: FontId::proportional(size),
                    color: base_color,
                    ..Default::default()
                },
            );
            rest = chars.as_str();
        } else {
            break;
        }
    }

    first_link
}

/// Collapse `[label](url)` inside a bold segment into `label` so raw URLs never leak.
fn extract_markdown_links_inline(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    let mut rest = s;
    while !rest.is_empty() {
        if let Some((lb, rb, rp)) = find_next_markdown_link(rest) {
            out.push_str(&rest[..lb]);
            out.push_str(&rest[lb + 1..rb]);
            rest = &rest[rp + 1..];
        } else {
            out.push_str(rest);
            break;
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn call_gallery_fit_aspects_and_speaker_layout_stay_within_bounds() {
        let stage = Rect::from_min_size(Pos2::new(10.0, 20.0), Vec2::new(800.0, 500.0));
        for n in [1, 2, 3, 4, 6, 9] {
            let tiles = compute_call_gallery_tiles(n, stage, 8.0, 16.0 / 9.0);
            assert_eq!(tiles.len(), n);
            for r in tiles {
                assert!(r.width() > 0.0 && r.height() > 0.0);
                assert!(r.left() >= stage.left() - 1.0 && r.right() <= stage.right() + 1.0);
                assert!(r.top() >= stage.top() - 1.0 && r.bottom() <= stage.bottom() + 1.0);
            }
        }

        let mixed = compute_call_fit_aspects(&[9.0 / 16.0, 16.0 / 9.0], stage, 10.0);
        assert_eq!(mixed.len(), 2);
        assert!(mixed[0].width() < mixed[0].height());
        assert!(mixed[1].width() > mixed[1].height());

        let (main_r, strip) = compute_call_speaker_layout(3, stage, 8.0, 16.0 / 9.0);
        assert!(main_r.width() > 400.0);
        assert_eq!(strip.len(), 3);

        assert_eq!(compute_call_per_page(280.0), 2);
        assert_eq!(compute_call_per_page(460.0), 4);
        assert_eq!(compute_call_per_page(650.0), 6);
        assert_eq!(compute_call_per_page(900.0), 8);

        let qr_defaults = default_quick_reply_items();
        assert_eq!(qr_defaults.len(), 4);
        assert!(qr_defaults[0].contains("bận"));
    }

    #[test]
    fn unread_badge_icon_and_device_filter_behave_correctly() {
        let icon0 = crate::gui::theme::load_app_icon_with_badge(0).unwrap();
        assert_eq!(icon0.rgba.len(), (icon0.width * icon0.height * 4) as usize);

        let icon5 = crate::gui::theme::load_app_icon_with_badge(5).unwrap();
        assert_eq!((icon5.width, icon5.height), (64, 64));
        assert_eq!(icon5.rgba.len(), 64 * 64 * 4);

        let icon99 = crate::gui::theme::load_app_icon_with_badge(125).unwrap();
        assert_eq!((icon99.width, icon99.height), (64, 64));

        assert!(crate::media::is_ignored_virtual_or_ir_device(
            "Integrated IR Camera"
        ));
        assert!(crate::media::is_ignored_virtual_or_ir_device(
            "Windows Hello Depth Camera"
        ));
        assert!(crate::media::is_ignored_virtual_or_ir_device(
            "Monitor of Built-in Audio"
        ));
        assert!(!crate::media::is_ignored_virtual_or_ir_device(
            "Integrated Webcam"
        ));
    }

    #[test]
    fn markdown_links_inside_bold_are_stripped_cleanly() {
        let raw = "Hẹn giờ gửi tin nhắn ([#38](https://github.com/ctdoteam1110/ctdozlite/issues/38)), REST API ([#35](https://github.com/ctdoteam1110/ctdozlite/issues/35))";
        let cleaned = extract_markdown_links_inline(raw);
        assert_eq!(cleaned, "Hẹn giờ gửi tin nhắn (#38), REST API (#35)");
    }
}
