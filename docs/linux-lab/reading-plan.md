# 책 스터디: 『Systems Performance』 (Brendan Gregg, 2nd ed.)

실습(01~06)과 나란히 가는 읽기 계획이다. 실습이 "현상을 손으로 만들어보기"라면, 이 책은 "그 현상을 설명하는 개념과 진단 방법론"을 채운다.

- 책: Brendan Gregg, *Systems Performance: Enterprise and the Cloud*, 2nd edition (2020, 928쪽)
- 원칙: **통독하지 않는다.** 실습 주차 직전에 해당 장의 개념과 방법론 부분만 꼼꼼히 읽고, 도구 옵션 설명과 출력 예시는 훑는다. 도구는 실습하면서 필요할 때 다시 찾는다.
- 언어: 원서(영어)로 읽는다. 면접에서 쓸 용어(saturation, run queue latency, page scanning, retransmits 등)를 영어 그대로 익히는 것도 목적이다.
- 시간: 주말 블록(1~2시간) 중 1시간을 읽기에 쓴다. 장이 길면 2주에 나눈다.

## 장별 계획

| 실습 주차 | 읽을 장 | 집중해서 읽을 부분 | 훑기만 할 부분 | 연결 실습 |
|---|---|---|---|---|
| 0 | 2장 Methodologies | 용어(latency, utilization, saturation), USE 방법, 워크로드 특성화, 드릴다운 분석, 레이턴시 분석, anti-method들 | 모델링, 용량 계획, 통계 세부 | 06-A 런북의 뼈대 |
| 1–2 | 11장 Cloud Computing | OS 가상화(컨테이너): namespace, cgroup, 리소스 제어, 컨테이너 안팎에서의 관찰 차이 | 하드웨어 가상화(하이퍼바이저) 세부, 경량 VM | 01-A, 01-B, 01-C |
| 3–5 | 7장 Memory | 가상 메모리, 페이징, 수요 페이징, 페이지 캐시와 회수, OOM killer, 사용률과 포화도 지표, 방법론 | 하드웨어 아키텍처(MMU, TLB) 세부, 튜닝 파라미터 목록 | 02 전체 |
| 6–7 | 6장 CPUs | run queue와 스케줄러, 사용률 vs 포화도, CPU 사용 시간 분류(user/sys/iowait/steal), 방법론 | 하드웨어(캐시, 인터커넥트) 세부, 프로파일링 도구 옵션 | 03-A, 03-B |
| 8 | 8장 File Systems, 9장 Disks | 파일시스템 캐시, 쓰기 지연과 동기 쓰기, I/O 스택, 디스크 레이턴시와 큐, 사용률 지표의 함정 | 파일시스템별 내부 구조, 디스크 하드웨어 세부 | 04 전체 |
| 9–10 | 10장 Network | TCP 연결 수명, 백로그와 큐, 재전송, 버퍼, 연결 생성률과 처리량 구분, 방법론 | NIC 하드웨어 세부, 튜닝 파라미터 목록 | 05 전체 |
| 11–12 | 4장 Observability Tools, 15장 BPF | 관찰 도구 종류(카운터, 트레이싱, 프로파일링), `/proc`·`/sys` 출처, BPF 도구가 어디에 붙는가(tracepoint, kprobe) | 개별 도구의 전체 옵션 | 06-A, 06-B |

필요할 때 찾아보는 장 (처음부터 읽지 않는다):

- **3장 Operating Systems**: 커널, 프로세스, 시스템 콜, 인터럽트 같은 기초가 막힐 때
- **5장 Applications**: 앱 레벨 프로파일링, 락, GC가 궁금할 때 (02-D~F 이후에 보면 좋다)
- **13장 perf, 14장 Ftrace**: 06-B에서 eBPF 도구로 부족할 때
- **16장 Case Study**: 플랜을 끝내고 마지막에. 실제 장애를 처음부터 끝까지 따라가는 사례라 06-C 게임데이 전에 읽으면 좋다

## 장별 확인 질문

