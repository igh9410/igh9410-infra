# 00. 환경 준비

## 왜 데스크톱 안의 VM인가

메인 클러스터 노드는 프로덕션 앱과 CNPG DB를 같이 돌리고, 홈랩 머신에는 VM을 더 띄울 메모리 여유가 없다.
이번 실습은 일부러 메모리, 디스크, PID, conntrack을 고갈시키기 때문에 **데스크톱 안에 Ubuntu VM을 하나 띄워서** 그 안에서만 한다.

- 데스크톱 OS 위에서 바로 하지 않는다. 포크 폭탄이나 sysctl 변경이 데스크톱 자체를 흔든다.
- VM 안에는 단일 노드 k3s를 띄운다. 메인 클러스터와 버전은 맞추되(`v1.34.4+k3s1`), CNI는 일부러 다르게 둔다
  (lab: flannel + kube-proxy iptables, main: Cilium eBPF). 이 차이가 05-E의 실습 재료가 된다.
- **VM 안에는 메인 클러스터 kubeconfig를 절대 넣지 않는다.** VM에서 쓸 수 있는 context는 `linux-lab` 하나뿐이라, 실수로 프로덕션에 적용할 방법 자체가 없다.

## 1. VM 만들기

| 항목 | 값 |
|---|---|
| OS | Ubuntu 24.04 LTS (cgroup v2 기본) |
| vCPU | 2 |
| 메모리 | 4 GiB |
| 디스크 | 30 GiB |
| 이름 | `linux-lab` |

어떤 도구든 상관없지만 **배포판 기본 커널**로 도는 VM이어야 한다. eBPF 도구(BCC)와 `perf`는 커널 헤더/패키지가 맞아야 동작하는데,
WSL2나 OrbStack처럼 자체 커널을 쓰는 환경에서는 일부 도구가 안 될 수 있다.

데스크톱 OS별 추천:

**Windows / Linux / macOS 공통: Multipass** (Ubuntu 클라우드 이미지 그대로 실행)

```bash
multipass launch 24.04 --name linux-lab --cpus 2 --memory 4G --disk 30G
multipass shell linux-lab
```

대안: Windows는 Hyper-V, Linux는 KVM(virt-manager), macOS는 Lima(`limactl start --name=linux-lab template://ubuntu-lts`).
Apple Silicon에서도 실습 이미지(busybox, python, node, golang, temurin, netshoot)는 전부 arm64를 지원한다.

## 2. 도구와 k3s 설치 (VM 안에서)

```bash
git clone https://github.com/igh9410/igh9410-infra.git
cd igh9410-infra
bash labs/linux-lab/host/setup-lab-vm.sh
```

스크립트가 하는 일:

- cgroup v2가 마운트되어 있는지 확인 (아니면 중단)
- 관찰 도구 설치: `sysstat`(vmstat, iostat, mpstat, pidstat, sar), `strace`, `ltrace`, `lsof`, `tcpdump`, `conntrack`, `fio`, `stress-ng`, `perf`, `bpftrace`, BCC 도구
- `sar` 히스토리 수집 활성화
- 단일 노드 k3s 설치 (Traefik 비활성화)
- `~/.kube/config`를 만들고 context 이름을 `linux-lab`으로 변경
- 실습 네임스페이스(`base`: namespace, LimitRange, ResourceQuota) 적용

여러 번 실행해도 안전하다. Ubuntu에서 BCC 도구는 이름 끝에 `-bpfcc`가 붙는다 (예: `execsnoop-bpfcc`, `oomkill-bpfcc`).

## 3. 작업 방식

- 모든 실습 명령(`kubectl`, `crictl`, `sudo ...`)은 **VM 안에서** 실행한다. 노드에 SSH할 필요 없이 VM 자체가 노드다.
- 습관: `kubectl`에는 항상 `--context linux-lab`을 붙인다. 문서의 명령도 전부 그렇게 되어 있다.
- 메인 클러스터를 **읽기 전용으로** 보는 단계(05-D의 Hubble, 05-E의 Cilium 서비스 맵)만 VM 밖, 평소 쓰는 터미널에서 `--context default`로 한다.
- 실습 매니페스트는 `labs/linux-lab/` 아래에 있고, `base`는 설치 스크립트가 이미 적용했다. 각 랩은 `base`를 포함하지 않으므로 `kubectl delete -k <lab>`이 네임스페이스까지 지우지 않는다.

## 4. 노드에서 컨테이너 찾는 법 (모든 랩에서 반복)

k3s는 containerd를 내장하고 있어서 VM 안에서 `crictl`을 바로 쓸 수 있다.

```bash
sudo crictl ps --name <container-name>
CID=$(sudo crictl ps --name <container-name> -q)
PID=$(sudo crictl inspect "$CID" | jq .info.pid)

# 이 프로세스가 속한 cgroup (cgroup driver와 상관없이 항상 정확함)
cat /proc/$PID/cgroup
CG=/sys/fs/cgroup$(cut -d: -f3 /proc/$PID/cgroup)
ls "$CG"

# 이 프로세스의 namespace들
sudo ls -l /proc/$PID/ns
```

`/proc/<pid>/cgroup`에서 경로를 읽는 방법을 기본으로 쓴다. cgroup 경로 형식은 cgroup driver(systemd/cgroupfs)에 따라 다르지만, 이 방법은 둘 다에서 통한다.

## 5. 실습이 끝나면

```bash
multipass stop linux-lab      # 다음 실습까지 꺼두기
multipass delete --purge linux-lab   # 12주 플랜이 끝나면 통째로 삭제
```

## 완료 확인

- [ ] `kubectl --context linux-lab get nodes` 가 `Ready`
- [ ] `kubectl config get-contexts` 에 `linux-lab` 하나만 보임
- [ ] `stat -fc %T /sys/fs/cgroup` 가 `cgroup2fs`
- [ ] `sudo execsnoop-bpfcc` 가 실행됨 (Ctrl+C로 종료)
- [ ] 아무 파드나 띄워서 위 4번 절차로 PID와 cgroup 경로를 찾아봄
