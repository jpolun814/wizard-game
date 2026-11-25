"""What the test tools share to run the game so that it comes out the same every time, whatever else the computer is doing.

  * project_copy()  a private copy of the project to run from, brought up to date first: nothing another program writes in the working folder reaches a run under way;
  * run_copies()    starts one or more copies of the game, with a save folder of their own, dice of a given seed (WIZARD_SEED, see scripts/core/steady_run.gd) and
                    frames of a fixed length; several copies talk through a Hub, which lets none of them begin a frame before all have finished the one before;
  * a program is called stuck by the work it has done (seconds of processor time) and never by the clock, so a busy computer makes a run slower and not different.
"""
import os
import shutil
import socket
import struct
import subprocess
import sys
import tempfile
import threading
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get("GODOT", "C:/Users/Jordan Polun/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe")
WINDOWS = sys.platform == "win32"
if WINDOWS and GODOT.endswith("_console.exe") and os.path.exists(GODOT.replace("_console.exe", ".exe")):
    GODOT = GODOT.replace("_console.exe", ".exe")  # (the console program only starts the other one: stopping it left the game itself running)

MOST_WORK = 1500.0   # seconds of processor time a check may use before it is called stuck: far more than any needs
AFTER_ERROR = 60.0   # seconds of processor time it may go on for after a script has failed (it has failed the check already)
MOST_STILL = 180.0   # seconds without using any processor time at all before it is called stuck


# --- A copy of the project ----------------------------------------------------------------------------------------------

LEFT_OUT = {".git", "art_source", "docs", "reports", "build", "__pycache__", ".claude", "android"}
KEPT = "art_source/parts_sheets/reference"  # a check looks at the pictures in this part of what is left out
_held = []  # the lock files this program holds


def base_folder():
    """Where the logs and the copies of this copy of the project (its path, cut short, names it) are kept."""
    import hashlib
    tag = os.path.basename(ROOT) + "_" + hashlib.md5(ROOT.lower().encode()).hexdigest()[:6]
    base = os.path.join(tempfile.gettempdir(), "wizard_checks", tag)
    os.makedirs(base, exist_ok=True)
    return base


def _hold(path):
    """Takes a lock that goes away with this program; False when another program has it."""
    handle = open(path, "a+b")
    try:
        if WINDOWS:
            import msvcrt
            handle.seek(0)
            msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
        else:
            import fcntl
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        handle.close()
        return False
    _held.append(handle)
    return True


def _files(top):
    found = {}
    for folder, names, files in os.walk(top):
        rel = os.path.relpath(folder, top)
        if rel == ".":
            names[:] = [n for n in names if n not in LEFT_OUT and n != ".godot"]
        names[:] = [n for n in names if n != "__pycache__"]
        for name in files:
            path = name if rel == "." else os.path.join(rel, name)
            try:
                state = os.stat(os.path.join(folder, name))
            except OSError:
                continue  # (gone since it was listed)
            found[path] = (state.st_size, int(state.st_mtime))
    for part in (KEPT, "art_source/.gdignore"):
        for name in (sorted(os.listdir(os.path.join(top, part))) if os.path.isdir(os.path.join(top, part)) else [""]):
            path = os.path.normpath(os.path.join(part, name))
            if os.path.isfile(os.path.join(top, path)):
                state = os.stat(os.path.join(top, path))
                found[path] = (state.st_size, int(state.st_mtime))
    return found


def _declares(path):
    """The lines of a script that the editor's list of classes is made from."""
    try:
        with open(path, encoding="utf-8", errors="replace") as text:
            return [line.strip() for line in text if line.startswith(("class_name", "extends", "@tool", "@icon"))]
    except OSError:
        return None


