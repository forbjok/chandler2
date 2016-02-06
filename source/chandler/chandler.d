module chandler.chandler;

import std.file : exists, getcwd;
import std.path : buildPath;
import std.regex : matchFirst, regex;
import std.stdio;

import chandler.project;

struct ChandlerConfig {
    struct Site {
        string urlRegex;
        string parser;
    }

    string downloadRootPath;
    string[] downloadExtensions;

    Site[string] sites;
}

class Chandler {
    ChandlerConfig config;
    IDownloadProgressTracker downloadProgressTracker;

    this() {
        config = ChandlerConfig();

        with (config) {
            downloadRootPath = buildPath(getcwd(), "threads");
            config.downloadExtensions = defaultDownloadExtensions;

            sites = [
                "boards.4chan.org": ChandlerConfig.Site(`(\w+)://([\w\.]+)/(\w+)/thread/(\d+)`, "4chan"),
            ];
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
            
            // Identify site by hostname
            if (hostname !in config.sites) {
                writeln("Unsupported site: ", hostname);
                return null;
            }

            auto site = config.sites[hostname];

            project = createProjectFromURL(source, site);
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

    private ChandlerProject createProjectFromURL(in string url, in ref ChandlerConfig.Site site) {
        auto urlRegex = regex(site.urlRegex);

        // Split thread URL to get hostname, board name and thread ID
        auto m = url.matchFirst(urlRegex);
        if (m.empty) {
            writeln("Error parsing url: ", url);
            return null;
        }

        auto hostname = text(m[2]);
        auto board = text(m[3]);
        auto thread = text(m[4]);

        auto savePath = buildPath(config.downloadRootPath, hostname, board, thread);

        auto project = ChandlerProject.create(site.parser, savePath, url);
        return project;
    }
}
