module chandl.parsers.basic;

import std.conv : to;

import html;

import chandl.threadparser;
import chandl.utils.linkfinder;

class BasicThread : IThread {
    private {
        Document _document;
        Node* _threadNode;
    }

    this(in const(char)[] html) {
        _document = createDocument(html);
    }

    ILink[] getLinks() {
        auto links = findLinks(&_document, _document.root);
        return links;
    }

    const(char)[] getHtml() {
        return _document.root.html;
    }

    UpdateResult update(in const(char)[] newHtml) {
        // Update not supported
        throw new Exception("Update not supported.");
    }

    bool isDead() {
        return false;
    }
}

class BasicThreadParser : IThreadParser {
    static this() {
        import chandl.parsers;
        registerParser("basic", new this());
    }

    @property bool supportsUpdate() {
        return false;
    }

    IThread parseThread(in const(char)[] html) {
        return new BasicThread(html);
    }
}
