# Upgrade Retrospective Command Logs

These files capture commands executed during the SUC-based k3s upgrade preparation and rollout.

## Files
- `commands-00-baseline-and-downtime-verification.md`
- `commands-01-master-wave-troubleshooting.md`
- `commands-02-worker-node02-wave.md`
- `commands-03-gitops-repo-and-docs.md`
- `commands-04-worker-node04-wave.md`
- `commands-05-worker-node01-wave.md`

## Suggested blog flow
1. Baseline and HA prechecks
2. Master wave issue and taint/toleration fix
3. Worker wave execution (`node02`)
4. Post-wave health verification and lessons learned
