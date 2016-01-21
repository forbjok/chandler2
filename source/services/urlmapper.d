import std.path;
import std.string;

import reurl;

@safe:

/*
class URLMap {
    string url;
    string path;

    this(in string url, in string path) {
        this.url = url;
        this.path = path;
    }
}*/

interface IURLMapper {
    string mapURL(in string url);
}

class URLMapper : IURLMapper {
    string mapURL(in string url) {
        auto purl = url.parseURL();
        auto path = purl.hostname ~ purl.path.replace("/", dirSeparator);

        return path; //new URLMap(url, path);
    }
}
