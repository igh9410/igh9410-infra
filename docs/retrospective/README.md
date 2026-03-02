# K3s Upgrade Retrospective: Moving to GitOps + SUC Without Production Downtime

Date: 2026-03-02  
Cluster: `default`  
Upgrade: `v1.33.5+k3s1` -> `v1.34.4+k3s1`  
Languages: English + Korean (below)

This looked like a routine minor version bump, but it became a good test of whether our upgrade process was actually reliable under stateful workloads.

Our cluster runs:
- 1 control-plane node + 4 worker nodes
- ArgoCD-managed applications (`dev`, `prod`)
- CloudNativePG (CNPG) clusters
- `local-path` storage, which makes node-level behavior important during drains and failovers

The goal was clear: upgrade every node while avoiding user-visible production downtime.

## Why This Process Was Designed This Way

This was my first in-place upgrade for this stack.  
Most of my production upgrade experience was blue-green on EKS, where cutover and rollback mechanics are different from in-place node waves.

Because of that, I designed this upgrade around Rancher System Upgrade Controller (SUC), managed through GitOps, with strict guardrails.

Key decisions:
- Pinned version in Git: `v1.34.4+k3s1`
- `concurrency: 1` and `cordon: true` for both `server-plan` and `agent-plan`
- Label gate for control-plane: `upgrade-server=active`
- Label gate for workers: `upgrade-wave=active`

This gave us controlled rollout waves, explicit checkpoints, and a clear audit trail.

Reference:
- `infrastructure/system-upgrade-controller/plans.yaml`
- `docs/k3s-system-upgrade-controller-upgrade-plan.md`

## Preflight Work That Actually Made the Difference

Before touching node versions, we focused on availability posture:

- Added PDBs (`minAvailable: 1`) for `gramnuri-api`, `gramnuri-web`, and `artskorner-api`
- Increased `dev` app replicas to 2
- Added anti-affinity/topology spread by hostname
- Fixed CNPG topology key to `kubernetes.io/hostname`
- Aligned WAL storage class and production sync replication settings

On a cluster with `local-path`, this prep is not optional. It directly reduces upgrade blast radius.

Reference:
- `docs/k3s-upgrade-progress-summary.md`
- `docs/retrospective/commands-00-baseline-and-downtime-verification.md`

## Execution Timeline (UTC, 2026-03-02)

### 1) Control-plane wave

We triggered the control-plane plan first via node label.

What went wrong:
- `apply-server-plan` stayed `Pending` because the plan did not fully match control-plane taints.

How we fixed it:
- Added/verified toleration: `node-role.kubernetes.io/control-plane`
- Added/verified toleration: `node-role.kubernetes.io/master`
- Re-synced and resumed the wave

Result:
- Control-plane upgraded and came back `Ready`.

Reference:
- `docs/retrospective/commands-01-master-wave-troubleshooting.md`

### 2) Worker waves: `node02` -> `node04` -> `node01`

For each worker:
- Add `upgrade-wave=active`
- Watch SUC jobs/pods + node readiness/version
- Remove label
- Re-check app and DB health before next wave

All three workers upgraded successfully to `v1.34.4+k3s1`.

Reference:
- `docs/retrospective/commands-02-worker-node02-wave.md`
- `docs/retrospective/commands-04-worker-node04-wave.md`
- `docs/retrospective/commands-05-worker-node01-wave.md`

### 3) CNPG primary handover drills before `node03`

Before the final worker wave, we intentionally triggered DB primary handovers to measure risk in advance.

`dev-gramnuri-db-cluster`
- Full failover phase: ~`3m27s`
- Primary promotion window: ~`11.4s`
- App impact: `dev/gramnuri-api` showed 2x `500` (about `1.4s` burst)

`prod-artskorner-db-cluster`
- Full failover phase: ~`16.2s`
- Promotion window: ~`3.7s`
- App impact: no observed `500` in measured window

