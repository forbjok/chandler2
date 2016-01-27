import std.algorithm;
import std.array;
import std.range;
import std.regex;

import reurl;

@safe:

interface ILinkFilter {
    bool match(in string link);
}

class LinkFilter : ILinkFilter {
    private string[] _matchExtensions;

    @property string[] extensions() {
        return this._matchExtensions;
    }

    void addExtension(in string extension) {
        if (this._matchExtensions.canFind(extension)) {
            // If this extension already exists, don't add it again
            return;
        }

        this._matchExtensions ~= extension;
    }

    bool match(in string link) {
        auto url = link.parseURL();
        auto filterExtensions = regex(`/[\w\-\./]+\.(?:` ~ this._matchExtensions.join("|") ~ `)`);

        auto absoluteUrl = url ~ link;
        auto m = absoluteUrl.path.matchFirst(filterExtensions);

        return !m.empty;
    }
}

unittest {
    immutable string link1 = "http://test.com/dir/index.html?param=value#fragment";
    immutable string link2 = "http://test.com/dir/image1.png?param=value#fragment";
    immutable string link3 = "http://test.com/dir/image2.jpg?param=value#fragment";

    auto filter = new LinkFilter();
    filter.addExtension("png");
    filter.addExtension("jpg");

    assert(!filter.match(link1));
    assert(filter.match(link2));
    assert(filter.match(link3));
}
