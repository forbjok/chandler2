module chandl.threaddownloader;

import std.algorithm.searching;
import std.conv : text, to;
import std.datetime : SysTime;
import std.path : buildPath;

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

string defaultMapURL(in string url) {
    import std.path : dirSeparator;
    import std.string;

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
        IThreadParser _parser;
        string[] _downloadExtensions = defaultDownloadExtensions;
    }

    @property string url() {
        return this._url;
    }

    @property string path() {
        return this._path;
    }

    @property string[] downloadExtensions() {
        return this._downloadExtensions;
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

    void download() {
        const(char)[] html;

        auto success = downloadThread(html);

        if (!success) {
            if (notChanged !is null) {
                notChanged();
            }

            return;
        }

        processHTML(html);
    }

    protected bool downloadThread(out const(char)[] html) {
        auto downloader = new FileDownloader(url);

        // TODO: Fix already UTF-8 encoded pages getting incorrectly UTF8-decoded, potentially resulting in corrupted characters
        auto result = downloader.get(html);

        if (result.status.code == 304) {
            // No update found
            return false;
        }
        else if (result.code != 200) {
            throw new Exception("Error downloading thread: " ~ text(result.code, " ", result.reason));
        }

        return true;
    }

    protected void processHTML(in const(char)[] html) {
        import std.file;
        import std.path;

        auto outputHTMLPath = buildPath(this._path, "thread.html");
        const(char)[] outputHTML;

        if (_parser.supportsUpdate && outputHTMLPath.exists()) {
            /* If the parser supports updating (merging) threads
               and the output file already exists, update the existing
               file with new posts from the HTML. */
            auto baseHTML = readHTML(outputHTMLPath);
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

        // Write resulting HTML to output file
        std.file.write(outputHTMLPath, outputHTML);
    }

    private void processLinks(ILink[] links) {
        import std.file;

        auto pBaseURL = this._url.parseURL();

        string[] knownUrls;
        DownloadFile[] filesToDownload;
        foreach(link; links) {
            auto absoluteUrl = (pBaseURL ~ link.url).toString();

            if (link.tag == "script") {
                // Purge all script links, lest they cause extreme slowness in loading saved HTMLs
                link.url = "";
                continue;
            }

            if (!absoluteUrl.linkHasExtension(this._downloadExtensions))
                continue;

            auto path = this.mapURL(absoluteUrl);
            auto destinationPath = buildPath(this._path, path);

            // Update link to local relative path
            link.url = path.to!string;

            if (knownUrls.canFind(absoluteUrl))
                continue;

            knownUrls ~= absoluteUrl;

            // If destination file already exists, there is no need to download it
            if (destinationPath.exists())
                continue;

            // Add to list of links to download
            filesToDownload ~= DownloadFile(absoluteUrl, destinationPath);
        }

        downloadManager.downloadFiles(filesToDownload);
    }
}
