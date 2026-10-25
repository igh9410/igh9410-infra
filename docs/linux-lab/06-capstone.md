# 06. 종합 (11–12주차)

01~05에서 개별 현상을 만들어봤다. 마지막 2주는 그걸 **순서 있는 진단 습관**과 **남에게 보여줄 수 있는 결과물**로 바꾼다.

## 06-A. 노드 장애 대응 런북 작성

Brendan Gregg의 "60초 분석" 체크리스트를 뼈대로, 내 환경(k3s, Cilium, 컨테이너)에 맞는 런북을 직접 쓴다.
산출물: `docs/linux-lab/runbook-node-triage.md`

뼈대가 되는 명령 순서 (각 줄에서 **무엇을 보고, 어떤 값이면 어디로 넘어가는지**를 런북에 적는다):

```bash
uptime                 # load average 추세: 1분/5분/15분
dmesg -T | tail        # OOM kill, I/O 에러, conntrack table full
vmstat 1               # r, b, si/so, us/sy/wa/st
mpstat -P ALL 1        # 특정 CPU만 바쁜가
pidstat 1              # 어떤 프로세스가
iostat -xz 1           # 디스크 await, 큐 길이
free -m                # buff/cache 포함해서 해석
sar -n DEV 1           # 네트워크 처리량
sar -n TCP,ETCP 1      # 연결 생성률, 재전송
top                    # 마지막으로 전체 확인
```

컨테이너 환경이라 추가로 들어가야 할 단계:

- 문제 프로세스 → 컨테이너 → 파드 역추적 (`/proc/<pid>/cgroup`, `crictl ps`, `crictl inspect`)
- 해당 cgroup의 `cpu.stat`(throttling), `memory.events`(OOM), `memory.pressure`/`cpu.pressure`/`io.pressure`(PSI)
- 쿠버네티스 쪽 신호: `kubectl describe node`(Conditions: MemoryPressure, DiskPressure, PIDPressure), `kubectl get events`

USE 방법으로 자원별 표를 런북 맨 위에 둔다.

| 자원 | 사용률 (Utilization) | 포화도 (Saturation) | 에러 (Errors) |
|---|---|---|---|
| CPU | | | |
| 메모리 | | | |
| 디스크 I/O | | | |
| 디스크 용량/inode | | | |
| 네트워크 | | | |
| PID / 파일 디스크립터 | | | |

각 칸에 01~05에서 실제로 써본 명령이나 파일을 채운다. 채우지 못하는 칸이 있으면 그게 다음 공부 거리다.

## 06-B. eBPF 도구로 다시 보기

01~05 중 랩 3개를 골라 다시 돌리면서, 이번에는 BCC/bpftrace 도구로 관찰한다. 같은 현상을 다른 각도에서 보는 연습이다.

| 다시 볼 랩 | 도구 | 무엇이 새로 보이는가 |
|---|---|---|
| 02-A 커널 OOM | `oomkill-bpfcc` | 어떤 프로세스가, 어떤 cgroup 압박 때문에 죽었는지 실시간 |
| 03-A throttling | `runqlat-bpfcc`, `cpudist-bpfcc` | 실행 대기 지연 분포 |
| 03-C PID 1 시그널 | `killsnoop-bpfcc` | 누가 어떤 시그널을 언제 보냈는지 |
| 03-D 좀비 / 03-E PID | `execsnoop-bpfcc` | 짧게 살다 죽는 프로세스 |
| 04-A 지운 파일 | `opensnoop-bpfcc` | 누가 어떤 파일을 열고 있는지 |
| 04-D I/O | `biolatency-bpfcc` | 블록 I/O 지연 히스토그램 |
| 05-A/B TCP | `tcpconnect-bpfcc`, `tcplife-bpfcc` | 연결 단위 수명, 포트 |

bpftrace 원라이너 하나는 직접 써본다. 예: 프로세스별 `openat` 호출 수 세기.

```bash
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_openat { @[comm] = count(); }'
```

메인 클러스터의 Cilium도 eBPF라는 점을 연결해서 정리한다: Hubble이 보여주는 흐름 데이터가 어디서 오는지.

## 06-C. 게임데이 (블라인드 진단)

장애를 만드는 사람과 찾는 사람을 분리해야 진짜 연습이 된다. 두 가지 방법 중 하나를 고른다.

1. **장애 주입 스크립트를 직접 작성한다.** `labs/linux-lab/host/inject-fault.sh`: 01~05에서 만든 장애 중 하나를 무작위로 골라 주입하고, 정답은 root만 읽을 수 있는 파일에 남긴다. 스크립트를 쓰는 과정 자체가 복습이다. 장애 후보:
   - cgroup 안의 메모리 누수 프로세스
   - CPU quota가 낮게 걸린 서비스
   - 지워진 채 열려 있는 대용량 파일
   - inode가 고갈된 마운트
   - 포트 범위가 좁아진 netns 안의 클라이언트
   - 좀비를 만드는 부모 프로세스
2. **Claude에게 출제를 맡긴다.** 정답을 말하지 말고 장애 주입 명령만 만들게 한 뒤, 다른 터미널에서 진단한다.

규칙: AI 없이 30분, 06-A 런북만 보고 진단한다. 5회 중 4회 이상 원인까지 맞히면 이 플랜은 끝이다. 매 회차 소요 시간과 막힌 지점을 노트에 남긴다.

## 06-D. 영어 블로그 글

01~05 노트 중 가장 재미있었던 것 하나를 영어 글로 다듬어 블로그(geonhyukim.com)에 올린다. 추천 주제:

- "Why your Node.js OOM never shows up as OOMKilled" (02-D, 02-E, 02-F 묶어서)
- "The 30-second pod shutdown: PID 1 and signals in containers" (03-C)
- "Same Service, two datapaths: kube-proxy iptables vs Cilium eBPF" (05-E)

글로벌 리모트 채용에서는 이력서 한 줄보다 이런 글 하나가 "원리를 이해하고, 글로 설명할 수 있다"를 더 잘 보여준다.
회사 환경 이야기를 넣을 때는 회사 이름, 내부 시스템, 보안 사고 세부 사항은 빼고 홈랩 재현 결과로 설명한다.

## 플랜 종료 후

- 이력서 Projects의 Homelab 항목에 한 줄 추가: 재현한 장애 종류와 런북, 블로그 링크
- 면접 질문 목록(01~05) 전체를 영어로 한 번에 녹음해서 다시 들어본다
- 다음 단계 후보: 커널 메모리 회수(kswapd, PSI 기반 oomd), 네트워크 스택 심화(qdisc, TCP 혼잡 제어), `perf`로 CPU 프로파일링과 flame graph
