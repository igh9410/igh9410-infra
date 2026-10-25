# 02. 메모리 (3–5주차)

> 📖 이번 파트의 책: 『Systems Performance』 7장 Memory. 범위와 확인 질문은 [reading-plan.md](reading-plan.md)

이 파트의 목표는 두 문장을 원리로 설명할 수 있게 되는 것이다.

1. **"메모리 사용량"은 하나의 숫자가 아니다.** RSS, page cache, working set, cgroup usage는 서로 다른 것을 센다.
2. **OOM은 누가 판단하느냐에 따라 종류가 다르다.** 커널(cgroup OOM killer), kubelet(eviction), 언어 런타임(V8, JVM, Go)이 각각 다른 기준으로 프로세스를 끝낸다.

## 먼저 읽고 정리할 개념

노트에 자기 말로 한 줄씩 정의를 적고 시작한다.

| 용어 | 한 줄 정의 (직접 작성) |
|---|---|
| anonymous memory (anon) | |
| page cache (file) | |
| RSS | |
| `memory.current` (cgroup usage) | |
| `active_file` / `inactive_file` | |
| working set (`container_memory_working_set_bytes`) | |
| shmem / tmpfs | |

관찰에 쓰는 파일 (컨테이너 또는 파드 cgroup 디렉터리):

- `memory.current`: 지금 이 cgroup에 청구된 전체 메모리
- `memory.stat`: `anon`, `file`, `active_file`, `inactive_file`, `shmem` 등으로 쪼갠 내역
- `memory.events`: `oom`, `oom_kill` 카운터. cgroup v2에서는 하위 cgroup의 이벤트까지 합산된다 (해당 cgroup만 보려면 `memory.events.local`)
- `memory.pressure`: PSI. 메모리가 부족해서 작업이 멈춘 시간 비율

랩을 하는 동안 노드에서 다음을 켜두면 좋다.

```bash
sudo dmesg -wT | grep -i -E "oom|killed"     # 커널이 죽였는지
sudo oomkill-bpfcc                            # 커널 OOM kill 이벤트를 eBPF로 추적
kubectl --context linux-lab -n linux-lab get pod -w
```

## 02-A. 커널 OOM

```bash
kubectl --context linux-lab apply -k labs/linux-lab/02-memory/kernel-oom
kubectl --context linux-lab -n linux-lab logs -f kernel-oom
```

예측: 몇 MiB 근처에서 죽는가? 종료 코드와 `reason`은?

관찰:

```bash
kubectl --context linux-lab -n linux-lab get pod kernel-oom \
  -o jsonpath='{.status.containerStatuses[0].state.terminated}{"\n"}'
```

- 컨테이너가 죽기 전에 노드에서 컨테이너 cgroup의 `memory.current`, `memory.stat`의 `anon`을 1초마다 찍어본다 (`watch -n1`)
- 죽은 뒤에는 컨테이너 cgroup이 사라진다. **파드 레벨** cgroup의 `memory.events`에서 `oom_kill`이 늘었는지 확인한다
- `dmesg`에 찍힌 메시지에서 누가, 어떤 cgroup 때문에 죽었는지 읽는다

<details>
<summary>정답 확인</summary>

`reason: OOMKilled`, `exitCode: 137` (128 + SIGKILL 9). 커널은 cgroup 사용량이 `memory.max`에 닿았을 때 먼저 회수를 시도하고, 회수할 수 있는 게 없으면(대부분 anon 메모리라서) cgroup 안의 프로세스를 SIGKILL로 죽인다. 로그상 할당량이 128MiB가 아니라 110~120MiB 근처에서 끊기는 이유는 파이썬 인터프리터 자체도 메모리를 쓰기 때문이다 (마지막 `VmRSS` 값과 비교해본다).

</details>

## 02-B. page cache는 OOM을 일으키는가

```bash
kubectl --context linux-lab apply -k labs/linux-lab/02-memory/page-cache
```

메모리 limit은 128Mi인데 512MiB 파일을 쓰고 계속 읽는다. **죽을지 안 죽을지 먼저 예측한다.**

관찰:

- 노드에서 `memory.stat`의 `file`, `active_file`, `inactive_file`, `anon`
- `memory.current`가 limit 근처에 붙어 있는가
- `kubectl --context linux-lab top pod page-cache` (working set) 값
- 2~3분 뒤 파드 상태와 `restartCount`

<details>
<summary>정답 확인</summary>

