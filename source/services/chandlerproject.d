import std.conv;

import chandler;

enum ProjectDirName = ".chandler";
enum ThreadConfigName = "thread.json";

struct ThreadConfig {
    string url;
    string[] downloadExtensions;
}

ChandlerThread createChandlerProject(in char[] url, in char[] path) {
    auto chandler = new ChandlerThread(url, path);

    // Add default extensions
    with (chandler) {
        includeExtension("ico");
        includeExtension("css");
        includeExtension("png");
        includeExtension("jpg");
        includeExtension("gif");
        includeExtension("webm");
    }

    return chandler;
}

ChandlerThread loadChandlerProject(in char[] path) {
    import std.file;
    import stdx.data.json;
    import jsonserialized;
    import std.path;

    auto projectDir = buildPath(path, ProjectDirName);
    auto threadJsonPath = buildPath(projectDir, ThreadConfigName);

    // If project dir does not exist, create it
    if (!projectDir.exists())
        throw new Exception("Chandler project not found in: " ~ path.to!string);

    // Read JSON configuration file
    auto threadJson = readText(threadJsonPath);
    auto jsonConfig = threadJson.toJSONValue();

    ThreadConfig threadConfig;
    threadConfig.deserializeFromJSONValue(jsonConfig);

    auto chandler = new ChandlerThread(threadConfig.url, path);
    foreach(ext; threadConfig.downloadExtensions) {
        chandler.includeExtension(ext);
    }

    return chandler;
}

void saveProject(ChandlerThread chandlerThread) {
    import std.file;
    import stdx.data.json;
    import jsonserialized;
    import std.path;

    auto downloadDir = chandlerThread.path;
    auto projectDir = buildPath(downloadDir, ProjectDirName);
    auto threadJsonPath = buildPath(projectDir, ThreadConfigName);

    ThreadConfig threadConfig;
    with (threadConfig) {
        url = chandlerThread.url;
        downloadExtensions = chandlerThread.downloadExtensions;
    }

    // If project dir does not exist, create it
    if (!projectDir.exists())
        mkdirRecurse(projectDir);

    // Serialize configuration to JSON
    auto jsonConfig = threadConfig.serializeToJSONValue();

    // Write thread JSON to file
    write(threadJsonPath, cast(void[])jsonConfig.toJSON());
}
