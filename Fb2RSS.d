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
module fb2rss;

import std.net.curl;
import std.stdio;
import std.string;
import std.datetime;
import std.range;
import std.file;
import std.utf;
import drss.rss;
import drss.render;
import kxml.xml;
import std.typecons;

/**
 * Manages all the relevant tasks of 
 * $(UL
 * $(LI Fetching)
 * $(LI Parsing)
 * $(LI Formatting and Outputting)
 * )
 */
class FBStream : DRSS!(Post){
	///Holds all the retrieved posts
	Post posts[];
	///Holds the url, where we get the data from. Can either be an URL or a filename.
	private string fetch_url;
	///The plaintext string holding the whole file
	char[] document;
	
	DRSS_Header headers[]=[Tuple!(string,string)("url",null),Tuple!(string,string)("title",null)];
	
	/**
	 * The useragent to use for requesting the page with facebook.
	 * Facebook does check this, and if it doesn't know it, it displays an
	 * "Update your Browser"-Message
	 */
	string userAgent="Mozilla/5.0 (Windows NT 6.1; rv:2.0.1) Gecko/20110504 Firefox/7.0.1";
	
	///The RSS-Header to append.
	string rss_header=`<?xml version="1.0" encoding="UTF-8" standalone="yes"?>`;
	
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
		
		super(h);
	}
	
	/**
	 * Parses the document.
	 * 
	 * Params:
	 * 	document = The documentstring to parse.
	 */
	override public void parse(string document){
		XmlNode[] arr;
		XmlNode root=readDocument(document);
		arr=root.parseXPath(`//meta[@property="og:url"]`);
		headers[0][1]=arr[0].getAttribute("content");
		arr=root.parseXPath(`//meta[@property="og:title"]`);
		headers[1][1]=arr[0].getAttribute("content");
		
		XmlNode[] nodes=root.parseXPath(`//code`);
		generatePosts(nodes);
	}
	
	/**
	 * Generates the posts
	 * Params: nodes = The `<code></code>` nodes, where the data can be found.
	 */
	 
	private void generatePosts(XmlNode[] nodes){
		foreach(ref XmlNode node; nodes){
			XmlNode subTree=readDocument((cast(XmlComment)(node.getChildren()[0]))._comment);
			XmlNode[] matches=subTree.parseXPath(`//div[@data-time]`);
			if(matches.length==0){continue;}
			foreach(ref XmlNode match; retro(matches)){
				appendPost(match);
			}
		}
	}
	
	/**
	 * Gets the information from the data-div and appends it to #posts
	 * Params: match = The data-div node
	 */
	private void appendPost(XmlNode match){
		XmlNode[] usercontent=match.parseXPath(`//div[@class="_5pbx userContent"]`);
		if(usercontent.length==0){
			return;
		}
		XmlNode[] translatediv=usercontent[0].parseXPath(`/div[@class="_43f9"]`);
		if(translatediv.length>0){
			usercontent[0].removeChild(translatediv[0]);
		}
		SysTime t=SysTime(unixTimeToStdTime(to!ulong(match.getAttribute("data-time"))));
		XmlNode[] href=match.parseXPath(`//a[@class="_5pcq"]`);	
		addEntry(Post(usercontent[0],t,href[0].getAttribute("href")));
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
		writeln(rss_header);
		writeln(n);
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
	
	/**
	 * Return: The title of the posting 
	 * Bugs: title_cutoff is reached with fewer characters when there are 
	 * 	a lot of multibyte characters in the string.
	 */
	@property string title(){
		string cont=content.getChildren()[0].getCData();
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

void main(string args[]){
	FBStream str=new FBStream(args[1]);
	str.update();
	str.writeRSS(stdout);
}
