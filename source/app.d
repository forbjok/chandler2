import core.thread : dur, Thread;
static import std.getopt;
import std.path : absolutePath, baseName, stripExtension;
import std.stdio;

import dstatus.status;
import chandl.threaddownloader;
import chandler;
import chandler.utils.pidlock : PIDLockedException;

import cli.utils.breakhandler;
import cli.ui.downloadprogresstracker;

int main(string[] args)
{
    bool versionWanted = false;
    string destination;
    string subdirectory;
    string[] watchThreads;
    string[] rebuildProjects;
    int interval = 60;

    // Always print a newline when the program exits
    scope(exit) writeln();

    try {
        // Parse arguments
        auto getoptResult = std.getopt.getopt(args,
            std.getopt.config.bundling,
            "version", &versionWanted,
            "d|destination", &destination,
            "i|interval", &interval,
            "r|rebuild", &rebuildProjects,
            "s|subdirectory", &subdirectory,
            "w|watch", &watchThreads);

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

    if (versionWanted) {
        writefln("Chandler version %s", import("VERSION"));
        return 0;
    }

    // If there is nothing to do, display usage information
    if (args.length <= 1
        && watchThreads.length == 0
        && rebuildProjects.length == 0)
    {
        writeUsage(args[0]);
        return 1;
    }

    bool isTerminating = false;

    import cli.utils.breakhandler;
    registerBreakHandler({ isTerminating = true; });
    handleBreak();

    auto downloadProgressTracker = new DownloadProgressTracker();
    auto chandler = new Chandler(downloadProgressTracker, () => isTerminating);
    chandler.readConfig();
    chandler.subdirectory = subdirectory;

    if (destination.length > 0) {
        chandler.config.downloadPath = destination.absolutePath();
    }

    auto loadSource(in string source) {
        ChandlerProject project;

        try {
            project = chandler.loadSource(source);
        }
        catch (PIDLockedException) {
            writeln(source, " is already in use by another chandler process. Skipping.");
            return null;
        }

        if (project is null) {
            return null;
        }

        // Print info when a thread update occurred
        project.threadUpdated = (updateResult) {
            writefln("Thread updated. %d new posts found.", updateResult.newPosts.length);
        };

        // Print error message if a link download fails
        project.linkDownloadFailed = (url, message) {
            writefln("Failed to download file: [%s]: %s.", url, message);
        };

        project.notChanged = () => writeln("No changes since last update.");

        project.save();
        return project;
    }

    /* Rebuild projects if any were specified */
    foreach(projectPath; rebuildProjects) {
        if (isTerminating)
            break;

        writeln("Rebuilding project at ", projectPath);

        // Rebuild project
        chandler.rebuildProject(projectPath);
    }

    /* Download all download-once sources */
    foreach(source; args[1..$]) {
        if (isTerminating)
            break;

        auto project = loadSource(source);
        if (project is null) {
            continue;
        }

        writeln("Downloading thread ", project.url, " to ", project.path);

        // Download thread once
        project.download();
    }

    /* Try to load any sources specified for watching */
    ChandlerProject[] watchProjects;
    foreach(source; watchThreads) {
        if (isTerminating)
            break;

        auto project = loadSource(source);
        if (project is null) {
            continue;
        }

        // We got a valid project - add it to the pile
        watchProjects ~= project;
    }

    /* If any valid threads were specified to be watched, watch them. */
    while(!isTerminating && watchProjects.length > 0) {
        auto projects = watchProjects;
        watchProjects.length = 0;

        foreach(project; projects) {
            writeln("Downloading thread ", project.url, " to ", project.path);

            try {
                // Download thread
                project.download();
            }
            catch(Exception ex) {
                writeln("Failed to download thread: ", project.url, ": ", ex.msg);
            }

            if (!project.isDead) {
                // If the thread is still alive, keep watching it
                watchProjects ~= project;
            }
            else {
                writeln("R.I.P. ", project.url);
                destroy(project);
            }
        }

        // If there are no more threads left to watch, break out of the loop
        if (watchProjects.length == 0) {
            break;
        }

        // Do countdown
        auto status = status();
        scope(exit) status.clear();

        status.write("Updating in ");

        for(int i = interval; i > 0; --i) {
            if (isTerminating)
                break;

            status.report(i, "...");
            Thread.getThis().sleep(dur!("seconds")(1));
        }
    }

    return 0;
}

void writeUsage(in string executable) {
    writefln("Usage: %s [options] [sources...]", executable.baseName().stripExtension());
    writeln();
    writeln("A source can be either a thread URL or a path to a chandler project. (downloaded thread)");
    writeln();
    writeln("Options:");
    writeln("\t-d|destination\t<path>\t\tSpecify download root directory");
    writeln("\t-i|interval\t<seconds>\tSpecify update interval for watched threads");
    writeln("\t-r|rebuild\t<project>\tSpecify a project to rebuild. Can be specified multiple times.");
    writeln("\t-s|subdirectory\t<subpath>\tSpecify an additional subpath.");
    writeln("\t-w|watch\t<source>\tSpecify a source to watch. Can be specified multiple times.");
}
