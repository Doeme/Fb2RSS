import std.stdio;
import fbstream;

void main(string[] args){
	FBStream str=new FBStream(args[1]);
	str.update();
	str.writeRSS(stdout);
}

