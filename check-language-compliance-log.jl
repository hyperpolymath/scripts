#!/usr/bin/env julia
# SPDX-License-Identifier: MPL-2.0
# POSIX descriptor-based logger for check-language-compliance.sh.

using Base.Filesystem: JL_O_RDONLY, JL_O_WRONLY, JL_O_CREAT, JL_O_DIRECTORY,
    JL_O_NOFOLLOW, JL_O_NONBLOCK, JL_O_CLOEXEC

"""
Open `name` relative to directory descriptor `dirfd` using POSIX `flags` and
return a file descriptor that the caller must close. Absolute names ignore
`dirfd`. When creating a file, `mode` specifies permissions subject to the umask.
Throw a `SystemError` if the operating system rejects the open.
"""
function openat(dirfd, name, flags, mode=0o600)
    result = ccall(:openat, Cint, (Cint, Cstring, Cint, Cuint), dirfd, name, flags, mode)
    Base.systemerror("openat $name", result == -1)
    return result
end

"""
Create or truncate a private report and return a writable stream for the caller
to close. `state_dir` is the full, absolute report directory, normally ending in
`scripts/language-compliance`; `log_name` uses eight digits followed by `.log`
(the calendar date is not validated).

Create missing directories with mode `0700`, subject to the umask, and set the
final directory to `0700`. Reject `.` and `..` components and directory symlinks;
the final three directory components must belong to the invoking user. The log
must be a regular file owned by that user with one hard link, and must not be a
symlink. Set its mode to `0600` and truncate it only after validation.

Throw on invalid arguments or unsafe paths/files, and propagate errors from
opening, inspecting, changing permissions or truncating. Directory creation and
permission changes may remain after failure; no fallback log is returned.
"""
function private_log(state_dir, log_name)
    isabspath(state_dir) || error("state directory must be absolute")
    occursin(r"^[0-9]{8}\.log$", log_name) || error("invalid log name")
    uid = ccall(:getuid, Cuint, ())
    dirflags = JL_O_RDONLY | JL_O_DIRECTORY | JL_O_NOFOLLOW | JL_O_CLOEXEC
    # Start at / and walk every component through its open parent. No directory
    # symlinks are accepted, including in XDG_STATE_HOME and HOME.
    dirfd = ccall(:open, Cint, (Cstring, Cint), "/", dirflags)
    Base.systemerror("open /", dirfd == -1)
    try
        parts = split(state_dir, '/'; keepempty=false)
        for (index, part) in enumerate(parts)
            part in (".", "..") && error("state directory must not contain . or ..")
            # mkdirat applies 0700 at creation, without a permissive interval.
            # If it already exists, openat and fstat below validate the object.
            ccall(:mkdirat, Cint, (Cint, Cstring, Cuint), dirfd, part, 0o700)
            nextfd = openat(dirfd, part, dirflags)
            ccall(:close, Cint, (Cint,), dirfd)
            dirfd = nextfd
            # The state base, scripts and language-compliance must be ours;
            # system ancestors such as /home may belong to root.
            if index >= length(parts) - 2
                stat(RawFD(dirfd)).uid == uid || error("state directory is not owned by invoking user")
            end
        end
        Base.systemerror("fchmod state directory", ccall(:fchmod, Cint, (Cint, Cuint), dirfd, 0o700) == -1)
        # Do not truncate until the opened inode has passed validation. NONBLOCK
        # prevents a planted FIFO from hanging the process before fstat.
        logfd = openat(dirfd, log_name, JL_O_WRONLY | JL_O_CREAT | JL_O_NOFOLLOW | JL_O_NONBLOCK | JL_O_CLOEXEC)
        log = Base.fdio(logfd, true)
        try
            info = stat(log)
            isfile(info) && info.uid == uid && info.nlink == 1 || error("unsafe log file")
            Base.systemerror("fchmod log", ccall(:fchmod, Cint, (Cint, Cuint), logfd, 0o600) == -1)
            truncate(log, 0)
            return log
        catch
            close(log)
            rethrow()
        end
    finally
        ccall(:close, Cint, (Cint,), dirfd)
    end
end

try
    length(ARGS) == 2 || error("expected state directory and dated log name")
    log = private_log(ARGS...)
    try
        while !eof(stdin)
            data = readavailable(stdin)
            write(log, data) == length(data) || error("incomplete log write")
            flush(log)
            write(stdout, data)
            flush(stdout)
        end
    finally
        close(log)
    end
catch err
    println(stderr, "Language compliance logging failed: ", sprint(showerror, err))
    exit(1)
end