`prod-gramnuri-db-cluster`
- Full failover phase: ~`3m13s` (longer due to old primary termination delay)
- Promotion window: ~`3.6s`
- App impact: no observed `500` in measured window
- POST traffic continued (`200` and one `429`), no DB-error signature
- Additional planned switchover to `node04` (`2026-03-02T12:13:45Z`)
- Primary election window: ~`3.8s` (`currentPrimaryTimestamp=2026-03-02T12:13:48.766Z`)
- Full switchover to healthy: ~`29s` (`Cluster in healthy state` at `2026-03-02T12:14:14Z`)

Reference:
- `docs/retrospective/commands-06-dev-primary-handover-before-node03.md`
- `docs/retrospective/commands-07-prod-artskorner-primary-handover-before-node03.md`
- `docs/retrospective/commands-08-prod-gramnuri-primary-handover-before-node03.md`
- `docs/retrospective/commands-10-prod-gramnuri-node04-switchover.md`
- `docs/k3s-failover-impact-report.md`

### 4) Final worker wave: `node03`

After handover validation:
- SUC job start: `2026-03-02T10:37:25Z`
- SUC job end: `2026-03-02T10:38:29Z`
- Duration: ~`64s`

Observed during this wave (`prod-gramnuri` focus):
- No `500` signal from `prod/gramnuri-api` or `prod/gramnuri-web`
- `prod-gramnuri-db-cluster` primary remained on `node01`
- No new CNPG failover/recovery event in that window

Reference:
- `docs/retrospective/commands-09-worker-node03-wave.md`

## Final Result

All nodes ended on `v1.34.4+k3s1`:
- `controlplane`
- `node01`
- `node02`
- `node03`
- `node04`

Observed downtime outcome:
- Confirmed brief app-visible interruption only in `dev/gramnuri-api` during the dev DB failover drill
- No production app-visible downtime detected in measured failover and upgrade windows

One caveat:
- This conclusion is based on observed logs/events and probe traffic. Strong evidence, but still traffic-dependent.

## What I’d Keep for Future Upgrades

- Keep upgrades label-gated and wave-based
- Keep versions pinned in Git
- Keep DB handover drills before high-risk node waves
- Keep between-wave health checkpoints mandatory
- Keep command-level evidence logs for every maintenance event

## Raw Evidence Files

- `commands-00-baseline-and-downtime-verification.md`
- `commands-01-master-wave-troubleshooting.md`
- `commands-02-worker-node02-wave.md`
- `commands-03-gitops-repo-and-docs.md`
- `commands-04-worker-node04-wave.md`
- `commands-05-worker-node01-wave.md`
- `commands-06-dev-primary-handover-before-node03.md`
- `commands-07-prod-artskorner-primary-handover-before-node03.md`
- `commands-08-prod-gramnuri-primary-handover-before-node03.md`
- `commands-10-prod-gramnuri-node04-switchover.md`
- `commands-09-worker-node03-wave.md`
- `../k3s-failover-impact-report.md`

---

# K3s 업그레이드 회고: GitOps + SUC로 프로덕션 무중단에 가깝게 진행한 방법

일자: 2026-03-02  
클러스터: `default`  
업그레이드: `v1.33.5+k3s1` -> `v1.34.4+k3s1`  
영문 버전: 위 섹션

처음에는 단순한 마이너 업그레이드처럼 보였습니다.  
하지만 실제로는, 상태 저장 워크로드가 있는 환경에서 업그레이드 절차 자체가 얼마나 신뢰할 수 있는지 검증하는 작업이었습니다.

이번 클러스터 환경은 다음과 같습니다.
- 컨트롤 플레인 1대 + 워커 4대
- ArgoCD로 운영 중인 앱(`dev`, `prod`)
- CloudNativePG(CNPG) 데이터베이스 클러스터
- `local-path` 스토리지(노드 배치/드레인 시 영향이 큼)

