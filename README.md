# .github

Organization-level GitHub configuration and reusable workflows for [caelicode](https://github.com/caelicode).

## Reusable Workflows

| Workflow | Purpose | Used By |
|----------|---------|---------|
| `reusable-python-setup.yml` | Checkout + Python + pip install | github-user-management, status-page, secret-scanner |
| `reusable-lint-python.yml` | flake8 + black + isort | Python repos (PR quality gate) |
| `reusable-lint-node.yml` | ESLint + npm test | Node.js repos (PR quality gate) |
| `reusable-notify-on-failure.yml` | Email notification via send-email action | All repos (on workflow failure) |
| `reusable-secret-rotation-reminder.yml` | Monthly issue for secret rotation | This repo (scheduled) |

## Usage

Call any reusable workflow from another repo:

```yaml
jobs:
  lint:
    uses: caelicode/.github/.github/workflows/reusable-lint-python.yml@main
    with:
      python-version: '3.12'
      source-dir: 'scripts/'
```

## Secret Rotation

The `reusable-secret-rotation-reminder.yml` workflow runs on the 1st and 15th of each month, creating a GitHub issue that lists all org secrets needing rotation. See the [runner-infrastructure RUNBOOK](https://github.com/caelicode/runner-infrastructure/blob/main/RUNBOOK.md) for detailed rotation procedures.
