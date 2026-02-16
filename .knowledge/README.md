# Knowledge Repo Hooks

This repository is connected to TKD.

Generated files:

- `repo-connection.json`: repo-level connection metadata
- `learned-payload.template.json`: starter payload template
- `emit-learned.sh`: helper script for submitting `agent.learned` events
- `git-hooks/`: managed hook targets invoked by Git wrappers
- `hooks/`: agent hook commands (e.g. Claude PostToolUse)

Installed integrations:

- Git wrappers: `.git/hooks/post-commit`, `.git/hooks/pre-push`
- Claude settings: `.claude/settings.local.json` -> `.knowledge/hooks/claude-post-tool-use.sh`

Example:

```bash
./.knowledge/emit-learned.sh ./.knowledge/learned-payload.template.json 0.7
```
