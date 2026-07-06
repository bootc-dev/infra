use anyhow::{Context, Result};
use clap::Parser;
use std::path::{Path, PathBuf};
use xshell::{cmd, Shell};

#[derive(Parser)]
#[command(about = "Sync common files from infra to target repositories")]
struct Args {
    /// Path to the infra repository
    infra_path: PathBuf,
    /// Path to the target repository
    target_path: PathBuf,
    /// Git commit SHA to mark as synced
    current_commit: String,
    /// Patterns to exclude from syncing (passed to rsync --exclude)
    #[arg(long)]
    exclude: Vec<String>,
}

const COMMIT_MARKER: &str = ".bootc-dev-infra-commit.txt";

/// Git operations for querying repository history
struct GitOps;

impl GitOps {
    /// Get list of files deleted between two commits with given prefix
    fn get_deleted_files(
        sh: &Shell,
        repo_path: &Path,
        old_commit: &str,
        new_commit: &str,
        prefix: &str,
    ) -> Result<Vec<String>> {
        let _dir = sh.push_dir(repo_path);
        let output = cmd!(sh, "git diff --name-only --diff-filter=D {old_commit} {new_commit} -- {prefix}")
            .read()
            .context("Failed to run git diff")?;

        let files = output
            .lines()
            .map(|s| s.to_string())
            .filter(|s| !s.is_empty())
            .collect();

        Ok(files)
    }

    /// Check if there are any changes between commits for given prefix
    fn has_changes(
        sh: &Shell,
        repo_path: &Path,
        old_commit: &str,
        new_commit: &str,
        prefix: &str,
    ) -> Result<bool> {
        let _dir = sh.push_dir(repo_path);
        // git diff --quiet returns exit code 1 if there are differences
        let result = cmd!(sh, "git diff --quiet {old_commit} {new_commit} -- {prefix}").run();

        match result {
            Ok(_) => Ok(false), // No changes
            Err(_) => Ok(true), // Has changes (exit code 1)
        }
    }
}

/// File operations for syncing
struct FileOps;

impl FileOps {
    /// Read the last synced commit from target repository
    fn read_commit_marker(target_path: &Path) -> Result<Option<String>> {
        let marker_path = target_path.join(COMMIT_MARKER);
        if !marker_path.exists() {
            return Ok(None);
        }

        let content = std::fs::read_to_string(&marker_path)
            .context("Failed to read commit marker")?;
        Ok(Some(content.trim().to_string()))
    }

    /// Write the current commit to target repository marker file
    fn write_commit_marker(target_path: &Path, commit: &str) -> Result<()> {
        let marker_path = target_path.join(COMMIT_MARKER);
        std::fs::write(&marker_path, format!("{}\n", commit))
            .context("Failed to write commit marker")?;
        Ok(())
    }

    /// Remove a file if it exists
    fn remove_file(file_path: &Path) -> Result<()> {
        if file_path.exists() && file_path.is_file() {
            std::fs::remove_file(file_path)
                .with_context(|| format!("Failed to remove file: {}", file_path.display()))?;
            println!("  Removed: {}", file_path.display());
        }
        Ok(())
    }

    /// Sync directory using rsync
    fn sync_directory(sh: &Shell, source: &Path, target: &Path, excludes: &[String]) -> Result<()> {
        let source_str = format!("{}/", source.display());
        let target_str = target.display().to_string();

        let mut rsync_args = vec!["-av".to_string()];
        for pattern in excludes {
            rsync_args.push("--exclude".to_string());
            rsync_args.push(pattern.clone());
        }
        rsync_args.push(source_str);
        rsync_args.push(target_str);

        cmd!(sh, "rsync {rsync_args...}")
            .run()
            .context("Failed to sync directory with rsync")?;

        Ok(())
    }

}

/// Main syncer that orchestrates the sync process
struct CommonFileSyncer;

impl CommonFileSyncer {
    /// Sync common files from infra to target repository
    fn sync(
        infra_path: &Path,
        target_path: &Path,
        current_commit: &str,
        excludes: &[String],
    ) -> Result<bool> {
        let common_path = infra_path.join("common");
        if !common_path.exists() {
            anyhow::bail!("Common directory not found: {}", common_path.display());
        }

        let previous_commit = FileOps::read_commit_marker(target_path)?;

        match previous_commit {
            Some(prev) => Self::sync_incremental(
                infra_path,
                target_path,
                &common_path,
                &prev,
                current_commit,
                excludes,
            ),
            None => Self::sync_initial(target_path, &common_path, current_commit, excludes),
        }
    }

