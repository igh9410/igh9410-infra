# linux-lab

Manifests and scripts for the Linux deep-dive plan in [`docs/linux-lab`](../../docs/linux-lab/README.md).

**These labs break things on purpose** (OOM kills, disk fill, PID and conntrack exhaustion).
Run them only inside the lab VM on the desktop (Ubuntu + single-node k3s, see `docs/linux-lab/00-setup.md`), never against the main cluster.

- No ArgoCD Application references this directory, so nothing here is synced automatically.
- Always pass `--context linux-lab` to `kubectl`.

## Layout

```
labs/linux-lab/
├── base/                    # namespace, LimitRange, ResourceQuota (apply once)
├── 01-cgroup-inspect/       # pod spec -> cgroup values on the node
├── 02-memory/
│   ├── kernel-oom/          # cgroup OOM kill (137)
│   ├── page-cache/          # file cache near the limit, no OOM
│   ├── tmpfs-oom/           # memory-backed emptyDir
│   ├── node-heap-oom/       # V8 heap OOM (134) vs Buffer OOM (137)
│   ├── jvm-oom/             # OutOfMemoryError with and without ExitOnOutOfMemoryError
│   └── go-memlimit/         # GOGC vs GOMEMLIMIT under a 128Mi limit
├── 03-cpu-process/
│   ├── cpu-throttle/        # CFS quota throttling
│   ├── pid1-signals/        # SIGTERM handling as PID 1
│   └── zombie/              # unreaped children
├── 04-storage/
│   └── ephemeral-eviction/  # kubelet ephemeral-storage eviction
├── 05-network/
│   └── dns-ndots/           # ndots:5 vs ndots:1
└── host/
    ├── setup-lab-vm.sh      # run inside the lab VM: tools, k3s, linux-lab context, base
    └── tcp-lab.py           # TCP churn / hold generator for TIME_WAIT, port and conntrack labs
```

## Usage

```bash
bash labs/linux-lab/host/setup-lab-vm.sh                                 # once, inside the VM (also applies base)
kubectl --context linux-lab apply -k labs/linux-lab/02-memory/kernel-oom  # one lab at a time
kubectl --context linux-lab delete -k labs/linux-lab/02-memory/kernel-oom # cleanup
```

Each lab kustomization only sets `namespace: linux-lab` and does not include `base`,
so deleting a lab never deletes the namespace.
