#!/usr/bin/env python3
"""Minimal DAP client used by smoke tests. Verifies a REAL debug session:
launch -> breakpoint hit -> stack -> local variable value -> step over -> continue -> terminated.

usage: dap_smoke.py CONFIG.json   (see tests/test.sh for generated configs)
config keys: transport(stdio|tcp), cmd[], launch{}, bp_file, bp_line, expect_var, expect_value(optional), cwd
"""
import json, os, queue, re, socket, subprocess, sys, threading, time

cfg = json.load(open(sys.argv[1]))
TIMEOUT = float(cfg.get("timeout", 60))

class Dap:
    def __init__(self, rfile, wfile):
        self.r, self.w, self.seq, self.events, self.pending = rfile, wfile, 0, [], {}
        self.q = queue.Queue()
        threading.Thread(target=self._pump, daemon=True).start()
    def _pump(self):
        try:
            while True:
                length = None
                while True:
                    line = self.r.readline()
                    if not line: self.q.put(None); return
                    line = line.strip()
                    if not line: break
                    if line.lower().startswith(b"content-length:"): length = int(line.split(b":")[1])
                self.q.put(json.loads(self.r.read(length)))
        except Exception: self.q.put(None)
    def _write(self, msg):
        data = json.dumps(msg).encode()
        self.w.write(b"Content-Length: %d\r\n\r\n" % len(data) + data); self.w.flush()
    def send(self, command, arguments=None):
        self.seq += 1
        self._write({"seq": self.seq, "type": "request", "command": command, "arguments": arguments or {}})
        return self.seq
    def _read(self, timeout=1.0):
        try: msg = self.q.get(timeout=timeout)
        except queue.Empty: return
        if msg is None: raise EOFError("adapter closed connection")
        if msg["type"] == "response": self.pending[msg["request_seq"]] = msg
        elif msg["type"] == "event": self.events.append(msg)
        elif msg["type"] == "request":  # reverse request (e.g. runInTerminal) - unsupported
            self.seq += 1
            self._write({"seq": self.seq, "type": "response", "request_seq": msg["seq"], "success": False, "command": msg["command"], "message": "unsupported"})
    def response(self, seq, timeout=TIMEOUT):
        end = time.time() + timeout
        while seq not in self.pending:
            if time.time() > end: raise TimeoutError(f"no response to request {seq}; events={[e['event'] for e in self.events]}")
            self._read()
        return self.pending.pop(seq)
    def event(self, name, timeout=TIMEOUT):
        end = time.time() + timeout
        while True:
            for i, e in enumerate(self.events):
                if e["event"] == name: return self.events.pop(i)
            if time.time() > end: raise TimeoutError(f"no '{name}' event; events={[(e['event'], e.get('body',{}).get('output')) for e in self.events]} responses={list(self.pending.values())}")
            self._read()

def ok(label): print(f"  ok   {label}")
def die(label, detail=""):
    print(f"  FAIL {label} {detail}"); sys.exit(1)

