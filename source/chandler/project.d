module chandler.project;

import std.conv : text, to;
import std.datetime : Clock, SysTime, UTC;
import std.file;
import std.format;
import std.path;

import chandl.utils.htmlutils;

public import chandl.threaddownloader;

enum ProjectDirName = ".chandler";
enum ThreadConfigName = "thread.json";
enum OriginalsDirName = "originals";

struct ThreadConfig {
    string parser;
    string url;
    string[] downloadExtensions;
}

class ChandlerProject : ThreadDownloader {
    private {
        string _projectDir;
        string _originalsPath;
        string _threadConfigPath;

        string _parserName;

        SysTime _lastModified = SysTime.min();
    }

    private this(in string parserName, in string url, in string path, in string projectDir) {
        import chandl.parsers : getParser;

        _parserName = parserName;
        auto parser = getParser(_parserName);

        super(parser, url, path);

        this._projectDir = projectDir.to!string;
        this._originalsPath = buildPath(this._projectDir, OriginalsDirName);
        this._threadConfigPath = buildPath(this._projectDir, ThreadConfigName);
    }

    override bool downloadThread(out const(char)[] html) {
        import chandl.utils.download : FileDownloader;

        auto now = Clock.currTime(UTC());
        auto unixTime = now.toUnixTime();
        auto filename = buildPath(_originalsPath, "%d.html".format(unixTime));

        mkdirRecurse(_originalsPath);

        auto downloader = new FileDownloader(url);
        downloader.setIfModifiedSince(_lastModified);

        auto result = downloader.download(filename);
        if (result.code == 304) {
            // No update found
            return false;
        }
        else if (result.code == 404) {
            throw new ThreadNotFoundException(url);
        }
        else if (result.code != 200) {
            throw new Exception("Error downloading thread: " ~ text(result.code, " ", result.reason));
        }

        _lastModified = result.lastModified;

        html = text(readHTML(filename));
        return true;
    }

    /* Create a new project in path, for the given url */
    static ChandlerProject create(in string parserName, in string path, in string url) {
        // Get absolute path
        auto absolutePath = text(path).absolutePath();

        auto projectDir = buildPath(absolutePath, ProjectDirName);

        auto project = new ChandlerProject(parserName, url, absolutePath, projectDir);

        return project;
    }

    /* Load project from a path */
    static ChandlerProject load(in string path) {
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

        auto project = new ChandlerProject(threadConfig.parser, threadConfig.url, absolutePath, projectDir);

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
            parser = _parserName;
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
        import std.algorithm.iteration : filter, map;
        import std.algorithm.sorting : sort;
        import std.array : array;
        import std.file : exists;
        import std.stdio : writeln;
        import std.string : endsWith;

        import chandl.threadparser : ThreadParseException;

        auto threadHTMLPath = buildPath(path, "thread.html");
        if (threadHTMLPath.exists()) {
            std.file.remove(threadHTMLPath);
        }

        /* Fetch a list of all original htmls sorted by name
           (which is a unix timestamp, and should be in download order) */
        auto originalFilenames = _originalsPath.dirEntries(SpanMode.shallow)
            .filter!(e => e.isFile && e.name.endsWith(".html"))
            .map!(e => e.name)
            .array()
            .sort();

        writeln("Rebuilding thread from originals...");
        foreach(filename; originalFilenames)
        {
            writeln("Processing ", filename.baseName, "...");

            try {
                auto html = readHTML(filename);
                this.processHTML(html);
            }
            catch(ThreadParseException ex) {
                writeln(ex.msg);
            }
        }
    }
}
