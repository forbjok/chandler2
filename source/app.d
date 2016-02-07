import std.getopt : getopt;
import std.path : baseName;
import std.stdio;

import dstatus.status;
import chandl.downloader;
import chandler;

import cli.utils.breakhandler;
import cli.ui.downloadprogresstracker;

int main(string[] args)
{
    string[] watchThreads;
    string[] rebuildProjects;
    int interval = 30;

    try {
        // Parse arguments
        auto getoptResult = getopt(args,
            std.getopt.config.bundling,
            "r|rebuild", &rebuildProjects,
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

    auto chandler = new Chandler();
    chandler.downloadProgressTracker = new DownloadProgressTracker();

    auto loadSource(in string source) {
        auto project = chandler.loadSource(source);
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
    if (watchProjects.length > 0) {
        import core.thread;

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

void writeUsage(in string executable) {
    writefln("Usage: %s [-c] [-i INTERVAL] [--help] <url(s)>", executable.baseName());
}
