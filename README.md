Facebook to RSS converter
==============

This program is designed to provide non-login RSS Feeds from Facebookpages,
since they turned the official RSS Feeds off.

Compiling
--------------

```shell
make DMD="your-favorite-dmd"
```

Usage
--------------
```shell
./captcha
./Fb2RSS https://facebook.com/<page_name>
```
This will write the Atom Feed to stdout, which can be piped to a File, Process, /dev/null, whatever...

Captcha
-------
The first command (`./captcha`) has to be executed only *once*.
Please follow the instructions it gives you.


