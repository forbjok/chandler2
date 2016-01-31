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
        struct Post {
            Node* node;
            int id;

            this(Node* node) {
                this.node = node;
                this.id = node.getPostId();
            }
        }

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

        string[] newLinks;

        auto oldPosts = this.getAllPosts().map!(p => p.id).array();

        auto newThread = new FourChanThread(newHtml);
        auto newPosts = newThread.getAllPosts().map!(p => p.id).array();

        auto addedPosts = setDifference(newPosts, oldPosts);

        import std.stdio;
        writeln("Added posts (", oldPosts.length , " => ", newPosts.length , "): ", addedPosts);

        foreach(postId; addedPosts) {
            auto lastCommonAncestorPostId = oldPosts
                .filter!(p => p < postId)
                .array()[$-1];

            auto post = newThread.getPost(postId);
            auto oldCommonAncestor = this.getPost(lastCommonAncestorPostId);

            auto newOldPost = this._document.createElement("div");
            //newOldPost.html = post.node.html;

            writeln("CA ", lastCommonAncestorPostId);
            //oldCommonAncestor.node.insertAfter(newOldPost);
        }

        auto result = new UpdateResult(newLinks);
        return result;
    }

    private Post[] getAllPosts() {
        auto posts = this._threadNode.children()
            .map!(p => Post(p))
            .array()
            .sort!("a.id < b.id")
            .array();

        return posts;
    }

    private Post getPost(int id) {
        auto postNode = this._document.querySelector("div.postContainer", this._threadNode);

        return Post(postNode);
    }
}

class FourChanThreadParser : IThreadParser {
    IThread parseThread(in char[] html) {
        return new FourChanThread(html);
    }
}
