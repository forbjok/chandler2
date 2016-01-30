import std.algorithm;
import std.array;
import std.conv;

import threadparser;
import linkfinder;

import html;
import reurl;

class FourChanThread : IThread {
    private string url;
    private Document document;

    this(in string url, in char[] html) {
        this.url = url;
        this.document = createDocument(html);
    }

    ILink[] getLinks() {
        auto doc = this.document;
        auto rootURL = this.url.parseURL();

        auto links = findLinks(&doc, doc.root);
        return links;
    }

    const(char)[] getHtml() {
        return this.document.root.html;
    }

    UpdateResult update(in char[] newHtml) {
        string[] newLinks;

        auto result = new UpdateResult(newLinks);
        return result;
    }
}

class FourChanThreadParser : IThreadParser {
    IThread parseThread(in string url, in char[] html) {
        return new FourChanThread(url, html);
    }
}
