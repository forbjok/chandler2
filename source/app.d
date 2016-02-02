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
import chandlerproject;

import dstatus.progress;
import dstatus.termutils;

void main(string[] args)
{
    auto baseURL = "";
    auto basePath = "temptest".absolutePath();
    //auto html = get(baseURL);
    //std.file.write("orig.html", html);
    //auto html = readText("orig.html");

    handleBreak();

    auto chandl = ChandlerProject.create(basePath, baseURL);
    chandl.save();
    //auto chandl = ChandlerProject.load(basePath);

    chandl.downloadLink = (url, destinationPath) {
        import std.file;
        import std.net.curl;
        import std.path;

        // Ensure that destination directory exists
        auto destinationDir = destinationPath.dirName();
        mkdirRecurse(destinationDir);

        // If an exception is thrown during download, delete the broken file
        scope(failure) std.file.remove(destinationPath);

        auto operation = operationProgressIndicator(getTerminalWidth(), 1);
        scope(exit) operation.clear();
        
        operation.step(url);

        auto http = HTTP();
        http.onProgress = (dlTotal, dlNow, ulTotal, ulNow) {
            auto percent = dlTotal == 0 ? 0 : ((dlNow.to!float / dlTotal) * 100).to!int;
            operation.progress(percent);
            return 0;
        };

        // Download file
        download(url, destinationPath, http);
    };

    // Print info when a thread update occurred
    chandl.threadUpdated = (updateResult) {
        writefln("%d new posts found.", updateResult.newPosts.length);
    };

    // Print error message if a link download fails
    chandl.linkDownloaded = (url, destinationFile) {
        writefln("%s downloaded.", url);
    };

    // Print error message if a link download fails
    chandl.linkDownloadFailed = (url, message) {
        writefln("Failed to download file: [%s]: %s.", url, message);
    };

    chandl.download();
    //chandl.rebuild();
}
