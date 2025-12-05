---
trigger: always_on
---

# Windsurf Rules for DeltaChat iOS Project

## File Creation Rules

- **Before creating any new file**, examine the existing project structure to determine the appropriate location and organization
- Follow the established project patterns and directory structure when placing new files
- If a new file requires grouping with similar files, create the necessary folder structure to maintain project organization consistency
- Consider the existing naming conventions and architectural patterns used throughout the codebase

## Project Structure Guidelines

This iOS project follows a modular structure with:
- Main app code in `deltachat-ios/`
- Core functionality in `DcCore/`
- Extensions in separate folders (e.g., `DcShare/`, `DcWidget/`, `DcNotificationService/`)
- Tests in `DcTests/`
- Documentation in `docs/`
- Build scripts in `scripts/`d

When adding new files, first explore the relevant directories to understand the existing organization patterns before creating new files or directories.
