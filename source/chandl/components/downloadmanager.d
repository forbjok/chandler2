module chandl.components.downloadmanager;

import std.conv : text;
static import std.file;
import std.file : exists;
import std.range : chain;

import chandl.utils.download;

alias CancellationCallback = bool delegate();

struct DownloadFile {
    string url;
    string destinationPath;
}

struct DownloadResult {
    DownloadFile[] downloaded;
    DownloadFile[] failed;
    DownloadFile[] notFound;
}

interface IDownloadManager {
    DownloadResult downloadFiles(in DownloadFile[] files);
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

    CancellationCallback cancellationCallback;
    IDownloadProgressTracker downloadProgressTracker;

    DownloadResult downloadFiles(in DownloadFile[] files) {
        downloadProgressTracker.started(files);
        scope(exit) downloadProgressTracker.completed();

        auto result = DownloadResult();

        auto retryFiles = _retryFiles;
        _retryFiles.length = 0;

        foreach(file; chain(retryFiles, files)) {
            if (cancellationCallback()) {
                // If the download was cancelled, add all remaining files to failed
                result.failed ~= file;
                continue;
            }

            // Update progress step
            downloadProgressTracker.fileStarted(file);

            try {
                // Download file
                auto downloader = new FileDownloader(file.url);
                downloader.cancellationCallback = cancellationCallback;
                downloader.onProgress = (c, t) => downloadProgressTracker.fileProgress(c, t);

                auto fileResult = downloader.download(file.destinationPath);
                if (fileResult.status.code != 200) {
                    if (file.destinationPath.exists()) {
                        std.file.remove(file.destinationPath);
                    }

                    downloadProgressTracker.fileFailed(file, fileResult.status.reason);

                    if (fileResult.status.code == 404) {
                        result.notFound ~= file;
                        continue;
                    }

                    throw new Exception(text(fileResult.status.code, " ", fileResult.status.reason));
                }

                result.downloaded ~= file;
                downloadProgressTracker.fileCompleted(file);
            }
            catch(Exception ex) {
                // If an exception is thrown, add file to failed list
                result.failed ~= file;
                downloadProgressTracker.fileFailed(file, ex.msg);
                continue;
            }
        }

        return result;
    }
}
