# Skille

Skille is a local control layer for AI-agent skills that already live in each
agent's own skill roots. It discovers, installs, updates, and helps author
standard Agent Skills packages without creating a proprietary skill store or
format.

Product language: [CONTEXT.md](CONTEXT.md). Spec and prototypes:
[`.scratch/skille-spec/`](.scratch/skille-spec/).

## Build & run

```bash
swift build
swift run Skille
```

Requires macOS 14+ and Xcode / Swift 6.

## Control-plane tests

Behavior is verified at the **`SkilleControl.ControlPlane`** seam against a
**temporary filesystem** (no real Application Support, no real git):

```bash
swift test
```

Convention: each test creates a unique directory under
`FileManager.default.temporaryDirectory`, passes it as
`ControlPlane(sidecarRoot:)`, and deletes it afterward. Fake/stub git fetch
will plug into the same seam in later issues.

## Security

Please report vulnerabilities privately. See
[SECURITY.md](.github/SECURITY.md) for instructions.
