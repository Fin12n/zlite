with open('src/gui/workspace.rs', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix second conflict
old2 = """<<<<<<< HEAD
=======
                    if let Some(mention_name) = click_chosen_mention {
                        if let Some((at_pos, _)) = active_mention_info {
                            let prefix = &self.input_message[..at_pos];
                            self.input_message = format!("{}@{} ", prefix, mention_name);
                            self.composer_mention_selected = 0;
                            self.dismissed_mention_suggest_for.clear();
                            self.composer_focus_pending = true;
                        }
>>>>>>> main
                    }"""

new2 = """                    if let Some(mention_name) = click_chosen_mention {
                        if let Some((at_pos, _)) = active_mention_info {
                            let prefix = &self.input_message[..at_pos];
                            self.input_message = format!("{}@{} ", prefix, mention_name);
                            self.composer_mention_selected = 0;
                            self.dismissed_mention_suggest_for.clear();
                            self.composer_focus_pending = true;
                        }
                    }"""

assert old2 in content, 'second not found'
content = content.replace(old2, new2)

# Fix third conflict
old3 = """<<<<<<< HEAD
                    } else {
                    // 3. Optional Sticker Picker Drawer
=======
>>>>>>> main
                    }"""

new3 = """                    } else {
                    // 3. Optional Sticker Picker Drawer"""

assert old3 in content, 'third not found'
content = content.replace(old3, new3)

with open('src/gui/workspace.rs', 'w', encoding='utf-8') as f:
    f.write(content)
print("Fixed conflicts 2 and 3")
