
/**
 * @file Fb2RSS.d
 * 
 * @author Dominik Schmidt <das1993@hotmail.com>
 * 
 * @brief Fb2RSS is a translator from the HTML structure generated by Facebook to
 * an atom feed.
 * 
 * The page is formatted like this:
 * - The relevant data is inside `<code></code>` blocks
 * - Inside these blocks is further HTML-Data, which is commented out.
 * - The posting and metadata is inside a `<div></div>`, which has the date-time attribute set.
 * 	- The actual text to the post is inside another `<div></div>`, with class="_5pbx userContent"
 * 	- The link to the Post is inside the href of `<a></a>` with class="_5pcq"
 * 
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

import std.net.curl;
import std.stdio;
import std.string;
import std.datetime;
import std.range;
import std.file;
import kxml.xml;

/**
 * Manages all the relevant tasks of 
 * - Fetching
 * - Parsing
 * - Formatting and Outputting
 */
class FBStream : RandomFiniteAssignable!(Post){
	///Holds all the retrieved posts
	Post posts[];
	///Holds the feed url
	string url;
	///Holds the url, where we get the data from. Can either be an URL or a filename.
	private string fetch_url;
	///The title of the feed
	string title;
	///The generated data Nodes, which hold all relevant data.
	XmlNode dataNodes[]; 
	///The plaintext string holding the whole file
	string document;	
	/**
	 * The useragent to use for requesting the page with facebook.
	 * Facebook does check this, and if it doesn't know it, it displays an
	 * "Update your Browser"-Message
	 */
	string userAgent="Mozilla/5.0 (Windows NT 6.1; rv:2.0.1) Gecko/20110504 Firefox/7.0.1";
	
	///The RSS-Header to append.
	string rss_header=`<?xml version="1.0" encoding="UTF-8" standalone="yes"?>`;
	
	///The root node
	XmlNode root; 
	
	/**
	 * @brief Functions for the Range-Interface
	 * 
	 * Mostly, they only wrap around the #posts array
	 */
	@property FBStream save(){
		FBStream str=this.clone();
		str.posts=this.posts.save;
		return str;
	}
	
	///@copydoc save
	@property void front(Post newVal){
		posts~=newVal;
	}
	///@copydoc save
	@property void back(Post newVal){
		posts=[newVal]~posts;
	}
	///@copydoc save
	void opIndexAssign(Post val, size_t index){
		posts[index]=val;
	}
	///@copydoc save
	Post opIndex(size_t i){
		return posts[i];
	}
	///@copydoc save
	Post moveAt(size_t i){
		return posts.moveAt(i);
	}
	
	/**
	 * Returns a clone of the current object.
	 * @warning The members all point to the same data, so if you change 
	 * 			a member variable of the clone, the parent will change too.
	 * @return A clone of the current object.
	 */
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
	///@copydoc save
	@property size_t length(){
		return posts.length;
	}
	///@copydoc save
	FBStream opSlice(size_t a, size_t b){
		FBStream str=this.clone();
		str.posts=this.posts[a..b];
		return str;
	}
	///@copydoc save
	@property Post back(){
		return posts.back();
	}
	///@copydoc save
	Post moveBack(){
		return posts.moveBack();
	}
	///@copydoc save
	void popBack(){
		posts.popBack();
	}
	///@copydoc save
	int opApply(int delegate(Post) func){
		int result=0;
		foreach(ref Post p; posts){
			result=func(p);
			if(result) break;
		}
		return result;
	}
	///@copydoc save
	int opApply(int delegate(size_t,Post) func){
		int result=0;
		foreach(size_t c,ref Post p; posts){
			result=func(c,p);
			if(result) break;
		}
		return result;
	}
	///@copydoc save
	@property bool empty(){
		return posts.empty;
	}
	///@copydoc save
	void popFront(){
		posts.popFront();
	}
	///@copydoc save
	Post moveFront(){
		return posts.moveFront();
	}
	///@copydoc save
	@property Post front(){
		return posts.front;
	}
	
	/**
	 *	@param fetch_url Fetch the Data from this source
	 */
	this(string fetch_url){
		this.fetch_url=fetch_url;
	}
	
