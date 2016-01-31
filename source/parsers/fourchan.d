import std.algorithm;
import std.array;
import std.conv;

import threadparser;
import linkfinder;

import html;
import reurl;

class FourChanThread : IThread {
    private string _url;
    private Document _document;
    private Node* _threadNode;

    this(in string url, in char[] html) {
        this._url = url;
        this._document = createDocument(html);

        this._threadNode = this._document.querySelector("div.thread");
    }

    ILink[] getLinks() {
        auto doc = this._document;
        auto rootURL = this._url.parseURL();

        auto links = findLinks(&doc, doc.root);
        return links;
    }

    const(char)[] getHtml() {
        return this._document.root.html;
    }

    UpdateResult update(in char[] newHtml) {
        string[] newLinks;

        auto result = new UpdateResult(newLinks);
        return result;
    }

    private Node*[] getAllPosts() {
        Node*[] posts;
        foreach(node; this._threadNode.children()) {
            posts ~= node;
        }

        return posts;
    }

    private Node* getPost(int id) {
        auto postNode = this._document.querySelector("div.postContainer", this._threadNode);

        return postNode;
    }
}

class FourChanThreadParser : IThreadParser {
    IThread parseThread(in string url, in char[] html) {
        return new FourChanThread(url, html);
    }
}
