import std.getopt;
import vibe.core.core : sleep;
import vibe.core.log;
import vibe.http.fileserver : serveStaticFiles;
import vibe.http.router : URLRouter;
import vibe.http.server;
import vibe.http.websockets : WebSocket, handleWebSockets;

import core.time;
import std.conv : to;
import std.stdio;
import std.file;
import std.parallelism;
import core.thread;
import core.sys.posix.signal;

import filewatch;

shared bool isRunning = true;
shared bool changed;
string file;

shared static this()
{
	auto router = new URLRouter;
	router.get("/", staticRedirect("/index.html"));
	router.get("/ws", handleWebSockets(&handleWebSocketConnection));
	router.get("*", serveStaticFiles("public/"));

	auto settings = new HTTPServerSettings;
	settings.port = 8080;
	settings.bindAddresses = ["::1", "127.0.0.1"];
	listenHTTP(settings, router);
}

void handleWebSocketConnection(scope WebSocket socket)
{
	writeln("Got new web socket connection.");
	ulong sent;
	ulong oldSent;
	string msg = "get";

	socket.send(file.readText);

	while (socket.connected) {
		sleep(1.seconds);

		//if(socket.dataAvailableForRead)
		//	msg = socket.receiveText();
		if(changed && sent == oldSent || msg == "get") {
			socket.send(file.readText);
			sent++;
			msg = "";
		} else if(!changed) {
			oldSent = sent;
		}
	}

	writeln("Client disconnected.");
}

void watchChanges(FileWatch fileWatch, Thread parent) {

	while(isRunning) {
		changed = false;
		fileWatch.update;
		Thread.sleep(dur!"seconds"(1));
	}

	throw new Exception("oh... Bye then!");
}

extern (C)
{
	void mybye(int value) {
		isRunning = false;
		throw new Exception("oh... Bye then!");
	}
}

int main(string[] args) {
	getopt(args, "file", &file);

	void notify(FileWatch.Event event, string path) {
		std.stdio.writeln("event: ", event, " ", path);
		changed = true;
	}

	if(file == "" || !file.exists) {
		writeln("Invalid file. You forgot to pass --file flag?");
		return 1;
	}

	std.stdio.writeln("Watching for file: ", file);

	FileWatch fileWatch;
	fileWatch.addNotify(file, &notify);
	fileWatch.update(false);

	args = [];

	auto fileTask = task!watchChanges(fileWatch, Thread.getThis);
    fileTask.executeInNewThread();
    sigset(SIGINT, &mybye);


	import vibe.core.args : finalizeCommandLineOptions;
	import vibe.core.core : runEventLoop, lowerPrivileges;
	import vibe.core.log;
	import std.encoding : sanitize;

	version (unittest) {
		logInfo("All unit tests were successful.");
		return 0;
	} else {
		lowerPrivileges();

		logDiagnostic("Running event loop...");
		int status;

		try {
			status = runEventLoop();
		} catch( Throwable th ){
			writeln("Unhandled exception in event loop: %s", th.msg);
			writeln("Full exception: %s", th.toString().sanitize());
			return 1;
		}

		writeln("Event loop exited with status %d.", status);
		return status;
	}
}
