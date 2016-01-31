import std.format;

interface IThread {
    const(char)[] getHtml();
    ILink[] getLinks();

    UpdateResult update(in char[] newHtml);
}

interface ILink {
    @property string tag();
    @property string attr();
    @property string url();
    @property string url(in string value);
}

interface IThreadParser {
    IThread parseThread(in char[] html);
}

class UpdateResult {
    ILink[] newLinks;

    this(ILink[] newLinks) {
        this.newLinks = newLinks;
    }
}

class PostNotFoundException : Exception {
    this(int postId) {
        super("Post not found: %d".format(postId));
    }
}
