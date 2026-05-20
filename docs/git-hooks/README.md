This directory contains the canonical `pre-push` hook template and utilities to deploy it across local clones and CI images.

Usage
- Configure the `REPO_MGMT_PAT` secret in the `ai-research-workbench` repository if you want the deploy workflow to automatically send repository dispatch events to target repositories.
- After merging the `chore/hook-template` branch, the workflow `Deploy Hook Template` will package `pre-push.template` and `install-hooks.sh` as an artifact.

How other repos can respond
1. Add a workflow that listens for the `repository_dispatch` event with `event_type: update-hook-template`.
2. In that workflow, download the artifact or fetch the template from the canonical repo (via raw URL or GitHub API), then run `scripts/install-hooks.sh` in the runner to update the repo's `.git/hooks`.

Example listener snippet (add to other repo `.github/workflows`):

```
on:
  repository_dispatch:
    types: [update-hook-template]

jobs:
  install-hook:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Fetch canonical hook template
        run: |
          curl -fsSL -o docs/git-hooks/pre-push.template https://raw.githubusercontent.com/xdkp/ai-research-workbench/develop/docs/git-hooks/pre-push.template
          curl -fsSL -o scripts/install-hooks.sh https://raw.githubusercontent.com/xdkp/ai-research-workbench/develop/scripts/install-hooks.sh
          chmod +x scripts/install-hooks.sh
      - name: Apply hooks
        run: scripts/install-hooks.sh
```

Notes
- The automatic dispatch requires a Personal Access Token with `repo` scope stored as `REPO_MGMT_PAT` in the canonical repo's secrets. If you prefer not to provide a token, the workflow will still publish the artifact and you can manually download it from the Actions run.
- The installer runs in the local runner environment and will update the checked-out repository's `.git/hooks`. CI runners typically do not persist `.git/hooks` between runs; use this mechanism to update images or persistent runners by adding the installer to your image build pipeline.
