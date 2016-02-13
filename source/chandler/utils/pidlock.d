module chandler.utils.pidlock;

import std.conv : text, to;
import std.file : exists, readText, remove, write;
import std.process : thisProcessID;

class PIDLockedException : Exception {
    this(in int pid) {
        super("Locked by existing process with ID " ~ text(pid));
    }
}

private bool processExists(int pid) {
    version (Posix) {
        import core.sys.posix.signal : kill;

        return kill(pid, 0) == 0;
    }
    else version (Windows) {
        import core.sys.windows.winbase : CloseHandle, GetExitCodeProcess, OpenProcess, STILL_ACTIVE;
        import core.sys.windows.windef : DWORD;
        import core.sys.windows.winnt : PROCESS_QUERY_INFORMATION;

        auto handle = OpenProcess(PROCESS_QUERY_INFORMATION, true, pid);
        if (handle is null) {
            return false;
        }

        // Ensure that process handle is closed
        scope(exit) CloseHandle(handle);

        DWORD exitCode;
        if (GetExitCodeProcess(handle, &exitCode)) {
            return exitCode == STILL_ACTIVE;
        }

        return false;
    }
}

final class PIDLock {
    private {
        string _pidFilePath;
        bool _lockAcquired = false;
    }

    this(in string pidFilePath) {
        _pidFilePath = pidFilePath;

        if (_pidFilePath.exists()) {
            // Read PID from file
            auto pidString = readText(_pidFilePath);
            auto pid = pidString.to!int;

            if (pid.processExists()) {
                // If process with this ID exists, throw an exception
                throw new PIDLockedException(pid);
            }
        }

        auto pid = thisProcessID();
        write(_pidFilePath, cast(void[]) text(pid));
        _lockAcquired = true;
    }

    ~this() {
        // If we acquired the lock...
        if (_lockAcquired) {
            // Release the PID lock by deleting the PID file
            remove(_pidFilePath);
        }
    }
}
