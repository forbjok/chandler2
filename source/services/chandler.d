import std.algorithm.searching;
import std.conv;
import std.datetime : SysTime;
import std.net.curl;

import fourchan;
import linkfilter;
import threadparser;
import reurl;
import download;

struct DownloadFile {
    string url;
    string destinationPath;
}

interface IDownloadProgressTracker {
    void started(in DownloadFile[] files);
    void fileStarted(in DownloadFile file);
    void fileProgress(in short percent);
    void fileCompleted(in DownloadFile file);
    void completed();
}

string defaultMapURL(in char[] url) {
    import std.path;
    import std.string;

    auto purl = text(url).parseURL();
    auto path = purl.hostname ~ purl.path.replace("/", dirSeparator);

    return path.to!string;
}

const(char)[] curlGetURL(in char[] url) {
    import std.net.curl;

    return get(url);
}

class ChandlerThread {
    private {
        string _url;
        string _path;
        IThreadParser _parser;
        string[] _downloadExtensions;
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

    IDownloadProgressTracker downloadProgressTracker;

    // Customizable functions
    const(char)[] delegate(in char[] url) getURL;
    string delegate(in char[] url) mapURL;

    // Events
    void delegate(in char[] html, in SysTime time) threadDownloaded;
    void delegate(in UpdateResult updateResult) threadUpdated;
    void delegate(in char[] url, in char[] message) linkDownloadFailed;

    this(in char[] url, in char[] path) {
        import std.functional;

        this._url = url.to!string;
        this._path = path.to!string;

        this._parser = new FourChanThreadParser();

        this.getURL = toDelegate(&curlGetURL);
        this.mapURL = toDelegate(&defaultMapURL);
    }

    void includeExtension(in string extension) {
        import std.algorithm.searching;

        if (this._downloadExtensions.canFind(extension)) {
            // If this extension already exists, don't add it again
            return;
        }

        this._downloadExtensions ~= extension;
    }

    void download() {
        import std.datetime : Clock, UTC;

        auto html = this.getURL(this._url);

        auto now = Clock.currTime(UTC());

        if (this.threadDownloaded !is null)
            this.threadDownloaded(html, now);

        this.processHTML(html);
    }

    protected void processHTML(in char[] html) {
        import std.file;
        import std.path;

        auto outputHTMLPath = buildPath(this._path, "thread.html");
        const(char)[] outputHTML;

        if (outputHTMLPath.exists()) {
            /* If the output file already exists, update the existing
               file with new posts from the HTML. */
            auto baseHTML = readText(outputHTMLPath);
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
        DownloadFile[] downloadLinks;
        foreach(link; links) {
            auto absoluteUrl = (pBaseURL ~ link.url).toString();

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
            downloadLinks ~= DownloadFile(absoluteUrl, destinationPath);
        }

        downloadProgressTracker.started(downloadLinks);
        scope(exit) downloadProgressTracker.completed();

        foreach(dl; downloadLinks) {
            // Update progress step
            downloadProgressTracker.fileStarted(dl);

            try {
                // Download file
                downloadFile(dl.url, dl.destinationPath, (p) => downloadProgressTracker.fileProgress(p));

                downloadProgressTracker.fileCompleted(dl);
            }
            catch(Exception ex) {
                import std.format;

                if (this.linkDownloadFailed !is null)
                    this.linkDownloadFailed(dl.url, ex.msg);

                continue;
            }
        }
    }
}
