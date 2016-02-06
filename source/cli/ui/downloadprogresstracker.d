module cli.ui.downloadprogresstracker;

import std.conv : to;
import std.stdio;

import chandl.downloader;

import cli.ui.downloadprogressindicator;

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

    void fileProgress(in size_t current, in size_t total) {
        auto percent = (total == 0 ? 0 : ((current.to!float / total) * 100)).to!short;
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
