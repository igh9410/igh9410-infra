# 05. 네트워킹 (9–10주차)

네트워크 장애는 "연결이 가끔 실패한다", "DNS가 느리다"처럼 재현하기 어려운 모양으로 나타난다.
이 파트는 그런 증상을 일부러 만들어서 커널 상태(TCP 상태, 포트, conntrack 테이블)로 설명하는 연습이다.

호스트 실습은 `tcp-lab.py`(`labs/linux-lab/host/`)를 쓴다. 표준 라이브러리만 쓰므로 VM 안의 레포 클론에서 바로 실행한다.

```bash
cd ~/igh9410-infra/labs/linux-lab/host
```

sysctl을 바꾸는 실습은 **별도 network namespace**에서 한다. `net.*` sysctl 대부분은 namespace마다 따로 있어서, 호스트 설정을 건드리지 않는다. 01-A에서 본 namespace가 여기서 다시 쓰인다.

## 05-A. TCP 상태와 TIME_WAIT는 어느 쪽에 쌓이는가

```bash
sudo ip netns add tcplab
sudo ip netns exec tcplab ip link set lo up

# 1) 클라이언트가 먼저 끊는 경우
sudo ip netns exec tcplab python3 tcp-lab.py server --port 8080 &
sudo ip netns exec tcplab python3 tcp-lab.py churn --port 8080 --count 200 --report 100
sudo ip netns exec tcplab ss -tan state time-wait | head

# 2) 서버가 먼저 끊는 경우
sudo ip netns exec tcplab python3 tcp-lab.py server --port 8081 --close-first &
sudo ip netns exec tcplab python3 tcp-lab.py churn --port 8081 --count 200 --report 100 --wait-eof
sudo ip netns exec tcplab ss -tan state time-wait | head
```

조사할 질문:

- 각 경우에 TIME_WAIT 소켓의 **로컬 포트**는 서버 포트인가, 임시(ephemeral) 포트인가? 즉 어느 쪽에 쌓였는가?
- TIME_WAIT는 왜 존재하는가? 없으면 어떤 문제가 생기는가? (늦게 도착한 패킷, 마지막 ACK 유실)
- TIME_WAIT 유지 시간은 얼마인가? `ss -tan -o state time-wait`의 타이머로 확인
- `ss -s`, `ss -tanp`로 상태별 개수 세기. `ESTAB`, `CLOSE_WAIT`가 쌓이는 건 각각 무슨 의미인가? (특히 `CLOSE_WAIT`가 계속 늘면 누구의 버그인가?)

## 05-B. ephemeral port 고갈

```bash
# 이 namespace에서만 임시 포트를 10개로 줄인다
sudo ip netns exec tcplab sysctl -w net.ipv4.ip_local_port_range="40000 40009"
cat /proc/sys/net/ipv4/ip_local_port_range        # 호스트 값은 그대로인지 확인

sudo ip netns exec tcplab python3 tcp-lab.py churn --port 8080 --count 30 --report 10
sudo ip netns exec tcplab python3 tcp-lab.py churn --port 8081 --count 30 --report 10 --wait-eof
```

예측: 각 경우 몇 번째 연결부터 실패하고, 에러는 무엇인가?

<details>
<summary>정답 확인</summary>

클라이언트가 먼저 끊으면 클라이언트 쪽에 TIME_WAIT가 남고, 그 동안 해당 임시 포트를 같은 목적지로 재사용할 수 없다. 포트가 10개뿐이라 11번째부터 `EADDRNOTAVAIL`(Cannot assign requested address)로 실패한다. 서버가 먼저 끊으면 TIME_WAIT가 서버 쪽에 남아서 클라이언트 포트는 바로 재사용되고, 실패하지 않는다.
실무 패턴: 커넥션 풀 없이 짧은 HTTP 요청을 대량으로 보내는 클라이언트(배치, 프록시, 헬스체크)가 같은 목적지로 포트를 고갈시킨다. 해결은 keep-alive와 커넥션 풀이 먼저이고, `ip_local_port_range` 확대나 `tcp_tw_reuse`는 그다음이다.

</details>

## 05-C. conntrack 테이블 고갈 (lab VM 호스트)

conntrack은 NAT와 상태 기반 방화벽을 위해 커널이 모든 연결을 기억하는 테이블이다. kube-proxy(iptables 모드)의 Service NAT도 여기에 의존한다.

```bash
ORIG=$(cat /proc/sys/net/netfilter/nf_conntrack_max); echo "original: $ORIG"   # 노트에 적어둔다
sudo conntrack -C                                # 현재 항목 수
sudo sysctl -w net.netfilter.nf_conntrack_max=$(( $(sudo conntrack -C) + 300 ))

python3 tcp-lab.py server --port 9090 &
python3 tcp-lab.py hold --port 9090 --count 400 --report 50 --timeout 1 &
# 출력에서 errors가 생기기 시작하는 시점을 본다 (몇 분 걸릴 수 있다)
sudo dmesg -T | grep -i conntrack | tail -3
sudo conntrack -S | head -3                      # drop, insert_failed 등

# 반드시 원래 값으로 되돌린다
kill %2 %1
sudo sysctl -w net.netfilter.nf_conntrack_max=$ORIG
```

조사할 질문:

- 테이블이 꽉 차면 새 연결에 무슨 일이 일어나는가? 클라이언트는 어떤 에러를 보는가? (거부가 아니라 패킷 드롭이라 타임아웃이 된다)
- 이미 맺어진 연결은 영향을 받는가?
- 실무 증상: "트래픽이 몰리면 노드 전체의 연결이 간헐적으로 타임아웃". 어떤 지표로 미리 알 수 있는가? (`node_nf_conntrack_entries / node_nf_conntrack_entries_limit`)
- 메인 클러스터는 Cilium `kubeProxyReplacement: true`라서 Service 처리를 iptables conntrack이 아니라 eBPF 자체 테이블(CT map)로 한다. 그 테이블도 꽉 찰 수 있는가? (05-E에서 확인)

