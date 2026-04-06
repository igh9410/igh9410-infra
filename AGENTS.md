# AGENTS.md

## Custom Application Manifests

For custom applications in this repository, do not use `exec`-based `preStop` hooks such as `/bin/sh -c "sleep 30"`.

Several custom application images are built as multi-stage images and run as distroless containers, so shell binaries like `/bin/sh` and `sleep` may not exist in the runtime image.

When a shutdown delay is needed, use the Kubernetes lifecycle `sleep` action instead:

```yaml
lifecycle:
  preStop:
    sleep:
      seconds: 30
terminationGracePeriodSeconds: 60
```

Apply this convention to all custom applications under `apps/` unless a service has a documented exception.

## Multi-Agent Git Workflow

When multiple agents work on this repository, each agent must use a separate branch for its own task.

Do not have multiple agents modify the same files in parallel. Split work so each agent owns a disjoint file set, and avoid touching files that another agent is already editing.

If a task would require editing files that are already in another agent's scope, re-scope the task first instead of creating overlapping commits.

The recommended setup for parallel agent work is one coordinator session plus one terminal session per agent task, with each agent working on its own branch and preferably its own `git worktree`.

Do not run multiple editing agents against the same checkout. Sharing one working tree is acceptable for read-only investigation, but concurrent file edits must happen in separate branches and separate worktrees.
