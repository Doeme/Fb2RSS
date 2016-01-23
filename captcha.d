import fbstream;
import std.net.curl;
import std.stdio;
import std.file;
import std.path;
import std.regex;
import std.format;
import std.range;
import std.algorithm.searching;


immutable string probe_url="https://www.facebook.com/Facebook";

/**
 * Tries to fetch the captcha and set the cookies
 * 
 * Returns: 0 if the captcha is solved, 1 otherwise.
 */
int main(string[] args){
	auto h=HTTP();
	char[] buf;
	
	h.url=probe_url;
	h.setUserAgent(FBStream.userAgent);
	h.setCookieJar(getCookiePath());
	h.onReceive = (ubyte[] data){
		buf~=cast(char[])data;
		return data.length;
	};
	h.perform();
	
	if(FBStream.captchaSolved(buf)){
		writeln("Captcha already solved :)");
		return 0;
	}
	
	auto url_regex=ctRegex!(".*(https://www.facebook.com/captcha/tfbimage.php[^\"]+).*");
	auto url=matchFirst(buf, url_regex)[1];
	auto datr_regex=ctRegex!(".*\"_js_datr\",\"([^\"]+)\".*");
	auto datr=matchFirst(buf, datr_regex);
	
	h.setCookie("_js_datr="~datr[1]);
	
	
	auto captcha_regex=ctRegex!(".*name=\"captcha_persist_data\" value=\"([^\"]+)\".*");
	auto captcha_hash=matchFirst(buf, captcha_regex)[1];
	
	buf=null;
	h.url=url;
	h.perform();
	
	File f;
	string file=buildPath(tempDir(),"fb2rss_captcha.png");
	f.open(file, "w+");
	scope(exit){
		f.close();
		remove(file);
	}
	f.write(buf);
	f.close();
	writeln("The captcha has been written to "~file);
	writeln("Please enter the text below:");
	char[] captcha;
	readln(captcha);
	captcha=captcha[0..$-1]; //Exclude '\n'
	
	buf=null;
	h.url=probe_url;
	h.method=HTTP.Method.post;
	h.setPostData(
		format(
			"captcha_persist_data=%s&captcha_response=%s&captcha_submit=1",
			captcha_hash,
			captcha
		),
		"application/x-www-form-urlencoded"
	);
	h.perform();
	
	if(FBStream.captchaSolved(buf)){
		writeln("Success");
	}
	else{
		writeln("Sorry, didn't work :C");
		writeln("Please, try again!");
		return 1;
	}
	return 0;
}
