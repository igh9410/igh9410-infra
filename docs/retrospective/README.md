# Upgrade Retrospective Command Logs

These files capture commands executed during the SUC-based k3s upgrade preparation and rollout.
Measured downtime/impact analysis is documented separately in:
- `../k3s-failover-impact-report.md`

## Files
- `commands-00-baseline-and-downtime-verification.md`
- `commands-01-master-wave-troubleshooting.md`
- `commands-02-worker-node02-wave.md`
- `commands-03-gitops-repo-and-docs.md`
- `commands-04-worker-node04-wave.md`
- `commands-05-worker-node01-wave.md`
- `commands-06-dev-primary-handover-before-node03.md`
- `commands-07-prod-artskorner-primary-handover-before-node03.md`
- `commands-08-prod-gramnuri-primary-handover-before-node03.md`
- `commands-09-worker-node03-wave.md`

## Suggested blog flow
1. Baseline and HA prechecks
2. Master wave issue and taint/toleration fix
3. Worker wave execution (`node02`)
4. Post-wave health verification and lessons learned
