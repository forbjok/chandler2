import std.conv : to;
import std.file;
import std.net.curl;
import std.path;

void downloadFile(in string url, in string destinationPath, void delegate(in short percent) onProgress) {
    // Ensure that destination directory exists
    auto destinationDir = destinationPath.dirName();
    mkdirRecurse(destinationDir);

    // If an exception is thrown during download, delete the broken file
    scope(failure) std.file.remove(destinationPath);

    auto http = HTTP();
    http.onProgress = (dlTotal, dlNow, ulTotal, ulNow) {
        auto percent = (dlTotal == 0 ? 0 : ((dlNow.to!float / dlTotal) * 100)).to!short;
        onProgress(percent);
        return 0;
    };

    // Download file
    download(url, destinationPath, http);
}