죽지 않는다. 파일 데이터는 page cache로 cgroup에 청구되지만, 깨끗한(이미 디스크에 쓰인) 페이지는 커널이 언제든 버리고 다시 읽을 수 있다. 그래서 `memory.current`가 limit 근처까지 올라가도 커널은 page cache를 회수하면서 버틴다.
`kubectl top`(working set = usage − inactive_file)도 높게 나올 수 있다. 자주 읽는 파일이라 active_file로 분류되기 때문이다. **대시보드의 메모리 그래프가 limit 근처라고 해서 곧 OOM이라는 뜻은 아니다**가 이 랩의 결론이다.

</details>

## 02-C. tmpfs emptyDir와 OOM

```bash
kubectl --context linux-lab apply -k labs/linux-lab/02-memory/tmpfs-oom
```

02-B와 거의 같지만 파일을 `medium: Memory` emptyDir(tmpfs)에 쓴다. 결과를 02-B와 비교한다.

조사할 질문:

- `memory.stat`에서 어느 항목이 늘어나는가? (`file`? `anon`? `shmem`?)
- 왜 이 메모리는 page cache처럼 회수되지 않는가?
- 쓰던 프로세스가 죽은 뒤에도 tmpfs에 남은 파일은 메모리를 계속 차지하는가? 그 메모리는 어느 cgroup에 청구되어 있는가?
- 변형: `sizeLimit`을 `64Mi`로 바꾸면 이번에는 **누가** 반응하는가? (커널? kubelet?) 파드 상태 메시지는 어떻게 다른가?

<details>
<summary>정답 확인</summary>

tmpfs의 파일은 `shmem`으로 청구되고, 디스크에 원본이 없어서 swap이 없는 노드에서는 회수할 수 없다. 그래서 limit에 닿으면 OOM kill이 일어난다. 파일은 프로세스가 아니라 볼륨(파드 수명)에 속하므로, 프로세스가 죽어도 메모리는 그대로 남는다.
`sizeLimit`을 넘기면 커널이 아니라 kubelet이 주기적으로 볼륨 사용량을 확인해서 파드를 **evict** 한다 (`reason: Evicted`). 같은 "메모리가 넘쳤다"도 판단 주체가 다르면 결과가 다르다.

</details>

## 02-D. Node.js: 힙 OOM vs Buffer OOM

```bash
kubectl --context linux-lab apply -k labs/linux-lab/02-memory/node-heap-oom
```

두 파드 모두 컨테이너 limit 256Mi, V8 힙 한도 64MB다. 차이는 JS 객체를 쌓느냐(`MODE=heap`), Buffer를 쌓느냐(`MODE=buffer`)뿐이다.

예측 표를 먼저 채운다.

| 파드 | 죽는 시점의 대략적인 메모리 | reason | exitCode | 누가 죽였나 |
|---|---|---|---|---|
| `node-heap-oom` | | | | |
| `node-buffer-oom` | | | | |

<details>
<summary>정답 확인</summary>

- `node-heap-oom`: 64MB 근처에서 V8이 "JavaScript heap out of memory"를 찍고 스스로 abort 한다. `reason: Error`, `exitCode: 134` (128 + SIGABRT 6). 커널 OOM이 아니라서 `OOMKilled`로 안 잡히고, 노드의 `memory.events`의 `oom_kill`도 늘지 않는다.
- `node-buffer-oom`: Buffer는 V8 힙 밖(external)에 잡혀서 `--max-old-space-size`의 영향을 받지 않는다. 256Mi 근처까지 커지다가 커널이 죽인다. `reason: OOMKilled`, `exitCode: 137`.

실무 교훈: Node 서비스의 OOM 알람을 `OOMKilled`로만 걸면 힙 OOM을 놓친다. 컨테이너 재시작 + 종료 코드, 그리고 앱 레벨 힙 지표(`heapUsed / heap limit`)를 같이 봐야 한다.

</details>

## 02-E. JVM: 프로세스는 살아 있는데 앱은 죽은 상태

```bash
kubectl --context linux-lab apply -k labs/linux-lab/02-memory/jvm-oom
kubectl --context linux-lab -n linux-lab logs -f jvm-oom-default -c jvm
kubectl --context linux-lab -n linux-lab logs -f jvm-oom-exit -c jvm
```

예측: 두 파드의 상태, `restartCount`, 종료 코드는?

관찰:

- `jvm-oom-default` 로그에서 `OutOfMemoryError` 이후에도 heartbeat가 계속 찍히는가? `allocatorAlive`는?
- 파드는 `Running`인가? 이 상태에서 liveness probe가 `/healthz` 같은 단순 응답이었다면 쿠버네티스는 문제를 알아챌 수 있는가?
- `jvm-oom-exit`의 종료 코드는 몇이고, 그 숫자는 어디서 왔는가?

<details>
<summary>정답 확인</summary>

