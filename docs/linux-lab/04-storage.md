# 04. 스토리지 (8주차)

> 📖 이번 파트의 책: 『Systems Performance』 8장 File Systems, 9장 Disks. 범위와 확인 질문은 [reading-plan.md](reading-plan.md)

"디스크가 꽉 찼다"는 사실 서로 다른 세 가지 문제다: 블록(용량)이 없거나, inode가 없거나, 지워진 파일을 누가 아직 잡고 있거나.
쿠버네티스에서는 여기에 kubelet의 ephemeral-storage eviction이 하나 더 붙는다.

이 파트의 호스트 실습은 루프백 디바이스나 `/var/tmp`처럼 **lab VM 안에서도 격리된 공간**에서 한다. 루트 파일시스템을 진짜로 채우지 않는다.

## 04-A. 지웠는데 공간이 안 돌아오는 파일 (lab VM 호스트)

```bash
sudo mkdir -p /mnt/small
sudo truncate -s 256M /var/tmp/small.img
sudo mkfs.ext4 -q /var/tmp/small.img
sudo mount -o loop /var/tmp/small.img /mnt/small

# 파일을 하나 쓰고, 다른 프로세스가 그 파일을 열어둔 채로 둔다
sudo dd if=/dev/zero of=/mnt/small/app.log bs=1M count=150
sudo tail -f /mnt/small/app.log > /dev/null &

sudo rm /mnt/small/app.log
df -h /mnt/small            # 용량이 돌아왔는가?
sudo du -sh /mnt/small      # du는 뭐라고 하는가?
```

조사할 질문:

- `df`와 `du`가 다른 숫자를 말하는 이유는? 각 도구는 무엇을 세는가?
- 지워진 파일을 누가 잡고 있는지 찾아라: `sudo lsof +L1`, `sudo ls -l /proc/<pid>/fd`
- 프로세스를 죽이지 않고 공간을 돌려받는 방법은? (`/proc/<pid>/fd/<n>`을 truncate)
- 실무에서 흔한 원인: logrotate가 파일을 지웠는데 앱이 예전 파일 디스크립터에 계속 쓰는 경우. 해결책 두 가지 (`copytruncate`, 앱이 SIGHUP으로 파일 재오픈)

## 04-B. inode 고갈 (lab VM 호스트)

```bash
sudo truncate -s 64M /var/tmp/inode.img
sudo mkfs.ext4 -q -N 256 /var/tmp/inode.img      # inode를 일부러 아주 적게
sudo mkdir -p /mnt/inode && sudo mount -o loop /var/tmp/inode.img /mnt/inode
sudo bash -c 'for i in $(seq 1 1000); do touch /mnt/inode/f$i || { echo "failed at $i"; break; }; done'
df -h /mnt/inode
df -i /mnt/inode
```

조사할 질문:

- 에러 메시지는 무엇이고, 용량 부족과 어떻게 구분하는가?
- inode가 고갈되는 실제 사례: 작은 세션 파일, 캐시 파일, 메일 큐, 컨테이너 이미지 레이어가 많은 노드
- 노드에서 inode를 많이 쓰는 디렉터리 찾기: `sudo du --inodes -x / 2>/dev/null | sort -n | tail`

정리:

```bash
sudo kill %1 2>/dev/null; sudo umount /mnt/small /mnt/inode
sudo rm -f /var/tmp/small.img /var/tmp/inode.img
```

## 04-C. ephemeral-storage eviction

```bash
kubectl --context linux-lab apply -k labs/linux-lab/04-storage/ephemeral-eviction
kubectl --context linux-lab -n linux-lab get pod ephemeral-eviction -w
```

limit 100Mi인데 emptyDir(디스크)에 200MiB를 쓴다. 예측: 누가 멈추는가 (커널? kubelet?), 얼마나 빨리, 파드 상태는?

<details>
<summary>정답 확인</summary>

커널은 이 limit을 모른다. 디스크 공간에는 cgroup 같은 커널 강제 장치가 없어서 `dd`는 200MiB를 다 쓴다. 그 뒤 kubelet이 주기적으로 파드의 ephemeral 사용량(컨테이너 쓰기 레이어 + 로그 + 디스크 emptyDir)을 계산하다가 limit 초과를 발견하고 파드를 **evict** 한다. 결과는 `status.phase: Failed`, `reason: Evicted`, 메시지에 ephemeral local storage 초과가 적힌다. 즉시가 아니라 감시 주기만큼 늦게 반응한다는 점이 메모리 OOM과의 차이다.

</details>

## 04-D. I/O 지연 관찰 (lab VM 호스트)

```bash
iostat -xz 1                               # r_await, w_await, aqu-sz, %util
sudo fio --name=randwrite --filename=/var/tmp/fio.test --size=512M \
  --rw=randwrite --bs=4k --direct=1 --ioengine=libaio --iodepth=32 \
  --runtime=30 --time_based
sudo biolatency-bpfcc 5 1                  # 블록 I/O 지연 분포 (히스토그램)
sudo rm -f /var/tmp/fio.test
```

조사할 질문:

- `%util`이 100%면 디스크가 한계라는 뜻인가? (NVMe처럼 병렬 처리하는 장치에서는 왜 오해일 수 있는가)
- `await`이 커지는 것과 `aqu-sz`(큐 길이)의 관계
- 이 시간 동안 `vmstat 1`의 `wa`와 03-B의 load average는 어떻게 변하는가?

## 면접 질문 (영어로 2분)

1. `df` says the disk is 100% full but `du` only finds half of that. What is going on and how do you fix it without restarting the service?
2. A node reports "No space left on device" but `df -h` shows plenty of free space. What do you check?
3. A pod was evicted for ephemeral storage. What counts toward ephemeral storage, and how would you prevent it?
4. How do you tell whether an application is slow because of disk I/O?

## 정리

```bash
kubectl --context linux-lab delete -k labs/linux-lab/04-storage/ephemeral-eviction --ignore-not-found
```
