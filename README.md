# .github

Organization-level GitHub configuration and reusable workflows for [caelicode](https://github.com/caelicode).

## Reusable Workflows

| Workflow | Purpose |
|----------|---------|
| `reusable-python-ci.yml` | Lint + test + coverage with matrix Python versions |
| `reusable-deploy-ssh.yml` | SSH deployment with retry, health checks, rollback |
| `reusable-docker-build.yml` | Docker build + push with Buildx caching and multi-platform |
| `reusable-lint-python.yml` | flake8 + black + isort (legacy) |
| `reusable-python-setup.yml` | Checkout + Python + pip install |
| `reusable-lint-node.yml` | ESLint + npm test |
| `reusable-notify-on-failure.yml` | Email notification via send-email action |
| `reusable-secret-rotation-reminder.yml` | Monthly issue for secret rotation |

## Usage

### Python CI (lint + test + coverage)

```yaml
jobs:
  ci:
    uses: caelicode/.github/.github/workflows/reusable-python-ci.yml@main
    with:
      python-versions: '["3.10", "3.12", "3.13"]'
      linter: ruff
      source-dir: src
      install-project: true
      coverage-threshold: 80
```

### SSH Deployment

```yaml
jobs:
  deploy:
    uses: caelicode/.github/.github/workflows/reusable-deploy-ssh.yml@main
    with:
      deploy-script: |
        cd /home/app/myproject
        git pull origin main
        npm install --production
        pm2 restart myapp
      health-check-url: https://myapp.example.com/health
    secrets:
      ssh-host: ${{ secrets.SERVER_HOST }}
      ssh-username: ${{ secrets.SERVER_USER }}
      ssh-key: ${{ secrets.SSH_PRIVATE_KEY }}
```

### Docker Build

```yaml
jobs:
  build:
    uses: caelicode/.github/.github/workflows/reusable-docker-build.yml@main
    with:
      image-name: myapp
      platforms: linux/amd64,linux/arm64
      tag-strategy: sha
```

## Secret Rotation

The `reusable-secret-rotation-reminder.yml` workflow runs on the 1st and 15th of each month, creating a GitHub issue that lists all org secrets needing rotation.