    /// Handle incremental sync when previous sync exists
    fn sync_incremental(
        infra_path: &Path,
        target_path: &Path,
        common_path: &Path,
        previous_commit: &str,
        current_commit: &str,
        excludes: &[String],
    ) -> Result<bool> {
        println!("Previous sync: {}", previous_commit);
        println!("Current commit: {}", current_commit);

        let sh = Shell::new()?;
        let has_changes =
            GitOps::has_changes(&sh, infra_path, previous_commit, current_commit, "common/")?;

        if !has_changes {
            println!("No changes in common/ directory, skipping");
            return Ok(false);
        }

        println!("Syncing changes from common/ directory");

        // Remove deleted files
        let deleted_files =
            GitOps::get_deleted_files(&sh, infra_path, previous_commit, current_commit, "common/")?;

        for file_path in deleted_files {
            // Strip 'common/' prefix to get target path
            if let Some(rel_path) = file_path.strip_prefix("common/") {
                let target_file = target_path.join(rel_path);
                FileOps::remove_file(&target_file)?;
            }
        }

        // Sync all current files
        FileOps::sync_directory(&sh, common_path, target_path, excludes)?;

        // Update commit marker
        FileOps::write_commit_marker(target_path, current_commit)?;

        Ok(true)
    }

    /// Handle initial sync when no previous sync exists
    fn sync_initial(
        target_path: &Path,
        common_path: &Path,
        current_commit: &str,
        excludes: &[String],
    ) -> Result<bool> {
        println!("First sync - copying all files");

        let sh = Shell::new()?;
        FileOps::sync_directory(&sh, common_path, target_path, excludes)?;
        FileOps::write_commit_marker(target_path, current_commit)?;

        Ok(true)
    }
}

