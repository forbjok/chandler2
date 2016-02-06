module chandl.parsers.basic;

import html;

import chandl.threadparser;
import chandl.utils.linkfinder;

class BasicThread : IThread {
    private {
        Document _document;
        Node* _threadNode;
    }

    this(in char[] html) {
        _document = createDocument(html);
    }

    ILink[] getLinks() {
        auto links = findLinks(&_document, _document.root);
        return links;
    }

    const(char)[] getHtml() {
        return _document.root.html;
    }

    UpdateResult update(in char[] newHtml) {
        // Update not supported
        throw new Exception("Update not supported.");
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

    IThread parseThread(in char[] html) {
        return new BasicThread(html);
    }
}