목표는 명확했습니다.  
모든 노드를 업그레이드하되, 프로덕션에서 사용자 체감 다운타임을 만들지 않는 것.

## 왜 이번 절차를 이렇게 설계했는가

이번 작업은 이 스택에서 처음 진행한 in-place 업그레이드였습니다.  
실제 프로덕션에서의 주요 업그레이드 경험은 EKS 기반 blue-green 방식이었고, 그 방식은 in-place 노드 웨이브와 위험 지점이 다릅니다.

그래서 이번에는 Rancher System Upgrade Controller(SUC)를 GitOps로 운영하면서, 가드레일을 강하게 두는 방식으로 설계했습니다.

핵심 설정은 다음과 같습니다.
- 타겟 버전 고정: `v1.34.4+k3s1`
- `server-plan`, `agent-plan` 모두 `concurrency: 1`, `cordon: true`
- 컨트롤 플레인 라벨 게이트: `upgrade-server=active`
- 워커 웨이브 라벨 게이트: `upgrade-wave=active`

결과적으로 업그레이드가 "한 번에 밀어넣는 작업"이 아니라,  
웨이브 단위로 통제 가능한 운영 절차가 되었습니다.

참고:
- `infrastructure/system-upgrade-controller/plans.yaml`
- `docs/k3s-system-upgrade-controller-upgrade-plan.md`

## 사전 작업에서 승부가 났다

노드 버전을 올리기 전에 가용성 자세를 먼저 정리했습니다.

- `gramnuri-api`, `gramnuri-web`, `artskorner-api`에 PDB(`minAvailable: 1`) 추가
- `dev` 앱 replicas 2로 상향
- 호스트네임 기준 anti-affinity/topology spread 적용
- CNPG topology key를 `kubernetes.io/hostname`으로 정리
- WAL storage class 및 프로덕션 동기 복제 설정 정비

`local-path` 환경에서는 이런 사전 정리가 선택이 아니라 필수에 가깝습니다.  
업그레이드 중 장애 전파 범위를 확실히 줄여줍니다.

참고:
- `docs/k3s-upgrade-progress-summary.md`
- `docs/retrospective/commands-00-baseline-and-downtime-verification.md`

## 실행 타임라인 (UTC, 2026-03-02)

### 1) 컨트롤 플레인 웨이브

라벨로 컨트롤 플레인 플랜을 먼저 트리거했습니다.

문제:
- `apply-server-plan` 파드가 `Pending` 상태로 멈춤
- 원인은 컨트롤 플레인 taint 허용(toleration) 불일치

조치:
- `node-role.kubernetes.io/control-plane` toleration 명시/확인
- `node-role.kubernetes.io/master` toleration 명시/확인
- ArgoCD 재동기화 후 재진행

결과:
- 컨트롤 플레인 업그레이드 완료, `Ready` 복귀

참고:
- `docs/retrospective/commands-01-master-wave-troubleshooting.md`

### 2) 워커 웨이브: `node02` -> `node04` -> `node01`

각 워커는 동일한 절차로 진행했습니다.
- `upgrade-wave=active` 라벨 부여
- SUC job/pod, 노드 버전/Ready 상태 모니터링
- 완료 후 라벨 제거
- 다음 웨이브 전에 앱/DB 상태 재검증

세 노드 모두 `v1.34.4+k3s1`로 정상 업그레이드되었습니다.

참고:
- `docs/retrospective/commands-02-worker-node02-wave.md`
- `docs/retrospective/commands-04-worker-node04-wave.md`
- `docs/retrospective/commands-05-worker-node01-wave.md`

### 3) `node03` 전 DB Primary Handover 드릴

마지막 워커(`node03`) 업그레이드 전에 CNPG primary handover를 의도적으로 실행해 리스크를 먼저 측정했습니다.

