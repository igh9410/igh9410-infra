#!/usr/bin/env python3
"""Small TCP load generator for the Linux lab VM (stdlib only).

  server  accept connections and keep them open until the peer closes.
          --close-first makes the server close right after accepting, so the
          server side ends up holding TIME_WAIT instead of the client.
  churn   open and immediately close connections in a loop (client closes
          first) and report errors such as EADDRNOTAVAIL. With --wait-eof
          the client waits for the server's FIN, so the server closes first.
  hold    open N connections and keep them all open, e.g. to fill the
          conntrack table.

Run it inside a throwaway network namespace when you change sysctls, for
example `sudo ip netns exec porttest python3 tcp-lab.py ...`, so the host's
own settings stay untouched.
"""
import argparse
import errno
import selectors
import signal
import socket
import time


def server(args):
    sel = selectors.DefaultSelector()
    lsock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    lsock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    lsock.bind((args.host, args.port))
    lsock.listen(4096)
    lsock.setblocking(False)
    sel.register(lsock, selectors.EVENT_READ, None)
    print(f"listening on {args.host}:{args.port} close_first={args.close_first}", flush=True)
    open_conns = 0
    while True:
        for key, _ in sel.select():
            if key.data is None:
                conn, _ = lsock.accept()
                if args.close_first:
                    conn.close()
                    continue
                conn.setblocking(False)
                sel.register(conn, selectors.EVENT_READ, "conn")
                open_conns += 1
            else:
                conn = key.fileobj
                if not conn.recv(4096):  # peer closed
                    sel.unregister(conn)
                    conn.close()
                    open_conns -= 1
        if args.verbose:
            print(f"open connections: {open_conns}", flush=True)


def churn(args):
    ok = 0
    errors = {}
    start = time.time()
    for i in range(1, args.count + 1):
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(args.timeout)
        try:
            s.connect((args.host, args.port))
            if args.wait_eof:
                # Wait for the server's FIN before closing, so the server is
                # the side that closes first.
                while s.recv(4096):
                    pass
            ok += 1
        except OSError as e:
            name = errno.errorcode.get(e.errno, str(e)) if e.errno else type(e).__name__
            errors[name] = errors.get(name, 0) + 1
        finally:
            s.close()  # without --wait-eof the client closes first
        if i % args.report == 0:
            print(f"attempts={i} ok={ok} errors={errors}", flush=True)
    print(f"done in {time.time() - start:.1f}s ok={ok} errors={errors}", flush=True)


def hold(args):
    socks = []
    errors = {}
    for i in range(1, args.count + 1):
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(args.timeout)
        try:
            s.connect((args.host, args.port))
            socks.append(s)
        except OSError as e:
            name = errno.errorcode.get(e.errno, str(e)) if e.errno else type(e).__name__
            errors[name] = errors.get(name, 0) + 1
            s.close()
        if i % args.report == 0:
            print(f"attempts={i} open={len(socks)} errors={errors}", flush=True)
    print(f"holding {len(socks)} connections, errors={errors}. Ctrl+C to release.", flush=True)
    # Treat SIGTERM like Ctrl+C so `kill <pid>` also releases the connections.
    signal.signal(signal.SIGTERM, signal.default_int_handler)
    try:
        while True:
            time.sleep(60)
    except KeyboardInterrupt:
        for s in socks:
            s.close()


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    for name in ("server", "churn", "hold"):
        sp = sub.add_parser(name)
        sp.add_argument("--host", default="127.0.0.1")
        sp.add_argument("--port", type=int, default=8080)
        if name == "server":
            sp.add_argument("--close-first", action="store_true")
            sp.add_argument("--verbose", action="store_true")
        else:
            sp.add_argument("--count", type=int, default=1000)
            sp.add_argument("--timeout", type=float, default=2.0)
            sp.add_argument("--report", type=int, default=100)
        if name == "churn":
            sp.add_argument("--wait-eof", action="store_true",
                            help="wait for the server to close first (pair with server --close-first)")
    args = p.parse_args()
    {"server": server, "churn": churn, "hold": hold}[args.cmd](args)


if __name__ == "__main__":
    main()
