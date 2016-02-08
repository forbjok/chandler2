module chandl.parsers.mergingparser;

import std.algorithm;
import std.array;
import std.conv : to;

import html;

import chandl.threadparser;
import chandl.utils.linkfinder;

abstract class MergingThread : IThread {
    protected {
        Document _document;
    }

    this(in char[] html) {
        _document = createDocument(html);
    }

    protected abstract Node*[] getAllPosts();
    protected abstract Node* getPost(in int id);
    protected abstract int getPostId(in Node* postElement);
    protected abstract void appendPost(Node* newPostElement);
    protected abstract MergingThread parseThread(in char[] html);

    ILink[] getLinks() {
        auto links = findLinks(&_document, _document.root);
        return links;
    }

    const(char)[] getHtml() {
        return _document.root.html;
    }

    UpdateResult update(in char[] newHtml) {
        import std.algorithm.iteration;
        import std.algorithm.setops;

        ILink[] newLinks;

        // Get all post IDs in this thread
        auto posts = this.getAllPosts()
            .map!(p => getPostId(p))
            .array();

        // Parse the updated thread HTML
        auto updateThread = parseThread(newHtml);

        // Get all post IDs in the updated thread
        auto updatePosts = updateThread.getAllPosts()
            .map!(p => getPostId(p))
            .array();

        // Get a list of all new post IDs
        auto newPostsIds = setDifference(updatePosts, posts).array();

        if (newPostsIds.length > 0) {
            foreach(newPostId; newPostsIds) {
                auto updatePost = updateThread.getPost(newPostId);

                /* Because there doesn't seem to be a way to create a new element
                   from existing HTML in htmld, create an empty dummy element and set its
                   inner HTML to the HTML of the updated post and get the newly
                   created post element by retrieving its first child element. */
                auto dummyElement = _document.createElement("div");
                dummyElement.html = updatePost.outerHTML;
                auto newPost = dummyElement.firstChild();

                // Append new post to thread
                appendPost(newPost);

                // Find links in the newly appended post and add them to the list
                newLinks ~= findLinks(&_document, newPost);
            }
        }

        return UpdateResult(newPostsIds, newLinks);
    }
}