/*
 * fan-config-store.c: Secure native file-descriptor based configuration store.
 *
 * Implements atomic no-follow writes in a validated private directory
 * to protect against symlink attacks and arbitrary file overwrite vulnerabilities.
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <errno.h>
#include <time.h>

#define CONFIG_FILENAME "fan-curve.json"
#define MAX_CONFIG_SIZE 65536

static int validate_and_open_private_dir(void) {
    const char *xdg = getenv("XDG_CONFIG_HOME");
    const char *home = getenv("HOME");
    char dirpath[4096];

    if (xdg && xdg[0] == '/') {
        if (snprintf(dirpath, sizeof(dirpath), "%s/omarchy", xdg) >= (int)sizeof(dirpath)) {
            return -1;
        }
    } else if (home && home[0] == '/') {
        char parent[4096];
        if (snprintf(parent, sizeof(parent), "%s/.config", home) >= (int)sizeof(parent)) {
            return -1;
        }
        mkdir(parent, 0700);
        if (snprintf(dirpath, sizeof(dirpath), "%s/.config/omarchy", home) >= (int)sizeof(dirpath)) {
            return -1;
        }
    } else {
        return -1;
    }

    /* Ensure directory exists with 0700 permissions */
    mkdir(dirpath, 0700);

    /* Validate directory attributes */
    struct stat st;
    if (lstat(dirpath, &st) != 0) {
        return -1;
    }

    if (!S_ISDIR(st.st_mode) || S_ISLNK(st.st_mode)) {
        return -1;
    }

    uid_t euid = geteuid();
    if (st.st_uid != euid) {
        return -1;
    }

    /* Ensure private directory permissions */
    if ((st.st_mode & 0077) != 0) {
        chmod(dirpath, 0700);
    }

    /* Open directory file descriptor with O_NOFOLLOW */
    int dirfd = open(dirpath, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (dirfd < 0) {
        return -1;
    }

    /* Verify directory file descriptor */
    if (fstat(dirfd, &st) != 0 || !S_ISDIR(st.st_mode) || st.st_uid != euid) {
        close(dirfd);
        return -1;
    }

    return dirfd;
}

static int do_save(int dirfd) {
    char buf[MAX_CONFIG_SIZE];
    size_t total = 0;
    int depth = 0;
    int started = 0;
    int in_string = 0;
    int escape = 0;

    while (total < sizeof(buf) - 1) {
        char c;
        ssize_t n = read(STDIN_FILENO, &c, 1);
        if (n <= 0) {
            break; /* EOF or pipe closed */
        }
        buf[total++] = c;

        if (!started) {
            if (c == '{') {
                started = 1;
                depth = 1;
            }
            continue;
        }

        if (escape) {
            escape = 0;
            continue;
        }
        if (c == '\\') {
            escape = 1;
            continue;
        }
        if (c == '"') {
            in_string = !in_string;
            continue;
        }
        if (!in_string) {
            if (c == '{') depth++;
            else if (c == '}') {
                depth--;
                if (depth == 0) {
                    /* Complete JSON root object parsed */
                    break;
                }
            }
        }
    }

    if (!started || depth != 0 || total == 0) {
        return 1;
    }

    /* Ensure trailing newline */
    if (total < sizeof(buf) - 1 && buf[total - 1] != '\n') {
        buf[total++] = '\n';
    }

    /* Create unique temp file inside the validated directory */
    char tmpfile[128];
    snprintf(tmpfile, sizeof(tmpfile), ".fan-curve.tmp.%d.%u", (int)getpid(), (unsigned int)time(NULL));

    int tmpfd = openat(dirfd, tmpfile, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0600);
    if (tmpfd < 0) {
        return 1;
    }

    size_t written = 0;
    while (written < total) {
        ssize_t w = write(tmpfd, buf + written, total - written);
        if (w <= 0) {
            close(tmpfd);
            unlinkat(dirfd, tmpfile, 0);
            return 1;
        }
        written += (size_t)w;
    }

    if (fsync(tmpfd) != 0) {
        close(tmpfd);
        unlinkat(dirfd, tmpfile, 0);
        return 1;
    }

    close(tmpfd);

    /* If destination is a symlink, unlink it so renameat won't target a symlink */
    struct stat dest_st;
    if (fstatat(dirfd, CONFIG_FILENAME, &dest_st, AT_SYMLINK_NOFOLLOW) == 0) {
        if (S_ISLNK(dest_st.st_mode)) {
            unlinkat(dirfd, CONFIG_FILENAME, 0);
        }
    }

    /* Atomically replace the destination */
    if (renameat(dirfd, tmpfile, dirfd, CONFIG_FILENAME) != 0) {
        unlinkat(dirfd, tmpfile, 0);
        return 1;
    }

    return 0;
}

static int do_load(int dirfd) {
    struct stat st;
    if (fstatat(dirfd, CONFIG_FILENAME, &st, AT_SYMLINK_NOFOLLOW) != 0) {
        return 0; /* File does not exist yet */
    }

    if (S_ISLNK(st.st_mode) || !S_ISREG(st.st_mode)) {
        return 1; /* Symlink or non-regular file rejected */
    }

    int fd = openat(dirfd, CONFIG_FILENAME, O_RDONLY | O_NOFOLLOW | O_CLOEXEC);
    if (fd < 0) {
        return 0;
    }

    char buf[4096];
    ssize_t n;
    while ((n = read(fd, buf, sizeof(buf))) > 0) {
        if (write(STDOUT_FILENO, buf, (size_t)n) != n) {
            close(fd);
            return 1;
        }
    }

    close(fd);
    return 0;
}

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s {save|load}\n", argv[0]);
        return 1;
    }

    int dirfd = validate_and_open_private_dir();
    if (dirfd < 0) {
        fprintf(stderr, "Failed to validate and open private config directory\n");
        return 1;
    }

    int ret = 1;
    if (strcmp(argv[1], "save") == 0) {
        ret = do_save(dirfd);
    } else if (strcmp(argv[1], "load") == 0) {
        ret = do_load(dirfd);
    } else {
        fprintf(stderr, "Unknown action: %s\n", argv[1]);
        ret = 1;
    }

    close(dirfd);
    return ret;
}
