import std.net.curl;
import std.stdio;
import std.conv;
import std.utf;
import std.string;
import std.datetime;
import std.range;
import std.file;
import kxml.xml;

class FBStream : RandomFiniteAssignable!(Post){
	Post posts[];
	string url;
	private string fetch_url;
	string title;
	XmlNode dataNodes[];
	string document;
	string userAgent="Mozilla/5.0 (Windows NT 6.1; rv:2.0.1) Gecko/20110504 Firefox/7.0.1";
	XmlNode root;
	@property FBStream save(){
		FBStream str=this.clone();
		str.posts=this.posts.save;
		return str;
	}
	@property void front(Post newVal){
		posts~=newVal;
	}
	@property void back(Post newVal){
		posts=[newVal]~posts;
	}
	void opIndexAssign(Post val, size_t index){
		posts[index]=val;
	}
	Post opIndex(size_t i){
		return posts[i];
	}
	Post moveAt(size_t i){
		return posts.moveAt(i);
	}
	private FBStream clone(){
		FBStream str=new FBStream(this.fetch_url);
		str.url=this.url;
		str.posts=this.posts;
		str.title=this.title;
		str.dataNodes=this.dataNodes;
		str.document=this.document;
		str.userAgent=this.userAgent;
		str.root=this.root;
		return str;
	}
	@property size_t length(){
		return posts.length;
	}
	FBStream opSlice(size_t a, size_t b){
		FBStream str=this.clone();
		str.posts=this.posts[a..b];
		return str;
	}
	@property Post back(){
		return posts.back();
	}
	Post moveBack(){
		return posts.moveBack();
	}
	void popBack(){
		posts.popBack();
	}
	int opApply(int delegate(Post) func){
		int result=0;
		foreach(ref Post p; posts){
			result=func(p);
			if(result) break;
		}
		return result;
	}
	int opApply(int delegate(size_t,Post) func){
		int result=0;
		foreach(size_t c,ref Post p; posts){
			result=func(c,p);
			if(result) break;
		}
		return result;
	}
	@property bool empty(){
		return posts.empty;
	}
	void popFront(){
		posts.popFront();
	}
	Post moveFront(){
		return posts.moveFront();
	}
	@property Post front(){
		return posts.front;
	}
	this(string fetch_url){
		this.fetch_url=fetch_url;
	}
	
	public void fetch(){
		if(exists(fetch_url) && isFile(fetch_url)){
			document=cast(string)read(fetch_url);
		}
		else{
			auto h=HTTP();
			h.setUserAgent(userAgent);
			h.url=fetch_url;
			h.onReceive = (ubyte[] data) {document~=cast(string)data; return data.length; };
			h.perform();
		}
	}
	public void parse(){
		XmlNode[] arr;
		root=readDocument(document);
		arr=root.parseXPath(`//meta[@property="og:url"]`);
		url=arr[0].getAttribute("content");
		arr=root.parseXPath(`//meta[@property="og:title"]`);
		title=arr[0].getAttribute("content");
		
		XmlNode[] nodes=root.parseXPath(`//code`);
		generatePosts(nodes);
	}
	private void generatePosts(XmlNode[] nodes){
		foreach(ref XmlNode node; nodes){
			XmlNode subTree=readDocument((cast(XmlComment)(node.getChildren()[0]))._comment);
			XmlNode[] matches=subTree.parseXPath(`//div[@data-time]`);
			if(matches.length==0){continue;}
			dataNodes~=subTree;
			foreach(ref XmlNode match; matches){
				appendPost(match);
			}
		}
	}
	private void appendPost(XmlNode match){
		XmlNode[] usercontent=match.parseXPath(`//div[@class="_5pbx userContent"]`);
		if(usercontent.length==0){
			return;
		}
		SysTime t=SysTime(unixTimeToStdTime(to!ulong(match.getAttribute("data-time"))));
		XmlNode[] href=match.parseXPath(`//a[@class="_5pcq"]`);	
		posts~=Post(usercontent[0],t,href[0].getAttribute("href"));
	}
	
	public void generateRSS(File into){
		XmlNode rss = new XmlNode("feed");
		rss.setAttribute("xmlns","http://www.w3.org/2005/Atom");
		rss.addChild(new XmlNode("id").addCData(url));
		rss.addChild(new XmlNode("title").addCData(title));
		//rss.addChild(new XmlNode("author").addChild(new XmlNode("name").addCData(title)));
		//rss.addChild(new XmlNode("updated").addCData(posts[0].time.toISOExtString()));
		foreach(ref Post p; posts){
			XmlNode e=new XmlNode("entry");
			e.addChild(new XmlNode("title").addCData(p.time.toString()));
			e.addChild(new XmlNode("link").setAttribute("href","http://facebook.com"~p.href));
			e.addChild(new XmlNode("id").addCData("http://facebook.com"~p.href));
			e.addChild(new XmlNode("published").addCData(p.time.toISOExtString()));
			e.addChild(new XmlNode("updated").addCData(p.time.toISOExtString()));
			e.addChild(new XmlNode("content").setAttribute("type","text/html").addCData(p.content.toString()));
			rss.addChild(e);
		}
		into.writeln(`<?xml version="1.0" encoding="UTF-8" standalone="yes"?>`);
		into.writeln(rss);
	}
}

struct Post{
	XmlNode content;
	SysTime time;
	string href;
}

void main(string args[]){
	FBStream str=new FBStream(args[1]);
	str.fetch();
	str.parse();
	str.generateRSS(stdout);
}