proc = None; sock = None
try:
    if cfg["transport"] == "stdio":
        proc = subprocess.Popen(cfg["cmd"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, cwd=cfg.get("cwd"))
        dap = Dap(proc.stdout, proc.stdin)
    else:
        port = int(cfg.get("port", 38697))
        proc = subprocess.Popen([c.replace("${port}", str(port)) for c in cfg["cmd"]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, cwd=cfg.get("cwd"))
        for _ in range(100):
            try: sock = socket.create_connection(("127.0.0.1", port), timeout=1); break
            except OSError: time.sleep(0.1)
        else: die("connect to adapter")
        sock.settimeout(None)
        dap = Dap(sock.makefile("rb"), sock.makefile("wb"))

    r = dap.response(dap.send("initialize", {"clientID": "devenv-smoke", "adapterID": cfg.get("adapterID", "smoke"), "linesStartAt1": True, "columnsStartAt1": True, "pathFormat": "path", "supportsRunInTerminalRequest": False}))
    if not r["success"]: die("initialize", r)
    ok("adapter initialize")

    launch_seq = dap.send(cfg.get("request", "launch"), cfg["launch"])
    dap.event("initialized"); ok("initialized event")
    if cfg.get("bp_file"):
        bp = dap.response(dap.send("setBreakpoints", {"source": {"path": cfg["bp_file"]}, "breakpoints": [{"line": cfg["bp_line"]}]}))
        if not bp["success"]: die("setBreakpoints", bp)
        ok(f"setBreakpoints {os.path.basename(cfg['bp_file'])}:{cfg['bp_line']} verified={bp['body']['breakpoints'][0].get('verified')}")
    if cfg.get("exception_filters"):
        ex = dap.response(dap.send("setExceptionBreakpoints", {"filters": cfg["exception_filters"]}))
        if not ex["success"]: die("setExceptionBreakpoints", ex)
        ok(f"setExceptionBreakpoints {cfg['exception_filters']}")
    dap.response(dap.send("configurationDone"))
    stopped = dap.event("stopped"); ok(f"stopped (reason={stopped['body'].get('reason')})")
    if cfg.get("expect_reason") and stopped["body"].get("reason") != cfg["expect_reason"]: die("stop reason", stopped["body"])
    tid = stopped["body"].get("threadId", 1)

    st = dap.response(dap.send("stackTrace", {"threadId": tid, "levels": 20}))["body"]["stackFrames"]
    if not st: die("stackTrace empty")
    ok("call stack: " + " <- ".join(f["name"] for f in st[:4]))
    top = st[0]
    if cfg.get("expect_frame") and cfg["expect_frame"] not in top["name"]: die("top frame", f"{top['name']!r} lacks {cfg['expect_frame']!r}")

    scopes = dap.response(dap.send("scopes", {"frameId": top["id"]}))["body"]["scopes"]
    found = {}
    for sc in scopes:
        vs = dap.response(dap.send("variables", {"variablesReference": sc["variablesReference"]}))["body"]["variables"]
        for v in vs: found[v["name"]] = v["value"]
    ok(f"locals/args: { {k: found[k] for k in list(found)[:6]} }")
    name = cfg["expect_var"]
    if name not in found: die(f"variable {name!r} visible", f"have {list(found)}")
    if "expect_value" in cfg and not re.fullmatch(cfg["expect_value"], found[name]): die(f"value of {name}", f"{found[name]!r} !~ {cfg['expect_value']!r}")
    ok(f"variable {name} = {found[name]}")

    if cfg.get("evaluate"):
        ev = dap.response(dap.send("evaluate", {"expression": cfg["evaluate"]["expr"], "frameId": top["id"], "context": "repl"}))
        if not ev["success"] or not re.fullmatch(cfg["evaluate"]["match"], ev["body"]["result"]): die("evaluate", ev)
        ok(f"evaluate {cfg['evaluate']['expr']} = {ev['body']['result']}")

    if not cfg.get("skip_step"):  # an unhandled-exception stop cannot be stepped
        dap.response(dap.send("next", {"threadId": tid})); dap.event("stopped"); ok("step over -> stopped again")
    dap.send("continue", {"threadId": tid})
    # session ends either via terminated or exited
    end = time.time() + TIMEOUT
    while time.time() < end:
        names = [e["event"] for e in dap.events]
        if "terminated" in names or "exited" in names: break
        # a loop may hit the breakpoint again: keep continuing
        if "stopped" in names:
            e = dap.event("stopped"); dap.send("continue", {"threadId": e["body"].get("threadId", tid)})
        dap._read()
    else: die("session end")
    ok("continue -> program terminated")
    try: dap.send("disconnect", {})
    except Exception: pass
    print("DAP SMOKE PASS"); sys.exit(0)
except SystemExit: raise
except Exception as e:
    print(f"  FAIL exception: {type(e).__name__}: {e}"); sys.exit(1)
finally:
    if proc and proc.poll() is None: proc.kill()
