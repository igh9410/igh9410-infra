# 03. CPU와 프로세스 (6–7주차)

CPU limit은 메모리 limit과 다르게 **죽이지 않고 느리게 만든다.** 그래서 증상이 "가끔 느리다", "p99만 튄다"처럼 애매하게 나타난다.
프로세스 쪽은 PID 1이 특별하다는 사실 하나가 graceful shutdown, 좀비, 시그널 문제를 대부분 설명한다.

## 03-A. CPU throttling

```bash
kubectl --context linux-lab apply -k labs/linux-lab/03-cpu-process/cpu-throttle
```

바쁜 루프 2개가 CPU 2개를 원하지만 limit은 0.5개다.

관찰 (노드에서 컨테이너 cgroup):

```bash
watch -n1 cat $CG/cpu.stat     # nr_periods, nr_throttled, throttled_usec
cat $CG/cpu.max
cat $CG/cpu.pressure           # PSI: CPU를 기다리느라 멈춘 시간
top -H -p $PID                 # 스레드별 사용률
```

조사할 질문:

- `kubectl top`에서 CPU 사용량은 얼마로 나오는가? 그런데 프로세스는 왜 더 쓰고 싶어 하는가?
- 100ms 주기 중 몇 ms를 실제로 돌고 몇 ms를 멈춰 있는가? `nr_throttled / nr_periods` 비율로 계산해본다.
- 이 상태의 웹 서버라면 평균 응답시간과 p99 중 어느 쪽이 먼저 나빠질까? 왜?
- limit을 `2`로 올리면 `nr_throttled` 증가가 멈추는가?

<details>
<summary>정답 확인</summary>

`kubectl top`은 500m 근처로 나온다. 루프 2개가 매 100ms 주기마다 합쳐서 50ms의 quota를 금방 다 쓰고, 나머지 시간 동안 cgroup 전체가 멈춘다(throttled). 거의 모든 주기가 throttle 되므로 `nr_throttled`가 `nr_periods`와 거의 같이 증가한다.
요청 하나가 quota가 바닥난 시점에 걸리면 다음 주기까지 최대 수십 ms를 그냥 기다린다. 그래서 평균보다 **꼬리 지연(p99)**이 먼저 나빠진다. 멀티스레드 앱은 여러 스레드가 quota를 동시에 써버려서 더 심하다. CPU limit을 빼고 request만 두는 팀이 많은 이유다.

</details>

Prometheus 지표 이름도 같이 기억해둔다: `container_cpu_cfs_throttled_periods_total`, `container_cpu_cfs_periods_total`.

## 03-B. load average와 D 상태 (lab VM 호스트)

```bash
uptime
# CPU를 거의 안 쓰면서 load를 올리는 방법: 디스크를 직접 I/O로 두드린다
for i in 1 2 3 4; do
  sudo dd if=/dev/zero of=/var/tmp/io-$i bs=1M count=2048 oflag=direct &
done
vmstat 1                       # r, b, wa 열
top                            # load average, %wa, 프로세스 상태 D
ps -eo pid,stat,wchan:20,cmd | awk '$2 ~ /D/'
wait; sudo rm -f /var/tmp/io-*
```

조사할 질문:

- CPU 사용률은 낮은데 load average가 올라가는 이유는? 리눅스의 load average는 무엇을 세는가?
- `vmstat`의 `r`과 `b` 열은 각각 무엇인가?
- D(uninterruptible sleep) 상태의 프로세스는 `kill -9`로 죽는가?

<details>
<summary>정답 확인</summary>

리눅스 load average는 실행 중이거나 실행을 기다리는 태스크(R)에 더해 **uninterruptible sleep(D)** 상태 태스크까지 센다. 디스크 I/O를 기다리는 프로세스는 D 상태라서 CPU를 안 써도 load를 올린다. 그래서 "load가 높다 = CPU가 부족하다"가 아니다. `vmstat`의 `r`은 실행 대기, `b`는 블록된(D) 프로세스 수다. D 상태는 시그널을 받지 않아서 I/O가 끝날 때까지 `kill -9`도 바로 듣지 않는다 (NFS 행이 대표적인 사례).

</details>

## 03-C. PID 1과 시그널

```bash
kubectl --context linux-lab apply -k labs/linux-lab/03-cpu-process/pid1-signals
kubectl --context linux-lab -n linux-lab get pods -l lab=03-pid1-signals

for p in pid1-no-handler pid1-trap pid1-shared-ns; do
  echo "== $p"
  kubectl --context linux-lab -n linux-lab get pod $p \
    -o jsonpath='{.spec.terminationGracePeriodSeconds}{"s grace\n"}'
  time kubectl --context linux-lab -n linux-lab delete pod $p --wait=true
done
```

삭제하기 전에 각 파드의 삭제 소요 시간과 종료 코드를 예측한다. 종료 코드는 다른 터미널에서 `get pod -w -o yaml`로 보거나, `kubectl get events`로 확인한다.

