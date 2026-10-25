# 00. 환경 준비

## 왜 별도 VM인가

메인 클러스터 노드는 프로덕션 앱과 CNPG DB를 같이 돌린다. 이번 실습은 일부러 메모리, 디스크, PID, conntrack을 고갈시키기 때문에
메인 노드에서 하면 프로덕션 장애가 된다. XCP-ng에서 VM을 하나 따로 만들고, 그 안에 단일 노드 k3s를 띄운다.
메인 클러스터와 버전은 맞추되(`v1.34.4+k3s1`), CNI는 일부러 다르게 둔다 (lab: flannel + kube-proxy iptables, main: Cilium eBPF).
이 차이는 05-E에서 그대로 실습 재료가 된다.

## 1. VM 만들기 (XCP-ng)

| 항목 | 값 |
|---|---|
| OS | Ubuntu Server 24.04 LTS (cgroup v2 기본) |
| vCPU | 2 |
| 메모리 | 4 GiB |
| 디스크 | 30 GiB |
| 네트워크 | 메인 클러스터와 같은 대역 (예: `192.168.44.x`) |
| 이름 | `linux-lab` |

설치할 때 OpenSSH 서버를 켜고, 사용자는 `igh9410`으로 만든다.

## 2. SSH 키와 인벤토리

```bash
ssh-copy-id -i ansible/files/id_rsa_ansible.pub igh9410@<LAB_VM_IP>
```

`ansible/inventory/inventory.ini`의 `[linux_lab]` 그룹에 VM IP를 추가한다.

## 3. 도구와 k3s 설치

```bash
cd ansible
ansible-playbook -i inventory/inventory.ini playbooks/setup_linux_lab.yml
```

플레이북이 하는 일:

- 관찰 도구 설치: `sysstat`(vmstat, iostat, mpstat, pidstat, sar), `strace`, `ltrace`, `lsof`, `tcpdump`, `conntrack`, `fio`, `stress-ng`, `perf`, `bpftrace`, BCC 도구
- `sar` 히스토리 수집 활성화
- cgroup v2가 마운트되어 있는지 확인 (아니면 실패)
- 단일 노드 k3s 설치 (Traefik 비활성화)

Ubuntu에서 BCC 도구는 이름 끝에 `-bpfcc`가 붙는다 (예: `execsnoop-bpfcc`, `oomkill-bpfcc`).

## 4. kubeconfig 연결

```bash
scp igh9410@<LAB_VM_IP>:/etc/rancher/k3s/k3s.yaml ~/.kube/linux-lab.yaml
# server 주소를 127.0.0.1에서 VM IP로 바꾸고, context 이름을 linux-lab으로 바꾼다
sed -i "s/127.0.0.1/<LAB_VM_IP>/; s/: default$/: linux-lab/" ~/.kube/linux-lab.yaml
export KUBECONFIG=~/.kube/config:~/.kube/linux-lab.yaml
kubectl config get-contexts   # linux-lab 이 보여야 한다
```

습관: 실습 명령에는 항상 `--context linux-lab`을 붙인다. 메인 클러스터에 실수로 적용하는 걸 막는 가장 싼 방법이다.

## 5. 실습 네임스페이스

```bash
kubectl --context linux-lab apply -k labs/linux-lab/base
kubectl --context linux-lab -n linux-lab get limitrange,resourcequota
```

`base`는 처음에 한 번만 적용한다. 각 랩은 `base`를 포함하지 않으므로 `kubectl delete -k <lab>`이 네임스페이스까지 지우지 않는다.

## 6. 노드에서 컨테이너 찾는 법 (모든 랩에서 반복)

k3s는 containerd를 내장하고 있어서 노드에서 `crictl`을 바로 쓸 수 있다.

```bash
ssh igh9410@<LAB_VM_IP>
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

## 완료 확인

- [ ] `kubectl --context linux-lab get nodes` 가 `Ready`
- [ ] `stat -fc %T /sys/fs/cgroup` 가 `cgroup2fs`
- [ ] `sudo execsnoop-bpfcc` 가 실행됨 (Ctrl+C로 종료)
- [ ] 아무 파드나 띄워서 위 6번 절차로 PID와 cgroup 경로를 찾아봄
