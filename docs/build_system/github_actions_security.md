# GitHub Actions Security Guide

## Overview

This document provides comprehensive security guidance for GitHub Actions in the 4-Servo Ornithopter project, addressing supply-chain security, best practices, and maintenance procedures.

## Table of Contents

1. [Supply-Chain Security](#supply-chain-security)
2. [Action Pinning Strategy](#action-pinning-strategy)
3. [Current Action Registry](#current-action-registry)
4. [Maintenance Procedures](#maintenance-procedures)
5. [Security Checklist](#security-checklist)
6. [Incident Response](#incident-response)

## Supply-Chain Security

### The Problem

GitHub Actions can be referenced using mutable tags (e.g., `@v3`, `@v4.11.0`). These tags can be:
- **Moved**: A repository maintainer can move a tag to point to different code
- **Compromised**: If an action repository is compromised, attackers can modify the code behind existing tags
- **Malicious**: Updated versions could introduce malicious code

Since actions run with access to:
- Repository code and secrets
- `GITHUB_TOKEN` with write permissions
- CI/CD environment

A compromised action could:
- Exfiltrate secrets (API keys, tokens, credentials)
- Modify source code or build artifacts
- Inject backdoors into releases
- Steal sensitive data from the repository

### The Solution

**Pin all actions to specific commit SHAs** instead of mutable tags:

```yaml
# ❌ Vulnerable: Mutable tag
- uses: actions/checkout@v3

# ✅ Secure: Pinned to immutable commit SHA
- uses: actions/checkout@f43a0e5ff2bd294095638e18286ca9a3d1956744 # v3.6.0
```

Benefits:
- **Immutability**: Commit SHAs cannot be changed
- **Auditability**: Exact code version is known and verifiable
- **Control**: Updates only happen when explicitly chosen
- **Traceability**: Version comments maintain human readability

## Action Pinning Strategy

### Implementation Guidelines

1. **Always use commit SHAs**: Never use branch names or mutable tags in production workflows

2. **Include version comments**: Add comments showing the semantic version for human readability
   ```yaml
   uses: actions/checkout@f43a0e5ff2bd294095638e18286ca9a3d1956744 # v3.6.0
   ```

3. **Document SHA sources**: Verify SHAs from official releases
   - Go to repository: `https://github.com/[owner]/[repo]`
   - Navigate to Releases
   - Find the tag (e.g., `v3.6.0`)
   - Copy the commit SHA from the tag

4. **Use automation**: Leverage `scripts/update_actions.sh` for maintenance

### Finding Commit SHAs

**Method 1: GitHub Web Interface**
```
1. Navigate to https://github.com/actions/checkout/releases
2. Click on the desired release tag (e.g., v3.6.0)
3. Copy the commit SHA from the URL or commit badge
```

**Method 2: Git Command Line**
```bash
# Clone the action repository
git clone https://github.com/actions/checkout.git
cd checkout

# Get SHA for a specific tag
git rev-parse v3.6.0
# Output: f43a0e5ff2bd294095638e18286ca9a3d1956744
```

**Method 3: GitHub API**
```bash
# Get tag information
curl -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/actions/checkout/git/refs/tags/v3.6.0
```

## Current Action Registry

All actions used in this project with their pinned versions:

### Official GitHub Actions

| Action | Version | Commit SHA | Purpose |
|--------|---------|------------|---------|
| `actions/checkout` | v3.6.0 | `f43a0e5ff2bd294095638e18286ca9a3d1956744` | Repository checkout |
| `actions/cache` | v3.3.2 | `704facf57e6136b1bc63b828d79edcd491f0ee84` | Dependency caching |
| `actions/setup-python` | v4.7.1 | `65d7f2d534ac1bc67fcd62888c5f4f3d2cb2b236` | Python environment |
| `actions/upload-artifact` | v3.1.3 | `a8a3f3ad30e3422c9c7b888a15615d19a852ae32` | Artifact upload |
| `actions/download-artifact` | v3.0.2 | `9bc31d5ccc31df68ecc42ccf4149144866c47d8a` | Artifact download |

### Third-Party Actions

| Action | Version | Commit SHA | Purpose | Security Review |
|--------|---------|------------|---------|----------------|
| `jidicula/clang-format-action` | v4.11.0 | `c74383674bf5f7c69f60ce562019c1c94bc1421a` | Code formatting | ✅ Reviewed 2026-01-03 |
| `softprops/action-gh-release` | v1.0.0 | `de2c0eb89ae2a093876385947365aca7b0e5f844` | GitHub releases | ✅ Reviewed 2026-01-03 |

**Third-Party Action Security Review Criteria**:
- ✅ Source code reviewed for suspicious activity
- ✅ Repository has >100 stars and active maintenance
- ✅ No known security issues or CVEs
- ✅ Action does not request unnecessary permissions
- ✅ Minimal secret exposure

## Maintenance Procedures

### Quarterly Security Review

**Schedule**: Review actions every 3 months or when security advisories are published.

**Procedure**:

1. **Check for updates**:
   ```bash
   ./scripts/update_actions.sh --check
   ```

2. **Review release notes**: For each action, check:
   - Security fixes
   - Breaking changes
   - New features
   - Deprecation notices

3. **Test updates**: In a feature branch:
   ```bash
   # Update to new SHAs
   ./scripts/update_actions.sh --update
   
   # Edit workflow files with new references
   # Run CI to verify compatibility
   ```

4. **Merge after validation**: Only update production after successful testing

### Emergency Security Updates

If a security vulnerability is disclosed:

1. **Assess impact**: Does it affect actions we use?
2. **Priority update**: Update affected actions immediately
3. **Test quickly**: Run critical workflows to verify functionality
4. **Deploy**: Merge to production after basic validation
5. **Monitor**: Watch for any issues in CI/CD

### Adding New Actions

Before adding a new action:

1. **Evaluate necessity**: Can the task be done without external actions?

2. **Security audit**:
   ```
   - Is it from a trusted source? (GitHub official > well-known org > individual)
   - Does it have good community trust? (stars, forks, usage)
   - Is it actively maintained? (recent commits, responsive to issues)
   - What permissions does it need?
   - Does it access secrets?
   ```

3. **Code review**: For third-party actions, review the source:
   ```bash
   git clone https://github.com/[owner]/[repo]
   git checkout [version-tag]
   # Review action.yml and implementation files
   ```

4. **Test in isolation**: Create a test workflow before production use

5. **Document**: Add to action registry with security review notes

## Security Checklist

Use this checklist for all workflow changes:

### Before Committing
- [ ] All actions pinned to commit SHAs (no mutable tags)
- [ ] Version comments included for all actions
- [ ] No hardcoded secrets in workflow files
- [ ] Minimal permissions for `GITHUB_TOKEN`
- [ ] Third-party actions reviewed and documented
- [ ] Test workflows run successfully

### Monthly
- [ ] Review GitHub security advisories
- [ ] Check for deprecated actions
- [ ] Audit secret usage
- [ ] Review workflow logs for anomalies

### Quarterly
- [ ] Run `./scripts/update_actions.sh --check`
- [ ] Update actions to latest stable versions
- [ ] Review and update security documentation
- [ ] Conduct security training for contributors

### Annually
- [ ] Comprehensive security audit
- [ ] Rotate all secrets and tokens
- [ ] Review and update security policies
- [ ] Evaluate new security tools/practices

## Incident Response

### Suspected Compromise

If you suspect an action or workflow has been compromised:

1. **Disable workflows immediately**:
   ```bash
   # Disable all workflows
   gh workflow disable --all
   ```

2. **Investigate**:
   - Review workflow run logs
   - Check for unauthorized code changes
   - Audit secret access logs
   - Review artifact contents

3. **Contain**:
   - Rotate all secrets and tokens
   - Revoke compromised credentials
   - Block affected action versions

4. **Remediate**:
   - Update to known-good action versions
   - Fix any introduced vulnerabilities
   - Review and strengthen security measures

5. **Recover**:
   - Re-enable workflows after verification
   - Monitor closely for 48-72 hours
   - Document incident and lessons learned

### Reporting Security Issues

To report security concerns:

1. **Do not** create public issues for security vulnerabilities
2. Email security contact (see SECURITY.md)
3. Include: action name, version, SHA, description of issue
4. Allow time for response before public disclosure

## Best Practices Summary

### DO ✅
- Pin all actions to commit SHAs
- Include version comments
- Use official GitHub actions when possible
- Review third-party actions before use
- Keep actions updated quarterly
- Minimize secret exposure
- Use least-privilege permissions
- Document security reviews
- Test updates before production deployment

### DON'T ❌
- Use mutable tags (`@v3`, `@latest`, `@main`)
- Skip security reviews for new actions
- Hardcode secrets in workflows
- Grant excessive permissions to `GITHUB_TOKEN`
- Use unmaintained or abandoned actions
- Deploy updates without testing
- Ignore security advisories
- Use actions from untrusted sources

## Additional Resources

### Official Documentation
- [GitHub Actions Security Guides](https://docs.github.com/en/actions/security-guides)
- [Security Hardening for GitHub Actions](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
- [OIDC Security Tokens](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)

### Security Research
- [GitHub Actions Security Best Practices](https://securitylab.github.com/research/github-actions-preventing-pwn-requests/)
- [Supply Chain Security for GitHub Actions](https://github.blog/2021-02-12-avoiding-npm-substitution-attacks/)

### Tools
- [Action Pinning Tool](https://github.com/mheap/pin-github-action)
- [Dependabot for GitHub Actions](https://docs.github.com/en/code-security/dependabot/working-with-dependabot/keeping-your-actions-up-to-date-with-dependabot)
- [ActionLint](https://github.com/rhysd/actionlint) - Workflow linter

## Maintenance Log

| Date | Action | Version | Previous SHA | New SHA | Reviewer |
|------|--------|---------|--------------|---------|----------|
| 2026-01-03 | All actions | Initial | N/A | See registry | copilot |

---

**Last Updated**: 2026-01-03  
**Reviewed By**: Security Team  
**Next Review**: 2026-04-03 (Quarterly)

For questions or concerns, see [CONTRIBUTING.md](../../CONTRIBUTING.md) or contact the maintainers.
