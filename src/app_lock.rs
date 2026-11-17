//! Application Lock PIN security and Media Cache Management (#106).
//!
//! Provides cryptographic PIN hashing (salted SHA-256), verification,
//! and disk cache calculation/purging for temporary media, thumbnails, and sticker caches.

use sha2::{Digest, Sha256};
use std::path::Path;

const PIN_SALT_PREFIX: &[u8] = b"zlite_app_lock_salt_v1:";
const HIDDEN_CHAT_PIN_SALT_PREFIX: &[u8] = b"zlite_hidden_chat_pin_v1:";

/// Hashes an application PIN using SHA-256 with a domain-separated salt.
pub fn hash_app_pin(pin: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(PIN_SALT_PREFIX);
    hasher.update(pin.trim().as_bytes());
    format!("{:x}", hasher.finalize())
}

/// Verifies whether the provided PIN matches the stored hash.
pub fn verify_app_pin(pin: &str, stored_hash: &str) -> bool {
    if stored_hash.is_empty() {
        return false;
    }
    let candidate = hash_app_pin(pin);
    candidate.eq_ignore_ascii_case(stored_hash.trim())
}

/// Hashes a Hidden Chat PIN using SHA-256 with a domain-separated salt.
pub fn hash_hidden_chat_pin(pin: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(HIDDEN_CHAT_PIN_SALT_PREFIX);
    hasher.update(pin.trim().as_bytes());
    format!("{:x}", hasher.finalize())
}

/// Verifies whether the provided PIN matches the stored Hidden Chat PIN hash.
pub fn verify_hidden_chat_pin(pin: &str, stored_hash: &str) -> bool {
    if stored_hash.is_empty() || pin.trim().is_empty() {
        return false;
    }
    let candidate = hash_hidden_chat_pin(pin);
    candidate.eq_ignore_ascii_case(stored_hash.trim())
}

/// Recursively calculates total byte size of files within the given directories.
pub fn calculate_cache_size(dirs: &[&Path]) -> u64 {
    let mut total_bytes = 0u64;
    for dir in dirs {
        if !dir.exists() || !dir.is_dir() {
            continue;
        }
        if let Ok(entries) = std::fs::read_dir(dir) {
            for entry in entries.flatten() {
                let p = entry.path();
                if p.is_file() {
                    if let Ok(meta) = entry.metadata() {
                        total_bytes = total_bytes.saturating_add(meta.len());
                    }
                } else if p.is_dir() {
                    total_bytes = total_bytes.saturating_add(calculate_cache_size(&[&p]));
                }
            }
        }
    }
    total_bytes
}

/// Purges cached files within specific directories only, returning `(bytes_freed, files_deleted)`.
pub fn purge_directories(dirs: &[&Path]) -> (u64, usize) {
    let mut bytes_freed = 0u64;
    let mut files_deleted = 0usize;

    for dir in dirs {
        if !dir.exists() || !dir.is_dir() {
            continue;
        }
        if let Ok(entries) = std::fs::read_dir(dir) {
            for entry in entries.flatten() {
                let p = entry.path();
                if p.is_file() {
                    let len = entry.metadata().map(|m| m.len()).unwrap_or(0);
                    if std::fs::remove_file(&p).is_ok() {
                        bytes_freed = bytes_freed.saturating_add(len);
                        files_deleted += 1;
                    }
                } else if p.is_dir() {
                    let (sub_bytes, sub_files) = purge_directories(&[&p]);
                    bytes_freed = bytes_freed.saturating_add(sub_bytes);
                    files_deleted += sub_files;
                    let _ = std::fs::remove_dir(&p);
                }
            }
        }
    }
    (bytes_freed, files_deleted)
}

