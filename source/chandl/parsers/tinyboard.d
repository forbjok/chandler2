module chandl.parsers.tinyboard;

import std.algorithm;
import std.array;
import std.conv : text, to;
import std.range : dropOne;

import html;
import reurl;

import chandl.threadparser;
import chandl.utils.linkfinder;

private bool hasClass(in Node* node, in string cls) {
    auto classes = node.attr("class").split();
    if (classes.canFind(cls)) {
        return true;
    }

    return false;
}

private int getPostId(in Node* node) {
    import std.regex;

    auto re = regex(`reply_(\d+)`);

    auto id = node.attr("id");
    auto m = id.matchFirst(re);
    if (m.empty) {
        if (node.hasClass("op")) {
            // If the post is the OP post, it does not have an ID, so just return 0 as its post number
            return 0;
        }

        throw new Exception("Node is not a post.");
    }

    return m[1].to!int;
}

class TinyboardThread : IThread {
    private {
        Document _document;
        Node* _threadNode;
    }

    this(in char[] html) {
        this._document = createDocument(html);

        /* Tinyboard doesn't have a class for the thread container,
           so just get the first post's parent element.
           It should be the thread container */
        this._threadNode = this._document.querySelector("div.post").parent;
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

        ILink[] newLinks;

        // Get all post IDs in this thread
        auto posts = this.getAllPosts()
            .map!(p => p.getPostId())
            .array();

        // Parse the updated thread HTML
        auto updateThread = new TinyboardThread(newHtml);

        // Get all post IDs in the updated thread
        auto updatePosts = updateThread.getAllPosts()
            .map!(p => p.getPostId())
            .array();

        // Get a list of all new post IDs
        auto newPostsIds = setDifference(updatePosts, posts).array();

        if (newPostsIds.length > 0) {
            // Create convenience variables
            auto doc = &this._document;

            /* In Tinyboard, one can not simply append new posts to the thread node.
               Instead, one must insert them after the last post.
               This is because some genius decided it was agood idea to put
               a bunch of page footer junk after the last post, inside the thread element.
               Go figure. */
            auto lastPostNode = getPost(posts[$-1]);
            debug assert(lastPostNode !is null);
            auto firstFooterElement = lastPostNode.nextSibling;
            debug assert(firstFooterElement !is null);

            foreach(newPostId; newPostsIds) {
                auto updatePost = updateThread.getPost(newPostId);

                /* Because there doesn't seem to be a way to create a new element
                   from existing HTML in htmld, create an empty dummy element and set its
                   inner HTML to the HTML of the updated post and get the newly
                   created post element by retrieving its first child element. */
                auto dummyElement = doc.createElement("div");
                dummyElement.html = updatePost.outerHTML;
                auto newPost = dummyElement.firstChild();

                // Insert new post before first footer element (effectively always right after the last post)
                doc.createElement("br").insertAfter(firstFooterElement);
                newPost.insertAfter(firstFooterElement);

                // Find links in the newly appended post and add them to the list
                newLinks ~= findLinks(doc, newPost);
            }
        }

        return UpdateResult(newPostsIds, newLinks);
    }

    private Node*[] getAllPosts() {
        // Get all post containers inside the thread node (which should be all posts)
        auto posts = this._document.querySelectorAll("div.post", this._threadNode)
            .map!(p => cast(Node*) p)
            .array();

        return posts;
    }

    private Node* getPost(in int id) {
        import std.format;

        if (id == 0) {
            return _document.querySelector("div.op", _threadNode);
        }

        // Query post container element by ID
        auto postNode = this._document.querySelector("#reply_%d".format(id), this._threadNode);

        return postNode;
    }
}

class TinyboardThreadParser : IThreadParser {
    static this() {
        import chandl.parsers;
        registerParser("tinyboard", new this());
    }

    IThread parseThread(in char[] html) {
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
