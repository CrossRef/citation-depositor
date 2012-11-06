$(document).ready(function() {
  function refreshResultList() {
    var val = $("#citation-textarea").text();
    $("#results-table").html('');
    $.get("/search/dois?q=" + encodeURIComponent(val)).done(function(data) {
      $.each(data, function(i, result) {
	var row = $("<tr>").addClass("result-row");
	row.append($("<td>").addClass("result-doi").text(result["doi"]));
	row.append($("<td>").addClass("result-text").html(result["fullCitation"]));
	$("#results-table").append(row);
      });
      addResultRowClickHandlers();
    });
  }

  function refreshDoiResult() {
    var val = $("#doi-input").val();
    $.get("/search/dois?q=" + encodeURIComponent(val)).done(function(data) {
      if (data.length > 0) {
	$("#search-result").html(data[0]["fullCitation"]);
      } else {
	$("#search-result").text("DOI doesn't exist");
      }
    });
  }

  function addResultRowClickHandlers() {
    $(".result-row").click(function(e) {
      var newText = $(this).find(".result-text").text();
      var newDoi = $(this).find(".result-doi").text();
      
      $("#citation-textarea").text(newText);
      
      var div = $("<div>").addClass("alert").addClass("alert-success");
      div.text("Matched to " + newDoi);
      
      $("#citation-doi-info").html("");
      $("#citation-doi-info").append(div);
      
      $("#citation-text-input").val(newText);
      $("#citation-doi-input").val(newDoi);
      
      refreshResultList();
      
      e.preventDefault();
      return false;
    });
  }

  var timeIt = (function() {
    var timer = 0;
    return function(callback, ms) {
      clearTimeout(timer);
      timer = setTimeout(callback, ms);
      }
  })();

  $("#doi-input").bind('paste keyup', function(e) {
    timeIt(refreshDoiResult, 500);
  });

  $("#citation-textarea").bind('paste keyup', function(e) {
    timeIt(refreshResultList, 500);
  });

  $(".citation-row").click(function(e) {
    window.location = window.location + "/" + $(this).attr("id");
    e.preventDefault();
    return false;
  });

  if ($("#doi-input").length != 0) {
    refreshDoiResult();
  }

  if ($("#citation-textarea").length != 0) {
    refreshResultList();
  }
});

