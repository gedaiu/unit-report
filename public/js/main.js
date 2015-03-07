$(function() {
	$('body').on('click', 'a', function() {
		var elm = $( $(this).attr("href") );

	    $('html, body').animate({
	        scrollTop: $(elm).offset().top
	    }, 500);

	    return false;
	});

	if(typeof(Worker) !== "undefined") {
	    w = new Worker("js/logWorker.js");

	    w.onmessage = function(e) {
			var data = JSON.parse(e.data);

			console.log(data);

			if(data.message == "htmlResults")
		  		$("#results").html(data.html);

			if(data.message == "htmlMenu")
		  		$("#menu").html(data.html);

		  	if(data.message == "addBodyClass")
		  		$("body").addClass(data.cls);

		  	if(data.message == "removeBodyClass")
		  		$("body").removeClass(data.cls);
		}

		$(".btn-run-test").click(function() {
			w.postMessage("runTest");
		});

	} else {
	    alert("Web workers are not supported. Try a newer browser!");
	}
})
