module.exports = {
  // Find all repositories the GitHub App token has permissions to
  autodiscover: true,

  // Open onboarding PRs on repos that don't yet have a Renovate config,
  // proposing the standard config that extends the shared org-wide preset.
  //
  // The onboarding branch is set explicitly because branchPrefix does not
  // apply to onboarding PRs.
  onboarding: true,
  onboardingBranch: 'bootc-renovate/configure',
  onboardingConfig: {
    "$schema": "https://docs.renovatebot.com/renovate-schema.json",
    "extends": ["local>bootc-dev/infra:renovate-shared-config.json"],
  },

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