- `jvm-oom-default`: `OutOfMemoryError`는 예외라서 그걸 던진 스레드(allocator)만 죽는다. JVM 프로세스는 살아 있고, 파드는 `Running`, 재시작 0회. 실제 서비스였다면 요청 처리 스레드 일부가 죽은 "반쯤 망가진" 상태로 계속 떠 있게 된다. 단순한 liveness probe로는 잡히지 않는다.
- `jvm-oom-exit`: `-XX:+ExitOnOutOfMemoryError`로 첫 OOM에서 JVM이 종료된다. `exitCode: 3`. 쿠버네티스가 재시작할 수 있는 상태가 된다.
- 추가로 생각할 것: 힙(`-Xmx`)은 멀쩡한데 메타스페이스, 스레드 스택, 다이렉트 버퍼 같은 힙 밖 메모리 때문에 컨테이너 전체가 limit을 넘으면? 그때는 커널이 죽이고 `OOMKilled 137`이 된다. 그래서 컨테이너에서는 `-Xmx`를 고정값보다 `-XX:MaxRAMPercentage`로 limit 대비 비율로 잡는 경우가 많다.

</details>

## 02-F. Go: GOMEMLIMIT

```bash
kubectl --context linux-lab apply -k labs/linux-lab/02-memory/go-memlimit
kubectl --context linux-lab -n linux-lab logs -f go-no-memlimit -c memlab
kubectl --context linux-lab -n linux-lab logs -f go-with-memlimit -c memlab
```

같은 바이너리, 같은 70MiB live set, 같은 128Mi limit. `GOMEMLIMIT=100MiB` 유무만 다르다.

예측: 어느 쪽이 살아남는가? 살아남는 쪽은 그 대가로 무엇을 더 쓰는가?

관찰:

- `GODEBUG=gctrace=1` 출력에서 GC 직전/직후 힙 크기(`X->Y->Z MB`)와 GC 빈도
- 로그의 `numGC` 증가 속도 비교
- `kubectl top`으로 두 파드의 CPU 사용량 비교

<details>
<summary>정답 확인</summary>

- `go-no-memlimit`: 기본 `GOGC=100`이면 다음 GC 목표가 live set의 약 2배(140MiB)라서, GC가 돌기 전에 128Mi limit을 넘는다. 커널이 죽인다 (`OOMKilled`, `137`). Go는 런타임에 힙 상한이 없어서 "컨테이너 사망 = 앱 메모리 사망"이 된다.
- `go-with-memlimit`: 전체 메모리가 100MiB에 가까워지면 런타임이 GC를 더 자주 돌려서 limit 밑에 머문다. 대가는 GC CPU 사용량 증가 (`numGC`가 훨씬 빨리 는다).
- 한계: `GOMEMLIMIT`은 소프트 한도다. live set 자체가 한도를 넘으면 GC를 아무리 돌려도 못 줄인다. `LIVE_MIB`를 110으로 바꿔서 확인해본다. GC가 쉬지 않고 돌다가(런타임은 GC가 CPU를 독점하지 않도록 상한을 두기 때문에) 결국 한도를 넘어 커지는 모습을 `gctrace`로 볼 수 있다.

</details>

## 02 종합: 직접 만드는 표

이 파트가 끝나면 아래 표를 노트에 채우고, 그 표를 보지 않고 설명할 수 있어야 한다.

| 상황 | 판단 주체 | 기준 | 쿠버네티스에서 보이는 모습 |
|---|---|---|---|
| 컨테이너 anon 메모리가 limit 초과 | | | |
| page cache가 limit 근처 | | | |
| tmpfs 파일이 limit 초과 | | | |
| emptyDir `sizeLimit` 초과 | | | |
| 노드 전체 메모리 부족 | | | |
| Node.js 힙 한도 초과 | | | |
| JVM 힙 부족 (기본 설정) | | | |
| Go 힙 증가 | | | |

## 면접 질문 (영어로 2분)

1. A pod's memory graph is at 95% of its limit but it never gets OOMKilled. Why could that be?
2. What is the difference between a container being OOMKilled and a pod being evicted?
3. Our Node.js service restarts with exit code 134 and nothing shows up in our OOMKilled alerts. What is happening and how would you alert on it?
4. A Java service is "Running" but returns errors after a memory spike, and it never restarts. What do you suspect and what would you change?
5. When would you set GOMEMLIMIT, and what can it not protect you from?

## 정리

```bash
for l in kernel-oom page-cache tmpfs-oom node-heap-oom jvm-oom go-memlimit; do
  kubectl --context linux-lab delete -k labs/linux-lab/02-memory/$l --ignore-not-found
done
```
