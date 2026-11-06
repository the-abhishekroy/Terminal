#!/usr/bin/env python3
"""
Build Cli's bootstrap: take the upstream Termux aarch64 bootstrap, add proot (+deps),
and rewrite the hardcoded app path /data/data/com.termux -> /data/data/<NEW> in every
file (same length, so binaries stay valid). Output: app/src/main/cpp/bootstrap-aarch64.zip
usage: make-bootstrap.py <out.zip> [cache_dir]
"""
import hashlib, io, lzma, os, re, sys, tarfile, urllib.request, zipfile

OLD = b"com.termux"
NEW = b"app.clipod"
assert len(OLD) == len(NEW)
BOOT_URL = "https://github.com/termux/termux-packages/releases/download/bootstrap-2026.02.12-r1%2Bapt.android-7/bootstrap-aarch64.zip"
BOOT_SHA = "ea2aeba8819e517db711f8c32369e89e7c52cee73e07930ff91185e1ab93f4f3"
REPO = "https://packages-cf.termux.dev/apt/termux-main/"
EXTRA = ["proot",                          # kept for optional use
         "nodejs-lts", "npm", "libc++",    # Claude Code runs on native Node (no proot: it froze there)
         "git", "openssh", "ripgrep"]      # what Claude Code needs
PROVIDED = {"nodejs"}                      # nodejs-lts satisfies npm's dependency
FORCE_UPDATE = {"libc++"}                  # bootstrap ships an older libc++ than nodejs-lts needs
PATH_OLD = b"/data/data/" + OLD
PATH_NEW = b"/data/data/" + NEW

out = sys.argv[1]
cache = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(out), ".bootstrap-cache")
os.makedirs(cache, exist_ok=True)

def fetch(url, dest):
    if not os.path.exists(dest):
        print("download", url)
        import subprocess
        subprocess.check_call(["curl", "-fSL", "--retry", "3", "-A", "cli-bootstrap-builder", "-o", dest + ".tmp", url])
        os.rename(dest + ".tmp", dest)
    return dest

def sha256(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""): h.update(b)
    return h.hexdigest()

boot = fetch(BOOT_URL, os.path.join(cache, "bootstrap-upstream.zip"))
assert sha256(boot) == BOOT_SHA, "bootstrap checksum mismatch"
zin = zipfile.ZipFile(boot)

# --- package index
idx = fetch(REPO + "dists/stable/main/binary-aarch64/Packages", os.path.join(cache, "Packages")).__str__()
pk = {}
for blk in open(idx, encoding="utf-8").read().split("\n\n"):
    m = re.search(r"^Package: (.+)$", blk, re.M)
    if m: pk[m.group(1)] = blk
field = lambda b, k: (re.search(r"^%s: (.*)$" % k, b, re.M) or [None, ""])[1]

status_text = zin.read("var/lib/dpkg/status").decode() if "var/lib/dpkg/status" in zin.namelist() else ""
installed = (set(re.findall(r"^Package: (.+)$", status_text, re.M)) | PROVIDED) - FORCE_UPDATE
need, queue = [], list(EXTRA)
while queue:
    n = queue.pop(0)
    if n in installed or n in need or n not in pk: continue
    need.append(n)
    for dep in field(pk[n], "Depends").split(","):
        dep = dep.split("|")[0].strip().split(" ")[0]
        if dep: queue.append(dep)
print("adding packages:", need)

def ar_members(data):
    assert data[:8] == b"!<arch>\n"
    i = 8
    while i < len(data):
        name = data[i:i+16].decode().strip(); size = int(data[i+48:i+58]); i += 60
        yield name, data[i:i+size]
        i += size + (size & 1)

def patch(b):
    return b.replace(PATH_OLD, PATH_NEW)

files, links, modes = {}, [], {}
exec_paths = set()   # files that must be executable (the app installer only chmods bin/ and libexec/)
for info in zin.infolist():
    if info.filename == "SYMLINKS.txt": continue
    if info.is_dir(): continue
    files[info.filename] = zin.read(info.filename)