/// Scans the system temp directory for orphan zlite temporary video/audio/temp files.
pub fn purge_temp_artifacts() -> (u64, usize) {
    let mut bytes_freed = 0u64;
    let mut files_deleted = 0usize;

    let temp_dir = std::env::temp_dir();
    if let Ok(entries) = std::fs::read_dir(&temp_dir) {
        for entry in entries.flatten() {
            let p = entry.path();
            if p.is_file() {
                if let Some(file_name) = p.file_name().and_then(|s| s.to_str()) {
                    if file_name.starts_with("zlite_video_")
                        || file_name.starts_with("zlite_audio_")
                        || file_name.starts_with("zlite_temp_")
                    {
                        let len = entry.metadata().map(|m| m.len()).unwrap_or(0);
                        if std::fs::remove_file(&p).is_ok() {
                            bytes_freed = bytes_freed.saturating_add(len);
                            files_deleted += 1;
                        }
                    }
                }
            }
        }
    }
    (bytes_freed, files_deleted)
}

/// Purges cached files within the given directories and cleans orphan temp files, returning `(bytes_freed, files_deleted)`.
pub fn purge_media_cache(dirs: &[&Path]) -> (u64, usize) {
    let (d_bytes, d_files) = purge_directories(dirs);
    let (t_bytes, t_files) = purge_temp_artifacts();
    (d_bytes.saturating_add(t_bytes), d_files + t_files)
}

/// Formats byte count into human-readable unit (B, KB, MB, GB).
pub fn format_bytes(bytes: u64) -> String {
    const KB: u64 = 1024;
    const MB: u64 = 1024 * 1024;
    const GB: u64 = 1024 * 1024 * 1024;

    if bytes >= GB {
        format!("{:.2} GB", bytes as f64 / GB as f64)
    } else if bytes >= MB {
        format!("{:.2} MB", bytes as f64 / MB as f64)
    } else if bytes >= KB {
        format!("{:.1} KB", bytes as f64 / KB as f64)
    } else {
        format!("{bytes} B")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_task6_app_lock_pin_hashing_and_verification() {
        let pin = "123456";
        let hash = hash_app_pin(pin);
        assert!(!hash.is_empty());
        assert_eq!(hash.len(), 64); // SHA-256 hex string

        // Valid pin matches
        assert!(verify_app_pin("123456", &hash));
        assert!(verify_app_pin(" 123456 ", &hash)); // trimmed

        // Invalid pin fails
        assert!(!verify_app_pin("000000", &hash));
        assert!(!verify_app_pin("12345", &hash));
        assert!(!verify_app_pin("", &hash));
        assert!(!verify_app_pin("123456", ""));

        // Test hidden chat PIN
        let pin2 = "9876";
        let h_hash = hash_hidden_chat_pin(pin2);
        assert_ne!(h_hash, hash_app_pin(pin2)); // domain separation
        assert!(verify_hidden_chat_pin("9876", &h_hash));
        assert!(verify_hidden_chat_pin(" 9876 ", &h_hash));
        assert!(!verify_hidden_chat_pin("1234", &h_hash));
    }

    #[test]
    fn test_task6_cache_size_calculation_and_purging() {
        let test_dir = std::env::temp_dir().join(format!("zlite_test_cache_{}", std::process::id()));
        let _ = std::fs::create_dir_all(&test_dir);

        let file1 = test_dir.join("temp_1.bin");
        let file2 = test_dir.join("temp_2.bin");
        std::fs::write(&file1, b"hello world cache 1234").expect("write test file 1");
        std::fs::write(&file2, b"another cache entry file 5678").expect("write test file 2");

        let size = calculate_cache_size(&[&test_dir]);
        assert_eq!(size, 22 + 29); // 51 bytes

        let formatted = format_bytes(size);
        assert_eq!(formatted, "51 B");
        assert_eq!(format_bytes(2048), "2.0 KB");
        assert_eq!(format_bytes(10 * 1024 * 1024), "10.00 MB");

        let (freed, count) = purge_directories(&[&test_dir]);
        assert_eq!(freed, 51);
        assert_eq!(count, 2);

        let size_after = calculate_cache_size(&[&test_dir]);
        assert_eq!(size_after, 0);

        // Also test purge_temp_artifacts doesn't crash
        let _ = purge_temp_artifacts();

        let _ = std::fs::remove_dir_all(&test_dir);
    }
}