def project_copy():
    """The path of a copy of the project as it is now, which no other run uses while this program lives."""
    base = base_folder()
    k = 0
    while not _hold(os.path.join(base, "copy%d.lock" % k)):
        k += 1
    copy = os.path.join(base, "copy%d" % k)
    ready = os.path.join(base, "copy%d.ready" % k)
    fresh = not os.path.exists(ready)
    os.makedirs(copy, exist_ok=True)
    if fresh:
        shutil.copytree(os.path.join(ROOT, ".godot"), os.path.join(copy, ".godot"), dirs_exist_ok=True, ignore=shutil.ignore_patterns("editor", "shader_cache", "mono"))
    reimport = fresh
    for _ in range(6):  # until nothing has changed while it was being copied
        ours, theirs = _files(copy), _files(ROOT)
        changed = [p for p in theirs if ours.get(p) != theirs[p]]
        gone = [p for p in ours if p not in theirs]
        if not changed and not gone:
            break
        for path in changed:
            source, target = os.path.join(ROOT, path), os.path.join(copy, path)
            if path not in ours or not path.endswith((".gd", ".uid", ".json", ".py", ".md")):
                reimport = True
            elif path.endswith(".gd") and _declares(source) != _declares(target):
                reimport = True
            os.makedirs(os.path.dirname(target), exist_ok=True)
            try:
                shutil.copy2(source, target)
            except OSError:
                pass  # (being written: the next round has it)
        for path in gone:
            reimport = True
            os.remove(os.path.join(copy, path))
    if reimport:
        if os.path.exists(ready):
            os.remove(ready)
        subprocess.run([GODOT, "--headless", "--path", copy, "--import"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, stdin=subprocess.DEVNULL)
    open(ready, "w").close()
    return copy


# --- A job: a program and everything it starts ----------------------------------------------------------------------------

class Job:
    """The programs of one check: all of them stop when it is closed, or when this program ends however it ends; and it knows how much work they have done."""

    def __init__(self):
        self.procs = []
        self.handle = None
        if WINDOWS:
            import ctypes
            from ctypes import wintypes
            self.k32 = ctypes.WinDLL("kernel32", use_last_error=True)
            self.k32.CreateJobObjectW.restype = wintypes.HANDLE
            self.k32.CreateJobObjectW.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
            self.k32.SetInformationJobObject.argtypes = [wintypes.HANDLE, ctypes.c_int, ctypes.c_void_p, wintypes.DWORD]
            self.k32.QueryInformationJobObject.argtypes = [wintypes.HANDLE, ctypes.c_int, ctypes.c_void_p, wintypes.DWORD, ctypes.c_void_p]
            self.k32.AssignProcessToJobObject.argtypes = [wintypes.HANDLE, wintypes.HANDLE]
            self.k32.CloseHandle.argtypes = [wintypes.HANDLE]
            self.handle = self.k32.CreateJobObjectW(None, None)
            limits = (ctypes.c_byte * 144)()  # JOBOBJECT_EXTENDED_LIMIT_INFORMATION
            struct.pack_into("<I", limits, 16, 0x2000)  # LimitFlags: KILL_ON_JOB_CLOSE
            self.k32.SetInformationJobObject(self.handle, 9, limits, 144)

    def start(self, command, env, cwd, log):
        with open(log, "wb") as out:  # (a file, not a pipe: a full pipe stops the program)
            proc = subprocess.Popen(command, stdout=out, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL, env=env, cwd=cwd, creationflags=0x4000 if WINDOWS else 0)
        if self.handle:
            self.k32.AssignProcessToJobObject(self.handle, int(proc._handle))
        self.procs.append(proc)
        return proc

    def work(self):
        """Seconds of processor time used so far."""
        if self.handle:
            import ctypes
            info = (ctypes.c_byte * 48)()  # JOBOBJECT_BASIC_ACCOUNTING_INFORMATION
            self.k32.QueryInformationJobObject(self.handle, 1, info, 48, None)
            user, kernel = struct.unpack_from("<qq", info, 0)
            return (user + kernel) / 1e7
        total = 0.0
        for proc in self.procs:
            try:
                fields = open("/proc/%d/stat" % proc.pid).read().rsplit(")", 1)[1].split()
                total += (int(fields[11]) + int(fields[12])) / os.sysconf("SC_CLK_TCK")
            except (OSError, IndexError):
                pass
        return total

    def close(self):
        for proc in self.procs:
            if proc.poll() is None:
                proc.kill()
        if self.handle:
            self.k32.CloseHandle(self.handle)
            self.handle = None
        for proc in self.procs:
            proc.wait()


# --- Copies that talk to each other -----------------------------------------------------------------------------------------

class Hub:
    """Where the copies of a network check meet at the end of every frame. Each sends what it has to say and waits; when all have, each is sent what all of them said.
    The place is one the system picks, on this computer only. A copy that has gone is left out from then on, and the others are told."""

    def __init__(self, copies):
        self.copies = copies
        self.listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.listener.bind(("127.0.0.1", 0))
        self.listener.listen(copies)
        self.port = self.listener.getsockname()[1]
        self.frames = 0
        threading.Thread(target=self._run, daemon=True).start()

    def _run(self):
        lines = {}
        try:
            while len(lines) < self.copies:
                line, _ = self.listener.accept()
                line.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
                number = self._read(line, 4)
                if number is not None:
                    lines[struct.unpack("<I", number)[0]] = line
            while lines:
                said = {}
                for copy in sorted(lines):
                    head = self._read(lines[copy], 4)
                    body = self._read(lines[copy], struct.unpack("<I", head)[0]) if head is not None else None
                    if body is None:
                        lines.pop(copy).close()
                    else:
                        said[copy] = body
                answer = b"".join(struct.pack("<II", copy, len(said[copy])) + said[copy] for copy in sorted(said))
                for copy in list(lines):
                    try:
                        lines[copy].sendall(struct.pack("<I", len(answer)) + answer)
                    except OSError:
                        pass  # (found gone at the next frame)
                self.frames += 1
        except OSError:
            pass
        finally:
            for line in lines.values():
                line.close()

    @staticmethod
    def _read(line, count):
        data = b""
        while len(data) < count:
            try:
                part = line.recv(count - len(data))
            except OSError:
                return None
            if not part:
                return None
            data += part
        return data

    def close(self):
        self.listener.close()


# --- Running the game -------------------------------------------------------------------------------------------------------

def environment(folder, name, seed, trace=""):
    """What a copy of the game is told: the dice's seed, and a save folder that is its own and empty."""
    home = os.path.join(folder, "home", name)
    shutil.rmtree(home, ignore_errors=True)
    os.makedirs(home)
    env = dict(os.environ, WIZARD_CHECK="1", WIZARD_SEED=str(seed))
    for left in ("WIZARD_PORT", "WIZARD_HUB", "WIZARD_COPY", "WIZARD_HURRY", "WIZARD_TRACE"):
        env.pop(left, None)
    env["APPDATA" if WINDOWS else "XDG_DATA_HOME"] = home
    if trace:
        env["WIZARD_TRACE"] = trace
    return env


def begin(job, command, env, project, log):
    """Starts a copy. Windows now and then cannot load the program at all (it ends at once, with an error of the loader's and without the engine's first line): none of
    the game has run then, so it is started again. A copy that has printed anything is never started again, however it ends."""
    for attempt in range(5):
        proc = job.start(command, env, project, log)
        try:
            proc.wait(0.5)
        except subprocess.TimeoutExpired:
            return
        if proc.returncode in (0, 1) or os.path.getsize(log) > 0 or attempt == 4:
            return
        job.procs.remove(proc)


def run_copies(commands, folder, name, project, seed, trace="", extra=None, lasting=(), most_work=MOST_WORK):
    """Runs the commands (one a copy) to their end. Returns (the exit code of each, what each printed, why they were stopped or "", seconds). A copy whose number is in
    `lasting` (a server) is stopped when all the others have ended, and its exit code is 0."""
    job, hub = Job(), Hub(len(commands)) if len(commands) > 1 else None
    started = time.time()
    logs, homes, stuck = [], [], ""
    try:
        for k, command in enumerate(commands):
            part = name if len(commands) == 1 else "%s_%d" % (name, k)
            env = environment(folder, part, seed, trace if len(commands) == 1 or not trace else "%s.%d" % (trace, k))
            env.update(extra or {})
            homes.append(os.path.join(folder, "home", part))
            if hub:
                env.update(WIZARD_HUB=str(hub.port), WIZARD_COPY=str(k))
            logs.append(os.path.join(folder, "out_%s.txt" % part))
            begin(job, command, env, project, logs[-1])
        worked, moved_at, looked_at, broke_at = 0.0, time.time(), time.time(), 0.0
        while any(proc.poll() is None for k, proc in enumerate(job.procs) if k not in lasting):
            time.sleep(0.05)
            if time.time() - looked_at < 2.0:
                continue
            looked_at = time.time()
            work = job.work()
            if work - worked > 0.05:
                worked, moved_at = work, looked_at
            if not broke_at and any(b"SCRIPT ERROR" in open(path, "rb").read() for path in logs):
                broke_at = work  # (a script that failed may have been the check itself, which then never ends)
            if broke_at and work > broke_at + AFTER_ERROR:
                stuck = "stuck: a script failed, and it did not end"
            elif work > most_work:
                stuck = "stuck: it has used %.0f seconds of processor time" % work
            elif looked_at - moved_at > MOST_STILL:
                stuck = "stuck: it has stood still, waiting for something that does not come"
            if stuck:
                break
        codes = [proc.poll() for proc in job.procs]
    finally:
        job.close()
        if hub:
            hub.close()
    codes = [0 if k in lasting and not stuck else (124 if code is None else code) for k, code in enumerate(codes)]
    texts = []
    for path in logs:
        with open(path, "rb") as text:
            texts.append(text.read().decode("utf-8", "replace").replace("\r\n", "\n"))
        os.remove(path)
    for home in homes:
        shutil.rmtree(home, ignore_errors=True)
    return codes, texts, stuck, time.time() - started
