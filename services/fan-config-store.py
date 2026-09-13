#!/usr/bin/env python3
"""
fan-config-store.py: Secure native FD-based configuration store helper.
Implements atomic no-follow writes in a validated private directory.
"""

import sys
import os
import stat
import time

CONFIG_FILENAME = "fan-curve.json"
MAX_CONFIG_SIZE = 65536

def validate_and_open_private_dir():
    xdg = os.environ.get("XDG_CONFIG_HOME")
    home = os.environ.get("HOME")

    if xdg and xdg.startswith("/"):
        dirpath = os.path.join(xdg, "omarchy")
    elif home and home.startswith("/"):
        parent = os.path.join(home, ".config")
        try:
            os.makedirs(parent, mode=0o700, exist_ok=True)
        except OSError:
            pass
        dirpath = os.path.join(parent, "omarchy")
    else:
        return -1

    try:
        os.makedirs(dirpath, mode=0o700, exist_ok=True)
    except OSError:
        pass

    try:
        st = os.lstat(dirpath)
    except OSError:
        return -1

    if not stat.S_ISDIR(st.st_mode) or stat.S_ISLNK(st.st_mode):
        return -1

    euid = os.geteuid()
    if st.st_uid != euid:
        return -1

    if (st.st_mode & 0o077) != 0:
        try:
            os.chmod(dirpath, 0o700)
        except OSError:
            pass

    try:
        flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_CLOEXEC", 0)
        dirfd = os.open(dirpath, flags)
    except OSError:
        return -1

    try:
        st = os.fstat(dirfd)
        if not stat.S_ISDIR(st.st_mode) or st.st_uid != euid:
            os.close(dirfd)
            return -1
    except OSError:
        os.close(dirfd)
        return -1

    return dirfd

def do_save(dirfd):
    chars = []
    started = False
    depth = 0
    in_string = False
    escape = False

    while len(chars) < MAX_CONFIG_SIZE:
        ch = sys.stdin.read(1)
        if not ch:
            break
        chars.append(ch)

        if not started:
            if ch == '{':
                started = True
                depth = 1
            continue

        if escape:
            escape = False
            continue
        if ch == '\\':
            escape = True
            continue
        if ch == '"':
            in_string = not in_string
            continue
        if not in_string:
            if ch == '{':
                depth += 1
            elif ch == '}':
                depth -= 1
                if depth == 0:
                    break

    if not started or depth != 0 or not chars:
        return 1

    if chars[-1] != '\n':
        chars.append('\n')

    raw = "".join(chars).encode("utf-8")
    tmpfile = f".fan-curve.tmp.{os.getpid()}.{int(time.time())}"

    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_CLOEXEC", 0)
    try:
        tmpfd = os.open(tmpfile, flags, 0o600, dir_fd=dirfd)
    except OSError:
        return 1

    try:
        os.write(tmpfd, raw)
        os.fsync(tmpfd)
    except OSError:
        os.close(tmpfd)
        try:
            os.unlink(tmpfile, dir_fd=dirfd)
        except OSError:
            pass
        return 1
    finally:
        try:
            os.close(tmpfd)
        except OSError:
            pass

    # Unlink if destination is currently a symlink
    try:
        dest_st = os.stat(CONFIG_FILENAME, dir_fd=dirfd, follow_symlinks=False)
        if stat.S_ISLNK(dest_st.st_mode):
            os.unlink(CONFIG_FILENAME, dir_fd=dirfd)
    except OSError:
        pass

    try:
        os.replace(tmpfile, CONFIG_FILENAME, src_dir_fd=dirfd, dst_dir_fd=dirfd)
    except OSError:
        try:
            os.unlink(tmpfile, dir_fd=dirfd)
        except OSError:
            pass
        return 1

    return 0

def do_load(dirfd):
    try:
        dest_st = os.stat(CONFIG_FILENAME, dir_fd=dirfd, follow_symlinks=False)
        if stat.S_ISLNK(dest_st.st_mode) or not stat.S_ISREG(dest_st.st_mode):
            return 1
    except OSError:
        return 0  # File does not exist yet

    try:
        flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_CLOEXEC", 0)
        fd = os.open(CONFIG_FILENAME, flags, dir_fd=dirfd)
    except OSError:
        return 0

    try:
        with open(fd, "r", encoding="utf-8", closefd=True) as f:
            sys.stdout.write(f.read())
            sys.stdout.flush()
    except OSError:
        return 1

    return 0

def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ("save", "load"):
        sys.stderr.write(f"Usage: {sys.argv[0]} {{save|load}}\n")
        sys.exit(1)

    dirfd = validate_and_open_private_dir()
    if dirfd < 0:
        sys.stderr.write("Failed to validate and open private config directory\n")
        sys.exit(1)

    try:
        if sys.argv[1] == "save":
            code = do_save(dirfd)
        else:
            code = do_load(dirfd)
    finally:
        os.close(dirfd)

    sys.exit(code)

if __name__ == "__main__":
    main()
