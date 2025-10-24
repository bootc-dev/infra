//! Container image garbage collection for GHCR.
//!
//! Deletes old container images from GitHub Container Registry based on age.
//! Uses the GitHub CLI (`gh`) for API access via xshell subprocess execution.
//!
//! # Features
//!
//! - Configurable retention period (default: 14 days)
//! - Dry run mode for safe testing
//! - Protects images tagged as `:latest`
//! - Detailed logging with statistics
//!
//! # Example
//!
//! ```bash
//! cargo xtask container-gc --retention-days 30 --dry-run true
//! ```

use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use clap::Parser;
use serde::Deserialize;
use std::time::Duration;
use xshell::{cmd, Shell};

/// Options for container garbage collection
#[derive(Parser, Debug)]
struct GcOptions {
    /// Delete container images older than this many days
    #[arg(long, default_value = "14", env = "RETENTION_DAYS")]
    retention_days: u32,

    /// Dry run mode - don't actually delete anything
    #[arg(long, default_value = "false", env = "DRY_RUN")]
    dry_run: bool,

    /// GitHub organization
    #[arg(long, default_value = "bootc-dev", env = "ORG")]
    org: String,

    /// Protect images tagged as 'latest' from deletion
    #[arg(long, default_value = "true")]
    protect_latest: bool,
}

#[derive(Debug, Deserialize)]
struct Package {
    name: String,
}

#[derive(Debug, Deserialize)]
struct PackageVersion {
    id: u64,
    name: Option<String>,
    created_at: String,
    #[allow(dead_code)]
    updated_at: String,
    metadata: VersionMetadata,
}

#[derive(Debug, Deserialize)]
struct VersionMetadata {
    container: ContainerMetadata,
}

#[derive(Debug, Deserialize)]
struct ContainerMetadata {
    tags: Vec<String>,
}

struct Stats {
    packages_processed: usize,
    versions_deleted: usize,
    versions_kept: usize,
    versions_skipped: usize,
}

impl Stats {
    fn new() -> Self {
        Self {
            packages_processed: 0,
            versions_deleted: 0,
            versions_kept: 0,
            versions_skipped: 0,
        }
    }
}

