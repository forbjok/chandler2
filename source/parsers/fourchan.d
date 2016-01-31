import std.algorithm;
import std.array;
import std.conv;

import threadparser;
import linkfinder;

import html;
import reurl;

private int getPostId(in Node* node) {
    import std.regex;

    auto re = regex(`pc(\d+)`);

    auto id = node.attr("id");
    auto m = id.matchFirst(re);
    if (m.empty)
        throw new Exception("Node is not a post container!");

    return m[1].to!int;
}

class FourChanThread : IThread {
    private {
        Document _document;
        Node* _threadNode;
    }

    this(in char[] html) {
        this._document = createDocument(html);

        this._threadNode = this._document.querySelector("div.thread");
    }

    ILink[] getLinks() {
        auto doc = this._document;

        auto links = findLinks(&doc, doc.root);
        return links;
    }

    const(char)[] getHtml() {
        return this._document.root.html;
    }

    UpdateResult update(in char[] newHtml) {
        import std.algorithm.iteration;
        import std.algorithm.setops;
        import std.stdio;

        ILink[] newLinks;

        writeln("GOP");
        auto oldPosts = this.getAllPosts()
            .map!(p => p.getPostId())
            .array();

        writeln("GNP");
        auto newThread = new FourChanThread(newHtml);
        auto newPosts = newThread.getAllPosts()
            .map!(p => p.getPostId())
            .array();

        auto addedPosts = setDifference(newPosts, oldPosts).array();

        writeln("Added posts (", oldPosts.length , " => ", newPosts.length , "): ", addedPosts);

        if (addedPosts.length == 0) {
            return new UpdateResult(newLinks);
        }

        writeln("FCA");
        // Find common ancestor post
        Node* oldCommonAncestor;
        auto newCommonAncestor = newThread.getPost(addedPosts[0]);
        while (oldCommonAncestor is null && newCommonAncestor !is null) {
            oldCommonAncestor = this.getPost(newCommonAncestor.getPostId());
            newCommonAncestor = newCommonAncestor.previousSibling;
            writeln("NCA ", newCommonAncestor);
        }

        if (oldCommonAncestor is null) {
            throw new Exception("Common ancestor not found.");
        }

        writeln("FoundCA");
        foreach(postId; addedPosts) {
            auto addedPost = newThread.getPost(postId);
            writeln("a");
            auto dummyElement = this._document.createElement("div");
            writeln("b");
            dummyElement.html = addedPost.outerHTML;
            auto newOldPost = dummyElement.firstChild();
            writeln("c");

            writeln("APC ", postId);
            this._threadNode.appendChild(newOldPost);

            newLinks ~= findLinks(&this._document, newOldPost);
        }

        auto result = new UpdateResult(newLinks);
        return result;
    }

    private Node*[] getAllPosts() {
        return this._threadNode.children().map!(p => cast(Node*) p).array();
    }

    /*
    private bool hasPost(int id) {
        auto postNode = this._document.querySelector("#pc%d".format(id), this._threadNode);

        return postNode !is null;
    }*/

    private Node* getPost(int id) {
        import std.format;

        auto postNode = this._document.querySelector("#pc%d".format(id), this._threadNode);
        /*if (postNode is null) {
            throw new PostNotFoundException(id);
        }*/

        return postNode;
    }
}

class FourChanThreadParser : IThreadParser {
    IThread parseThread(in char[] html) {
        return new FourChanThread(html);
    }
}
