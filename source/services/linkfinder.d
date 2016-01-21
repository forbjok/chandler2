import std.algorithm;
import std.array;
import std.conv;

import threadparser;

import html;

class LinkFinder {
    private class Link : ILink {
        private Node* node;
        private string attrname;

        this(Node* node, in string attrname) {
            this.node = node;
            this.attrname = attrname;
        }

        @property string url() {
            return this.node.attr(this.attrname).to!string;
        }

        @property string url(in string value) {
            this.node.attr(this.attrname, value);
            return value;
        }
    }

    ILink[] findLinks(Document* document, Node* node) {
        ILink[] links;

        void addLink(Node* node, in string attrname) {
            auto url = node.attr(attrname).to!string;

            /* Filter "trash" links, such as:
               - Blank strings
               - Fragment-only links
               - Links without a filename (ending in "/")
               - Javascript links */
            if (!isFileLink(url))
                return;

            links ~= new Link(node, attrname);
        }

        /* Retrieve all links from the HTML in their raw form */

        foreach(e; document.querySelectorAll("link", node)) {
            addLink(e, "href");
        }

        foreach(e; document.querySelectorAll("script", node)) {
            addLink(e, "src");
        }

        foreach(e; document.querySelectorAll("a", node)) {
            addLink(e, "href");
        }

        foreach(e; document.querySelectorAll("img", node)) {
            addLink(e, "src");
        }

        return links;
    }

    private bool isFileLink(in string link) {
        if (link.length == 0)
            return false;

        if (link.startsWith("#"))
            return false;

        if (link.endsWith("/"))
            return false;

        if (link.startsWith("javascript:"))
            return false;

        return true;
    }
}