`dev-gramnuri-db-cluster`
- 전체 failover 구간: 약 `3m27s`
- primary promotion 구간: 약 `11.4s`
- 앱 영향: `dev/gramnuri-api`에서 `500` 2건(약 `1.4s` 짧은 버스트)

`prod-artskorner-db-cluster`
- 전체 failover 구간: 약 `16.2s`
- promotion 구간: 약 `3.7s`
- 앱 영향: 측정 구간 내 `500` 미관측

`prod-gramnuri-db-cluster`
- 전체 failover 구간: 약 `3m13s` (기존 primary 종료 지연으로 길어짐)
- promotion 구간: 약 `3.6s`
- 앱 영향: 측정 구간 내 `500` 미관측
- failover 중 POST 트래픽도 처리됨(`200` 및 `429` 1건)
- 추가 planned switchover to `node04` (`2026-03-02T12:13:45Z`)
- primary 선출 구간: 약 `3.8s` (`currentPrimaryTimestamp=2026-03-02T12:13:48.766Z`)
- 클러스터 healthy 복귀까지: 약 `29s` (`2026-03-02T12:14:14Z`)

참고:
- `docs/retrospective/commands-06-dev-primary-handover-before-node03.md`
- `docs/retrospective/commands-07-prod-artskorner-primary-handover-before-node03.md`
- `docs/retrospective/commands-08-prod-gramnuri-primary-handover-before-node03.md`
- `docs/retrospective/commands-10-prod-gramnuri-node04-switchover.md`
- `docs/k3s-failover-impact-report.md`

### 4) 최종 워커 웨이브: `node03`

handover 검증 이후 `node03` 웨이브를 실행했습니다.

- SUC job 시작: `2026-03-02T10:37:25Z`
- SUC job 종료: `2026-03-02T10:38:29Z`
- 소요 시간: 약 `64s`

이 구간(`prod-gramnuri` 중심)에서 관측한 내용:
- `prod/gramnuri-api`, `prod/gramnuri-web`에서 `500` 신호 없음
- `prod-gramnuri-db-cluster` primary는 `node01`에 유지
- 해당 구간에서 CNPG failover/recovery 이벤트 추가 발생 없음

참고:
- `docs/retrospective/commands-09-worker-node03-wave.md`

## 최종 결과

모든 노드가 `v1.34.4+k3s1`로 정렬되었습니다.
- `controlplane`
- `node01`
- `node02`
- `node03`
- `node04`

관측 기준 다운타임 결론:
- 앱 레벨에서 명확히 확인된 중단은 `dev/gramnuri-api`의 짧은 오류 구간뿐
- 프로덕션(`gramnuri`, `artskorner`)은 측정한 failover/업그레이드 구간에서 사용자 가시적 다운타임 신호 미관측

단서:
- 위 결론은 로그/이벤트/프로브 기반 관측 결과입니다.
- 강한 근거이지만, 트래픽 패턴에 의존하는 성격은 남아 있습니다.

## 다음 업그레이드에도 유지할 원칙

- 라벨 게이트 + 웨이브 방식 유지
- 타겟 버전 Git 고정 유지
- 고위험 웨이브 전 DB handover 드릴 유지
- 웨이브 간 상태 검증을 필수 절차로 고정
- 명령/증적 로그를 항상 남기는 운영 습관 유지

## 원본 증적 파일

- `commands-00-baseline-and-downtime-verification.md`
- `commands-01-master-wave-troubleshooting.md`
- `commands-02-worker-node02-wave.md`
- `commands-03-gitops-repo-and-docs.md`
- `commands-04-worker-node04-wave.md`
- `commands-05-worker-node01-wave.md`
- `commands-06-dev-primary-handover-before-node03.md`
- `commands-07-prod-artskorner-primary-handover-before-node03.md`
- `commands-08-prod-gramnuri-primary-handover-before-node03.md`
- `commands-10-prod-gramnuri-node04-switchover.md`
- `commands-09-worker-node03-wave.md`
- `../k3s-failover-impact-report.md`
