# Linux 심화 실습 플랜

> 목표: "현상은 아는데 원리를 OS 레벨에서 끝까지 설명 못 하는" 상태에서
> "장애를 보면 커널이 무엇을 하고 있는지 도구 없이 추론하고 설명할 수 있는" 상태로 간다.
> 커널 코드를 읽는 수준이 아니라, 시니어 SRE 시나리오 면접(노드가 느려졌다, 파드가 죽는다, 연결이 안 된다)을
> 원리부터 답할 수 있는 수준이 기준이다.

- 기간: 12주 (2026-10-26 ~ 2027-01-24 기준, 평일 30분 + 주말 1~2시간)
- 환경: 메인 클러스터와 **분리된** 실습용 VM 1대 (단일 노드 k3s)
- 산출물: 랩별 노트, 노드 장애 대응 런북 1개, 영어 블로그 글 1개 이상

## 원칙

1. **예측 먼저.** 매니페스트를 apply 하기 전에 결과(종료 코드, 상태, 어떤 지표가 변하는지)를 노트에 먼저 적는다. 틀린 예측이 가장 많이 배우는 지점이다.
2. **AI는 정답 확인용.** 처음 20분은 AI 없이 직접 원인을 찾는다. 그다음 Claude로 검증하고, 내 설명과 다른 부분만 노트에 남긴다.
3. **"왜"를 내 말로 적는다.** 명령어 출력만 붙여넣으면 남는 게 없다. 각 랩은 "왜 그렇게 됐는지" 3~5문장으로 끝낸다.
4. **면접 답변으로 마무리.** 랩마다 해당 면접 질문에 영어로 2분 안에 답해본다(녹음 추천). 글로벌 리모트 목표에 맞춘 연습이다.
5. **실무 연결.** 회사에서 겪은 장애(Node/JVM OOM, 레거시 클러스터 노드 디버깅 등)와 연결되는 지점을 노트에 적는다.

## 안전 규칙 (중요)

이 홈랩은 물리 머신 1대 위에서 프로덕션 앱(`prod` 네임스페이스)과 CNPG DB를 같이 돌린다.
메모리 고갈, 디스크 채우기, conntrack 고갈 같은 실습을 메인 클러스터 노드에서 하면 프로덕션이 같이 죽는다.

- 모든 실습은 **별도 lab VM** (`linux-lab` kube context)에서 한다. XCP-ng VM은 메모리가 고정 할당이라 lab VM이 터져도 다른 VM에 번지지 않는다.
- `labs/`는 어떤 ArgoCD Application에도 연결되어 있지 않다. 자동 동기화되지 않으며, 항상 손으로 `--context linux-lab`을 붙여서 적용한다.
- 메인 클러스터(`default` context)에서는 **읽기 전용 관찰만** 한다 (예: 05의 Hubble DNS 관찰).
- 실습 중 바꾼 sysctl은 랩이 끝나면 원래 값으로 되돌리고, 되돌린 값을 노트에 기록한다.

## 커리큘럼

| 주차 | 파트 | 문서 | 핵심 질문 |
|---|---|---|---|
| 0 | 환경 준비 | [00-setup.md](00-setup.md) | lab VM, 단일 노드 k3s, 관찰 도구 |
| 1–2 | 컨테이너 = 프로세스 | [01-containers-are-processes.md](01-containers-are-processes.md) | namespace와 cgroup으로 컨테이너를 직접 만들고, 파드 스펙이 커널 값으로 어떻게 바뀌는가 |
| 3–5 | 메모리 | [02-memory.md](02-memory.md) | RSS, page cache, working set. 커널 OOM과 런타임 OOM(Node, JVM, Go)은 어떻게 다른가 |
| 6–7 | CPU와 프로세스 | [03-cpu-and-processes.md](03-cpu-and-processes.md) | throttling, load average, PID 1과 시그널, 좀비, PID 고갈 |
| 8 | 스토리지 | [04-storage.md](04-storage.md) | 지운 파일이 공간을 안 돌려줄 때, inode 고갈, ephemeral-storage eviction |
| 9–10 | 네트워킹 | [05-networking.md](05-networking.md) | TCP 상태와 TIME_WAIT, 포트 고갈, conntrack, DNS ndots, kube-proxy vs Cilium |
| 11–12 | 종합 | [06-capstone.md](06-capstone.md) | 60초 체크리스트 런북, eBPF 도구, 게임데이, 블로그 |

