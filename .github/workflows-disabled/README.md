# Workflow templates disabled by token scope

These workflow files are intentionally stored outside .github/workflows/ because the current GitHub token does not include the workflow scope required to push workflow definitions.

To activate:

1. Grant workflow scope to your GitHub token/CLI auth.
2. Move files from .github/workflows-disabled/ to .github/workflows/.
3. Commit and push.

