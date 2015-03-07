import std.getopt;
import vibe.core.core : sleep;
import vibe.core.log;
import vibe.http.fileserver : serveStaticFiles;
import vibe.http.router : URLRouter;
import vibe.http.server;
import vibe.http.websockets : WebSocket, handleWebSockets;
import vibe.data.json;

import core.time;
import std.conv : to;
import std.stdio;
import std.file;
import std.parallelism;
import std.path;
import std.process;
import std.datetime;

import core.thread;
import core.sys.posix.signal;

import filewatch;

shared bool isRunning = true;
shared string events[];

RunningTest test;

string reportFile;
string projectPath;

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

	auto client = new Client(socket);
	client.listen;

	writeln("Client disconnected.");
}


class Client {
	WebSocket socket;
	ulong eventPosition;
	string msg = "get";

	this(WebSocket socket) {
		this.socket = socket;
		eventPosition = events.length;
	}

	void sendReport() {
		writeln("send rep");
		Json msg = Json.emptyObject;
		msg["message"] = "log";
		msg["data"] = reportFile.readText;

		socket.send(msg.to!string);
	}

	void listen() {

		try {
			while (socket.connected) {
				bool hasData = socket.waitForData(dur!"msecs"(50));
				msg = "";

				if(hasData) {
					msg = socket.receiveText();
				} else if(eventPosition < events.length) {
					msg = events[eventPosition];
					eventPosition++;
				}

				if(msg != "")
					writeln("msg:",msg);

				if(msg == "runTest")
					runTest();
				else if(msg == "get")
					sendReport();
				else if(msg != "")
					socket.send(msg);
			}
		} catch(Exception e) {
			writeln(e);
		}
	}
}

void runTest() {
	writeln("Running tests");

	test = new RunningTest;
	test.start;
}

class RunningTest {
	SysTime beginTest;
	SysTime endTest;
	Pid pid;

	static void watchProcess(Pid pid) {
		try {
			auto proc = tryWait(pid);

			while(!proc.terminated) {
				proc = tryWait(pid);
				Thread.sleep(dur!"mseconds"(500));
			}

			if (proc.status == 0) writeln("Compilation succeeded!");
			else writeln("Compilation failed");
		} catch (Exception e) {
			writeln(e);
		}

		events ~= `{ "message": "testEnd" }`;
	}

	void start() {
		events ~= `{ "message": "testBegin" }`;

		Config config;
		File f;
		const(immutable(char)[][string]) env;

		pid = spawnProcess(["dub", "test"],
                        std.stdio.stdin,
                        std.stdio.stdout,
                        std.stdio.stderr,
                        env,
                        config,
                        cast(const(char[])) projectPath);

		auto fileTask = task!watchProcess(pid);
		fileTask.executeInNewThread();
	}
}

void watchChanges(FileWatch fileWatch, Thread parent) {

	while(isRunning) {
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

void createFileWatcher() {
	void notify(FileWatch.Event event, string path) {
		std.stdio.writeln("event: ", event, " ", path);
		events ~= "get";
	}

	std.stdio.writeln("Watching for file: ", reportFile);

	FileWatch fileWatch;
	fileWatch.addNotify(reportFile, &notify);
	fileWatch.update(false);

	auto fileTask = task!watchChanges(fileWatch, Thread.getThis);
    fileTask.executeInNewThread();
    sigset(SIGINT, &mybye);
}

int main(string[] args) {
	getopt(args, "path", &projectPath);

	if(projectPath == "" || !projectPath.exists) {
		writeln("Invalid file. You forgot to pass --path flag?");
		return 1;
	}

	reportFile = buildPath(projectPath, "results.json");

	createFileWatcher();

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