읽고 나서 책을 덮은 상태로 답해본다. 답이 막히면 그 부분만 다시 읽는다.

**2장 Methodologies**
- utilization, saturation, errors를 각각 정의하고, CPU와 메모리에서 각각 무엇으로 측정하는지 말할 수 있는가
- "streetlight anti-method"는 무엇이고, 왜 위험한가. 내가 실무에서 그렇게 한 적이 있는가
- 레이턴시가 어디서 생기는지 드릴다운하는 순서를 설명할 수 있는가

**11장 Cloud Computing**
- 컨테이너 안에서 `top`이나 `free`가 보여주는 값이 왜 오해를 부를 수 있는가
- cgroup의 CPU 제한 방식(shares/weight와 quota)은 각각 언제 효과가 나타나는가
- "noisy neighbor" 문제를 컨테이너 환경에서 어떻게 관찰하는가

**7장 Memory**
- 페이지 캐시 회수와 OOM은 어떤 순서로 일어나는가
- 메모리 포화(saturation)는 어떤 지표로 보는가 (page scanning, PSI, swapping)
- 사용률이 높은 것과 메모리가 부족한 것은 왜 다른 이야기인가

**6장 CPUs**
- 사용률 100%와 포화는 어떻게 다른가. run queue 길이와 run queue latency 중 무엇이 더 좋은 신호인가
- iowait는 왜 CPU 지표로서 오해를 부르는가
- steal time은 무엇이고 클라우드/VM 환경에서 왜 봐야 하는가

**8장 File Systems, 9장 Disks**
- 애플리케이션이 느끼는 파일시스템 레이턴시와 `iostat`의 디스크 레이턴시가 다른 이유
- 디스크 `%util` 100%가 항상 포화를 뜻하지 않는 이유
- write-back 캐시가 성능과 내구성에 각각 주는 영향

**10장 Network**
- 연결이 "느리다"를 연결 수립 지연, 처리량, 재전송, 큐잉으로 나눠서 진단하는 순서
- TCP 백로그(SYN 큐, accept 큐)가 넘치면 클라이언트는 무엇을 보는가
- 처리량은 낮은데 레이턴시가 높은 상황의 원인 후보

**4장 Observability Tools, 15장 BPF**
- 카운터 기반 도구와 트레이싱 도구의 차이, 각각의 오버헤드
- `vmstat`, `iostat`의 숫자는 커널의 어디(`/proc`, `/sys`)에서 오는가
- BPF 도구가 프로덕션에서 비교적 안전하게 쓰일 수 있는 이유와 한계

## 장별 노트

장마다 [BOOK-TEMPLATE.md](notes/BOOK-TEMPLATE.md)를 복사해서 `notes/book-chNN-<제목>.md`로 남긴다. 분량은 한 장당 한 페이지를 넘기지 않는다.
요약이 아니라 **내 말로 다시 쓴 개념 5개 + 실습에서 확인할 것 3개**가 핵심이다.

## 진행 체크리스트

- [ ] 2장 Methodologies
- [ ] 11장 Cloud Computing (OS 가상화 부분)
- [ ] 7장 Memory
- [ ] 6장 CPUs
- [ ] 8장 File Systems
- [ ] 9장 Disks
- [ ] 10장 Network
- [ ] 4장 Observability Tools
- [ ] 15장 BPF
- [ ] 16장 Case Study (06-C 게임데이 전)

## 막힐 때

- 책이 너무 무겁게 느껴지면 Brian Ward, *How Linux Works* (3rd ed.)로 큰 그림을 먼저 잡고 돌아온다. 프로세스, 메모리, 디바이스, 네트워크를 훨씬 가볍게 설명한다.
- 무료 보조 자료: brendangregg.com의 USE Method 페이지와 Linux 성능 도구 다이어그램, Netflix Tech Blog의 "Linux Performance Analysis in 60,000 Milliseconds"
- 다음 단계(선택): Brendan Gregg, *BPF Performance Tools* (2019). 06-B를 더 깊게 가고 싶을 때 해당 자원의 장만 골라 읽는다.
