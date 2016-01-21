import std.conv;
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

    this(in string url, in string path) {
        this._url = url;
        this._path = path;

        this._parser = new FourChanThreadParser();
        this._linkFilter = new LinkFilter();
        with (this._linkFilter) {
            addExtension("ico");
            addExtension("css");
            addExtension("png");
            addExtension("jpg");
            addExtension("gif");
            addExtension("webm");
        }

        this._urlMapper = new URLMapper();
        this._downloader = new Downloader();
    }

    void includeExtension(in string extension) {
        this._linkFilter.addExtension(extension);
    }

    void download() {
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

        std.file.write(buildPath(this._path, "thread.html"), thread.getHtml());
    }
}

struct ThreadConfig {
    string url;
    string[] downloadExtensions;
}

ChandlerThread loadChandlerProject(in char[] path) {
    return new ChandlerThread("","");
}

void saveProject(ChandlerThread chandlerThread) {
    import std.file;
    import stdx.data.json;
    import std.path;

    auto downloadDir = chandlerThread.path;
    auto projectDir = buildPath(downloadDir, ".chandler");
    auto threadJsonPath = buildPath(projectDir, "thread.json");

    ThreadConfig threadConfig;
    with (threadConfig) {
        url = chandlerThread.url;
        downloadExtensions = chandlerThread.downloadExtensions;
    }

    // If project dir does not exist, create it
    if (!projectDir.exists())
        mkdirRecurse(projectDir);
}
