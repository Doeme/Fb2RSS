import std.stdio;
import fbstream;
import std.algorithm: endsWith;
import std.regex;
import std.format;

void main(string[] args){
	string url=args[1];
	auto reg = ctRegex!`([^:]+)://([^/]+)/(.*)`;
	
	auto m = url.matchFirst(reg);
	if(!m){
		throw new Exception("Not an url");
	}
	url = format("https://m.facebook.com/%s",m[3]);
	
	FBStream str=new FBStream(url);
	str.update();
	str.writeRSS(stdout);
}

