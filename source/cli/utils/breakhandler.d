module cli.utils.breakhandler;

alias BreakHandler = void delegate();

private {
    shared BreakHandler[] breakHandlers;

    void callBreakHandlers() {
        foreach(handler; breakHandlers) {
            handler();
        }
    }
}

void registerBreakHandler(BreakHandler handler) {
    breakHandlers ~= handler;
}

void handleBreak() {
    version (Posix) {
        import core.stdc.signal;
        import core.stdc.stdio;
        import core.sys.posix.signal;

        extern (C) static nothrow void handler(int s) {
            try {
                callBreakHandlers();
            }
            catch (Throwable) {
            }
        }

        sigaction_t sa;

        sa.sa_handler = &handler;
        sigemptyset(&sa.sa_mask);
        sa.sa_flags = 0;

        sigaction(SIGINT, &sa, null);
        sigaction(SIGTERM, &sa, null);
    }
    else version (Windows) {
        import core.sys.windows.windef;
        import core.sys.windows.wincon;

        extern(Windows) static BOOL handler(DWORD d) nothrow {
            try {
                callBreakHandlers();
            }
            catch (Throwable) {
            }

            return TRUE;
        }

        SetConsoleCtrlHandler(cast(PHANDLER_ROUTINE)&handler, TRUE);
    }
}
