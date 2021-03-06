/**
 * Fb2RSS is a translator from the HTML structure generated by Facebook to
 * an atom feed.
 * 
 * The page is formatted like this:
 * $(UL
 * $(LI The relevant data is inside `<code></code>` blocks)
 * $(LI Inside these blocks is further HTML-Data, which is commented out.)
 * $(LI The posting and metadata is inside a `<div></div>`, which has the date-time attribute set.)
 * $(LI The actual text to the post is inside another `<div></div>`, with class="_5pbx userContent")
 * $(LI The link to the Post is inside the href of `<a></a>` with class="_5pcq")
 * )
 * 
 * Authors: Dominik Schmidt, das1993@hotmail.com
 * 
 * License: 
 * Copyright (C) 2015  Dominik Schmidt <das1993@hotmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */ 
module fbstream;

import std.net.curl;
import std.stdio;
import std.string;
import std.datetime : SysTime, unixTimeToStdTime;
import std.range;
import std.file;
import std.utf;
import drss.rss;
import drss.render;
import kxml.xml;
import std.typecons;
import std.conv;
import std.json;

string getCookiePath(){
	import std.path;
	import standardpaths;
	string base=writablePath(StandardPath.config);
	return buildPath(base, "Fb2RSS_cookiejar.txt");
}

class CaptchaException : Exception{
	this(string msg, string file=__FILE__, size_t line=__LINE__, Throwable next=null){
		super(msg,file,line,next);
	}
	override string toString(){
		return msg;
	}
}

JSONValue search(JSONValue tree, string id){
	with(JSONType)
	switch(tree.type){
		case object:
			auto o = tree.object;
			if(id in o){
				return o[id];
			}
			foreach(v; o.byValue){
				auto nv= search(v, id);
				if(nv.type != null_){
					return nv;
				}
			}
		break;
		case array:
			foreach(v; tree.array){
				auto nv= search(v, id);
				if(nv.type != null_){
					return nv;
				}
			}
		break;
		default:
			return JSONValue.init;
		break;
	}
	return JSONValue.init;
}

/**
 * Manages all the relevant tasks of 
 * $(UL
 * $(LI Fetching)
 * $(LI Parsing)
 * $(LI Formatting and Outputting)
 * )
 */
class FBStream : DRSS!(Post){
	///Holds the url, where we get the data from. Can either be an URL or a filename.
	private string fetch_url;
	///The plaintext string holding the whole file
	char[] document;
	
	DRSS_Header[] headers=[Tuple!(string,string)("url",null),Tuple!(string,string)("title",null)];
	
	/**
	 * The useragent to use for requesting the page with facebook.
	 * Facebook does check this, and if it doesn't know it, it displays an
	 * "Update your Browser"-Message
	 */
	static string userAgent="curl/7.72.0";
	
	///The RSS-Header to append.
	static string rss_header=`<?xml version="1.0" encoding="UTF-8" standalone="yes"?>`;
	
	immutable string url;
	
	/**
	 *	Params: fetch_url = Fetch the Data from this source
	 */
	this(string fetch_url){
		auto h=HTTP();
		h.url=fetch_url;
		h.setUserAgent(userAgent);
		date_reliability=DateReliable.YES;
		url=fetch_url;
		
		//h.setCookieJar(getCookiePath());
		
		super(h);
	}
	
	/**
	* Returns wether the page in buf is already unlocked.
	* 
	* Params:
	* 	buf =	The chararray of the page.
	* Returns: True if the page is unlocked, false otherwise
	*/
	static bool captchaSolved(in char[] buf){
		import std.algorithm.searching : canFind;
		return !canFind(buf, "tfbimage.php?captcha_challenge_code");
	}
	
	/**
	 * Parses the document.
	 * 
	 * Params:
	 * 	document = The documentstring to parse.
	 */
	override public void parse(string document){
		XmlNode[] arr;
		XmlNode root;
		
		root=readDocument(document);
		
		if(!captchaSolved(document)){
			throw new CaptchaException("Captcha has not been solved yet. "
			~"Please run the ./captcha utility");
		}
		arr=root.parseXPath(`//title`);
		headers[1][1]=arr[0].getCData().idup;
		headers[0][1]=url;
		
		XmlNode[] nodes=root.parseXPath(`//div[@id="recent"]`);
		assert(nodes.length>0, "No data nodes found!");
		nodes = nodes[0].getChildren()[0].getChildren()[0].getChildren();
		foreach(node; nodes.retro){
			appendPost(node);
		}
	}
	
