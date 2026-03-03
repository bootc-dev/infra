module.exports = {
  // Find all repositories the GitHub App token has permissions to
  autodiscover: true,

  // Don't create the onboarding PRs
  //
  // All repositories in the organisation will inherit the shared configuration
  // (./renovate-shared-config.json) by default unless they opt-out.
  onboarding: false,

  // Centralise all Renovate configuration into this repository
  //
  // This allows for easier management of Renovate settings across multiple
  // repositories and organisations. Each individual repository can still
  // contain their own configuration.
  //
  // Note: this uses an explicit repo name rather than {{parentOrg}}/infra
  // so that repos in other orgs (e.g. composefs) also inherit from here.
  inheritConfig: true,
  inheritConfigRepoName: 'bootc-dev/infra',
  inheritConfigFileName: "renovate-shared-config.json",
  inheritConfigStrict: true,

  // Prefix all branches created by Renovate with "bootc-renovate/"
  branchPrefix: 'bootc-renovate/',

  // Configure Renovate to use GitHub-specific API calls
  platform: 'github',

  // Enable dependency updates on forked repositories in the organisation
  forkProcessing: 'enabled',
};
