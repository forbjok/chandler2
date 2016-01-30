import std.algorithm;
import std.array;
import std.conv;

import threadparser;

import html;

struct HTag {
    string tag;
    string[] linkAttributes;
}

enum LinkTags = [
    HTag("link", ["href"]),
    HTag("script", ["src"]),
    HTag("a", ["href"]),
    HTag("img", ["src"]),
];

class LinkFinder {
    private class Link : ILink {
        private Node* _node;
        private string _attr;

        this(Node* node, in string attr) {
            this._node = node;
            this._attr = attr;
        }

        @property string tag() {
            return this._node.tag.to!string;
        }

        @property string attr() {
            return this._attr;
        }

        @property string url() {
            return this._node.attr(this._attr).to!string;
        }

        @property string url(in string value) {
            this._node.attr(this._attr, value);
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
        foreach(linkTag; LinkTags) {
            foreach(e; document.querySelectorAll(linkTag.tag, node)) {
                foreach(linkAttr; linkTag.linkAttributes) {
                    addLink(e, linkAttr);
                }
            }
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
