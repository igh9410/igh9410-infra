# 01. 컨테이너는 프로세스다 (1–2주차)

컨테이너는 커널 기능이 아니다. **namespace로 보이는 범위를 격리하고, cgroup으로 쓸 수 있는 자원을 제한한 평범한 프로세스**다.
이걸 손으로 직접 만들어보면 이후 모든 랩(OOM, throttling, PID 1)이 같은 원리의 변형이라는 게 보인다.

## 01-A. namespace를 손으로 만들기 (lab VM 호스트)

```bash
# 새 PID + mount + UTS namespace에서 셸 실행
sudo unshare --pid --fork --mount-proc --uts bash
hostname lab-container && hostname   # 바깥 호스트 이름은 그대로인지 다른 터미널에서 확인
ps -ef                               # 프로세스가 몇 개 보이는가? bash의 PID는?
echo $$
```

다른 터미널에서:

```bash
lsns                                  # 새로 생긴 namespace 찾기
ps -ef | grep "unshare"               # 바깥에서 본 bash의 PID는?
sudo nsenter --target <바깥 PID> --pid --mount --uts ps -ef   # 컨테이너에 exec 하는 것과 같은 원리
```

예측하고 확인할 것:

- 안쪽에서 본 bash의 PID와 바깥에서 본 PID가 다른 이유
- `--mount-proc` 없이 하면 `ps`가 왜 이상하게 나오는가
- `kubectl exec`가 내부적으로 하는 일과 `nsenter`의 관계

namespace 종류도 정리해둔다: `pid`, `net`, `mnt`, `uts`, `ipc`, `user`, `cgroup`, `time`.
특히 **mount namespace**가 컨테이너마다 다른 루트 파일시스템을 보게 해주는 핵심이다.

## 01-B. cgroup을 손으로 만들기 (lab VM 호스트)

```bash
# 메모리 64M, CPU 20%, 프로세스 20개로 제한된 셸
sudo systemd-run --scope -p MemoryMax=64M -p CPUQuota=20% -p TasksMax=20 --unit=handmade bash
cat /proc/self/cgroup
CG=/sys/fs/cgroup$(cut -d: -f3 /proc/self/cgroup)
cat $CG/memory.max $CG/cpu.max $CG/pids.max
```

이 셸 안에서 차례로 해본다:

1. `yes > /dev/null` 을 돌리고 다른 터미널에서 `top` 으로 CPU 사용률 확인 → `cat $CG/cpu.stat`
2. `python3 -c "b = b'x' * (100 * 1024 * 1024)"` → 무슨 일이 일어나고, `cat $CG/memory.events` 는 어떻게 변하는가
3. `for i in $(seq 30); do sleep 100 & done` → 몇 개부터 실패하는가, 에러 메시지는?

정리할 것: `CPUQuota=20%`가 `cpu.max`에 어떤 두 숫자로 들어갔는지, 그 두 숫자의 의미 (quota/period).

## 01-C. 파드 스펙이 노드의 cgroup 값이 되는 과정

```bash
kubectl --context linux-lab apply -k labs/linux-lab/01-cgroup-inspect
kubectl --context linux-lab -n linux-lab get pod cgroup-inspect -o jsonpath='{.status.qosClass}{"\n"}'
```

매니페스트의 `resources`를 보고 **아래 값을 먼저 노트에 예측**한 뒤, 노드에서 [00-setup의 6번 절차](00-setup.md#6-노드에서-컨테이너-찾는-법-모든-랩에서-반복)로 cgroup 디렉터리를 찾아 확인한다.

| 파일 | 예측 | 실제 |
|---|---|---|
| `cpu.max` | | |
| `cpu.weight` | | |
| `memory.max` | | |
| `memory.min` | | |
| 경로에 들어간 QoS 클래스 | | |

그리고 한 단계 위(파드 레벨) cgroup의 같은 파일들도 본다. 컨테이너가 하나뿐인데 파드 레벨에도 limit이 걸려 있는 이유는?

<details>
<summary>정답 확인 (예측을 적은 뒤에 열기)</summary>

- `cpu.max`: `50000 100000`. limit `500m` = 100ms 주기(period)마다 50ms(quota)까지 사용 가능.
- `cpu.weight`: request `250m`는 먼저 cgroup v1 방식의 shares(`250 * 1024 / 1000 = 256`)로 바뀐 뒤 v2 weight로 변환된다.
  예전 runc의 선형 변환식이면 `1 + (256 - 2) * 9999 / 262142` = **10**이 나온다.
  최근 runc/crun은 변환식을 바꿨기 때문에 다른 값이 나올 수 있다. 실제 값이 10이 아니면 `k3s --version`으로 번들된 containerd/runc 버전을 확인하고 변환식이 바뀐 이유를 찾아보는 것까지가 이 랩이다.
- `memory.max`: `134217728` (128Mi).
- `memory.min`: `0`. 메모리 request는 기본적으로 커널에 강제되지 않는다. 스케줄러가 노드에 파드를 배치할 때만 쓴다 (커널 보호를 거는 MemoryQoS 기능은 alpha).
- QoS: request와 limit이 달라서 `Burstable`. 경로에 `burstable`이 들어간다.
- 파드 레벨 limit: kubelet이 파드 단위로도 컨테이너 limit 합계를 걸어서, 파드 전체(사이드카, 공유 tmpfs 등)가 limit을 넘지 못하게 한다.

</details>

마지막으로 `kubectl exec`로 컨테이너 안에 들어가 `cat /sys/fs/cgroup/memory.max`를 해본다. 안에서 보이는 경로가 노드의 경로와 다른 이유는? (힌트: cgroup namespace)

## 면접 질문 (영어로 2분)

1. What is a container, from the kernel's point of view?
2. How are Kubernetes CPU requests and limits enforced on the node? What about memory requests?
3. What is the difference between namespaces and cgroups? Give an example where you need each.
4. How do you find which cgroup a container's process belongs to on a node, and what would you look at there?

## 정리

```bash
kubectl --context linux-lab delete -k labs/linux-lab/01-cgroup-inspect
```
