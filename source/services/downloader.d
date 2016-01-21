import std.conv;
import std.file;
import std.path;
import std.net.curl;

interface IDownloader {
    void download(in string url, in string destinationPath);
}

class Downloader : IDownloader {
    void download(in string url, in string destinationPath) {
        if (destinationPath.exists()) {
            // If destination file already exists, skip it
            return;
        }

        auto destinationDir = destinationPath.dirName();
        mkdirRecurse(destinationDir);

        import std.stdio;
        writeln("DL ", url, " -> ", destinationPath);

        scope(failure) {
            // If an exception is thrown during download, delete the broken file
            std.file.remove(destinationPath);
        }

        // Download file
        std.net.curl.download(url, destinationPath);
    }
}
