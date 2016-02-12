module chandl.parsers.tinyboard;

import std.algorithm;
import std.array;
import std.conv : to;

import html;

import chandl.threadparser;
import chandl.parsers.mergingparser;

private bool hasClass(in Node* node, in string cls) {
    auto classes = node.attr("class").split();
    if (classes.canFind(cls)) {
        return true;
    }

    return false;
}

class TinyboardThread : MergingThread {
    private {
        Node* _threadNode;
        Node* _lastPostElement;
    }

    this(in const(char)[] html) {
        super(html);

        /* Tinyboard doesn't have a class for the thread container,
           so just get the first post's parent element.
           It should be the thread container */
        auto firstPost = _document.querySelector("div.post");
        if (firstPost is null)
            throw new ThreadParseException("Could not locate first post.");

        _threadNode = firstPost.parent;
        if (_threadNode is null)
            throw new ThreadParseException("Could not locate thread element.");

        /* In Tinyboard, one can not simply append new posts to the thread node.
           Instead, one must insert them after the last post.
           This is because some genius decided it was a good idea to put
           a bunch of page footer junk after the last post, inside the thread element.
           Go figure. */
        _lastPostElement = getAllPosts()[$-1];
        if (_lastPostElement is null)
            throw new ThreadParseException("Could not locate last post element.");
    }

    override Node*[] getAllPosts() {
        // Get all post containers inside the thread node (which should be all posts)
        auto posts = _document.querySelectorAll("div.post", _threadNode)
            .map!(p => cast(Node*) p)
            .array();

        return posts;
    }

    override Node* getPost(in ulong id) {
        import std.format;

        if (id == 0) {
            return _document.querySelector("div.op", _threadNode);
        }

        // Query post container element by ID
        auto postNode = _document.querySelector("#reply_%d".format(id), _threadNode);

        return postNode;
    }

    override ulong getPostId(in Node* postElement) {
        import std.regex;

        auto re = regex(`reply_(\d+)`);

        auto id = postElement.attr("id");
        auto m = id.matchFirst(re);
        if (m.empty) {
            if (postElement.hasClass("op")) {
                // If the post is the OP post, it does not have an ID, so just return 0 as its post number
                return 0;
            }

            throw new Exception("Node is not a post.");
        }

        return m[1].to!int;
    }

    override void appendPost(Node* newPostElement) {
        // Create and insert a <br> after the current last post
        auto brElement = _document.createElement("br");
        brElement.insertAfter(_lastPostElement);

        // Insert the new post after the <br>
        newPostElement.insertAfter(brElement);

        // Update last post element to the newly inserted post
        _lastPostElement = newPostElement;
    }

    override MergingThread parseThread(in const(char)[] html) {
        return new TinyboardThread(html);
    }
}

class TinyboardThreadParser : IThreadParser {
    static this() {
        import chandl.parsers;
        registerParser("tinyboard", new this());
    }

    @property bool supportsUpdate() {
        return true;
    }

    IThread parseThread(in const(char)[] html) {
        return new TinyboardThread(html);
    }
}

unittest {
    import dunit.toolkit;

    // A single post
    enum testHTML1 = `<div id="thread_1"><div class="post op"></div><br><br><hr></div>`;

    // Two posts
    enum testHTML2 = `<div id="thread_1"><div class="post op"></div><br><div id="reply_2" class="post reply"></div><br><br><hr></div>`;

    // The second post has been deleted, and a third new one added
    enum testHTML3 = `<div id="thread_1"><div class="post op"></div><br><div id="reply_3" class="post reply"></div><br><br><hr></div>`;
    enum testHTML3Merged = `<div id="thread_1"><div class="post op"></div><br><div id="reply_2" class="post reply"></div><br><div id="reply_3" class="post reply"></div><br><br><hr></div>`;

    // Parse HTML1
    auto thread = new TinyboardThread(testHTML1);

    // Assert that getHtml() returns same HTML
    thread.getHtml().assertEqual(testHTML1);

    // Update thread with HTML2 and assert that it matches HTML2
    thread.update(testHTML2);
    thread.getHtml().assertEqual(testHTML2);

    // Update thread with HTML3 and assert that the resulting HTML contains all posts
    thread.update(testHTML3);
    thread.getHtml().assertEqual(testHTML3Merged);
}
