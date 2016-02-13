import std.getopt : getopt;
import std.path : absolutePath, baseName;
import std.stdio;

import dstatus.status;
import chandl.threaddownloader;
import chandler;
import chandler.utils.pidlock : PIDLockedException;

import cli.utils.breakhandler;
import cli.ui.downloadprogresstracker;

int main(string[] args)
{
    string destination;
    string[] watchThreads;
    string[] rebuildProjects;
    int interval = 30;

    try {
        // Parse arguments
        auto getoptResult = getopt(args,
            std.getopt.config.bundling,
            "d|destination", &destination,
            "i|interval", &interval,
            "r|rebuild", &rebuildProjects,
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

    auto downloadProgressTracker = new DownloadProgressTracker();
    auto chandler = new Chandler(downloadProgressTracker);
    chandler.readConfig();

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
        writeln("Rebuilding project at ", projectPath);

        // Rebuild project
        chandler.rebuildProject(projectPath);
    }

    /* Download all download-once sources */
    foreach(source; args[1..$]) {
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
        auto project = loadSource(source);
        if (project is null) {
            continue;
        }

        // We got a valid project - add it to the pile
        watchProjects ~= project;
    }

    /* If any valid threads were specified to be watched, watch them. */
    while(watchProjects.length > 0) {
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
            import core.thread;

            status.report(i, "...");
            Thread.getThis().sleep(dur!("seconds")(1));
        }
    }

    return 0;
}

void writeUsage(in string executable) {
    writefln("Usage: %s [-c] [-i INTERVAL] [--help] <url(s)>", executable.baseName());
}
