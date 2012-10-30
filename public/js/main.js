$(document).ready(function() {

  $("#doi-input").bind('paste keyup', function(e) {
    clearTimeout();
    setTimeout(function() {
      var val = $("#doi-input").val();
      $.get("/search/dois?q=" + encodeURIComponent(val)).done(function(data) {
	data = $.parseJSON(data);
	if (data.length > 0) {
	  $("#search-result").html(data[0]["fullCitation"]);
        } else {
	  $("#search-result").text("DOI doesn't exist");
        }
      });
    }, 500);
  });

  $("#citation-textarea").bind('paste keyup', function(e) {
    clearTimeout();
    setTimeout(function() {
      var val = $("#citation-textarea").text();
      $("#results-table").html();
      $.get("/search/dois?q=" + encodeURIComponent(val)).done(function(data) {
	data = $.parseJSON(data);
	$.each(data, function(i, result) {
	  var row = $("<tr>");
	  row.append($("<td>").html(result["fullCitation"]));
	  row.append($("<td>").html("<button class=\"btn\">Choose</button>"));
	  $("#results-table").append(row);
        });
      });
    });
  });

});