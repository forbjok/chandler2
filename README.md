# Chandler 2
[![Build Status](https://travis-ci.org/forbjok/chandler2.svg?branch=master)](https://travis-ci.org/forbjok/chandler2)

## Introduction
See a thread you consider worthy of archival?
Don't trust the 4chan archives to remain available?
Or perhaps it's not on 4chan, but on some tiny obscure imageboard nobody else has heard of or considered worth archiving?

Chandler to the rescue!

**Chandler 2** is a rewrite from scratch in D of Chandler, an imageboard thread downloader I wrote in Python a few years ago.
Like its predecessor, its purpose is to be able to quickly and easily download threads from imageboards, as well as being a fire and forget solution for watching and downloading updates to a thread.
For sites where this is supported (currently 4chan and Tinyboard-compatible sites), posts from previous threads which are later deleted will be preserved when updating threads.

Supported platforms are **GNU/Linux** (tested on Arch Linux, but should work others as well) and **Microsoft Windows**, but it might work on other *nixes as well if it's possible to get DMD and DUB working on them.

## Installing/Compiling
Currently, there is no Windows installer available for Chandler 2. This will be remedied soon.

Until then, you will have to compile it yourself.

1. Download and install the lastest version of DMD (the reference D compiler) from [dlang.org](http://dlang.org/)
2. Download and install DUB from [code.dlang.org](https://code.dlang.org/)
3. Clone this repository and execute the following command in it:
```
$ dub build
```

Voila! You should now have a usable executable in the root of the repository.

## How to use
To download a thread once and exit:
```
$ chandler <thread url>
```

To watch and update a thread indefinitely:
```
$ chandler -w <thread url>
```

That's the basics. For more parameters, see
```
$ chandler --help
```

## Where do threads go?
By default, threads are saved to **~/threads** on GNU/Linux and **My Documents\threads** on Windows.

This can be overridden by specifying the `-d <path>` option, or the **downloadPath** setting in your **chandler.json** configuration file.

## The chandler.json configuration file
By default, there will be no **chandler.json** configuration file, but you can create one.
It should be created as **~/.chandler.json** on GNU/Linux or at **%USERPROFILE%\chandler.json** on Windows.

A simple example configuration can look something like this:
```json
{
  "downloadPath": "~/my-chandler-threads",
  "sites": {
    "tinychan.org": {
      "urlRegex": "https?://([\\w\\.]+)/(\\w+)/res/(\\d+)",
      "parser": "tinyboard"
    },
    "obscurechan.org": {
      "urlRegex": "https?://([\\w\\.]+)/(\\w+)/thread/(\\d+)",
      "parser": "basic"
    }
  }
}
```

The **sites** section is entirely optional, but can be useful if you need to specify that a specific site should use a specific URL regex or parser.

By default, unknown sites will automatically use the **basic** parser and a very generic URL regex that _should_ work with most imageboards.

Specifying a **site** for its hostname in the configuration, as shown above, will let you override that.
This will generally only be necessary in order to use the **tinyboard** parser for a site you know or believe to be Tinyboard-compatible.

The capture groups in the URL regex will determine the directory structure that gets created for each thread inside your **download path**.
One subdirectory for each capture group.

## Parsers
These are the possible values for the **parser** property of a **site**.

There are currently three parsers:
* **fourchan**
* **tinyboard**
* **basic**

**fourchan**, as the name suggests is specifically for 4chan. For all I know, there may be other imageboards that happen to use the exact same HTML layout (class names, etc) as 4chan, and thus work with this parser. However, don't count on this working with anything other than 4chan.

**tinyboard** is for Tinyboard-compatible sites. I say "compatible", because not all sites that are based on Tinyboard are necessarily Tinyboard-compatible - they could have customized their HTML layouts and changed class names, etc. so that this parser will no longer work with them. For most Tinyboard-based sites, this should work though.

**basic** is completely basic. It does not rely on anything HTML-layout specific at all, and does not support preserving deleted posts. It should work with **ANY** site.

## Chandler projects
A chandler "project" (I use this term for lack of a better one) is what gets created when Chandler is used to download a thread.

In addition to the **thread.html** and any files downloaded from the thread, each project will contain a **.chandler** directory.

It contains the following:
* Various metadata, such as the thread's URL
* State related to downloading the thread
* All original pristine HTMLs as downloaded directly from the server

If you are 100% sure you are done downloading/updating a thread, you can safely delete this, however I would personally recommend keeping it.

## Rebuilding a project
Since a project stores all the original HTMLs, it is possible to completely rebuild the **thread.html** from the original HTMLs.

This is done using the `-r <project path>` option.

Possible reasons for doing this:
* Your **thread.html** somehow got corrupted or deleted
* A bug in Chandler caused **thread.html** to have an error, and an updated version has come out that fixes the bug
* You downloaded a thread using the **basic** parser, which does not preserve deleted posts, but a new parser was later added that supports the site it was downloaded from and now you want those deleted posts back in your **thread.html**

For this reason, I recommend keeping the **.chandler** directory.
