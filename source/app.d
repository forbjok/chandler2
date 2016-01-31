import std.algorithm;
import std.array;
import std.conv;
import std.file;
import std.path;
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

    //auto chandl = ChandlerProject.create(basePath, baseURL);
    //chandl.save();
    auto chandl = ChandlerProject.load(basePath);

    // Print info when a thread update occurred
    chandl.threadUpdated = (updateResult) {
        writefln("%d new posts found.", updateResult.newPosts.length);
    };

    // Print error message if a link download fails
    chandl.linkDownloadFailed = (url, message) {
        writefln("Failed to download file: [%s]: %s.", url, message);
    };

    //chandl.download();
    chandl.rebuild();
}
