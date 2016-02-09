module chandler.chandler;

import std.array : array;
import std.file : exists, getcwd;
import std.path : buildPath;
import std.regex : matchFirst, regex;
import std.stdio;

import chandler.project;

version (Posix) {
    enum ConfigFileName = ".chandler.json";
}
else version (Windows) {
    enum ConfigFileName = "chandler.json";
}

struct ChandlerConfig {
    struct Site {
        string urlRegex;
        string parser;
    }

    string downloadPath;
    string[] downloadExtensions;

    Site[string] sites;
}

class Chandler {
    ChandlerConfig config;
    IDownloadProgressTracker downloadProgressTracker;

    this() {
        config = ChandlerConfig();

        with (config) {
            downloadPath = buildPath(getDocumentsDirectory(), "threads");
            config.downloadExtensions = defaultDownloadExtensions;

            sites = [
                "boards.4chan.org": ChandlerConfig.Site(`https?://([\w\.]+)/(\w+)/thread/(\d+)`, "4chan"),
            ];
        }
    }

    void readConfig() {
        import std.file : readText;
        import jsonserialized;
        import stdx.data.json : toJSONValue;

        auto configPath = buildPath(getUserHomeDir(), ConfigFileName);

        if (!configPath.exists()) {
            return;
        }

        auto configJson = readText(configPath);
        auto configJsonValue = configJson.toJSONValue();
        config.deserializeFromJSONValue(configJsonValue);
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

            ChandlerConfig.Site site;
            // Identify site by hostname
            if (hostname in config.sites) {
                site = config.sites[hostname];
            }
            else {
                // Hostname was not recognized from the site list
                with (site) {
                    // Use basic parser
                    parser = "basic";

                    // Use generic regex that matches most common imageboard URL schemes
                    urlRegex = `https?://([\w\.]+)(?:/(\w+))?(?:/.*)*?(?:/(\d+))`;
                }
            }

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

        auto savePath = buildPath([config.downloadPath] ~ m.array()[1..$]);

        auto project = ChandlerProject.create(site.parser, savePath, url);
        return project;
    }
}

private string getUserHomeDir() {
    import std.process : environment;

    version (Posix) {
        return environment["HOME"];
    }
    else version (Windows) {
        return environment["USERPROFILE"];
    }
}

private string getDocumentsDirectory() {
    version (Posix) {
        return getUserHomeDir();
    }
    else version (Windows) {
        import core.stdc.wchar_ : wcslen;
        import core.sys.windows.shlobj;
        import core.sys.windows.windef;

        WCHAR[MAX_PATH] myDocumentsPath;

        SHGetFolderPath(null, CSIDL_PERSONAL, null, 0, myDocumentsPath.ptr);

        return myDocumentsPath[0..wcslen(myDocumentsPath.ptr)].to!string;
    }
}