## 05-D. DNS ndots

```bash
kubectl --context linux-lab apply -k labs/linux-lab/05-network/dns-ndots
kubectl --context linux-lab -n linux-lab exec dns-default -- cat /etc/resolv.conf
kubectl --context linux-lab -n linux-lab exec dns-ndots1 -- cat /etc/resolv.conf
```

각 파드에서 DNS 패킷을 잡으면서 외부 도메인을 한 번 조회한다.

```bash
kubectl --context linux-lab -n linux-lab exec -it dns-default -- \
  sh -c 'tcpdump -lnpi eth0 udp port 53 & sleep 1; curl -s -o /dev/null https://example.com; sleep 2; kill $!'
# dns-ndots1 에서도 똑같이
```

예측: `example.com` 한 번 조회에 DNS 쿼리가 몇 개 나가는가? (A와 AAAA를 따로 센다)

<details>
<summary>정답 확인</summary>

쿠버네티스 기본 `ndots:5`에서는 점이 5개 미만인 이름을 먼저 search 도메인을 붙여서 시도한다. `example.com.linux-lab.svc.cluster.local`, `example.com.svc.cluster.local`, `example.com.cluster.local`, (노드의 search 도메인이 있으면 그것까지) 순서로 NXDOMAIN을 받은 뒤에야 `example.com`을 묻는다. A/AAAA까지 곱하면 조회 한 번에 쿼리가 열 개 가까이 나간다. `ndots:1`이면 점이 하나 있으니 바로 절대 이름으로 묻는다.
외부 API를 많이 부르는 서비스에서 CoreDNS 부하와 지연이 커지는 흔한 원인이다. 해결: 이름 끝에 점을 붙인 FQDN(`example.com.`), 파드 `dnsConfig`의 `ndots` 조정, NodeLocal DNSCache.
참고: netshoot은 alpine(musl) 기반이라 search 도메인 쿼리를 glibc와 다른 방식(병렬)으로 보낸다. 패킷 순서가 생각과 다르면 그 차이를 찾아본다.

</details>

메인 클러스터에서는 VM 밖 평소 터미널에서 **읽기만** 해서 같은 현상을 Hubble로 본다.

```bash
kubectl --context default -n kube-system exec ds/cilium -- hubble observe --namespace prod --port 53 --last 50
```

`prod/gramnuri-api`가 외부 이름을 조회할 때도 쿼리가 여러 번 나가는가? 그렇다면 개선 PR을 만들 수 있는 실제 과제다.
(Hubble에서 쿼리 이름까지 보려면 DNS 규칙이 있는 CiliumNetworkPolicy로 DNS 프록시를 켜야 한다. 정책이 없으면 포트 53 L4 흐름만 보인다. 왜 그런지도 찾아본다.)

## 05-E. 같은 Service, 두 가지 데이터패스

lab k3s는 kube-proxy(iptables) + flannel, 메인 클러스터는 Cilium eBPF(kube-proxy 없음)다.

lab VM:

```bash
kubectl --context linux-lab -n linux-lab create deployment echo --image=busybox:1.37 -- sh -c 'trap "exit 0" TERM; while true; do sleep 1; done'
kubectl --context linux-lab -n linux-lab expose deployment echo --port 80
sudo iptables-save -t nat | grep -c KUBE-          # Service가 iptables 규칙으로 어떻게 표현되는가
sudo iptables-save -t nat | grep echo
sudo conntrack -L 2>/dev/null | head
```

메인 클러스터 (VM 밖 평소 터미널에서, 읽기 전용):

```bash
# 워커 노드 하나에 SSH해서
sudo iptables-save -t nat | grep -c KUBE-          # lab VM과 비교. 규칙이 남아 있다면 k3s 내장 kube-proxy가 꺼져 있는지(--disable-kube-proxy)부터 확인
sudo iptables-save | grep -c CILIUM                # Cilium이 iptables에 남기는 규칙은 무엇을 위한 것인가

# 데스크톱 터미널에서
kubectl --context default -n kube-system exec ds/cilium -- cilium-dbg service list | head
kubectl --context default -n kube-system exec ds/cilium -- cilium-dbg bpf ct list global | wc -l
```

조사할 질문:

- iptables 모드에서 Service가 수천 개가 되면 무엇이 느려지는가? eBPF 모드는 이 문제를 어떻게 피하는가?
- 메인 클러스터에서 Service 트래픽의 연결 상태는 어디에 저장되는가? 그 테이블의 크기 한도는 어디서 보는가?
- 이 차이를 면접에서 "왜 Cilium을 골랐나"의 근거로 2분 안에 설명해본다

## 면접 질문 (영어로 2분)

1. A batch job starts failing with "Cannot assign requested address" under load. Walk me through your diagnosis.
2. What is TIME_WAIT, which side holds it, and when does it become a problem?
3. Connections on a busy node time out intermittently while CPU and memory look fine. What kernel table would you check and why?
4. Why can DNS lookups from Kubernetes pods be slow for external names, and how do you fix it?
5. How does a ClusterIP Service actually route traffic with kube-proxy iptables mode versus Cilium's eBPF datapath?

## 정리

```bash
kubectl --context linux-lab delete -k labs/linux-lab/05-network/dns-ndots --ignore-not-found
kubectl --context linux-lab -n linux-lab delete deployment,service echo --ignore-not-found
sudo pkill -f tcp-lab.py
sudo ip netns del tcplab
```
