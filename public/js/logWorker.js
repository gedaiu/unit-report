self.onmessage = function(e) {
	console.log(e.data);

	if(e.data == "runTest")
		ws.send("runTest");

	if(e.data == "stopTest")
		ws.send("stopTest");
}

console.log(self.onmessage, self);

var ws = new WebSocket("ws://127.0.0.1:8080/ws");

ws.onopen = function() {
	console.log("open");
	ws.send("get");
}

ws.onmessage = function (evt) 
{ 
	var received_msg = JSON.parse(evt.data);
	console.log("Message is received:", received_msg);

	if(received_msg.message == "log") {
		var groups = groupItems(JSON.parse(received_msg.data));

		postMessage(JSON.stringify({
			message: "htmlResults",
			html: createResultHtml(groups)
		}));

		postMessage(JSON.stringify({
			message: "htmlMenu",
			html: createMenuHtml(groups)
		}));
	}

	if(received_msg.message == "testBegin") {
		postMessage(JSON.stringify({
			message: "addBodyClass",
			cls: "runningTest"
		}));

		postMessage(JSON.stringify({
			message: "executionTime",
			text: "0s"
		}));
	}

	if(received_msg.message == "testEnd") {
		postMessage(JSON.stringify({
			message: "removeBodyClass",
			cls: "runningTest"
		}));
	}

	if(received_msg.message == "executionTime") {
		postMessage(JSON.stringify({
			message: "executionTime",
			text: parseInt(parseInt(received_msg.msecs) / 1000) + "s"
		}));
	}
};

ws.onclose = function()
{ 
	console.log("Connection is closed..."); 
};

function groupItems(data) {
	var groups = {};

	for(i in data) {
		var group = data[i].qualifiedName.split(".");
		group.pop();
		group = group.join(".");

		if(!groups[group])
			groups[group] = [];

		groups[group].push( data[i] );
	}

	return groups;
}


function createResultItemHtml(index, item) {
	var str;
	var cls = "";

	if(!item.success)
		cls = "danger";

	str = "<tr class='"+cls+"'>\
            <td>"+index+"</td>\
            <td>"+item.name+"</td>\
            <td>"+item.success+"</td>\
            <td>"+item.duration+"</td>\
        </tr>";

	return str;
}

function createResultHtml(groups) {
	var str = "";

	for(group in groups) {
		str += '<div class="panel panel-default" id="'+toId(group)+'">';
		str += '<div class="panel-heading"><h3 class="panel-title">' + group + '</h3></div>';

		str += "<table class='table table-hover'>\
            <thead>\
                <tr>\
                    <th>#</th>\
                    <th>Name</th>\
                    <th>Success</th>\
                    <th>Duration</th>\
                </tr>\
            </thead>\
            <tbody>";

            for(i in groups[group])
            	str += createResultItemHtml(i, groups[group][i])

         str += "</tbody></table></div>";
	}

	return str;
}

function createMenuHtml(groups) {
	str = '<ul class="nav nav-pills nav-stacked">';

	for(group in groups) {
		str += '<li role="presentation"><a href="#'+toId(group)+'">'+group+'</a></li>';
	}

	str += '</ul>';

	return str;
}

function toId(name) {
	//Lower case everything
    name = name.toLowerCase();
    //Make alphanumeric (removes all other characters)
    name = name.replace(/[^a-z0-9_\s-]\//gi, "");
    //Clean up multiple dashes or whitespaces
    name = name.replace(/[\s-]+/gi, " ");
    //Convert whitespaces and underscore to dash
    name = name.replace(/[\s_.]/gi, "-");
    return name;
}



