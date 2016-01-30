import std.algorithm;
import std.array;
import std.conv : text;
import std.range;
import std.regex;

import reurl;

@safe:

bool linkHasExtension(in char[] link, in string[] extensions) {
    auto url = text(link).parseURL();
    auto filterExtensions = regex(`/[\w\-\./]+\.(?:` ~ extensions.join("|") ~ `)`);

    auto absoluteUrl = url ~ text(link);
    auto m = absoluteUrl.path.matchFirst(filterExtensions);

    return !m.empty;
}

unittest {
    immutable string link1 = "http://test.com/dir/index.html?param=value#fragment";
    immutable string link2 = "http://test.com/dir/image1.png?param=value#fragment";
    immutable string link3 = "http://test.com/dir/image2.jpg?param=value#fragment";
    immutable string[] extensions = ["png", "jpg"];

    assert(!link1.linkHasExtension(extensions));
    assert(link2.linkHasExtension(extensions));
    assert(link3.linkHasExtension(extensions));
}
