// memlab keeps a fixed live set in memory and then churns garbage at a steady
// rate, so you can watch how GOGC and GOMEMLIMIT decide when the GC runs.
//
// Without GOMEMLIMIT the heap goal is roughly live set * 2 (GOGC=100), which is
// above the container memory limit, so the kernel OOM-kills the container.
// With GOMEMLIMIT set below the container limit, the GC runs earlier instead.
package main

import (
	"fmt"
	"os"
	"runtime"
	"runtime/debug"
	"strconv"
	"time"
)

const mib = 1 << 20

// touch writes one byte per page so the kernel actually backs the slice with
// physical memory. Freshly mapped pages are zero pages until written, and an
// untouched slice would not show up in RSS or in the cgroup usage.
func touch(b []byte) {
	for i := 0; i < len(b); i += 4096 {
		b[i] = 1
	}
}

func envInt(name string, def int) int {
	if v, err := strconv.Atoi(os.Getenv(name)); err == nil {
		return v
	}
	return def
}

func main() {
	liveMiB := envInt("LIVE_MIB", 70)
	iterations := envInt("ITERATIONS", 0) // 0 = run forever

	live := make([][]byte, 0, liveMiB)
	for i := 0; i < liveMiB; i++ {
		b := make([]byte, mib)
		touch(b)
		live = append(live, b)
	}

	limit := debug.SetMemoryLimit(-1) // -1 reads the current limit without changing it
	fmt.Printf("live set=%dMiB GOGC=%q GOMEMLIMIT=%q effective limit=%dMiB\n",
		liveMiB, os.Getenv("GOGC"), os.Getenv("GOMEMLIMIT"), limit/mib)

	var ms runtime.MemStats
	var peakSys uint64
	var sink []byte
	for i := 1; iterations == 0 || i <= iterations; i++ {
		sink = make([]byte, mib) // becomes garbage on the next iteration
		touch(sink)
		if i%200 == 0 {
			runtime.ReadMemStats(&ms)
			if ms.Sys > peakSys {
				peakSys = ms.Sys
			}
			fmt.Printf("iter=%d heapAlloc=%dMiB heapSys=%dMiB sys=%dMiB peakSys=%dMiB numGC=%d\n",
				i, ms.HeapAlloc/mib, ms.HeapSys/mib, ms.Sys/mib, peakSys/mib, ms.NumGC)
		}
		time.Sleep(time.Millisecond)
	}
	runtime.KeepAlive(live)
	runtime.KeepAlive(sink)
}
