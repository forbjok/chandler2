module chandl.parsers.fourchan;

import std.algorithm;
import std.array;
import std.conv : to;

import html;
import reurl;

import chandl.threadparser;
import chandl.utils.linkfinder;

private int getPostId(in Node* node) {
    import std.regex;

    auto re = regex(`pc(\d+)`);

    auto id = node.attr("id");
    auto m = id.matchFirst(re);
    if (m.empty)
        throw new Exception("Node is not a post container.");

    return m[1].to!int;
}

class FourChanThread : IThread {
    private {
        Document _document;
        Node* _threadNode;
    }

    this(in char[] html) {
        _document = createDocument(html);

        _threadNode = _document.querySelector("div.thread");
        if (_threadNode is null)
            throw new ThreadParseException("Could not locate thread element.");
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
        auto updateThread = new FourChanThread(newHtml);

        // Get all post IDs in the updated thread
        auto updatePosts = updateThread.getAllPosts()
            .map!(p => p.getPostId())
            .array();

        // Get a list of all new post IDs
        auto newPostsIds = setDifference(updatePosts, posts).array();

        // Create convenience variables
        auto doc = &this._document;
        auto threadNode = this._threadNode;

        if (newPostsIds.length > 0) {
            foreach(newPostId; newPostsIds) {
                auto updatePost = updateThread.getPost(newPostId);

                /* Because there doesn't seem to be a way to create a new element
                   from existing HTML in htmld, create an empty dummy element and set its
                   inner HTML to the HTML of the updated post and get the newly
                   created post element by retrieving its first child element. */
                auto dummyElement = doc.createElement("div");
                dummyElement.html = updatePost.outerHTML;
                auto newPost = dummyElement.firstChild();

                // Append the new post to the thread node
                threadNode.appendChild(newPost);

                // Find links in the newly appended post and add them to the list
                newLinks ~= findLinks(doc, newPost);
            }
        }

        return UpdateResult(newPostsIds, newLinks);
    }

    private Node*[] getAllPosts() {
        // Get all post containers inside the thread node (which should be all posts)
        auto posts = this._document.querySelectorAll("div.postContainer", this._threadNode)
            .map!(p => cast(Node*) p)
            .array();

        return posts;
    }

    private Node* getPost(in int id) {
        import std.format;

        // Query post container element by ID
        auto postNode = this._document.querySelector("#pc%d".format(id), this._threadNode);

        return postNode;
    }
}

class FourChanThreadParser : IThreadParser {
    static this() {
        import chandl.parsers;
        registerParser("4chan", new this());
    }

    @property bool supportsUpdate() {
        return true;
    }

    IThread parseThread(in char[] html) {
        return new FourChanThread(html);
    }
}

unittest {
    import dunit.toolkit;

    // A single post
    enum testHTML1 = `<div class="thread"><div id="pc100001" class="postContainer"></div></div>`;

    // Two posts
    enum testHTML2 = `<div class="thread"><div id="pc100001" class="postContainer"></div><div id="pc100002" class="postContainer"></div></div>`;

    // The second post has been deleted, and a third new one added
    enum testHTML3 = `<div class="thread"><div id="pc100001" class="postContainer"></div><div id="pc100003" class="postContainer"></div></div>`;
    enum testHTML3Merged = `<div class="thread"><div id="pc100001" class="postContainer"></div><div id="pc100002" class="postContainer"></div><div id="pc100003" class="postContainer"></div></div>`;

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
