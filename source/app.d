import std.algorithm;
import std.array;
import std.conv;
import std.file;
import std.path;
import std.stdio;
import std.net.curl;

import breakhandler;
import chandlerproject;

void main(string[] args)
{
    auto baseURL = "";
    auto basePath = "temptest".absolutePath();
    //auto html = get(baseURL);
    //std.file.write("orig.html", html);
    //auto html = readText("orig.html");

    handleBreak();

    //auto chandl = createChandlerProject(baseURL, basePath);
    //chandl.saveProject();
    auto chandl = ChandlerProject.load(basePath);
    //chandl.download();
    chandl.rebuild();
}
