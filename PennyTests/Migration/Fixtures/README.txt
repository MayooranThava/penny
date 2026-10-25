PennyTests migration fixtures.

The upgrade tests write SwiftData stores at runtime from PennySchemaV103 (v1.0.3, commit dca913c) and from the unversioned v1.0.4 model list (commit 92c6746). This environment cannot run those App Store builds, so there is no checked-in .store binary. The folder stays a bundled resource for a future device-captured store. See PennyTests/Migration/README.md.