## 진행 체크리스트

랩을 끝내면 체크하고 노트 링크를 단다. 노트는 `docs/linux-lab/notes/`에 [TEMPLATE.md](notes/TEMPLATE.md)를 복사해서 쓴다.
포트폴리오로 쓸 수 있도록 노트는 영어로 쓰는 것을 추천한다.

- [ ] 00 lab VM + 단일 노드 k3s + 도구 설치
- [ ] 01-A namespace를 손으로 만들기 (`unshare`, `nsenter`)
- [ ] 01-B cgroup을 손으로 만들기 (`systemd-run`, cgroup v2 파일)
- [ ] 01-C 파드 스펙이 노드의 cgroup 값으로 바뀌는 과정 추적
- [ ] 02-A 커널 OOM (`kernel-oom`)
- [ ] 02-B page cache는 OOM을 일으키는가 (`page-cache`)
- [ ] 02-C tmpfs emptyDir와 OOM (`tmpfs-oom`)
- [ ] 02-D Node.js 힙 OOM vs Buffer OOM (`node-heap-oom`)
- [ ] 02-E JVM OOM과 `ExitOnOutOfMemoryError` (`jvm-oom`)
- [ ] 02-F Go `GOMEMLIMIT` (`go-memlimit`)
- [ ] 03-A CPU throttling (`cpu-throttle`)
- [ ] 03-B load average와 D 상태
- [ ] 03-C PID 1과 시그널 (`pid1-signals`)
- [ ] 03-D 좀비 프로세스 (`zombie`)
- [ ] 03-E PID 고갈
- [ ] 04-A 지웠는데 공간이 안 돌아오는 파일
- [ ] 04-B inode 고갈
- [ ] 04-C ephemeral-storage eviction (`ephemeral-eviction`)
- [ ] 04-D I/O 지연 관찰
- [ ] 05-A TCP 상태와 TIME_WAIT 위치
- [ ] 05-B ephemeral port 고갈
- [ ] 05-C conntrack 테이블 고갈
- [ ] 05-D DNS ndots (`dns-ndots`)
- [ ] 05-E 같은 Service, 두 가지 데이터패스 (kube-proxy iptables vs Cilium eBPF)
- [ ] 06-A 노드 장애 대응 런북 작성
- [ ] 06-B eBPF 도구로 01~05 다시 보기
- [ ] 06-C 게임데이 (블라인드 장애 진단)
- [ ] 06-D 영어 블로그 글 발행

## 완료 기준

각 파트 문서 끝의 면접 질문을 **노트 없이, 영어로, 2분 안에** 답할 수 있으면 그 파트는 끝이다.
12주 뒤 최종 확인: 06-C 게임데이에서 무작위 장애 5개 중 4개 이상을 AI 없이 30분 안에 원인까지 찾는다.

## 참고 자료

- Brendan Gregg, *Systems Performance* (2nd ed.) — 메모리, CPU, 디스크, 네트워크 장의 개념 부분
- Brendan Gregg, *Linux Performance Analysis in 60,000 Milliseconds* (Netflix Tech Blog) — 06-A 런북의 뼈대
- Brendan Gregg, USE Method — 자원별로 사용률(Utilization), 포화도(Saturation), 에러(Errors)를 순서대로 본다
- Linux kernel docs: `admin-guide/cgroup-v2` — `memory.*`, `cpu.*`, `pids.*` 파일의 정확한 의미
- `man 7 namespaces`, `man 7 cgroups`, `man 7 signal`, `man 7 tcp`
