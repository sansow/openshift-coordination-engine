# GitHub Repository Setup Guide

This guide helps you configure your GitHub repository for automated CI/CD and container image publishing to Quay.io.

## Required GitHub Secrets

Before pushing to GitHub, configure these secrets in your repository:

### Navigation
1. Go to your GitHub repository: `https://github.com/tosin2013/openshift-coordination-engine`
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**

### Required Secrets

#### 1. QUAY_USERNAME
- **Description**: Your Quay.io username or robot account name
- **Value**: `takinosh` or `takinosh+github_actions`
- **How to get**: 
  - Go to https://quay.io/user/takinosh?tab=settings
  - Or create a Robot Account for better security

#### 2. QUAY_TOKEN
- **Description**: Your Quay.io password or robot account token
- **How to get**:
  - **Option A - User Password**: Use your Quay.io account password (less secure)
  - **Option B - Robot Account** (RECOMMENDED):
    1. Go to https://quay.io/user/takinosh?tab=robots
    2. Click **Create Robot Account**
    3. Name it `github_actions`
    4. Grant **Write** permission to `takinosh/openshift-coordination-engine`
    5. Copy the generated token

#### 3. CODECOV_TOKEN (Optional)
- **Description**: Codecov token for code coverage reports
- **How to get**:
  1. Go to https://codecov.io/
  2. Sign in with GitHub
  3. Add repository `tosin2013/openshift-coordination-engine`
  4. Copy the upload token

## Setting Up Secrets

```bash
# Using GitHub CLI (recommended)
gh secret set QUAY_USERNAME -b "takinosh+github_actions"
gh secret set QUAY_TOKEN -b "YOUR_ROBOT_TOKEN_HERE"
gh secret set CODECOV_TOKEN -b "YOUR_CODECOV_TOKEN_HERE"

# Or set manually via GitHub UI
# Settings → Secrets and variables → Actions → New repository secret
```

## Verifying Setup

### 1. Check Secrets Are Set
```bash
gh secret list
# Should show: QUAY_USERNAME, QUAY_TOKEN, CODECOV_TOKEN
```

### 2. Test CI Workflow
```bash
# Push to main branch or create a PR
git push origin main

# Check workflow status
gh run list --workflow=ci.yaml

# View workflow logs
gh run view --log
```

### 3. Test Quay.io Push
```bash
# Tag and push (triggers release workflow)
git tag v0.1.0
git push origin v0.1.0

# Check workflow status
gh run list --workflow=release-quay.yaml

# Verify image on Quay.io
podman pull quay.io/takinosh/openshift-coordination-engine:latest
```

## GitHub Actions Workflows

### CI Workflow (`.github/workflows/ci.yaml`)
**Triggers**: Push to main/develop, Pull Requests
**Jobs**:
- **Lint**: Runs golangci-lint
- **Test**: Executes unit tests with coverage
- **Build**: Compiles binary and uploads artifact
- **Security Scan**: Runs Gosec and Trivy scanners

### Quay.io Release Workflow (`.github/workflows/release-quay.yaml`)
**Triggers**: Push to main, Tags (v*), Manual dispatch
**Jobs**:
- **Build and Push**: Builds multi-arch image (amd64, arm64) and pushes to Quay.io
- **Security Scan**: Scans container image with Trivy
- **GitHub Release**: Creates release notes for version tags

## Making Your First Push

```bash
# Initialize git (if not already done)
git init
git add .
git commit -m "Initial commit: OpenShift Coordination Engine"
git branch -M main

# Add remote (replace with your repository)
git remote add origin https://github.com/tosin2013/openshift-coordination-engine.git

# Push to GitHub
git push -u origin main

# Watch the CI workflow run
gh run watch

# After CI passes, create a release
git tag v0.1.0
git push origin v0.1.0

# Watch the release workflow
gh run watch
```

## Troubleshooting

### "Quay.io login failed"
```bash
# Verify secrets are set correctly
gh secret list

# Test Quay.io credentials locally
echo "YOUR_TOKEN" | podman login quay.io -u takinosh+github_actions --password-stdin

# Check workflow logs
gh run view --log
```

### "Permission denied to push image"
- Ensure robot account has **Write** permission
- Verify repository exists: https://quay.io/repository/takinosh/openshift-coordination-engine
- Make repository **Public** or grant robot account access

### "Tests failing in CI"
```bash
# Run tests locally first
make test

# Check for missing dependencies
go mod tidy

# Review test logs in GitHub Actions
gh run view --log --job=test
```

### "Lint errors in CI"
```bash
# Run linter locally
make lint

# Auto-fix formatting issues
make fmt

# Check specific errors
golangci-lint run
```

## Monitoring Workflows

### GitHub CLI Commands
```bash
# List recent workflow runs
gh run list

# Watch current run
gh run watch

# View specific run
gh run view RUN_ID

# View logs for failed run
gh run view RUN_ID --log-failed

# Re-run failed jobs
gh run rerun RUN_ID --failed
```

### GitHub UI
- View all workflows: `https://github.com/tosin2013/openshift-coordination-engine/actions`
- View CI runs: `https://github.com/tosin2013/openshift-coordination-engine/actions/workflows/ci.yaml`
- View releases: `https://github.com/tosin2013/openshift-coordination-engine/actions/workflows/release-quay.yaml`

## Security Best Practices

1. **Use Robot Accounts**: Create dedicated robot accounts for GitHub Actions instead of using personal credentials
2. **Limit Permissions**: Grant only necessary permissions (Write to specific repository)
3. **Rotate Tokens**: Periodically rotate Quay.io tokens
4. **Review Security Scans**: Check Trivy scan results in GitHub Security tab
5. **Enable Branch Protection**: Require CI to pass before merging PRs

## Next Steps

After setup:
1. ✅ Set up GitHub secrets
2. ✅ Push code to GitHub
3. ✅ Verify CI passes
4. ✅ Create first release (v0.1.0)
5. ✅ Verify image pushed to Quay.io
6. ✅ Test deployment with Helm

---

**Need Help?**
- GitHub Actions Documentation: https://docs.github.com/en/actions
- Quay.io Robot Accounts: https://docs.quay.io/glossary/robot-accounts.html
- GitHub CLI: https://cli.github.com/