fn main() -> Result<()> {
    let args = Args::parse();

    CommonFileSyncer::sync(
        &args.infra_path,
        &args.target_path,
        &args.current_commit,
        &args.exclude,
    )?;

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::TempDir;

    #[test]
    fn test_read_commit_marker_exists() {
        let dir = TempDir::new().unwrap();
        let marker = dir.path().join(COMMIT_MARKER);
        fs::write(&marker, "abc123\n").unwrap();

        let result = FileOps::read_commit_marker(dir.path()).unwrap();
        assert_eq!(result, Some("abc123".to_string()));
    }

    #[test]
    fn test_read_commit_marker_not_exists() {
        let dir = TempDir::new().unwrap();
        let result = FileOps::read_commit_marker(dir.path()).unwrap();
        assert_eq!(result, None);
    }

    #[test]
    fn test_write_commit_marker() {
        let dir = TempDir::new().unwrap();
        FileOps::write_commit_marker(dir.path(), "def456").unwrap();

        let marker = dir.path().join(COMMIT_MARKER);
        let content = fs::read_to_string(&marker).unwrap();
        assert_eq!(content, "def456\n");
    }

    #[test]
    fn test_remove_file_exists() {
        let dir = TempDir::new().unwrap();
        let file = dir.path().join("test.txt");
        fs::write(&file, "content").unwrap();

        FileOps::remove_file(&file).unwrap();
        assert!(!file.exists());
    }

    #[test]
    fn test_remove_file_not_exists() {
        let dir = TempDir::new().unwrap();
        let file = dir.path().join("nonexistent.txt");

        // Should not error
        FileOps::remove_file(&file).unwrap();
    }

    #[test]
    fn test_sync_common_not_found() {
        let infra_dir = TempDir::new().unwrap();
        let target_dir = TempDir::new().unwrap();

        let result = CommonFileSyncer::sync(
            infra_dir.path(),
            target_dir.path(),
            "abc123",
            &[],
        );

        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("Common directory not found"));
    }

    // Helper to initialize a git repo with common/ directory
    fn setup_infra_repo(dir: &Path) -> String {
        let sh = Shell::new().unwrap();
        let _d = sh.push_dir(dir);

        // Initialize repo
        cmd!(sh, "git init").run().unwrap();
        cmd!(sh, "git config user.email test@example.com").run().unwrap();
        cmd!(sh, "git config user.name 'Test User'").run().unwrap();

        // Create common directory with initial files
        let common_dir = dir.join("common");
        fs::create_dir(&common_dir).unwrap();
        fs::write(common_dir.join("file1.txt"), "content1").unwrap();
        fs::write(common_dir.join("file2.txt"), "content2").unwrap();

        // Commit
        cmd!(sh, "git add .").run().unwrap();
        cmd!(sh, "git commit -m 'Initial commit'").run().unwrap();

        // Get commit hash
        cmd!(sh, "git rev-parse HEAD").read().unwrap().trim().to_string()
    }

    #[test]
    fn test_initial_sync_with_git() {
        let infra_dir = TempDir::new().unwrap();
        let target_dir = TempDir::new().unwrap();

        let commit = setup_infra_repo(infra_dir.path());

        // Perform initial sync
        let result = CommonFileSyncer::sync(
            infra_dir.path(),
            target_dir.path(),
            &commit,
            &[],
        );

        assert!(result.is_ok());
        assert!(result.unwrap());

        // Verify files were synced
        assert!(target_dir.path().join("file1.txt").exists());
        assert!(target_dir.path().join("file2.txt").exists());
        assert_eq!(
            fs::read_to_string(target_dir.path().join("file1.txt")).unwrap(),
            "content1"
        );

        // Verify marker was created
        let marker = fs::read_to_string(target_dir.path().join(COMMIT_MARKER)).unwrap();
        assert_eq!(marker.trim(), commit);
    }

    #[test]
    fn test_incremental_sync_with_new_file() {
        let infra_dir = TempDir::new().unwrap();
        let target_dir = TempDir::new().unwrap();

        let initial_commit = setup_infra_repo(infra_dir.path());

        // Initial sync
        CommonFileSyncer::sync(infra_dir.path(), target_dir.path(), &initial_commit, &[]).unwrap();

        // Add a new file to common/
        let sh = Shell::new().unwrap();
        let _d = sh.push_dir(infra_dir.path());

        let common_dir = infra_dir.path().join("common");
        fs::write(common_dir.join("file3.txt"), "content3").unwrap();
        cmd!(sh, "git add .").run().unwrap();
        cmd!(sh, "git commit -m 'Add file3'").run().unwrap();

        let new_commit = cmd!(sh, "git rev-parse HEAD").read().unwrap().trim().to_string();

        // Perform incremental sync
        let result = CommonFileSyncer::sync(
            infra_dir.path(),
            target_dir.path(),
            &new_commit,
            &[],
        );

        assert!(result.is_ok());
        assert!(result.unwrap());

        // Verify new file exists
        assert!(target_dir.path().join("file3.txt").exists());
        assert_eq!(
            fs::read_to_string(target_dir.path().join("file3.txt")).unwrap(),
            "content3"
        );
    }

    #[test]
    fn test_incremental_sync_with_deleted_file() {
        let infra_dir = TempDir::new().unwrap();
        let target_dir = TempDir::new().unwrap();

        let initial_commit = setup_infra_repo(infra_dir.path());

        // Initial sync
        CommonFileSyncer::sync(infra_dir.path(), target_dir.path(), &initial_commit, &[]).unwrap();

        // Verify file2.txt exists
        assert!(target_dir.path().join("file2.txt").exists());

        // Delete file2.txt from common/
        let sh = Shell::new().unwrap();
        let _d = sh.push_dir(infra_dir.path());

        fs::remove_file(infra_dir.path().join("common/file2.txt")).unwrap();
        cmd!(sh, "git add .").run().unwrap();
        cmd!(sh, "git commit -m 'Delete file2'").run().unwrap();

        let new_commit = cmd!(sh, "git rev-parse HEAD").read().unwrap().trim().to_string();

        // Perform incremental sync
        let result = CommonFileSyncer::sync(
            infra_dir.path(),
            target_dir.path(),
            &new_commit,
            &[],
        );

        assert!(result.is_ok());
        assert!(result.unwrap());

        // Verify file2.txt was deleted
        assert!(!target_dir.path().join("file2.txt").exists());
        // But file1.txt should still exist
        assert!(target_dir.path().join("file1.txt").exists());
    }

    #[test]
    fn test_sync_no_changes() {
        let infra_dir = TempDir::new().unwrap();
        let target_dir = TempDir::new().unwrap();

        let commit = setup_infra_repo(infra_dir.path());

        // Initial sync
        CommonFileSyncer::sync(infra_dir.path(), target_dir.path(), &commit, &[]).unwrap();

        // Sync again with same commit (no changes)
        let result = CommonFileSyncer::sync(
            infra_dir.path(),
            target_dir.path(),
            &commit,
            &[],
        );

        assert!(result.is_ok());
        assert!(!result.unwrap()); // Should return false for no changes
    }

    #[test]
    fn test_sync_preserves_repo_specific_files() {
        let infra_dir = TempDir::new().unwrap();
        let target_dir = TempDir::new().unwrap();

        let initial_commit = setup_infra_repo(infra_dir.path());

        // Create a repo-specific file in target before sync
        fs::write(target_dir.path().join("repo-specific.txt"), "local content").unwrap();

        // Initial sync
        CommonFileSyncer::sync(infra_dir.path(), target_dir.path(), &initial_commit, &[]).unwrap();

        // Verify repo-specific file still exists
        assert!(target_dir.path().join("repo-specific.txt").exists());
        assert_eq!(
            fs::read_to_string(target_dir.path().join("repo-specific.txt")).unwrap(),
            "local content"
        );

        // Verify synced files exist
        assert!(target_dir.path().join("file1.txt").exists());
        assert!(target_dir.path().join("file2.txt").exists());
    }

}
