Facebook to RSS converter
==============

This program is designed to provide non-login RSS Feeds from Facebookpages,
since they turned the official RSS Feeds off.

Compiling
--------------

- Install a D Compiler and Phobos Runtime
- Make sure to add ./kxml/source/ as an includepath.

Usage
--------------
```shell
./Fb2RSS https://facebook.com/<page_name>
```
This will write the Atom Feed to stdout, which can be piped to a File, Process, /dev/null, whatever...

