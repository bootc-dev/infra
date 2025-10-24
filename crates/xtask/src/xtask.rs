//! See https://github.com/matklad/cargo-xtask
//! This project uses xtask pattern for automation tasks.

use std::process::Command;

use anyhow::{Context, Result};
use xshell::Shell;

mod container_gc;

type TaskFn = fn(&Shell) -> Result<()>;

const TASKS: &[(&str, TaskFn)] = &[("container-gc", container_gc::run)];

fn main() {
    if let Err(e) = try_main() {
        eprintln!("error: {e:#}");
        std::process::exit(1);
    }
}

fn try_main() -> Result<()> {
    // Ensure our working directory is the toplevel (if we're in a git repo)
    {
        if let Ok(toplevel_path) = Command::new("git")
            .args(["rev-parse", "--show-toplevel"])
            .output()
        {
            if toplevel_path.status.success() {
                let path = String::from_utf8(toplevel_path.stdout)?;
                std::env::set_current_dir(path.trim()).context("Changing to toplevel")?;
            }
        }
    }

    let task = std::env::args().nth(1);

    let sh = xshell::Shell::new()?;
    if let Some(cmd) = task.as_deref() {
        let f = TASKS
            .iter()
            .find_map(|(k, f)| (*k == cmd).then_some(*f))
            .unwrap_or(print_help);
        f(&sh)
    } else {
        print_help(&sh)?;
        Ok(())
    }
}

fn print_help(_sh: &Shell) -> Result<()> {
    println!("Available tasks:");
    for (name, _) in TASKS {
        println!("  {name}");
    }
    Ok(())
}