| 파드 | 예상 삭제 시간 | 예상 종료 코드 | 실제 |
|---|---|---|---|
| `pid1-no-handler` | | | |
| `pid1-trap` | | | |
| `pid1-shared-ns` | | | |

<details>
<summary>정답 확인</summary>

- `pid1-no-handler`: 약 20초 (grace period 전체). PID namespace의 init(PID 1)에는 커널이 기본 시그널 동작을 적용하지 않는다. 핸들러가 없으면 SIGTERM은 그냥 무시된다. 결국 grace period가 끝나고 SIGKILL로 죽는다 (`137`).
- `pid1-trap`: 거의 즉시. 셸이 SIGTERM 핸들러를 설치했으니 받아서 `exit 0`.
- `pid1-shared-ns`: 거의 즉시, `143` (128 + SIGTERM 15). `shareProcessNamespace: true`면 pause 컨테이너가 PID 1이 되고, `sh`는 일반 프로세스라서 SIGTERM의 기본 동작(종료)이 그대로 적용된다.

실무 교훈: 셸 스크립트 엔트리포인트(`sh -c "..."`)나 Dockerfile의 shell form `CMD`는 앱이 SIGTERM을 못 받는 흔한 원인이다. `exec`로 앱을 PID 1로 만들고 앱이 SIGTERM을 처리하게 하거나, `tini` 같은 init을 쓴다. 배포 때마다 파드 종료가 30초씩 걸린다면 가장 먼저 의심할 곳이다.

</details>

## 03-D. 좀비 프로세스

```bash
kubectl --context linux-lab apply -k labs/linux-lab/03-cpu-process/zombie
kubectl --context linux-lab -n linux-lab exec zombie -- ps -o pid,ppid,stat,comm
```

노드에서도 본다: `ps -eo pid,ppid,stat,cmd | awk '$3 ~ /Z/'`

조사할 질문:

- 좀비는 메모리나 CPU를 쓰는가? 그럼 무엇을 차지하는가?
- `kill -9 <좀비 PID>`는 효과가 있는가? 없다면 좀비를 없애는 방법은?
- 보통 고아 프로세스는 PID 1이 거둔다(reap). 이 컨테이너에서는 왜 안 거둬지는가?
- 좀비가 계속 쌓이면 결국 어떤 자원이 바닥나는가? (03-E와 연결)

<details>
<summary>정답 확인</summary>

좀비는 이미 종료됐고 메모리도 반납했지만, 부모가 `wait()`로 종료 상태를 읽어갈 때까지 프로세스 테이블 항목과 **PID**를 차지한다. 이미 죽었으니 `kill -9`는 효과가 없다. 부모가 `wait()`하게 고치거나, 부모를 죽이면 PID 1이 고아를 넘겨받아 거둔다. 이 컨테이너에서는 PID 1(파이썬)이 바로 그 무심한 부모라서 아무도 거두지 않는다. 쌓이면 `pids.max`나 노드의 `pid_max`에 닿아 새 프로세스를 못 만든다. 컨테이너에 `tini`를 넣는 이유가 시그널 전달과 함께 이 좀비 수거다.

</details>

## 03-E. PID 고갈 (lab VM 호스트)

포크 폭탄은 반드시 제한된 cgroup 안에서만 실행한다.

```bash
sudo systemd-run --scope -p TasksMax=50 --unit=forkbomb bash
CG=/sys/fs/cgroup$(cut -d: -f3 /proc/self/cgroup)
cat $CG/pids.max
:(){ :|:& };:          # 이 셸 안에서만
# 다른 터미널에서
cat /sys/fs/cgroup/system.slice/forkbomb.scope/pids.current
cat /sys/fs/cgroup/system.slice/forkbomb.scope/pids.events
sudo systemctl stop forkbomb.scope
```

조사할 질문:

- 제한에 닿은 뒤 셸에서 명령을 치면 어떤 에러가 나는가? (`fork: Resource temporarily unavailable`, EAGAIN)
- 쿠버네티스에서 파드 단위 PID 제한은 어디서 설정하는가? lab k3s에 `--kubelet-arg=pod-max-pids=100`을 넣어 보고, 파드의 `pids.max`가 바뀌는지 확인한다.
- 노드 전체 한도는 `/proc/sys/kernel/pid_max`. 메인 클러스터 노드의 현재 값은? (읽기만 한다)

## 면접 질문 (영어로 2분)

1. A service has CPU usage well below its limit on the dashboard, but p99 latency spikes. What could be going on and how would you confirm it?
2. Load average on a node is 30 on a 4-core machine but CPU usage is 20%. What does that tell you?
3. Pods take exactly 30 seconds to terminate on every deploy. What is the most likely cause?
4. What is a zombie process, and why do containers sometimes accumulate them?
5. Should you set CPU limits on latency-sensitive services? Argue both sides.

## 정리

```bash
for l in cpu-throttle pid1-signals zombie; do
  kubectl --context linux-lab delete -k labs/linux-lab/03-cpu-process/$l --ignore-not-found
done
```