	/**
	 * Fetch the data from #fetch_url, and save it in #document
	 */
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
	/**
	 * Parses #document. Afterwords #posts, #root, #dataNodes will be filled.
	 */
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
	
	/**
	 * Generates #posts
	 * @param nodes The `<code></code>` nodes, where the data can be found.
	 */
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
	
	/**
	 * Gets the information from the data-div and appends it to #posts
	 * @param match The data-div node
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
		posts~=Post(usercontent[0],t,href[0].getAttribute("href"));
	}
	
	/**
	 * Generates an XML-Document template to be filled with entries.
	 * @return The root-node of the Atom-Feed
	 */
	public XmlNode getRSSRoot(){
		XmlNode rss = new XmlNode("feed");
		rss.setAttribute("xmlns","http://www.w3.org/2005/Atom");
		rss.addChild(new XmlNode("id").addCData(url));
		rss.addChild(new XmlNode("title").addCData(title));
		rss.addChild(new XmlNode("link").setAttribute("href",url));
		return rss;
	}
	
	/**
	 * Generates an XML-Document which validates as an Atom-Feed corresponding
	 * to the Facebookpage found in #fetch_url, or the document in #document.
	 * @return The root-node of the Atom-Feed
	 */
	public XmlNode generateRSS(){
		XmlNode rss = getRSSRoot();
		foreach(ref Post p; posts){
			rss.addChild(p.getEntry());
		}
		return rss;
	}
	
	/**
	 * @overload generateRSS
	 * @param r Take the Posts from the range r, instead of #posts
	 */
	public XmlNode generateRSS(Range)(Range r) if(isInputRange!(Range)){
		XmlNode rss = getRSSRoot();
		foreach(Post p; r){
			rss.addChild(p.getEntry());
		}
		return rss;
	}

	/**
	 * Writes a valid Atom-Feed xmlfile to the file specified
	 * @param into The file to write the feed to
	 */
	public void writeRSS(File into){
		XmlNode rss=generateRSS();
		into.writeln(rss_header);
		into.writeln(rss);
	}
}

struct Post{
	///The userdata `<div></div>`
	XmlNode content;
	///The modification date 
	SysTime time;
	///The Post-href
	string href;
	///The count of characters, until the title gets cut off.
	static ushort title_cutoff=80;
	
	///@return The title of the posting 
	@property string title(){
		string cont=content.getChildren()[0].getCData();
		if(cont.length>title_cutoff){
			cont=cont[0..title_cutoff];
			cont~="...";
		}
		return cont;
	}
	///@return The link to the post.
	@property string link() const{
		return "https://facebook.com"~href;
	}
	
	/**
	 * @return An unique id to the post
	 * @bug It should be something sensible here, not just the link.
	 * 		Optimally, it should be the same as the facebookfeed read.
	 */
	@property string id() const{
		return link();
	}
	
	/// @return The Atom-valid datestring
	@property string ISOTime() const{
		return time.toISOExtString();
	}
	
	/// @return An UCData-Object describing the content of the post.
	@property UCData getUCContent(){
		UCData uc=new UCData();
		uc.setCData(content.toString());
		return uc;
	}

	/**
	 * Compares the object with b by comparing the dates
	 * @return -1 if b is bigger, 1 if b is smaller, 0 if they're equal
	 */
	int opCmp(ref Post b) const{
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
	 * @return The Entry-Node for inclusion inside the Atom-Feed.
	 */
	XmlNode getEntry(){
		XmlNode e=new XmlNode("entry");
		e.addChild(new XmlNode("title").addCData(title));
		e.addChild(new XmlNode("link").setAttribute("href",link));
		e.addChild(new XmlNode("id").addCData(id));
		e.addChild(new XmlNode("published").addCData(ISOTime()));
		e.addChild(new XmlNode("content").setAttribute("type","html").addChild(getUCContent()));
		return e;
	}
	
	bool opEquals(ref Post b) const{
		return (opCmp(b)==0);
	}
}

void main(string args[]){
	FBStream str=new FBStream(args[1]);
	str.fetch();
	str.parse();
	str.writeRSS(stdout);
}
