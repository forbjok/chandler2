import std.conv;
import std.datetime : SysTime;
import std.net.curl;
import std.stdio;

import downloader;
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

class ChandlerThread {
    private {
        string _url;
        string _path;
        IThreadParser _parser;
        string[] _downloadExtensions;
        IDownloader _downloader;
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

    string delegate(in char[] url) mapURL;

    void delegate(in char[] html, in SysTime time) threadDownloaded;

    this(in char[] url, in char[] path) {
        import std.functional;

        this._url = url.to!string;
        this._path = path.to!string;

        this._parser = new FourChanThreadParser();
        this._downloader = new Downloader();

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

        auto html = get(this._url);

        auto now = Clock.currTime(UTC());

        if (this.threadDownloaded !is null)
            this.threadDownloaded(html, now);

        this.process(html);
    }

    protected void process(in char[] html) {
        import std.path;

        auto thread = this._parser.parseThread(this._url, html);
        auto links = thread.getLinks();
        auto pBaseURL = this._url.parseURL();

        //foreach(p; thread.get)

        foreach(link; links) {
            auto absoluteUrl = (pBaseURL ~ link.url).toString();

            if (!absoluteUrl.linkHasExtension(this._downloadExtensions))
                continue;

            auto path = this.mapURL(absoluteUrl);
            auto destinationPath = buildPath(this._path, path);

            try {
                this._downloader.download(absoluteUrl, destinationPath);
            }
            catch(Exception ex) {
                writefln("Failed to download file: [%s]: %s.", absoluteUrl, ex.msg);
                continue;
            }

            link.url = path.to!string;
        }

        std.file.write(buildPath(this._path, "thread.html"), thread.getHtml());
    }
}
