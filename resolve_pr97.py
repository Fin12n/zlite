with open('src/gui/workspace.rs', 'r', encoding='utf-8') as f:
    content = f.read()

# First conflict
old1_marker = '<<<<<<< HEAD\n                    let posting_restricted = self.threads.get(self.selected_thread_index)'
old1_end = '>>>>>>> main'
assert old1_marker in content
assert old1_end in content

start1 = content.find(old1_marker)
end1 = content.find(old1_end) + len(old1_end)
# Replace entire first conflict with merged version
merged1 = '''                    let posting_restricted = self.threads.get(self.selected_thread_index)
                        .is_some_and(|thread| thread.is_group && thread.presentation.posting_restricted == Some(true));

                    let active_mention_info = if self.settings.suggest_mentions {
                        extract_active_mention_query(&self.input_message)
                            .map(|(pos, q)| (pos, q.to_string()))
                    } else {
                        None
                    };
                    let mut mention_candidates: Vec<MentionCandidate> = Vec::new();
                    if let Some((_, ref query)) = active_mention_info {
                        if &self.dismissed_mention_suggest_for != query {
                            let q_trim = query.trim();
                            let q_fold = crate::chat::strip_vn_for_sticker_kw(q_trim);

                            if is_group {
                                if q_trim.is_empty()
                                    || "all".contains(&q_fold)
                                    || "tat ca".contains(&q_fold)
                                    || "nhom".contains(&q_fold)
                                {
                                    mention_candidates.push(MentionCandidate {
                                        id: "-1".to_string(),
                                        name: "All".to_string(),
                                        avatar: None,
                                        role: "Nhac ca nhom (@All)".to_string(),
                                        is_all: true,
                                    });
                                }

                                if let Some(members) = self.group_members_map.get(&thread_id) {
                                    for m in members {
                                        if m.name.trim().is_empty() {
                                            continue;
                                        }
                                        if q_trim.is_empty() {
                                            mention_candidates.push(MentionCandidate {
                                                id: m.id.clone(),
                                                name: m.name.clone(),
                                                avatar: m.avatar.clone(),
                                                role: m.role.clone(),
                                                is_all: false,
                                            });
                                        } else {
                                            let m_fold = crate::chat::strip_vn_for_sticker_kw(&m.name);
                                            if m.name.to_lowercase().contains(&q_trim.to_lowercase())
                                                || m_fold.contains(&q_fold)
                                            {
                                                mention_candidates.push(MentionCandidate {
                                                    id: m.id.clone(),
                                                    name: m.name.clone(),
                                                    avatar: m.avatar.clone(),
                                                    role: m.role.clone(),
                                                    is_all: false,
                                                });
                                            }
                                        }
                                    }
                                } else if self.fetching_group_members.insert(thread_id.clone()) {
                                    if let Some(tx) = WORKER_TX.get() {
                                        let _ = tx.send(WorkerCmd::FetchGroupMembers {
                                            group_id: thread_id.clone(),
                                        });
                                    }
                                }
                            } else {
                                let p_name = thread_name.clone();
                                if !p_name.is_empty() {
                                    let p_fold = crate::chat::strip_vn_for_sticker_kw(&p_name);
                                    if q_trim.is_empty()
                                        || p_name.to_lowercase().contains(&q_trim.to_lowercase())
                                        || p_fold.contains(&q_fold)
                                    {
                                        mention_candidates.push(MentionCandidate {
                                            id: thread_id.clone(),
                                            name: p_name,
                                            avatar: thread_avatar.clone(),
                                            role: "Ban be".to_string(),
                                            is_all: false,
                                        });
                                    }
                                }
                            }
                        }
                    }

                    let contextual_stickers = if posting_restricted { Vec::new() } else { self.resolve_contextual_sticker_suggestions(ctx) };
                    let composer_link_preview = if posting_restricted {
                        None
                    } else {
                        self.resolve_composer_link_preview(ctx)
                    };'''

content = content[:start1] + merged1 + content[end1:]

# Second conflict
old2_marker = '<<<<<<< HEAD\n                    let picker_reserve = if posting_restricted'
old2_end = '>>>>>>> main'
assert old2_marker in content
start2 = content.find(old2_marker)
end2 = content.find(old2_end) + len(old2_end)
merged2 = '''                    let picker_reserve = if posting_restricted { 0.0 } else { (if self.sticker_picker_open { 268.0 } else { 0.0 })
                        + (if self.replying_to.is_some() { 48.0 } else { 0.0 })
                        + (if self.pending_clipboard_image.is_some() {
                            64.0
                        } else {
                            0.0
                        }) };'''
content = content[:start2] + merged2 + content[end2:]

# Third conflict
old3_marker = '<<<<<<< HEAD\n                    } else {\n                    // 3. Optional Sticker Picker Drawer'
old3_end = '>>>>>>> main'
assert old3_marker in content
start3 = content.find(old3_marker)
end3 = content.find(old3_end) + len(old3_end)
merged3 = '''                    } else {
                    // 3. Optional Sticker Picker Drawer'''
content = content[:start3] + merged3 + content[end3:]

with open('src/gui/workspace.rs', 'w', encoding='utf-8') as f:
    f.write(content)
print("All conflicts resolved")
