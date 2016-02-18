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

    this(in const(char)[] html) {
        _document = createDocument(html);
    }

    protected abstract Node*[] getAllPosts();
    protected abstract Node* getPost(in ulong id);
    protected abstract ulong getPostId(in Node* postElement);
    protected abstract void appendPost(Node* newPostElement);
    protected abstract MergingThread parseThread(in const(char)[] html);

    ILink[] getLinks() {
        auto links = findLinks(&_document, _document.root);
        return links;
    }

    const(char)[] getHtml() {
        return _document.root.html;
    }

    UpdateResult update(in const(char)[] newHtml) {
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

                // Clone the new post into this HTML document
                auto newPost = _document.clone(updatePost);

                // Append new post to thread
                appendPost(newPost);

                // Find links in the newly appended post and add them to the list
                newLinks ~= findLinks(&_document, newPost);
            }
        }

        return UpdateResult(newPostsIds, newLinks);
    }
}