syms = {}   # destination -> target; later packages win, and a name is either a file or a symlink, never both
for ln in zin.read("SYMLINKS.txt").decode().splitlines():
    t, d = ln.split("←"); d = d[2:] if d.startswith("./") else d; syms[d] = t

for n in need:
    deb = fetch(REPO + field(pk[n], "Filename"), os.path.join(cache, os.path.basename(field(pk[n], "Filename"))))
    assert sha256(deb) == field(pk[n], "SHA256"), "checksum mismatch " + n
    for name, blob in ar_members(open(deb, "rb").read()):
        if not name.startswith("data.tar"): continue
        tf = tarfile.open(fileobj=io.BytesIO(lzma.decompress(blob) if name.endswith(".xz") else blob))
        for m in tf.getmembers():
            p = m.name.lstrip("./")
            pre = "data/data/com.termux/files/usr/"
            if not p.startswith(pre): continue
            rel = p[len(pre):]
            if not rel: continue
            if m.issym():
                syms[rel] = m.linkname; files.pop(rel, None)
            elif m.isfile():
                files[rel] = tf.extractfile(m).read(); syms.pop(rel, None)
                if m.mode & 0o111 and not rel.startswith(("bin/", "libexec/")): exec_paths.add(rel)

# --- Cli branding: no Termux welcome text, silent second stage
files["etc/motd"] = b""
files["etc/motd.sh"] = b"#!/bin/sh\n"
fb = "etc/profile.d/01-termux-bootstrap-second-stage-fallback.sh"
t = files[fb].decode()
t = t.replace('echo "Starting fallback run of termux bootstrap second stage"', ':')
t = t.replace('second-stage.sh" || exit $?\n\tfi', 'second-stage.sh" >/dev/null 2>&1 || exit $?\n\tfi')
assert ">/dev/null 2>&1" in t
files[fb] = t.encode()

# --- tell dpkg about the packages we added
stanzas = ""
for n in need:
    stanzas += "Package: %s\nStatus: install ok installed\nArchitecture: aarch64\nVersion: %s\nDescription: bundled by Terminal\n\n" % (n, field(pk[n], "Version"))
sd = "var/lib/dpkg/status"
base = files.get(sd, b"").decode()
for n in FORCE_UPDATE:   # drop the old stanza of packages we replace
    base = re.sub(r"(?ms)^Package: %s\n.*?(?:\n\n|\Z)" % re.escape(n), "", base)
if base and not base.endswith("\n\n"): base += "\n"
files[sd] = (base + stanzas).encode()

# --- make sure the app's installer can create every symlink (it aborts on the first failure): dry-run in a temp dir
import tempfile, shutil
def dry_run():
    tmp = tempfile.mkdtemp(); bad = []
    try:
        for n in files:
            q = os.path.join(tmp, n); os.makedirs(os.path.dirname(q), exist_ok=True); open(q, "wb").close()
        for d, t in syms.items():
            q = os.path.join(tmp, d); os.makedirs(os.path.dirname(q), exist_ok=True)
            try: os.symlink(t, q)
            except OSError: bad.append(d)
    finally: shutil.rmtree(tmp)
    return bad
for _ in range(5):
    bad = dry_run()
    if not bad: break
    print("dropping %d conflicting symlink(s): %s" % (len(bad), bad[:3]))
    for d in bad: syms.pop(d, None)

files["etc/terminal-exec.list"] = ("\n".join(sorted(exec_paths)) + "\n").encode()

# --- patch + write
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zo:
    for name, data in files.items():
        zo.writestr(name, patch(data))
    zo.writestr("SYMLINKS.txt", patch("\n".join("%s←%s" % (t, d) for d, t in syms.items()).encode() + b"\n"))
left = sum(1 for d in files.values() if PATH_OLD in patch(d))
print("wrote", out, os.path.getsize(out), "bytes; %d files; leftover old paths: %d" % (len(files), left))
