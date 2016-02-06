module chandl.utils.download;

import std.conv : to;
import std.file;
import std.net.curl;
import std.path;

void downloadFile(in string url, in string destinationPath, void delegate(in size_t current, in size_t total) onProgress) {
    // Ensure that destination directory exists
    auto destinationDir = destinationPath.dirName();
    mkdirRecurse(destinationDir);

    // If an exception is thrown during download, delete the broken file
    scope(failure) std.file.remove(destinationPath);

    auto http = HTTP();
    http.onProgress = (dlTotal, dlNow, ulTotal, ulNow) {
        onProgress(dlNow, dlTotal);
        return 0;
    };

    // Download file
    download(url, destinationPath, http);
}
