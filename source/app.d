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

        auto file = File(destinationPath, "w");
        scope(exit) file.close();

        size_t downloadedBytes;
        writefln("Downloading %s... ", url);
        // Download file
        foreach(chunk; std.net.curl.byChunk(url)) {
            downloadedBytes += chunk.length;
            string progr = "%d%%".format(downloadedBytes);
            stdout.writef("%s%s", '\b'.repeat(progr.length), progr);
            file.rawWrite(chunk);
        }
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