	/**
	 * Gets the information from the data-div and appends it to #posts
	 * Params: match = The data-div node
	 */
	private void appendPost(XmlNode match){
		XmlNode usercontent;
		try{
			usercontent=match.parseXPath(`//div[@style]`)[0];
		}
		catch(Exception e){
			return;
		}
		SysTime t=getPostTimestamp(match);
		XmlNode[] href=match.parseXPath(`//a`);
		string hrefs;
		if(href.length!=0){
			hrefs=href[$-1].getAttribute("href");
			/*
			import std.regex;
			auto re = ctRegex!"[^?]+";
			auto m = hrefs.matchFirst(re);
			if(m){
				hrefs = m[0];
			}
			*/
		}
		assert(hrefs.length>0);
		addEntry(Post(usercontent,t,hrefs));
	}
	
	/**
	 * Gets the timestamp of a post
	 * 
	 */
	 private SysTime getPostTimestamp(XmlNode post){
		import std.json;
		auto attr = post.getAttribute("data-ft");
		auto json = parseJSON(attr);
		auto m = search(json, "publish_time");
		return SysTime(unixTimeToStdTime(m.integer));
	 }
	
	/**
	 * Fetches the raw-data, either from File or from URL
	 */
	public override bool fetch(){
		if(exists(url) && isFile(url)){
			buffer=cast(ubyte[])read(url);
			return true;
		}
		else{
			return super.fetch();
		}
	}
	
	/**
	 * Generates the RSS-file
	 * 
	 * Params:
	 * 	f = the file to write the RSS-Document to.
	 */
	void writeRSS(File f){
		import drss.render;
		XmlNode n=generateRSS(this,headers);
		f.writeln(rss_header);
		f.writeln(n);
	}
	
}

///
struct Post{
	///The userdata `<div></div>`
	XmlNode content;
	///The modification date 
	SysTime time;
	///The Post-href
	string href;
	///The count of characters, until the title gets cut off.
	static ushort title_cutoff=80;
	
	static string plaintext(XmlNode n){
		Appender!string app = Appender!string();
		plaintext(n, app);
		return app.data;
	}
	static void plaintext(XmlNode n, ref Appender!string app){
		app~=n.getCData();
		foreach(c; n.getChildren){
			plaintext(c, app);
		}
	}
	
	/**
	 * Return: The title of the posting 
	 * Bugs: title_cutoff is reached with fewer characters when there are 
	 * 	a lot of multibyte characters in the string.
	 */
	@property string title(){
		string cont=plaintext(content);
		if(cont.length>title_cutoff){
			cont=cont[0..toUTFindex(cont,title_cutoff)];
			cont~="...";
		}
		return cont;
	}
	///Returns: The link to the post.
	@property string link() const{
		return "https://facebook.com"~href;
	}
	
	/**
	 * Returns: An unique id to the post
	 * Bugs: It should be something sensible here, not just the link.
	 * 		Optimally, it should be the same as the facebookfeed read.
	 */
	@property string id() const{
		return link();
	}
	
	/// Returns: The Atom-valid datestring
	@property string ISOTime() const{
		return time.toISOExtString();
	}
	
	/// Returns: An UCData-Object describing the content of the post.
	@property UCData getUCContent(){
		UCData uc=new UCData();
		uc.setCData(content.toString());
		return uc;
	}

	/**
	 * Compares the object with b by comparing the dates
	 * Returns: -1 if b is bigger, 1 if b is smaller, 0 if they're equal
	 */
	int opCmp(in ref Post b) const{
		if(time<b.time){
			return -1;
		}
		else if(time>b.time){
			return 1;
		}
		else{
			return 0;
		}
	}
	
	/**
	 * Generates an Atom-Entry matching the post
	 * Returns: The Entry-Node for inclusion inside the Atom-Feed.
	 */
	XmlNode toXML(){
		XmlNode e=new XmlNode("entry");
		e.addChild(new XmlNode("title").addCData(title));
		e.addChild(new XmlNode("link").setAttribute("href",link));
		e.addChild(new XmlNode("id").addCData(id));
		e.addChild(new XmlNode("published").addCData(ISOTime()));
		e.addChild(new XmlNode("content").setAttribute("type","html").addChild(getUCContent()));
		return e;
	}
	///
	bool opEquals(in ref Post b) const{
		return (opCmp(b)==0);
	}
	///
	bool opEquals(in Post b) const{
		return (opCmp(b)==0);
	}
}
