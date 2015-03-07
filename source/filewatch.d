module filewatch;

import std.path;
import std.file;
import std.stdio;
import std.conv;


private struct DiscoveredFiles {

	private {
		bool[string] fileList;
		bool[string] checked;
		string[string] hash;
	}

	string getHash(string fileName) {
		auto file = DirEntry(fileName);
		auto time = file.timeLastModified;
		auto size = file.size;
		auto dir = fileName.isDir;

		return time.toISOExtString ~ "." ~ size.to!string ~ "." ~ dir.to!string;
	}

	FileWatch.Event check(string path) {
		checked[path] = true;

		if(path !in fileList) {
			fileList[path] = true;
			hash[path] = getHash(path);
			return FileWatch.Event.Add;
		}

		if(path in fileList) {
			auto tmpHash = getHash(path);

			if(tmpHash != hash[path]) {
				hash[path] = tmpHash;
				return FileWatch.Event.Update;
			}
		}

		return FileWatch.Event.None;
	}

	string[] unchecked() {
		string[] list;

		foreach(file; fileList.keys)
			if(file !in checked)
				list ~= file;


		bool[string] empty;
		checked = empty;

		return list;
	}
}


struct FileWatch {
	enum Event {
		Add,
		Update,
		Remove,
		None
	}

	alias NotifyCb = void delegate(Event event, string path);

	private {
		NotifyCb[string] notifiers;
		DiscoveredFiles[string] discovered;
	}

	void addNotify(string pathPattern, NotifyCb notify) {
		notifiers[pathPattern] = notify;

		if(pathPattern !in discovered)
			discovered[pathPattern] = DiscoveredFiles();
	}

	void update(bool raiseNotifier = true) {
		foreach(pathPattern; notifiers.keys) {
			auto filePath = pathPattern.dirName;
			auto fileName = pathPattern.baseName;

			auto files = dirEntries(filePath, fileName, SpanMode.depth);

			foreach(file; files) {
				auto status = discovered[pathPattern].check(file);

				if(raiseNotifier && status != Event.None)
					notifiers[pathPattern](status, file);
			}

			auto removedFiles = discovered[pathPattern].unchecked;
			foreach(file; removedFiles)
				notifiers[pathPattern](Event.Remove, file);

		}
	}
}
