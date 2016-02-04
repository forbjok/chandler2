import std.conv : text;
import std.file : exists, getcwd;
import std.getopt : getopt;
import std.path : absolutePath, baseName, buildPath;
import std.range;
import std.regex : matchFirst, regex;
import std.stdio;

import dstatus.status;

import breakhandler;
import chandler;
import chandlerproject;
import downloadprogress;

class DownloadProgressTracker : IDownloadProgressTracker {
    private {
        DownloadProgressIndicator _downloadProgress;
    }

    void started(in DownloadFile[] files) {
        _downloadProgress = new DownloadProgressIndicator(files.length);
    }

    void fileStarted(in DownloadFile file) {
        _downloadProgress.step(file.url);
        _downloadProgress.progress(0);
    }

    void fileProgress(in short percent) {
        _downloadProgress.progress(percent);
    }

    void fileCompleted(in DownloadFile file) {
        // Print informational message when a file completes downloading
        _downloadProgress.clear();
        writefln("%s downloaded.", file.url);
    }

    void completed() {
        _downloadProgress.clear();
    }
}

enum getThreadId = regex(`(\w+)://([\w\.]+)/(\w+)/thread/(\d+)`);

int main(string[] args)
{
    bool continuous = false;
    int interval = 30;

    try {
        // Parse arguments
        auto getoptResult = getopt(args,
            std.getopt.config.bundling,
            "c|continuous", &continuous,
            "i|interval", &interval);

        if (getoptResult.helpWanted) {
            // If user wants help, give it to them
            writeUsage(args[0]);
            return 1;
        }
    }
    catch(Exception ex) {
        // If there is an error parsing arguments, print it
        writeln(ex.msg);
        return 1;
    }

    auto basePath = getcwd().absolutePath();

    void downloadThread(in string url) {
        auto m = url.matchFirst(getThreadId);
        if (m.empty) {
            writeln("Error getting thread ID for: ", url);
            return;
        }

        auto savePath = buildPath(basePath, "threads", text(m[4]));

        writeln("Downloading thread ", url, " to ", savePath);

        ChandlerProject chandl;
        if (savePath.exists()) {
            chandl = ChandlerProject.load(savePath);
        }
        else {
            chandl = ChandlerProject.create(savePath, url);
            chandl.save();
        }

        chandl.downloadProgressTracker = new DownloadProgressTracker();

        // Print info when a thread update occurred
        chandl.threadUpdated = (updateResult) {
            writefln("%d new posts found.", updateResult.newPosts.length);
        };

        // Print error message if a link download fails
        chandl.linkDownloadFailed = (url, message) {
            writefln("Failed to download file: [%s]: %s.", url, message);
        };

        chandl.download();
        //chandl.rebuild();
    }

    void downloadThreadContinuous(in string url) {
        import core.thread;

        while(true) {
            // Download thread
            downloadThread(url);

            // Do countdown
            auto status = status();
            scope(exit) status.clear();

            status.write("Updating in ");

            for(int i = interval; i > 0; --i) {
                status.report(i, "...");
                Thread.getThis().sleep(dur!("seconds")(1));
            }
        }
    }

    if (continuous) {
        auto url = args[1];

        // Download thread continuously
        downloadThreadContinuous(url);
    }
    else {
        foreach(url; args[1..$]) {
            // Download thread once
            downloadThread(url);
        }
    }

    return 0;
}

void writeUsage(in string executable) {
    writefln("Usage: %s [-c] [-i INTERVAL] [--help] <url(s)>", executable.baseName());
}
