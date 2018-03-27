module chandl.utils.linkfinder;

import std.algorithm;
import std.array;
import std.conv : to;

import html;

import chandl.threadparser;

struct LinkTag {
    string tag;
    string[] linkAttributes;
}

enum LinkTags = [
    LinkTag("link", ["href"]),
    LinkTag("script", ["src"]),
    LinkTag("a", ["href"]),
    LinkTag("img", ["src"]),
];


private class Link : ILink {
    private Node _node;
    private string _attr;
    private string _originalValue;

    this(Node node, in string attr) {
        _node = node;
        _attr = attr;
        _originalValue = _node.attr(_attr).to!string;
    }

    @property string tag() {
        return _node.tag.to!string;
    }

    @property string attr() {
        return _attr;
    }

    @property string url() {
        return _node.attr(_attr).to!string;
    }

    @property string url(in string value) {
        // Store original value
        _node.attr("data-original-" ~ _attr, _originalValue);

        _node.attr(_attr, value);
        return value;
    }
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

ILink[] findLinks(Document document, Node node) {
    ILink[] links;

    void addLink(Node node, in string attrname) {
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
