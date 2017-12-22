module chandler.project;

import core.time : TimeException;
import std.algorithm.iteration : filter, map;
import std.algorithm.sorting : sort;
import std.array : array;
import std.conv : text, to;
import std.datetime : Clock, SysTime, UTC;
import std.file;
import std.format;
import std.path : absolutePath, baseName, buildPath, exists;

import jsonserialized;
import stdx.data.json;

import chandl.components.downloadmanager;
import chandl.utils.htmlutils;
import chandler.utils.pidlock;

public import chandl.threaddownloader;

enum ProjectDirName = ".chandler";
enum ThreadConfigFileName = "thread.json";
enum StateFileName = "state.json";
enum OriginalsDirName = "originals";
enum PIDFileName = "chandler.pid";

struct ThreadConfig {
    string parser;
    string url;
    string[] downloadExtensions;
}

struct ProjectState {
    struct LinkState {
        string[] failed;
    }

    string lastModified;
    bool isDead;
    LinkState links;
}

class ChandlerProject : ThreadDownloader {
    private {
        string _projectDir;
        string _originalsPath;
        string _threadConfigPath;
        string _statePath;

        string _parserName;

        SysTime _lastModified = SysTime.min();

        PIDLock _pidLock;
    }

    private this(in string parserName, in string url, in string path, in string projectDir) {
        import chandl.parsers : getParser;

        _parserName = parserName;
        auto parser = getParser(_parserName);

        super(parser, url, path);

        _projectDir = projectDir.to!string;
        _originalsPath = buildPath(_projectDir, OriginalsDirName);
        _threadConfigPath = buildPath(_projectDir, ThreadConfigFileName);
        _statePath = buildPath(_projectDir, StateFileName);

        // If project dir does not exist, create it
        if (!_projectDir.exists())
            mkdirRecurse(_projectDir);

        auto pidFileName = buildPath(_projectDir, PIDFileName);
        _pidLock = new PIDLock(pidFileName);
    }

    ~this() {
        destroy(_pidLock);
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
        if (result.code != 200) {
            // If status code was not 200 (success), delete whatever file was produced
            std.file.remove(filename);

            switch(result.code) {
            case 304:
                // No update found
                return false;
            case 404:
                throw new ThreadNotFoundException(url);
            default:
                throw new Exception("Error downloading thread: " ~ text(result.code, " ", result.reason));
            }
        }

        _lastModified = result.lastModified;

        html = text(readHTML(filename));
        return true;
    }

    override void downloadFiles() {
        super.downloadFiles();
        saveState();
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
        // Get absolute path
        auto absolutePath = text(path).absolutePath();

        // Construct project directory path
        auto projectDir = buildPath(absolutePath, ProjectDirName);

        if (!projectDir.exists())
            throw new Exception("Chandler project not found in: " ~ absolutePath.to!string);

        auto threadJsonPath = buildPath(projectDir, ThreadConfigFileName);

        // Read JSON configuration file
        auto threadJson = readText(threadJsonPath);
        auto jsonConfig = threadJson.toJSONValue();

        ThreadConfig threadConfig;
        threadConfig.deserializeFromJSONValue(jsonConfig);

        auto project = new ChandlerProject(threadConfig.parser, threadConfig.url, absolutePath, projectDir);

        foreach(ext; threadConfig.downloadExtensions) {
            project.includeExtension(ext);
        }

        // Load state
        project.loadState();

        return project;
    }

    /* Save project configuration */
    void save() {
        ThreadConfig threadConfig;
        with (threadConfig) {
            parser = _parserName;
            url = this.url;
            downloadExtensions = this.downloadExtensions;
        }

        // If project dir does not exist, create it
        if (!_projectDir.exists())
            mkdirRecurse(_projectDir);

        // Serialize configuration to JSON
        auto jsonConfig = threadConfig.serializeToJSONValue();

        // Write thread JSON to file
        write(_threadConfigPath, cast(void[])jsonConfig.toJSON());
    }

    /* Rebuild thread from original HTMLs */
    void rebuild() {
        import std.stdio : writeln;
        import std.string : endsWith;

        import chandl.threadparser : ThreadParseException;

        // If thread HTML exists, delete it
        if (threadHTMLPath.exists()) {
            std.file.remove(threadHTMLPath);
        }

        // If state file exists, delete it
        if (_statePath.exists()) {
            std.file.remove(_statePath);
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
                processHTML(html);
            }
            catch(ThreadParseException ex) {
                writeln(ex.msg);
            }
        }

        // Attempt to re-download any missing files
        downloadFiles();
        writeln("Rebuild complete.");
    }

    private void saveState() {
        // Get current state
        ProjectState state;
        state.lastModified = _lastModified.toISOExtString();
        state.isDead = _isDead;
        state.links.failed = failedFiles.map!(f => f.url).array();

        // Serialize state to JSON
        auto jvState = state.serializeToJSONValue();

        // Write state to file
        write(_statePath, cast(void[])jvState.toJSON());
    }

    private void loadState() {
        if (!_statePath.exists()) {
            // If there is no state file, return immediately
            return;
        }

        // Read state file
        auto stateJson = readText(_statePath);
        auto jvState = stateJson.toJSONValue();

        // Deserialize state
        ProjectState state;
        state.deserializeFromJSONValue(jvState);

        // Restore state
        try {
            _lastModified = SysTime.fromISOExtString(state.lastModified);
        }
        catch (TimeException) {
            // Presumably the date string in the state file was invalid or blank
            // We can safely ignore this.
        }

        // Restore dead status
        _isDead = state.isDead;

        failedFiles = state.links.failed
            .map!(url => DownloadFile(url, buildPath(path, mapURL(url))))
            .array();
    }
}
