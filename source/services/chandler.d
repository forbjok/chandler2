import std.conv;
import std.datetime : SysTime;
import std.net.curl;

import fourchan;
import linkfilter;
import threadparser;
import reurl;

string defaultMapURL(in char[] url) {
    import std.path;
    import std.string;

    auto purl = text(url).parseURL();
    auto path = purl.hostname ~ purl.path.replace("/", dirSeparator);

    return path.to!string;
}

void curlDownload(in string url, in string destinationPath) {
    import std.file;
    import std.net.curl;
    import std.path;

    // Ensure that destination directory exists
    auto destinationDir = destinationPath.dirName();
    mkdirRecurse(destinationDir);

    // If an exception is thrown during download, delete the broken file
    scope(failure) std.file.remove(destinationPath);

    // Download file
    download(url, destinationPath);
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

    // Customizable functions
    string delegate(in char[] url) mapURL;
    void delegate(in string url, in string destinationPath) downloadLink;

    // Events
    void delegate(in char[] html, in SysTime time) threadDownloaded;
    void delegate(in UpdateResult updateResult) threadUpdated;
    void delegate(in char[] url, in char[] destinationFile) linkDownloaded;
    void delegate(in char[] url, in char[] message) linkDownloadFailed;

    this(in char[] url, in char[] path) {
        import std.functional;

        this._url = url.to!string;
        this._path = path.to!string;

        this._parser = new FourChanThreadParser();

        this.mapURL = toDelegate(&defaultMapURL);
        this.downloadLink = toDelegate(&curlDownload);
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

        auto html = get(this._url);

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

        foreach(link; links) {
            auto absoluteUrl = (pBaseURL ~ link.url).toString();

            if (!absoluteUrl.linkHasExtension(this._downloadExtensions))
                continue;

            auto path = this.mapURL(absoluteUrl);
            auto destinationPath = buildPath(this._path, path);

            // Update link to local relative path
            link.url = path.to!string;

            // If destination file already exists, skip it
            if (destinationPath.exists())
                continue;

            try {
                // Download file
                this.downloadLink(absoluteUrl, destinationPath);

                if (this.linkDownloaded !is null)
                    this.linkDownloaded(absoluteUrl, destinationPath);
            }
            catch(Exception ex) {
                import std.format;

                if (this.linkDownloadFailed !is null)
                    this.linkDownloadFailed(absoluteUrl, ex.msg);

                continue;
            }
        }
    }
}
