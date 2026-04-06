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
