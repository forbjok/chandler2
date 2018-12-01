module chandl.utils.download;

import std.conv : to;
import std.datetime : parseRFC822DateTime, SysTime;
import std.file;
static import std.net.curl;
import std.net.curl : HTTP;
import std.path;

enum LastModifiedHeader = "last-modified";
enum IfModifiedSinceHeader = "if-modified-since";

struct HTTPStatus {
    ushort code;
    string reason;
}

struct FileDownloadResult {
    HTTPStatus status;
    alias status this;

    SysTime lastModified;
}

alias CancellationCallback = bool delegate();
alias DownloadProgressCallback = void delegate(in size_t current, in size_t total);

class FileDownloader {
    private {
        string _url;

        bool _useIfModifiedSince = false;
        SysTime _ifModifiedSince;
    }

    CancellationCallback cancellationCallback;
    DownloadProgressCallback onProgress;

    this(in string url) {
        _url = url;

        // Set default callback functions
        cancellationCallback = () { return false; };
        onProgress = (c, t) { };
    }

    void setIfModifiedSince(in SysTime timestamp) {
        _useIfModifiedSince = true;
        _ifModifiedSince = timestamp;
    }

    FileDownloadResult download(in string destinationPath) {
        import chandl.utils.rfc822datetime : toRFC822DateTime;

        // Ensure that destination directory exists
        auto destinationDir = destinationPath.dirName();
        mkdirRecurse(destinationDir);

        // If an exception is thrown during download, delete the incomplete file
        scope(failure) {
            if (destinationPath.exists()) {
                std.file.remove(destinationPath);
            }
        }

        auto http = HTTP();

        http.onProgress = (dlTotal, dlNow, ulTotal, ulNow) {
            onProgress(dlNow, dlTotal);
            return cancellationCallback() ? 1 : 0;
        };

        if (_useIfModifiedSince) {
            // I'd use setTimeCondition, but it appears to be broken, so manual addRequestHeader it is.
            //http.setTimeCondition(HTTP.TimeCond.ifmodsince, _ifModifiedSince);
            http.addRequestHeader(IfModifiedSinceHeader, _ifModifiedSince.toRFC822DateTime());
        }

        // Download file
        std.net.curl.download(_url, destinationPath, http);

        return FileDownloadResult(HTTPStatus(http.statusLine.code, http.statusLine.reason), http.getLastModified());
    }

    FileDownloadResult get(out const(char)[] buffer) {
        import chandl.utils.rfc822datetime : toRFC822DateTime;

        auto http = HTTP();

        if (onProgress !is null) {
            http.onProgress = (dlTotal, dlNow, ulTotal, ulNow) {
                onProgress(dlNow, dlTotal);
                return 0;
            };
        }

        if (_useIfModifiedSince) {
            http.addRequestHeader(IfModifiedSinceHeader, _ifModifiedSince.toRFC822DateTime());
        }

        buffer = std.net.curl.get(_url, http);
        return FileDownloadResult(HTTPStatus(http.statusLine.code, http.statusLine.reason), http.getLastModified());
    }
}

private SysTime getLastModified(ref HTTP http) {
    auto lastModified = SysTime.min();
    if (LastModifiedHeader in http.responseHeaders) {
        lastModified = parseRFC822DateTime(http.responseHeaders[LastModifiedHeader]);
    }

    return lastModified;
}
