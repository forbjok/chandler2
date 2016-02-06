import std.conv : text;
import std.file : exists, getcwd;
import std.getopt : getopt;
import std.path : absolutePath, baseName, buildPath;
import std.range;
import std.regex : matchFirst, regex;
import std.stdio;

import dstatus.status;
import chandl.downloader;
import chandler.project;

import cli.utils.breakhandler;
import cli.ui.downloadprogresstracker;

string basePath;
DownloadProgressTracker downloadProgressTracker;

int main(string[] args)
{
    string[] watchThreads;
    int interval = 30;

    try {
        // Parse arguments
        auto getoptResult = getopt(args,
            std.getopt.config.bundling,
            "w|watch", &watchThreads,
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

    basePath = getcwd().absolutePath();
    downloadProgressTracker = new DownloadProgressTracker();

    foreach(source; args[1..$]) {
        auto project = getProjectFromSource(source);

        writeln("Downloading thread ", project.url, " to ", project.path);

        // Download thread once
        project.download();
    }

    if (watchThreads.length > 0) {
        import core.thread;

        ChandlerProject[] watchProjects;
        foreach(source; watchThreads) {
            auto project = getProjectFromSource(source);
            if (project is null) {
                continue;
            }

            // We got a valid project - add it to the pile
            watchProjects ~= project;
        }

        while(true) {
            foreach(project; watchProjects) {
                writeln("Downloading thread ", project.url, " to ", project.path);

                // Download thread
                project.download();
            }

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

    return 0;
}

ChandlerProject getProjectFromSource(in string source) {
    enum getHostname = regex(`(\w+)://([\w\.]+)`);

    ChandlerProject project;

    auto m = source.matchFirst(getHostname);
    if (m.empty) {
        // Source is not an URL
        if (!source.exists()) {
            writeln(source, " is neither a valid URL nor an existing path.");
            return null;
        }
        // Source is an existing path - try to load project
        project = ChandlerProject.load(source);
    }
    else {
        auto hostname = m[2];
        // TODO: Identify site by hostname?

        project = createProject(source);
    }

    project.downloadProgressTracker = downloadProgressTracker;

    // Print info when a thread update occurred
    project.threadUpdated = (updateResult) {
        writefln("%d new posts found.", updateResult.newPosts.length);
    };

    // Print error message if a link download fails
    project.linkDownloadFailed = (url, message) {
        writefln("Failed to download file: [%s]: %s.", url, message);
    };

    project.save();
    return project;
}

ChandlerProject createProject(in string url) {
    enum getThreadId = regex(`(\w+)://([\w\.]+)/(\w+)/thread/(\d+)`);

    auto m = url.matchFirst(getThreadId);
    if (m.empty) {
        writeln("Error getting thread ID for: ", url);
        return null;
    }

    auto savePath = buildPath(basePath, "threads", text(m[4]));

    auto project = ChandlerProject.create(savePath, url);
    return project;
}

void writeUsage(in string executable) {
    writefln("Usage: %s [-c] [-i INTERVAL] [--help] <url(s)>", executable.baseName());
}
