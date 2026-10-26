# Contributing to uMatter

Thanks for contributing.

## Scope

This project targets MicroPython + Matter integration on ESP32-class hardware.
Contributions are welcome for:

- native module implementation (`modules/umatter`)
- build/flash automation (`scripts/`)
- test and certification readiness
- documentation and release tooling

## Development Prerequisites

- Windows PowerShell + WSL
- Python with `esptool` and `mpremote`
- ESP-IDF in WSL
- Access to supported hardware (at least ESP32-C5 or ESP32-C6 for runtime validation)

Operational flow is documented in `mp_skill.md`.

## Branch and Commit Guidelines

- Create feature branches from `main`.
- Keep each PR focused on one technical concern.
- Prefer descriptive commit messages:
  - `feat(runtime): add commissioning diagnostics`
  - `fix(flash): resolve chip from board`
  - `docs(phase-0): add step-16 report`

## Code Style

- Keep source ASCII unless a file already uses Unicode.
- Add concise comments only where logic is non-obvious.
- Do not introduce destructive git operations in automation scripts.

## Validation Requirements

Before opening a PR:

1. Run preflight:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_preflight.ps1
```

2. If you touched runtime/build logic, run at least one target build:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 -SkipFlash -SkipSmoke
```

3. For hardware-facing changes, provide:
- board name
- COM port used
- command used
- pass/fail result
- artifact path(s) under `artifacts/`

## Pull Request Checklist

- Problem and scope clearly described.
- Files changed are listed with rationale.
- Validation evidence attached.
- Risks and follow-up work identified.
- Docs updated when API/workflow changed.

## Reporting Issues

Use GitHub issue templates and include:

- board/chip
- firmware build instance
- full command line
- relevant log snippets

## Authorship and contributions

Project-maintained changes use the Git identity `Mateusz Sury
<66475105+mateuszsury@users.noreply.github.com>`. Configure it locally before
committing:

```sh
git config user.name "Mateusz Sury"
git config user.email "66475105+mateuszsury@users.noreply.github.com"
git config user.useConfigOnly true
```

The maintainer takes responsibility for tool-assisted changes. Do not add AI
tools as authors or co-authors. Preserve genuine human contributions, upstream
history, copyright notices and third-party licenses. Keep release provenance
and checksums intact. Describe the purpose of each change and record relevant
validation; avoid generic upload messages and environment-specific worktree names.
