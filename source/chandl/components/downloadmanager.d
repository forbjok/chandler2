module chandl.components.downloadmanager;

import std.file : remove;
import std.path : exists;
import std.range : chain;

import chandl.utils.download;

struct DownloadFile {
    string url;
    string destinationPath;
}

interface IDownloadManager {
    void downloadFiles(in DownloadFile[] files);
}

interface IDownloadProgressTracker {
    void started(in DownloadFile[] files);
    void fileStarted(in DownloadFile file);
    void fileProgress(in size_t current, in size_t total);
    void fileCompleted(in DownloadFile file);
    void fileFailed(in DownloadFile file, in string reason);
    void completed();
}

class DownloadManager : IDownloadManager {
    private {
        DownloadFile[] _retryFiles;
    }

    IDownloadProgressTracker downloadProgressTracker;

    void downloadFiles(in DownloadFile[] files) {
        downloadProgressTracker.started(files);
        scope(exit) downloadProgressTracker.completed();

        auto retryFiles = _retryFiles;
        _retryFiles.length = 0;

        foreach(file; chain(retryFiles, files)) {
            // Update progress step
            downloadProgressTracker.fileStarted(file);

            try {
                // Download file
                auto downloader = new FileDownloader(file.url);
                downloader.onProgress = (c, t) => downloadProgressTracker.fileProgress(c, t);

                auto result = downloader.download(file.destinationPath);
                if (result.status.code != 200) {
                    if (file.destinationPath.exists()) {
                        std.file.remove(file.destinationPath);
                    }

                    downloadProgressTracker.fileFailed(file, result.status.reason);

                    if (result.status.code != 404) {
                        // If the status code is not 404 (file not found), retry file later
                        _retryFiles ~= file;
                    }

                    continue;
                }

                downloadProgressTracker.fileCompleted(file);
            }
            catch(Exception ex) {
                downloadProgressTracker.fileFailed(file, ex.msg);
                continue;
            }
        }
    }
}
