import std.conv;
import std.datetime;
import std.net.curl;
import std.stdio;

import downloader;
import fourchan;
import linkfilter;
import threadparser;
import reurl;
import urlmapper;

class ChandlerThread {
    private string _url;
    private string _path;
    private IThreadParser _parser;
    private LinkFilter _linkFilter;
    private IURLMapper _urlMapper;
    private IDownloader _downloader;

    @property string url() {
        return this._url;
    }

    @property string path() {
        return this._path;
    }

    @property string[] downloadExtensions() {
        return this._linkFilter.extensions;
    }

    void delegate(in char[] html, in SysTime time) threadDownloaded;

    this(in char[] url, in char[] path) {
        this._url = url.to!string;
        this._path = path.to!string;

        this._parser = new FourChanThreadParser();
        this._linkFilter = new LinkFilter();
        this._urlMapper = new URLMapper();
        this._downloader = new Downloader();
    }

    void includeExtension(in string extension) {
        this._linkFilter.addExtension(extension);
    }

    void download() {
        import std.datetime;
        import std.path;

        auto html = get(this._url);
        auto thread = this._parser.parseThread(this._url, html);
        auto links = thread.getLinks();
        auto pBaseURL = this._url.parseURL();

        foreach(link; links) {
            auto absoluteUrl = (pBaseURL ~ link.url).toString();

            if (!this._linkFilter.match(absoluteUrl))
                continue;

            auto path = this._urlMapper.mapURL(absoluteUrl);
            auto destinationPath = buildPath(this._path, path);

            try {
                this._downloader.download(absoluteUrl, destinationPath);
            }
            catch(Exception ex) {
                writefln("Failed to download file: [%s]: %s.", absoluteUrl, ex.msg);
                continue;
            }

            link.url = path;
        }

        auto now = Clock.currTime(UTC());

        if (this.threadDownloaded !is null)
            this.threadDownloaded(html, now);

        std.file.write(buildPath(this._path, "thread.html"), thread.getHtml());
    }
}
