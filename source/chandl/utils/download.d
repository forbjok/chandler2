module chandl.utils.download;

import std.conv : to;
import std.file;
import std.net.curl : download, get, HTTP;
import std.path;

struct HTTPStatus {
    ushort code;
    string reason;
}

HTTPStatus downloadFile(in string url, in string destinationPath, in string[string] requestHeaders, void delegate(in size_t current, in size_t total) onProgress = null) {
    // Ensure that destination directory exists
    auto destinationDir = destinationPath.dirName();
    mkdirRecurse(destinationDir);

    // If an exception is thrown during download, delete the broken file
    scope(failure) std.file.remove(destinationPath);

    auto http = HTTP();

    if (onProgress !is null) {
        http.onProgress = (dlTotal, dlNow, ulTotal, ulNow) {
            onProgress(dlNow, dlTotal);
            return 0;
        };
    }

    // Add request headers
    foreach(name, value; requestHeaders) {
        http.addRequestHeader(name, value);
    }

    // Download file
    download(url, destinationPath, http);

    return HTTPStatus(http.statusLine.code, http.statusLine.reason);
}

char[] getFile(in string url, void delegate(in size_t current, in size_t total) onProgress = null) {
    auto http = HTTP();

    if (onProgress !is null) {
        http.onProgress = (dlTotal, dlNow, ulTotal, ulNow) {
            onProgress(dlNow, dlTotal);
            return 0;
        };
    }

    // Get file
    return get(url, http);
}
