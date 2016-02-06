module chandler.chandler;

import std.file : exists, getcwd;
import std.path : buildPath;
import std.regex : matchFirst, regex;
import std.stdio;

import chandler.project;

struct ChandlerConfig {
    string downloadRootPath;
    string[] downloadExtensions;
}

class Chandler {
    ChandlerConfig config;
    IDownloadProgressTracker downloadProgressTracker;

    this() {
        config = ChandlerConfig();

        with (config) {
            downloadRootPath = buildPath(getcwd(), "threads");
            config.downloadExtensions = defaultDownloadExtensions;
        }
    }

    ChandlerProject loadSource(in string source) {
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

            project = createProjectFromURL(source);
        }

        project.downloadProgressTracker = downloadProgressTracker;
        return project;
    }

    void rebuildProject(in string source) {
        // In the case of rebuilds, source MUST be an existing path
        if (!source.exists()) {
            writeln(source, " is not a valid path.");
            return;
        }

        // Load project
        auto project = loadSource(source);

        // Rebuild
        project.rebuild();
    }

    private ChandlerProject createProjectFromURL(in string url) {
        enum getThreadId = regex(`(\w+)://([\w\.]+)/(\w+)/thread/(\d+)`);

        auto m = url.matchFirst(getThreadId);
        if (m.empty) {
            writeln("Error getting thread ID for: ", url);
            return null;
        }

        auto savePath = buildPath(config.downloadRootPath, text(m[4]));

        auto project = ChandlerProject.create(savePath, url);
        return project;
    }
}
