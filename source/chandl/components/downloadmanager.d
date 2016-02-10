module chandl.components.downloadmanager;

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
    IDownloadProgressTracker downloadProgressTracker;

    void downloadFiles(in DownloadFile[] files) {
        downloadProgressTracker.started(files);
        scope(exit) downloadProgressTracker.completed();

        foreach(file; files) {
            // Update progress step
            downloadProgressTracker.fileStarted(file);

            try {
                // Download file
                auto downloader = new FileDownloader(file.url);
                downloader.onProgress = (c, t) => downloadProgressTracker.fileProgress(c, t);

                downloader.download(file.destinationPath);

                downloadProgressTracker.fileCompleted(file);
            }
            catch(Exception ex) {
                downloadProgressTracker.fileFailed(file, ex.msg);
                continue;
            }
        }
    }
}
