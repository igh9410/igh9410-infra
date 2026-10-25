// MODE=heap   grows JS objects on the V8 heap until --max-old-space-size is hit.
// MODE=buffer grows Buffers, which live outside the V8 heap, until the
//             container memory limit is hit.
const mode = process.env.MODE || "heap";
const keep = [];
let mib = 0;

function grow() {
  if (mode === "buffer") {
    // Buffer.alloc with a fill value writes every byte, so the pages really
    // count against the cgroup.
    keep.push(Buffer.alloc(8 * 1024 * 1024, 1));
  } else {
    // An array of 1M doubles is roughly 8MiB of V8 heap.
    keep.push(new Array(1024 * 1024).fill(Math.random()));
  }
  mib += 8;
  const m = process.memoryUsage();
  console.log(
    `mode=${mode} kept~${mib}MiB heapUsed=${(m.heapUsed / 2 ** 20) | 0}MiB ` +
      `external=${(m.external / 2 ** 20) | 0}MiB rss=${(m.rss / 2 ** 20) | 0}MiB`
  );
}

process.on("SIGTERM", () => process.exit(0));
setInterval(grow, 300);
