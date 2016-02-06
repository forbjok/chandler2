module chandler.project;

import std.conv : text, to;
import std.file;
import std.format;
import std.path;

public import chandl.downloader;

enum ProjectDirName = ".chandler";
enum ThreadConfigName = "thread.json";
enum OriginalsDirName = "originals";

struct ThreadConfig {
    string url;
    string[] downloadExtensions;
}

class ChandlerProject : ThreadDownloader {
    private {
        string _projectDir;
        string _originalsPath;
        string _threadConfigPath;
    }

    private this(in char[] url, in char[] path, in char[] projectDir) {
        super(url, path);

        this._projectDir = projectDir.to!string;
        this._originalsPath = buildPath(this._projectDir, OriginalsDirName);
        this._threadConfigPath = buildPath(this._projectDir, ThreadConfigName);

        this.threadDownloaded = (html, time) {
            auto unixTime = time.toUnixTime();

            mkdirRecurse(this._originalsPath);
            std.file.write(buildPath(this._originalsPath, "%d.html".format(unixTime)), html);
        };
    }

    /* Create a new project in path, for the given url */
    static ChandlerProject create(in char[] path, in char[] url) {
        // Get absolute path
        auto absolutePath = text(path).absolutePath();

        auto projectDir = buildPath(absolutePath, ProjectDirName);

        auto project = new ChandlerProject(url, absolutePath, projectDir);

        return project;
    }

    /* Load project from a path */
    static ChandlerProject load(in char[] path) {
        import jsonserialized;
        import stdx.data.json;

        // Get absolute path
        auto absolutePath = text(path).absolutePath();

        // Construct project directory path
        auto projectDir = buildPath(absolutePath, ProjectDirName);

        if (!projectDir.exists())
            throw new Exception("Chandler project not found in: " ~ absolutePath.to!string);

        auto threadJsonPath = buildPath(projectDir, ThreadConfigName);

        // Read JSON configuration file
        auto threadJson = readText(threadJsonPath);
        auto jsonConfig = threadJson.toJSONValue();

        ThreadConfig threadConfig;
        threadConfig.deserializeFromJSONValue(jsonConfig);

        auto project = new ChandlerProject(threadConfig.url, absolutePath, projectDir);

        foreach(ext; threadConfig.downloadExtensions) {
            project.includeExtension(ext);
        }

        return project;
    }

    /* Save project configuration */
    void save() {
        import jsonserialized;
        import stdx.data.json;

        ThreadConfig threadConfig;
        with (threadConfig) {
            url = this.url;
            downloadExtensions = this.downloadExtensions;
        }

        // If project dir does not exist, create it
        if (!this._projectDir.exists())
            mkdirRecurse(this._projectDir);

        // Serialize configuration to JSON
        auto jsonConfig = threadConfig.serializeToJSONValue();

        // Write thread JSON to file
        write(this._threadConfigPath, cast(void[])jsonConfig.toJSON());
    }

    /* Rebuild thread from original HTMLs */
    void rebuild() {
        import std.algorithm.iteration;
        import std.algorithm.sorting;
        import std.array;
        import std.file;
        import std.stdio;
        import std.string;

        auto threadHTMLPath = buildPath(this.path, "thread.html");
        if (threadHTMLPath.exists()) {
            std.file.remove(threadHTMLPath);
        }

        /* Fetch a list of all original htmls sorted by name
           (which is a unix timestamp, and should be in download order) */
        auto originalFilenames = this._originalsPath.dirEntries(SpanMode.shallow)
            .filter!(e => e.isFile && e.name.endsWith(".html"))
            .map!(e => e.name)
            .array()
            .sort();

        writeln("Rebuilding thread from originals...");
        foreach(filename; originalFilenames)
        {
            writefln("Processing %s...", filename.baseName);

            auto html = readText(filename);
            this.processHTML(html);
        }
    }
}
