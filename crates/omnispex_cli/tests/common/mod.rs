#![allow(dead_code)]

use std::path::{Path, PathBuf};
use std::process::{Command, Output};

pub fn cli_bin() -> &'static str {
    env!("CARGO_BIN_EXE_omnispex_cli")
}

pub fn run_cli<I, S>(args: I) -> Output
where
    I: IntoIterator<Item = S>,
    S: AsRef<std::ffi::OsStr>,
{
    Command::new(cli_bin())
        .args(args)
        .output()
        .expect("Failed to execute omnispex_cli binary")
}

pub fn project_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .expect("parent of crates")
        .parent()
        .expect("project root")
        .to_path_buf()
}

pub fn temp_dir(name: &str) -> PathBuf {
    let dir = std::env::temp_dir().join(format!("omnispex_test_{}_{}", name, std::process::id()));
    let _ = std::fs::create_dir_all(&dir);
    dir
}
