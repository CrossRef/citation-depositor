$(document).ready(function() {
  function refreshResultList() {
    var val = $("#citation-textarea").text();
    $("#results-table").html('');
    $.get("/dois/search?q=" + encodeURIComponent(val)).done(function(data) {
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
    $.get("/dois/info?doi=" + encodeURIComponent(val)).done(function(data) {
      if (data['status'] == 'ok') {
	$("#search-result-owner").text(data['owner_name']);
	$("#search-result-prefix").text(data['owner_prefix']);
	$("#search-result").html(data['info']['fullCitation']);
	$("#search-result-info").removeClass('hidden');
	$("#btn-next-citations").removeClass('disabled');
      } else {
	$("#search-result").text("DOI doesn't exist");
	$("#search-result-info").addClass('hidden');
	$("#btn-next-citations").addClass('disabled');
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
    $("#search-result").html("<center><img class=\"loader\" src=\"/img/loader.gif\"></img></center>");
    $("#search-result-info").addClass("hidden");
    $("#btn-next-citations").addClass('disabled');
    timeIt(refreshDoiResult, 500);
  });

  $("#citation-textarea").bind('paste keyup', function(e) {
    $("#results-table").html("<center><img class=\"loader\" src=\"/img/loader.gif\"></img></center>");
    timeIt(refreshResultList, 500);
  });

  $("#btn-next-citations").click(function(e) {
    if (!$(this).hasClass('disabled')) {
      $('#form-doi').submit();
    }
    e.preventDefault();
    return false;
  });

  $("#btn-back-upload").click(function(e) {
    window.location.href = "/deposit";
    e.preventDefault();
    return false;
  });

  $("#btn-back-doi").click(function(e) {
    window.location.href = "doi";
    e.preventDefault();
    return false;
  });

  function afterFileUpload(pdfFilename, pdfName) {
    $("#btn-next-doi").click(function(e) {
      window.location.href = "/deposit/" + pdfName + "/doi";
      e.preventDefault();
      return false;
    });
    $("#btn-next-doi").removeClass('disabled');
    $(".before-upload").hide();
    $("#pick-button").unbind("click");
    $("#pick-button").html("<center><h3 class=\"text-success\">" + pdfFilename + " uploaded!</h3>");
    $("#pick-button").removeClass("dashed-well").addClass("success-dashed-well");
  };

  $("#pick-button").click(function(e) {
    filepicker.pick({mimetypes: ['application/pdf']},
		    function(FPFile) {
		      $.post("/deposit", {url: FPFile.url, filename: FPFile.filename}).done(function(data) {
			afterFileUpload(FPFile.filename, data['pdf_name']);
		      });
		    });
    e.preventDefault();
    return false;
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

  $('.timeago').timeago();
});

