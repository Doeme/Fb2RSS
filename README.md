Facebook to RSS converter
==============

This program is designed to provide non-login RSS Feeds from Facebookpages,
since they turned the official RSS Feeds off.

Compiling
--------------

- Install a D Compiler and Phobos Runtime
- Make sure to add ./kxml/source/kxml/xml.d to the input files of the compilercall
- You also have to link against libCurl

With ldc2, the call looks something like
```shell
ldc2 Fb2RSS.d kxml/source/kxml/xml.d -L-lcurl
```

Usage
--------------
```shell
./Fb2RSS https://facebook.com/<page_name>
```
This will write the Atom Feed to stdout, which can be piped to a File, Process, /dev/null, whatever...

