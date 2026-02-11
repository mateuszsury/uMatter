# Release Process

## Versioning

- Use semantic versioning (`vMAJOR.MINOR.PATCH`).
- Update `CHANGELOG.md` before tagging.

## Release Inputs

1. Green CI on target branch.
2. Updated docs/reports for included scope.
3. Verified artifact packaging and checksums.

## Release Channels

- `stable`: production-ready milestones
- `experimental`: in-progress validation milestones

## GitHub Release

Use workflow:

- `.github/workflows/release-source.yml`

The workflow packages source archives and publishes SHA-256 checksums.

## Recommended Checklist

1. Confirm tag target commit.
2. Ensure `CHANGELOG.md` has final notes.
3. Trigger source release workflow with version.
4. Verify uploaded archive files and checksum file.
5. Publish release notes with known limitations and rollback guidance.