/// Run the container garbage collection task
pub fn run(sh: &Shell) -> Result<()> {
    let opts = GcOptions::parse_from(std::env::args().skip(1));

    // Validate inputs
    if opts.retention_days == 0 {
        anyhow::bail!("retention_days must be greater than 0");
    }
    if opts.retention_days > 3650 {
        anyhow::bail!("retention_days must be less than 3650 (10 years)");
    }

    println!("Container Image Garbage Collection");
    println!("===================================");
    println!("Organization: {}", opts.org);
    println!("Retention period: {} days", opts.retention_days);
    println!("Dry run: {}", opts.dry_run);
    println!();

    // Calculate cutoff date
    let now = Utc::now();
    let retention_duration = Duration::from_secs(opts.retention_days as u64 * 24 * 60 * 60);
    let cutoff_date = now - chrono::Duration::from_std(retention_duration)?;

    println!(
        "Cutoff date: {}",
        cutoff_date.format("%Y-%m-%d %H:%M:%S UTC")
    );
    println!();

    // Check if gh CLI is available and authenticated
    if cmd!(sh, "gh --version").quiet().run().is_err() {
        anyhow::bail!(
            "GitHub CLI (gh) is not installed or not in PATH. Install from https://cli.github.com/"
        );
    }

    if cmd!(sh, "gh auth status").quiet().run().is_err() {
        anyhow::bail!("GitHub CLI is not authenticated. Run 'gh auth login' first.");
    }

    let org = &opts.org;

    // Get all packages for the organization
    // Note: GitHub API has rate limits. For large operations, consider adding delays.
    let packages_json = cmd!(
        sh,
        "gh api
         -H Accept: application/vnd.github+json
         -H X-GitHub-Api-Version: 2022-11-28
         /orgs/{org}/packages?package_type=container&per_page=100
         --paginate"
    )
    .read()
    .with_context(|| {
        format!(
            "Failed to list packages for organization '{org}'. \
             Verify the organization exists and you have 'packages:read' permission."
        )
    })?;

    let packages: Vec<Package> =
        serde_json::from_str(&packages_json).context("Failed to parse packages JSON")?;

    if packages.is_empty() {
        println!("No container packages found");
        return Ok(());
    }

    let mut stats = Stats::new();

    // Process each package
    for package in &packages {
        println!("\nProcessing package: {}", package.name);
        stats.packages_processed += 1;

        let package_name = &package.name;

        // Get all versions for this package
        let versions_json = cmd!(
            sh,
            "gh api
             -H Accept: application/vnd.github+json
             -H X-GitHub-Api-Version: 2022-11-28
             /orgs/{org}/packages/container/{package_name}/versions?per_page=100
             --paginate"
        )
        .read()
        .with_context(|| format!("Failed to list versions for package {}", package.name))?;

        let versions: Vec<PackageVersion> = serde_json::from_str(&versions_json)
            .with_context(|| format!("Failed to parse versions JSON for {}", package.name))?;

        // Process each version
        for version in versions {
            let created_at: DateTime<Utc> = version
                .created_at
                .parse()
                .context("Failed to parse created_at timestamp")?;
            let age_days = (now - created_at).num_days();

            let version_name = version.name.as_deref().unwrap_or("untagged");
            let tags_str = if version.metadata.container.tags.is_empty() {
                "no tags".to_string()
            } else {
                version.metadata.container.tags.join(", ")
            };

            // Check if version is older than retention period
            if created_at < cutoff_date {
                // Skip if tagged as 'latest' and protection is enabled
                if opts.protect_latest
                    && version
                        .metadata
                        .container
                        .tags
                        .iter()
                        .any(|tag| tag == "latest")
                {
                    println!(
                        "  SKIP (latest): {}:{} (id: {}, age: {} days, tags: {})",
                        package.name, version_name, version.id, age_days, tags_str
                    );
                    stats.versions_skipped += 1;
                    continue;
                }

                if opts.dry_run {
                    println!(
                        "  DRY RUN - Would delete: {}:{} (id: {}, age: {} days, tags: {})",
                        package.name, version_name, version.id, age_days, tags_str
                    );
                    stats.versions_deleted += 1;
                } else {
                    println!(
                        "  DELETE: {}:{} (id: {}, age: {} days, tags: {})",
                        package.name, version_name, version.id, age_days, tags_str
                    );

                    let version_id = version.id.to_string();
                    let result = cmd!(
                        sh,
                        "gh api
                         --method DELETE
                         -H Accept: application/vnd.github+json
                         -H X-GitHub-Api-Version: 2022-11-28
                         /orgs/{org}/packages/container/{package_name}/versions/{version_id}"
                    )
                    .quiet()
                    .run();

                    match result {
                        Ok(_) => {
                            println!("    Success");
                            stats.versions_deleted += 1;
                        }
                        Err(e) => {
                            eprintln!("    Failed to delete version {}: {e}", version.id);
                            eprintln!(
                                "    This may indicate insufficient permissions or API rate limiting."
                            );
                        }
                    }
                }
            } else {
                println!(
                    "  Keep: {}:{} (age: {} days, tags: {})",
                    package.name, version_name, age_days, tags_str
                );
                stats.versions_kept += 1;
            }
        }
    }

    // Print summary
    println!();
    println!("==========================================");
    println!("Summary:");
    println!("  Packages processed: {}", stats.packages_processed);
    if opts.dry_run {
        println!("  Would delete: {} versions", stats.versions_deleted);
    } else {
        println!("  Deleted: {} versions", stats.versions_deleted);
    }
    println!("  Kept: {} versions", stats.versions_kept);
    println!("  Skipped (protected): {} versions", stats.versions_skipped);
    println!("==========================================");

    Ok(())
}
