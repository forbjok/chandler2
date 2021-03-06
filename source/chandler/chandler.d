module chandler.chandler;

import std.array : array;
import std.conv : to;
import std.file : exists, getcwd;
import std.path : buildPath;
import std.regex : matchFirst, regex;
import std.stdio;

import chandl.components.downloadmanager;
import chandler.project;

version (Posix) {
    static immutable ConfigFileNames = [".chandler.yml", ".chandler.json"];
}
else version (Windows) {
    static immutable ConfigFileNames = ["chandler.yml", "chandler.json"];
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
    private {
        IDownloadManager _downloadManager;
    }

    ChandlerConfig config;
    string subdirectory;

    IDownloadProgressTracker downloadProgressTracker;

    this(IDownloadProgressTracker downloadProgressTracker, CancellationCallback cancellationCallback) {
        auto downloadManager = new DownloadManager();
        downloadManager.cancellationCallback = cancellationCallback;
        downloadManager.downloadProgressTracker = downloadProgressTracker;
        _downloadManager = downloadManager;

        with (config) {
            downloadPath = buildPath(getDocumentsDirectory(), "threads");
            config.downloadExtensions = defaultDownloadExtensions.dup;

            sites = [
                "boards.4chan.org": ChandlerConfig.Site(`https?://([\w\.]+)/(\w+)/thread/(\d+)`, "4chan"),
            ];
        }
    }

    private string findFirstExistingConfigFile() {
        foreach(cfn; ConfigFileNames) {
            auto configFilePath = buildPath(getUserHomeDir(), cfn);

            if (exists(configFilePath))
                return configFilePath;
        }

        return "";
    }

    private void loadJsonConfig(string filename) {
        import std.file : readText;
        import jsonserialized : deserializeFromJSONValue;
        import stdx.data.json : toJSONValue;

        auto configJson = readText(filename);
        auto configJsonValue = configJson.toJSONValue();
        config.deserializeFromJSONValue(configJsonValue);
    }

    private void loadYamlConfig(string filename) {
        import dyaml : Loader;
        import yamlserialized : deserializeInto;

        // Load YAML file into a Node
        auto loader = Loader.fromFile(filename);
        auto node = loader.load();

        // Deserialize Node into the config structure
        node.deserializeInto(config);
    }

    void readConfig() {
        import std.path : extension;
        import std.string : empty;

        auto configFilePath = findFirstExistingConfigFile();

        if (configFilePath.empty) {
            return;
        }

        auto configExtension = extension(configFilePath);
        switch (configExtension) {
            case ".json":
                loadJsonConfig(configFilePath);
                break;
            case ".yml":
                loadYamlConfig(configFilePath);
                break;
            default:
                break;
        }

        // Perform tilde (user home directory) expansion for posix systems
        version (Posix) {
            import std.path : expandTilde;
            config.downloadPath = config.downloadPath.expandTilde();
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
                    urlRegex = `https?://([\w\.\-]+)(?:/([\w\-_]+))?(?:/.*)*?(?:/(\d+))`;
                }
            }

            project = createProjectFromURL(source, site);
        }

        project.downloadManager = _downloadManager;
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
        if (project is null) {
            writeln("Could not load project from: ", source);
        }

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

        auto savePath = buildPath([config.downloadPath, subdirectory] ~ m.array()[1..$]);

        if (savePath.exists()) {
            // If path already exists, load the existing project
            return ChandlerProject.load(savePath);
        }

        // Create a new project
        return ChandlerProject.create(site.parser, savePath, url);
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
