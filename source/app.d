import std.algorithm;
import std.array;
import std.conv;
import std.file;
import std.format;
import std.path;
import std.range;
import std.stdio;
import std.net.curl;

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


void main(string[] args)
{
    auto baseURL = "";
    auto basePath = "temptest".absolutePath();
    //auto html = get(baseURL);
    //std.file.write("orig.html", html);
    //auto html = readText("orig.html");

    //handleBreak();

    auto chandl = ChandlerProject.create(basePath, baseURL);
    chandl.save();
    //auto chandl = ChandlerProject.load(basePath);

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
