with open('src/gui/workspace.rs', 'r', encoding='utf-8') as f:
    content = f.read()

# First conflict: HEAD has posting_restricted, incoming (main) has mention candidates
# We want both
old1_start = content.find('<<<<<<< HEAD\n                    let posting_restricted = self.threads.get(self.selected_thread_index)')
old1_sep = content.find('=======', old1_start)
old1_end = content.find('>>>>>>> main', old1_sep) + len('>>>>>>> main')

head_part = content[old1_start + len('<<<<<<< HEAD\n'):old1_sep]
incoming_part = content[old1_sep + len('=======\n'):old1_end - len('>>>>>>> main')]

# Build merged: posting_restricted + mention candidates + contextual_stickers conditional
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

content = content[:old1_start] + merged1 + content[old1_end:]

# Second conflict
old2_start = content.find('<<<<<<< HEAD\n=======\n                    if let Some(mention_name)')
old2_end = content.find('>>>>>>> main', old2_start) + len('>>>>>>> main')
assert old2_start != -1, "second not found"
merged2 = '''                    if let Some(mention_name) = click_chosen_mention {
                        if let Some((at_pos, _)) = active_mention_info {
                            let prefix = &self.input_message[..at_pos];
                            self.input_message = format!("{}@{} ", prefix, mention_name);
                            self.composer_mention_selected = 0;
                            self.dismissed_mention_suggest_for.clear();
                            self.composer_focus_pending = true;
                        }
                    }'''
content = content[:old2_start] + merged2 + content[old2_end:]

with open('src/gui/workspace.rs', 'w', encoding='utf-8') as f:
    f.write(content)
print("Conflicts resolved")
