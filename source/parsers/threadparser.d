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

struct UpdateResult {
    int[] newPosts;
    ILink[] newLinks;
}

class PostNotFoundException : Exception {
    this(int postId) {
        super("Post not found: %d".format(postId));
    }
}

class NoCommonPostException : Exception {
    this() {
        super("No common post found");
    }
}
