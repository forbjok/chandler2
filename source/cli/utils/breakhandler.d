module cli.utils.breakhandler;

import std.stdio;

static bool isTerminating = false;

void handleBreak() {
    version (Windows) {
        import core.sys.windows.windef;
        import core.sys.windows.wincon;

        extern(Windows) static BOOL handler(DWORD d) nothrow {
            try {
                writeln("Ctrl-C pressed.");
            }
            catch {
            }

            isTerminating = true;
            return TRUE;
        }

        SetConsoleCtrlHandler(cast(PHANDLER_ROUTINE)&handler, TRUE);
    }
    else version (Posix) {
        import core.stdc.signal;
        import core.stdc.stdio;
        import core.sys.posix.signal;

        extern (C) static nothrow void handler(int s) {
            try {
                writeln("Ctrl-C pressed.");
            }
            catch {
            }

            isTerminating = true;
        }

        sigaction_t sa;

        sa.sa_handler = &handler;
        sigemptyset(&sa.sa_mask);
        sa.sa_flags = 0;

        sigaction(SIGINT, &sa, null);
    }
}