module chandl.threaddownloader;

import std.algorithm.searching;
import std.conv : text, to;
import std.datetime : SysTime;
import std.path : buildPath, dirSeparator;
import std.string : replace;

import reurl;

import chandl.threadparser;
import chandl.components.downloadmanager;
import chandl.utils.download;
import chandl.utils.htmlutils;
import chandl.utils.linkfilter;

enum defaultDownloadExtensions = [
    "ico",
    "css",
    "png",
    "jpg",
    "gif",
    "webm",
];

class ThreadNotFoundException : Exception {
    this(in string url) {
        super("Thread not found: " ~ url);
    }
}

string defaultMapURL(in string url) {
    auto purl = url.parseURL();
    auto path = purl.hostname ~ purl.path.replace("/", dirSeparator);

    return path;
}

alias ThreadUpdatedCallback = void delegate(in UpdateResult updateResult);
alias NotChangedCallback = void delegate();
alias LinkDownloadFailedCallback = void delegate(in string url, in string message);

class ThreadDownloader {
    private {
        string _url;
        string _path;
        string _threadHTMLPath;
        IThreadParser _parser;
        string[] _downloadExtensions = defaultDownloadExtensions;
        bool _isDead = false;
    }

    protected {
        DownloadFile[] filesToDownload;
        DownloadFile[] failedFiles;
    }

    @property string url() {
        return _url;
    }

    @property string path() {
        return _path;
    }

    @property string threadHTMLPath() {
        return _threadHTMLPath;
    }

    @property string[] downloadExtensions() {
        return _downloadExtensions;
    }

    @property bool isDead() {
        return _isDead;
    }

    // Customizable functions
    string delegate(in string url) mapURL;

    // Events
    ThreadUpdatedCallback threadUpdated;
    NotChangedCallback notChanged;
    LinkDownloadFailedCallback linkDownloadFailed;

    IDownloadManager downloadManager;

    this(IThreadParser parser, in string url, in string path) {
        import std.functional;

        _parser = parser;
        _url = url;
        _path = path;
        _threadHTMLPath = buildPath(_path, "thread.html");

        mapURL = toDelegate(&defaultMapURL);
    }

    void includeExtension(in string extension) {
        import std.algorithm.searching;

        if (_downloadExtensions.canFind(extension)) {
            // If this extension already exists, don't add it again
            return;
        }

        _downloadExtensions ~= extension;
    }

    bool download() {
        const(char)[] html;

        bool success;
        try {
            success = downloadThread(html);
        }
        catch (ThreadNotFoundException) {
            // If the thread was not found, it must have 404'd - mark it as dead
            _isDead = true;
            return false;
        }

        /* When this scope exits successfully, fire downloadFiles().
           This is so that previously failed files will be re-tried even
           if there are no changes to the HTML since the last download. */
        scope(success) downloadFiles();

        if (!success) {
            if (notChanged !is null) {
                notChanged();
            }

            return false;
        }

        processHTML(html);

        return true;
    }

    protected bool downloadThread(out const(char)[] html) {
        auto downloader = new FileDownloader(url);

        // TODO: Fix already UTF-8 encoded pages getting incorrectly UTF8-decoded, potentially resulting in corrupted characters
        auto result = downloader.get(html);

        if (result.status.code == 304) {
            // No update found
            return false;
        }
        else if (result.code == 404) {
            throw new ThreadNotFoundException(url);
        }
        else if (result.code != 200) {
            throw new Exception("Error downloading thread: " ~ text(result.code, " ", result.reason));
        }

        return true;
    }

    protected void downloadFiles() {
        import std.array : array;
        import std.range : chain;

        // Get all failed files and files awaiting download
        auto files = chain(failedFiles, filesToDownload).array();

        // Clear out file lists
        filesToDownload.length = 0;
        failedFiles.length = 0;

        if (files.length == 0) {
            // If there are no files, there is no need to do anything.
            return;
        }

        try {
            auto result = downloadManager.downloadFiles(files);

            failedFiles ~= result.failed;
        }
        catch (Exception ex) {
            // If download process bombs, add all files to the failed list
            failedFiles ~= files;
            throw ex;
        }
    }

    protected void processHTML(in const(char)[] html) {
        import std.file;
        import std.path;

        const(char)[] outputHTML;

        if (_parser.supportsUpdate && _threadHTMLPath.exists()) {
            /* If the parser supports updating (merging) threads
               and the output file already exists, update the existing
               file with new posts from the HTML. */
            auto baseHTML = readHTML(_threadHTMLPath);
            auto baseThread = this._parser.parseThread(baseHTML);

            auto updateResult = baseThread.update(html);

            // Process new links
            this.processLinks(updateResult.newLinks);

            if (this.threadUpdated !is null)
                this.threadUpdated(updateResult);

            outputHTML = baseThread.getHtml();
        }
        else {
            /* If the output file was not found, parse and process it
               in its entirety. */
            auto thread = this._parser.parseThread(html);
            auto links = thread.getLinks();

            // Process links
            this.processLinks(links);

            outputHTML = thread.getHtml();
        }

        // Purge scripts
        outputHTML = purgeScripts(outputHTML);

        // Write resulting HTML to output file
        std.file.write(_threadHTMLPath, outputHTML);
    }

    private void processLinks(ILink[] links) {
        import std.file;

        auto pBaseURL = _url.parseURL();

        string[] knownUrls;
        foreach(link; links) {
            auto absoluteUrl = (pBaseURL ~ link.url).toString();

            if (link.tag == "script") {
                // Purge all script links, lest they cause extreme slowness in loading saved HTMLs
                link.url = "";
                continue;
            }

            if (!absoluteUrl.linkHasExtension(_downloadExtensions))
                continue;

            string localPath;
            try {
                localPath = mapURL(absoluteUrl);
            }
            catch (Exception) {
                // Not a valid URL - ignore it
                continue;
            }

            auto fullLocalPath = buildPath(_path, localPath);

            // Update link to local relative path, replacing dir separators with forward slashes
            link.url = localPath.replace(dirSeparator, "/");

            if (knownUrls.canFind(absoluteUrl))
                continue;

            knownUrls ~= absoluteUrl;

            // If destination file already exists, there is no need to download it
            if (fullLocalPath.exists())
                continue;

            // Add links to list of files to download
            filesToDownload ~= DownloadFile(absoluteUrl, fullLocalPath);
        }
    }
}
