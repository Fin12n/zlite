//! Select writable storage before opening sessions, caches, logs, or databases.

use anyhow::{bail, Context, Result};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};

static NEXT_FILE: AtomicU64 = AtomicU64::new(0);

#[derive(Debug, Clone, Default)]
struct WindowsPathEnv<'a> {
    local_app_data: Option<&'a Path>,
    user_profile: Option<&'a Path>,
    program_files: Option<&'a Path>,
    program_files_x86: Option<&'a Path>,
    program_w6432: Option<&'a Path>,
    system_root: Option<&'a Path>,
}

fn normalize_windows_path(path: &Path) -> String {
    let raw = path.to_string_lossy();
    let stripped = raw
        .strip_prefix(r"\\?\")
        .or_else(|| raw.strip_prefix("//?/"))
        .unwrap_or(&raw);
    let mut normalized = stripped.replace('/', r"\").to_ascii_lowercase();
    while normalized.len() > 3 && normalized.ends_with('\\') {
        normalized.pop();
    }
    normalized
}

fn path_is_within_windows_root(candidate: &Path, root: &Path) -> bool {
    let cand = normalize_windows_path(candidate);
    let base = normalize_windows_path(root);
    if cand.is_empty() || base.is_empty() {
        return false;
    }
    cand == base
        || cand
            .strip_prefix(&base)
            .is_some_and(|rest| rest.starts_with('\\'))
}

fn is_windows_protected_or_installed_dir(
    cwd: &Path,
    executable: &Path,
    env: &WindowsPathEnv<'_>,
) -> bool {
    let exe_dir = executable.parent();
    // Inno Setup always places `unins000.exe` / `unins000.dat` next to the binary,
    // including per-user installs under `%LOCALAPPDATA%\Programs\ctdozlite`.
    let has_uninstaller = exe_dir.is_some_and(|dir| {
        dir.join("unins000.exe").is_file() || dir.join("unins000.dat").is_file()
    });
    if has_uninstaller {
        return true;
    }

    let protected_roots = [
        env.program_files,
        env.program_files_x86,
        env.program_w6432,
        env.system_root,
    ];
    for root in protected_roots.into_iter().flatten() {
        if path_is_within_windows_root(cwd, root)
            || exe_dir.is_some_and(|dir| path_is_within_windows_root(dir, root))
        {
            return true;
        }
    }

    // Fallback when running in unit tests or minimal environments without ProgramFiles env vars.
    let targets = [Some(cwd), exe_dir];
    for dir in targets.into_iter().flatten() {
        let norm = normalize_windows_path(dir);
        if norm.contains(r"\program files\")
            || norm.ends_with(r"\program files")
            || norm.contains(r"\program files (x86)\")
            || norm.ends_with(r"\program files (x86)")
            || norm.contains(r"\windows\system32")
            || norm.contains(r"\windows\syswow64")
        {
            return true;
        }
    }

    false
}

fn resolve_windows_local_app_data_dir(env: &WindowsPathEnv<'_>) -> Result<PathBuf> {
    let base = env
        .local_app_data
        .filter(|p| !p.as_os_str().is_empty())
        .map(PathBuf::from)
        .or_else(|| {
            env.user_profile
                .filter(|p| !p.as_os_str().is_empty())
                .map(|p| p.join("AppData").join("Local"))
        })
        .context("Cần LOCALAPPDATA hoặc USERPROFILE để xác định thư mục dữ liệu người dùng")?;

    let is_abs = base.is_absolute()
        || base.to_str().is_some_and(|s| {
            let b = s.as_bytes();
            b.first().is_some_and(u8::is_ascii_alphabetic)
                && b.get(1) == Some(&b':')
                && matches!(b.get(2), Some(b'\\') | Some(b'/'))
        });
    if !is_abs {
        bail!("LOCALAPPDATA phải là đường dẫn tuyệt đối");
    }
    Ok(base.join("ctdozlite"))
}

fn parse_cli_storage_args(args: &[String]) -> Result<(Option<PathBuf>, Option<String>)> {
    let mut explicit = None;
    let mut profile_name = None;
    let mut i = 0;
    while i < args.len() {
        let value = if args[i] == "--data-dir" {
            i += 1;
            Some(
                args.get(i)
                    .filter(|value| !value.starts_with('-'))
                    .context("--data-dir yêu cầu đường dẫn")?
                    .as_str(),
            )
        } else {
            args[i].strip_prefix("--data-dir=")
        };
        if let Some(value) = value {
            if value.is_empty() {
                bail!("--data-dir yêu cầu đường dẫn không rỗng");
            }
            if explicit.is_some() {
                bail!("--data-dir chỉ được chỉ định một lần");
            }
            explicit = Some(PathBuf::from(value));
            i += 1;
            continue;
        }
        let prof_val = if args[i] == "--profile" {
            i += 1;
            Some(
                args.get(i)
                    .filter(|value| !value.starts_with('-'))
                    .context("--profile yêu cầu tên hồ sơ tài khoản")?
                    .as_str(),
            )
        } else {
            args[i].strip_prefix("--profile=")
        };
        if let Some(prof) = prof_val {
            let safe: String = prof
                .trim()
                .chars()
                .filter(|c| c.is_ascii_alphanumeric() || *c == '-' || *c == '_')
                .collect();
            if safe.is_empty() {
                bail!("--profile chỉ chấp nhận ký tự chữ, số, '-' hoặc '_'");
            }
            profile_name = Some(safe);
        }
        i += 1;
    }
    Ok((explicit, profile_name))
}

/// Resolve paths without changing process state, including in parallel tests.
///
/// # Errors
/// Returns an error for invalid storage options or a missing/relative bundle HOME.
pub fn resolve(
    args: &[String],
    cwd: &Path,
    executable: &Path,
    home: Option<&Path>,
    macos: bool,
) -> Result<(PathBuf, bool)> {
    resolve_with_platform(args, cwd, executable, home, macos, false, &WindowsPathEnv::default())
}

fn resolve_with_platform(
    args: &[String],
    cwd: &Path,
    executable: &Path,
    home: Option<&Path>,
    macos: bool,
    windows: bool,
    win_env: &WindowsPathEnv<'_>,
) -> Result<(PathBuf, bool)> {
    let (explicit, profile_name) = parse_cli_storage_args(args)?;
    if let Some(path) = explicit {
        return Ok((
            if path.is_absolute() || path.to_str().is_some_and(|s| s.starts_with('/')) {
                path
            } else {
                cwd.join(path)
            },
            true,
        ));
    }
    let bundled = executable
        .parent()
        .filter(|p| p.file_name().is_some_and(|n| n == "MacOS"))
        .and_then(Path::parent)
        .filter(|p| p.file_name().is_some_and(|n| n == "Contents"))
        .and_then(Path::parent)
        .is_some_and(|p| p.extension().is_some_and(|e| e == "app"));
    let (base, is_private) = if macos && bundled {
        let home = home.context("Cần HOME để xác định Application Support")?;
        if !home.is_absolute() && !home.to_str().is_some_and(|s| s.starts_with('/')) {
            bail!("HOME phải là đường dẫn tuyệt đối");
        }
        (home.join("Library/Application Support/ctdozlite"), true)
    } else if windows && is_windows_protected_or_installed_dir(cwd, executable, win_env) {
        (resolve_windows_local_app_data_dir(win_env)?, true)
    } else {
        (cwd.to_path_buf(), false)
    };
    if let Some(prof) = profile_name {
        return Ok((base.join("profiles").join(prof), true));
    }
    Ok((base, is_private))
}

/// Validate storage before any persistent state is opened.
///
/// # Errors
/// Returns an error if creation, permissions, or the writable probe fails.
pub fn prepare(path: &Path, private: bool) -> Result<()> {
    if private {
        #[cfg(unix)]
        {
            use std::os::unix::fs::{DirBuilderExt, PermissionsExt};
            let mut builder = std::fs::DirBuilder::new();
            builder
                .recursive(true)
                .mode(0o700)
                .create(path)
                .with_context(|| format!("Không tạo được thư mục dữ liệu {}", path.display()))?;
            std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o700)).with_context(
                || format!("Không đặt được quyền thư mục dữ liệu {}", path.display()),
            )?;
        }
        #[cfg(not(unix))]
        std::fs::create_dir_all(path)
            .with_context(|| format!("Không tạo được thư mục dữ liệu {}", path.display()))?;
    }
    let (probe_path, probe) = create_private_file(path, ".storage-probe")
        .with_context(|| format!("Thư mục dữ liệu không ghi được: {}", path.display()))?;
    drop(probe);
    std::fs::remove_file(&probe_path).context("Không xóa được tệp kiểm tra quyền ghi")?;
    Ok(())
}

/// Select storage once before workers or persistent state are opened.
///
/// # Errors
/// Returns an error when process paths or writable storage cannot be selected.
pub fn initialize(args: &[String]) -> Result<PathBuf> {
    let cwd = std::env::current_dir().context("Không xác định được thư mục làm việc")?;
    let executable =
        std::env::current_exe().context("Không xác định được đường dẫn chương trình")?;
    let home = std::env::var_os("HOME").map(PathBuf::from);
    let local_app_data = std::env::var_os("LOCALAPPDATA").map(PathBuf::from);
    let user_profile = std::env::var_os("USERPROFILE").map(PathBuf::from);
    let program_files = std::env::var_os("ProgramFiles").map(PathBuf::from);
    let program_files_x86 = std::env::var_os("ProgramFiles(x86)").map(PathBuf::from);
    let program_w6432 = std::env::var_os("ProgramW6432").map(PathBuf::from);
    let system_root = std::env::var_os("SystemRoot").map(PathBuf::from);

    let win_env = WindowsPathEnv {
        local_app_data: local_app_data.as_deref(),
        user_profile: user_profile.as_deref(),
        program_files: program_files.as_deref(),
        program_files_x86: program_files_x86.as_deref(),
        program_w6432: program_w6432.as_deref(),
        system_root: system_root.as_deref(),
    };

    let (explicit, profile_name) = parse_cli_storage_args(args)?;
    let (mut path, mut private) = resolve_with_platform(
        args,
        &cwd,
        &executable,
        home.as_deref(),
        cfg!(target_os = "macos"),
        cfg!(target_os = "windows"),
        &win_env,
    )?;

    if let Err(err) = prepare(&path, private) {
        // Portable fallback on Windows: when launched from a read-only directory without explicit
        // `--data-dir`, route storage to `%LOCALAPPDATA%\ctdozlite` instead of failing to boot.
        let is_perm_err = err
            .chain()
            .filter_map(|cause| cause.downcast_ref::<std::io::Error>())
            .any(|io_err| io_err.kind() == std::io::ErrorKind::PermissionDenied);
        if cfg!(target_os = "windows") && explicit.is_none() && !private && is_perm_err {
            let mut fallback = resolve_windows_local_app_data_dir(&win_env)?;
            if let Some(ref prof) = profile_name {
                fallback = fallback.join("profiles").join(prof);
            }
            prepare(&fallback, true)?;
            path = fallback;
            private = true;
        } else {
            return Err(err);
        }
    }

    // One-way migration from read-only / legacy install directory (e.g. C:\Program Files\ctdozlite
    // populated when the user previously launched as Administrator) to per-user `%LOCALAPPDATA%`.
    if cfg!(target_os = "windows") && explicit.is_none() && profile_name.is_none() && private {
        if let Some(exe_dir) = executable.parent() {
            if let Err(mig_err) = migrate_legacy_install_data_if_needed(exe_dir, &path) {
                eprintln!(
                    "Cảnh báo: Không thể di chuyển dữ liệu cũ từ {} sang {}: {mig_err}",
                    exe_dir.display(),
                    path.display()
                );
            }
        }
    }

    // Legacy storage callers use relative paths; switch once before creating workers.
    std::env::set_current_dir(&path)
        .with_context(|| format!("Không chọn được thư mục dữ liệu {}", path.display()))?;
    Ok(path)
}

fn copy_file_atomic(src: &Path, dst: &Path) -> Result<()> {
    if let Some(parent) = dst.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let parent = dst
        .parent()
        .filter(|p| !p.as_os_str().is_empty())
        .unwrap_or_else(|| Path::new("."));
    let (temporary, mut dst_file) = create_private_file(parent, ".migrate-tmp")
        .with_context(|| format!("Không tạo được tệp tạm di chuyển {}", dst.display()))?;
    let result = (|| -> Result<()> {
        let mut src_file = std::fs::File::open(src)
            .with_context(|| format!("Không đọc được {}", src.display()))?;
        std::io::copy(&mut src_file, &mut dst_file)?;
        dst_file.sync_all()?;
        drop(dst_file);
        std::fs::rename(&temporary, dst)
            .with_context(|| format!("Không lưu được {}", dst.display()))?;
        Ok(())
    })();
    if result.is_err() {
        let _ = std::fs::remove_file(&temporary);
    }
    result
}

fn copy_dir_recursive_missing(src_dir: &Path, dst_dir: &Path, depth: usize) -> Result<()> {
    if depth > 6 || !src_dir.is_dir() {
        return Ok(());
    }
    std::fs::create_dir_all(dst_dir)?;
    for entry in std::fs::read_dir(src_dir)? {
        let entry = entry?;
        let file_type = entry.file_type()?;
        if file_type.is_symlink() {
            continue;
        }
        let name = entry.file_name();
        let src_path = entry.path();
        let dst_path = dst_dir.join(&name);
        if file_type.is_dir() {
            copy_dir_recursive_missing(&src_path, &dst_path, depth + 1)?;
        } else if file_type.is_file() && !dst_path.exists() {
            let _ = copy_file_atomic(&src_path, &dst_path);
        }
    }
    Ok(())
}

fn has_legacy_user_data(dir: &Path) -> bool {
    const MARKERS: &[&str] = &[
        "session.json",
        "zalo_history.db",
        "threads_cache.json",
        "app_settings.json",
    ];
    if MARKERS.iter().any(|name| dir.join(name).is_file()) {
        return true;
    }
    if dir
        .join("accounts")
        .read_dir()
        .is_ok_and(|mut it| it.next().is_some())
    {
        return true;
    }
    std::fs::read_dir(dir).is_ok_and(|entries| {
        entries
            .flatten()
            .any(|e| e.path().extension().is_some_and(|ext| ext == "db"))
    })
}

/// Copy legacy user state once from a read-only install dir into per-user `%LOCALAPPDATA%`.
/// Never modifies or removes files in `source_dir` so standard users do not require UAC.
fn migrate_legacy_install_data_if_needed(source_dir: &Path, dest_dir: &Path) -> Result<()> {
    if !source_dir.is_dir() || normalize_windows_path(source_dir) == normalize_windows_path(dest_dir)
    {
        return Ok(());
    }
    let marker_path = dest_dir.join(".migrated_from_install");
    if marker_path.exists()
        || dest_dir.join("session.json").exists()
        || dest_dir.join("zalo_history.db").exists()
    {
        return Ok(());
    }
    if !has_legacy_user_data(source_dir) {
        return Ok(());
    }

    const SINGLE_FILES: &[&str] = &[
        "session.json",
        "app_settings.json",
        "threads_cache.json",
        "theme.json",
        "custom_stickers.json",
        "autoreply_rules.json",
        "zalo_debug.log",
    ];
    for file_name in SINGLE_FILES {
        let src = source_dir.join(file_name);
        let dst = dest_dir.join(file_name);
        if src.is_file() && !dst.exists() {
            let _ = copy_file_atomic(&src, &dst);
        }
    }

    if let Ok(entries) = std::fs::read_dir(source_dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            if !path.is_file() {
                continue;
            }
            let Some(name_os) = path.file_name() else {
                continue;
            };
            let name = name_os.to_string_lossy();
            if !name.ends_with(".db") {
                continue;
            }
            let dst_db = dest_dir.join(name.as_ref());
            if dst_db.exists() {
                continue;
            }
            if copy_file_atomic(&path, &dst_db).is_ok() {
                for sidecar in ["-wal", "-shm"] {
                    let src_side = source_dir.join(format!("{name}{sidecar}"));
                    let dst_side = dest_dir.join(format!("{name}{sidecar}"));
                    if src_side.is_file() && !dst_side.exists() {
                        let _ = copy_file_atomic(&src_side, &dst_side);
                    }
                }
            }
        }
    }

    for sub_dir in ["accounts", "stickers_cache"] {
        let src_sub = source_dir.join(sub_dir);
        let dst_sub = dest_dir.join(sub_dir);
        if src_sub.is_dir() {
            let _ = copy_dir_recursive_missing(&src_sub, &dst_sub, 0);
        }
    }

    let marker_body = format!("migrated_from={}\n", source_dir.display());
    write_private_atomic(&marker_path, marker_body.as_bytes())?;
    Ok(())
}

fn create_private_file(parent: &Path, prefix: &str) -> std::io::Result<(PathBuf, std::fs::File)> {
    for _ in 0..100 {
        let path = parent.join(format!(
            "{prefix}-{}-{}",
            std::process::id(),
            NEXT_FILE.fetch_add(1, Ordering::Relaxed)
        ));
        let mut options = std::fs::OpenOptions::new();
        options.write(true).create_new(true);
        #[cfg(unix)]
        {
            use std::os::unix::fs::OpenOptionsExt;
            options.mode(0o600);
        }
        match options.open(&path) {
            Ok(file) => return Ok((path, file)),
            Err(error) if error.kind() == std::io::ErrorKind::AlreadyExists => continue,
            Err(error) => return Err(error),
        }
    }
    Err(std::io::Error::new(
        std::io::ErrorKind::AlreadyExists,
        "Không tạo được tệp kiểm tra quyền ghi",
    ))
}

/// Replace a session only after the complete private temporary file is flushed.
///
/// # Errors
/// Returns an error if creating, writing, flushing, or replacing the file fails.
pub fn write_private_atomic(path: &Path, contents: &[u8]) -> Result<()> {
    use std::io::Write;
    let parent = path
        .parent()
        .filter(|p| !p.as_os_str().is_empty())
        .unwrap_or_else(|| Path::new("."));
    let (temporary, mut file) = create_private_file(parent, ".session-tmp")
        .with_context(|| format!("Cannot create temporary session in {}", parent.display()))?;
    let result = (|| -> Result<()> {
        file.write_all(contents).context("Cannot write session")?;
        file.sync_all().context("Cannot flush session")?;
        drop(file);
        std::fs::rename(&temporary, path)
            .with_context(|| format!("Cannot replace session {}", path.display()))?;
        Ok(())
    })();
    if result.is_err() {
        // Preserve the original failure if best-effort temporary cleanup also fails.
        let _ = std::fs::remove_file(&temporary);
    }
    result
}

#[cfg(test)]
mod tests {
    use super::*;

    fn fixture() -> PathBuf {
        let path = std::env::temp_dir().join(format!(
            "ctdozlite-storage-test-{}-{}",
            std::process::id(),
            NEXT_FILE.fetch_add(1, Ordering::Relaxed)
        ));
        std::fs::create_dir(&path).unwrap();
        path
    }

    #[test]
    fn resolves_bundle_cli_and_explicit_paths() {
        let cwd = Path::new("/work");
        let exe = Path::new("/Applications/Zalo.app/Contents/MacOS/ctdozlite");
        assert_eq!(
            resolve(&[], cwd, exe, Some(Path::new("/Users/fixture")), true).unwrap(),
            (
                PathBuf::from("/Users/fixture/Library/Application Support/ctdozlite"),
                true
            )
        );
        assert_eq!(
            resolve(&[], cwd, Path::new("/bin/ctdozlite"), None, true).unwrap(),
            (cwd.to_path_buf(), false)
        );
        assert_eq!(
            resolve(&[], cwd, exe, None, false).unwrap(),
            (cwd.to_path_buf(), false)
        );
        assert_eq!(
            resolve(
                &["--data-dir".into(), "fixture".into()],
                cwd,
                exe,
                None,
                true
            )
            .unwrap(),
            (cwd.join("fixture"), true)
        );
        assert!(resolve(&[], cwd, exe, None, true).is_err());
        assert!(resolve(&["--data-dir".into()], cwd, exe, None, true).is_err());
        assert!(resolve(&["--data-dir=".into()], cwd, exe, None, true).is_err());
        assert!(resolve(
            &["--data-dir=a".into(), "--data-dir=b".into()],
            cwd,
            exe,
            None,
            true
        )
        .is_err());
        assert_eq!(
            resolve(
                &["--profile".into(), "acc_2".into()],
                cwd,
                Path::new("/bin/ctdozlite"),
                None,
                true
            )
            .unwrap(),
            (cwd.join("profiles").join("acc_2"), true)
        );
    }

    #[test]
    fn preparation_retains_existing_data_and_secures_directory() {
        let root = fixture();
        let path = root.join("storage");
        prepare(&path, true).unwrap();
        std::fs::write(path.join("session.json"), b"existing fixture").unwrap();
        prepare(&path, true).unwrap();
        assert_eq!(
            std::fs::read(path.join("session.json")).unwrap(),
            b"existing fixture"
        );
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            assert_eq!(
                std::fs::metadata(&path).unwrap().permissions().mode() & 0o777,
                0o700
            );
        }
        assert_eq!(std::fs::read_dir(&path).unwrap().count(), 1);
        assert!(prepare(&path.join("session.json"), true).is_err());
        std::fs::remove_dir_all(root).unwrap();
    }
    #[test]
    fn explicit_path_overrides_bundle_and_relative_home_is_rejected() {
        let cwd = Path::new("/work");
        let exe = Path::new("/Applications/Fixture.app/Contents/MacOS/ctdozlite");
        assert_eq!(
            resolve(&["--data-dir=/fixture-data".into()], cwd, exe, None, true).unwrap(),
            (PathBuf::from("/fixture-data"), true)
        );
        assert!(resolve(&[], cwd, exe, Some(Path::new("relative-home")), true).is_err());
        assert_eq!(
            resolve(
                &[],
                cwd,
                Path::new("/Fixture.app/Contents/MacOS-extra/ctdozlite"),
                None,
                true
            )
            .unwrap(),
            (cwd.to_path_buf(), false)
        );
    }

    #[test]
    fn legacy_preparation_keeps_existing_permissions_and_probe_files() {
        let root = fixture();
        let sentinel = root.join(format!(
            ".storage-probe-{}-{}",
            std::process::id(),
            NEXT_FILE.load(Ordering::Relaxed)
        ));
        std::fs::write(&sentinel, b"retained fixture").unwrap();
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            std::fs::set_permissions(&root, std::fs::Permissions::from_mode(0o755)).unwrap();
        }
        prepare(&root, false).unwrap();
        assert_eq!(std::fs::read(&sentinel).unwrap(), b"retained fixture");
        assert_eq!(std::fs::read_dir(&root).unwrap().count(), 1);
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            assert_eq!(
                std::fs::metadata(&root).unwrap().permissions().mode() & 0o777,
                0o755
            );
        }
        std::fs::remove_dir_all(root).unwrap();
    }
    #[test]
    fn spaced_storage_option_rejects_flags_but_explicit_dash_paths_are_valid() {
        let cwd = Path::new("/work");
        let exe = Path::new("/bin/ctdozlite");
        for flag in ["-d", "-v", "-V", "--logout"] {
            assert!(
                resolve(&["--data-dir".into(), flag.into()], cwd, exe, None, true).is_err(),
                "accepted {flag}"
            );
        }
        for args in [
            vec!["--data-dir=-d".into()],
            vec!["--data-dir".into(), "./-d".into()],
        ] {
            let (path, private) = resolve(&args, cwd, exe, None, true).unwrap();
            assert_eq!(path, cwd.join("-d"));
            assert!(private);
        }
    }
    #[test]
    fn atomic_write_is_private_and_failed_replace_retains_destination() {
        let root = fixture();
        let path = root.join("session.json");
        write_private_atomic(&path, b"first fixture").unwrap();
        write_private_atomic(&path, b"second fixture").unwrap();
        assert_eq!(std::fs::read(&path).unwrap(), b"second fixture");
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            assert_eq!(
                std::fs::metadata(&path).unwrap().permissions().mode() & 0o777,
                0o600
            );
        }
        let occupied = root.join("occupied");
        std::fs::create_dir(&occupied).unwrap();
        std::fs::write(occupied.join("keep"), b"retained").unwrap();
        assert!(write_private_atomic(&occupied, b"replacement").is_err());
        assert_eq!(std::fs::read(occupied.join("keep")).unwrap(), b"retained");
        assert!(write_private_atomic(&root.join("missing/session.json"), b"fixture").is_err());
        assert_eq!(std::fs::read_dir(&root).unwrap().count(), 2);
        std::fs::remove_dir_all(root).unwrap();
    }

    #[test]
    fn windows_installed_or_protected_paths_resolve_to_local_app_data() {
        let win_env = WindowsPathEnv {
            local_app_data: Some(Path::new(r"C:\Users\Alice\AppData\Local")),
            user_profile: Some(Path::new(r"C:\Users\Alice")),
            program_files: Some(Path::new(r"C:\Program Files")),
            program_files_x86: Some(Path::new(r"C:\Program Files (x86)")),
            program_w6432: Some(Path::new(r"C:\Program Files")),
            system_root: Some(Path::new(r"C:\Windows")),
        };

        let (resolved, private) = resolve_with_platform(
            &[],
            Path::new(r"C:\Program Files\ctdozlite"),
            Path::new(r"C:\Program Files\ctdozlite\ctdozlite.exe"),
            None,
            false,
            true,
            &win_env,
        )
        .unwrap();
        assert_eq!(resolved, PathBuf::from(r"C:\Users\Alice\AppData\Local\ctdozlite"));
        assert!(private);

        let (prof_resolved, prof_private) = resolve_with_platform(
            &["--profile".into(), "work_1".into()],
            Path::new(r"C:\Windows\System32"),
            Path::new(r"C:\Program Files\ctdozlite\ctdozlite.exe"),
            None,
            false,
            true,
            &win_env,
        )
        .unwrap();
        assert_eq!(
            prof_resolved,
            PathBuf::from(r"C:\Users\Alice\AppData\Local\ctdozlite\profiles\work_1")
        );
        assert!(prof_private);

        // Portable folder outside protected roots stays in cwd.
        let (portable, portable_private) = resolve_with_platform(
            &[],
            Path::new(r"D:\Portable\ctdozlite"),
            Path::new(r"D:\Portable\ctdozlite\ctdozlite.exe"),
            None,
            false,
            true,
            &win_env,
        )
        .unwrap();
        assert_eq!(portable, PathBuf::from(r"D:\Portable\ctdozlite"));
        assert!(!portable_private);
    }

    #[test]
    fn windows_uninstaller_sentinel_redirects_per_user_install_to_local_app_data() {
        let root = fixture();
        let install_dir = root.join("Programs").join("ctdozlite");
        std::fs::create_dir_all(&install_dir).unwrap();
        std::fs::write(install_dir.join("unins000.exe"), b"stub").unwrap();
        let app_data = root.join("LocalAppData");
        let win_env = WindowsPathEnv {
            local_app_data: Some(&app_data),
            ..Default::default()
        };

        let (resolved, private) = resolve_with_platform(
            &[],
            &install_dir,
            &install_dir.join("ctdozlite.exe"),
            None,
            false,
            true,
            &win_env,
        )
        .unwrap();
        assert_eq!(resolved, app_data.join("ctdozlite"));
        assert!(private);
        std::fs::remove_dir_all(root).unwrap();
    }

    #[test]
    fn one_way_migration_copies_legacy_install_data_and_keeps_source_intact() {
        let root = fixture();
        let src = root.join("install");
        let dst = root.join("appdata");
        std::fs::create_dir_all(src.join("accounts")).unwrap();
        std::fs::create_dir_all(&dst).unwrap();

        std::fs::write(src.join("session.json"), b"{\"uin\":\"123\"}").unwrap();
        std::fs::write(src.join("zalo_history.db"), b"sqlite-fixture").unwrap();
        std::fs::write(src.join("zalo_history.db-wal"), b"wal-fixture").unwrap();
        std::fs::write(src.join("accounts").join("123_session.json"), b"acc").unwrap();
        // Install artifacts must not be copied as user data.
        std::fs::write(src.join("unins000.exe"), b"installer").unwrap();

        migrate_legacy_install_data_if_needed(&src, &dst).unwrap();

        assert_eq!(std::fs::read(dst.join("session.json")).unwrap(), b"{\"uin\":\"123\"}");
        assert_eq!(std::fs::read(dst.join("zalo_history.db")).unwrap(), b"sqlite-fixture");
        assert_eq!(std::fs::read(dst.join("zalo_history.db-wal")).unwrap(), b"wal-fixture");
        assert_eq!(
            std::fs::read(dst.join("accounts").join("123_session.json")).unwrap(),
            b"acc"
        );
        assert!(!dst.join("unins000.exe").exists());
        assert!(dst.join(".migrated_from_install").exists());
        // Source files remain untouched.
        assert!(src.join("session.json").exists());

        // Subsequent runs must not overwrite newer destination state.
        std::fs::write(dst.join("session.json"), b"updated-session").unwrap();
        migrate_legacy_install_data_if_needed(&src, &dst).unwrap();
        assert_eq!(std::fs::read(dst.join("session.json")).unwrap(), b"updated-session");

        std::fs::remove_dir_all(root).unwrap();
    }
}
