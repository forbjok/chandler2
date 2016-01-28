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
}
