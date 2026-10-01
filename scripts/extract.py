#!/usr/bin/env python3
"""Extract the commands of each LFS book page into one shell file per page.

Usage: extract.py <book dir> <wget-list> <output dir>
"""
import html
import os
import re
import sys

book, wget_list, out = sys.argv[1:4]
tarballs = [l.strip().rsplit("/", 1)[1] for l in open(wget_list) if l.strip()]
tarballs = [t for t in tarballs if not t.endswith(".patch")]

tarballs = [t for t in tarballs if "html" not in t]


def norm(s):
    return re.sub(r"[^a-z0-9]", "", s.lower())


def tarball(title):
    # "Binutils-2.45 - Pass 1" and "Udev from Systemd-257.8" name the package
    # in the first and in the last word.
    word = title.split()[-1] if " from " in title else title.split()[0]
    hits = [t for t in tarballs if norm(t).startswith(norm(word))]
    return hits[0] if len(hits) == 1 else ""


# Pages that build.sh does by hand, or that hold examples only.
SKIP_PAGE = ("changingowner", "kernfs", "chroot", "chapter07-cleanup", "pkgmgt")
# Test suites and interactive commands. A block that matches is not written.
DROP = re.compile(
    r"make\b[^\n]*\b(check|check-root|test|tests|test_harness)\b"
    r"|su tester|chown -R tester|groupadd -g 102 dummy|groupdel dummy"
    r"|tests/run\.sh|Timed out|\^FAIL:|test_summary|gmp-check-log|ABI=32"
    r"|tzselect|vim -c|exec /usr/bin/bash")
# Placeholders in the book, and the value this build uses.
REPLACE = (("/usr/share/zoneinfo/<xxx>", "/usr/share/zoneinfo/Asia/Dubai"),
           ("PAGE=<paper_size>", "PAGE=A4"),
           # The profile run of Python fails on one test in the chroot.
           ("            --enable-optimizations \\\n", ""),
           ("passwd root", 'echo "root:$LFS_PASSWORD" | chpasswd'))

# The index page does not list every page. The "next" links do.
pages = []
page = "chapter05/introduction.html"
while not page.startswith("chapter09"):
    if re.match(r"chapter0[5-8]/", page):
        pages.append(page)
    text = open(os.path.join(book, page), encoding="utf-8").read()
    nxt = re.search(r'<li class="next">\s*<a[^>]*href="([^"]+)"', text).group(1)
    page = os.path.normpath(os.path.join(os.path.dirname(page), nxt))
os.makedirs(out, exist_ok=True)
for n, page in enumerate(pages):
    text = open(os.path.join(book, page), encoding="utf-8").read()
    title = html.unescape(re.sub(r"<[^>]+>", "", re.search(
        r"<h1[^>]*>(.*?)</h1>", text, re.S).group(1)))
    title = " ".join(title.split())
    title = re.sub(r"^\d+\.\d+\.\s*", "", title)
    cmds = re.findall(r'<pre class="userinput">(.*?)</pre>', text, re.S)
    cmds = [html.unescape(re.sub(r"<[^>]+>", "", c)) for c in cmds]
    name = "%03d-%s.sh" % (n, page[:-5].replace("/", "-"))
    cmds = [c for c in cmds if not DROP.search(c)]
    for old, new in REPLACE:
        cmds = [c.replace(old, new) for c in cmds]
    if not cmds or any(k in name for k in SKIP_PAGE):
        continue
    with open(os.path.join(out, name), "w") as f:
        f.write("# title: %s\n# tarball: %s\n" % (title, tarball(title)))
        f.write("\n\n".join(cmds) + "\n")
