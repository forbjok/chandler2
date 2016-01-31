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

        writeln("Added posts (", posts.length , " => ", updatePosts.length , "): ", newPostsIds);

        if (newPostsIds.length > 0) {
            foreach(newPostId; newPostsIds) {
                auto updatePost = updateThread.getPost(newPostId);

                /* Because there doesn't seem to be a way to create a new element
                   from existing HTML in htmld, create an empty dummy element and set its
                   inner HTML to the HTML of the updated post and get the newly
                   created post element by retrieving its first child element. */
                auto dummyElement = this._document.createElement("div");
                dummyElement.html = updatePost.outerHTML;
                auto newPost = dummyElement.firstChild();

                // Append the new post to the thread node
                this._threadNode.appendChild(newPost);

                // Find links in the newly appended post and add them to the list
                newLinks ~= findLinks(&this._document, newPost);
            }
        }

        return UpdateResult(newPostsIds, newLinks);
    }

    private Node*[] getAllPosts() {
        return this._threadNode.children().map!(p => cast(Node*) p).array();
    }

    private Node* getPost(int id) {
        import std.format;

        auto postNode = this._document.querySelector("#pc%d".format(id), this._threadNode);
        return postNode;
    }
}

class FourChanThreadParser : IThreadParser {
    IThread parseThread(in char[] html) {
        return new FourChanThread(html);
    }
}
