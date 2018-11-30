module chandl.parsers.fourchan;

import std.algorithm;
import std.array;
import std.conv : to;

import html;

import chandl.threadparser;
import chandl.parsers.mergingparser;

class FourChanThread : MergingThread {
    private {
        Node _threadNode;
    }

    this(in const(char)[] html) {
        super(html);

        _threadNode = _document.querySelector("div.thread");
        if (_threadNode is null)
            throw new ThreadParseException("Could not locate thread element.");
    }

    override Node[] getAllPosts() {
        // Get all post containers inside the thread node (which should be all posts)
        auto posts = this._document.querySelectorAll("div.postContainer", this._threadNode)
            .array();

        return posts;
    }

    override Node getPost(in ulong id) {
        import std.format;

        // Query post container element by ID
        auto postNode = this._document.querySelector("#pc%d".format(id), this._threadNode);

        return postNode;
    }

    override ulong getPostId(in Node postElement) {
        import std.regex;

        auto re = regex(`pc(\d+)`);

        auto id = postElement.attr("id");
        auto m = id.matchFirst(re);
        if (m.empty)
            throw new Exception("Node is not a post container.");

        return m[1].to!int;
    }

    override void appendPost(Node newPostElement) {
        // Append the new post to the thread node
        _threadNode.appendChild(newPostElement);
    }

    override MergingThread parseThread(in const(char)[] html) {
        return new FourChanThread(html);
    }

    bool isDead() {
        return this._document.querySelector("img.archivedIcon", this._threadNode) !is null;
    }
}

class FourChanThreadParser : IThreadParser {
    static this() {
        import chandl.parsers;
        registerParser("4chan", new typeof(this)());
    }

    @property bool supportsUpdate() {
        return true;
    }

    IThread parseThread(in const(char)[] html) {
        return new FourChanThread(html);
    }
}

unittest {
    import dunit.toolkit;

    // A single post
    enum testHTML1 = `<div class=thread><div id=pc100001 class=postContainer></div></div>`;

    // Two posts
    enum testHTML2 = `<div class=thread><div id=pc100001 class=postContainer></div><div id=pc100002 class=postContainer></div></div>`;

    // The second post has been deleted, and a third new one added
    enum testHTML3 = `<div class=thread><div id=pc100001 class=postContainer></div><div id=pc100003 class=postContainer></div></div>`;
    enum testHTML3Merged = `<div class=thread><div id=pc100001 class=postContainer></div><div id=pc100002 class=postContainer></div><div id=pc100003 class=postContainer></div></div>`;

    // Parse HTML1
    auto thread = new FourChanThread(testHTML1);

    // Assert that getHtml() returns same HTML
    thread.getHtml().assertEqual(testHTML1);

    // Update thread with HTML2 and assert that it matches HTML2
    thread.update(testHTML2);
    thread.getHtml().assertEqual(testHTML2);

    // Update thread with HTML3 and assert that the resulting HTML contains all posts
    thread.update(testHTML3);
    thread.getHtml().assertEqual(testHTML3Merged);
}
