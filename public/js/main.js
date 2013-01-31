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

  if ($("#doi-input").length != 0) {
    refreshDoiResult();
  }

  if ($("#citation-textarea").length != 0) {
    refreshResultList();
  }

  $('#btn-check').click(function(e) {
    var $btn = $(this);
    if ($btn.hasClass('disabled') || $('#input-url').val() == '') {
      e.preventDefault();
      return false;
    }

    $btn.addClass('disabled');
    $btn.find('i').addClass('icon-spin');

    $.get('/help/check', {url: $('#input-url').val()}).done(function(data) {
      $btn.removeClass('disabled');
      $btn.find('i').removeClass('icon-spin');

      $container = $('#check-result');
      $content = $('<ul>').addClass('icons').attr('style', 'margin-top: 1em;');
      $container.html('');

      if (data['has_meta']) {
	$succ = $('<li>').addClass('text-success').append($('<i>').addClass('icon-ok-sign'));
	$succ.append('The dc.identifier meta tag is present with a correctly formatted DOI.');
	$content.append($succ);
      } else {
	$fail = $('<li>').addClass('text-error').append($('<i>').addClass('icon-remove-sign'));
	$fail.append('The dc.identifier meta tag is missing, or it is not correctly formatted.');
	$content.append($fail);
      }

      if (data['has_widget']) {
	$succ = $('<li>').addClass('text-success').append($('<i>').addClass('icon-ok-sign'));
	$succ.append('The references widget script tag is present.');
	$content.append($succ);
      } else {
	$fail = $('<li>').addClass('text-error').append($('<i>').addClass('icon-remove-sign'));
	$fail.append('The references widget script tag is missing.');
	$content.append($fail);
      }

      if (data['has_content']) {
	$succ = $('<li>').addClass('text-success').append($('<i>').addClass('icon-ok-sign'));
	$succ.append('The references widget content div tag is present.');
	$content.append($succ);
      } else {
	$fail = $('<li>').addClass('text-error').append($('<i>').addClass('icon-remove-sign'));
	$fail.append('The references widget content div tag is missing.');
	$content.append($fail);
      }

      if (data['doi']) {
	if (data['has_citations']) {
	  $succ = $('<li>').addClass('text-success').append($('<i>').addClass('icon-ok-sign'));
	  $succ.append('The DOI has citations deposited with CrossRef.');
	  $content.append($succ);
	} else {
	  $fail = $('<li>').addClass('text-error').append($('<i>').addClass('icon-remove-sign'));
	  $fail.append('The DOI has no citations deposited. You may not have deposited any citations for this DOI, or the deposit may be queued for processing into the CrossRef database.');
	  $content.append($fail);
	}

	$info = $('<li>').addClass('text-info').append($('<i>').addClass('icon-info-sign'));
	$info.append('The DOI on this landing page is ' + data['doi']);
	$content.append($info);
      }

      $container.append($content);
    });

    e.preventDefault();
    return false;
  });

  $('.citation-row').hover(function(e) {
    $(this).find('.citation-controls').show();
    e.preventDefault();
    return false;
  }, function(e) {
    $(this).find('.citation-controls').hide();
    e.preventDefault();
    return false;
  });

  $('.btn-citation-edit').click(function(e) {
    window.location = window.location + "/" + $(this).parents('.citation-row').attr('id');
    e.preventDefault();
    return false;
  });

  $('.btn-citation-remove').click(function(e) {
    var $citationRow = $(this).parents('.citation-row');
    $citationRow.find('p').css('text-decoration', 'line-through');
    $citationRow.find('p').addClass('text-error');
    $citationRow.find('.btn-citation-unremove').show();
    $(this).hide();

    $.get('citations/' + $citationRow.attr('id') + '/remove');

    e.preventDefault();
    return false;
  });

  $('.btn-citation-unremove').click(function(e) {
    var $citationRow = $(this).parents('.citation-row');
    $citationRow.find('p').css('text-decoration', 'none');
    $citationRow.find('p').removeClass('text-error');
    $citationRow.find('.btn-citation-remove').show();
    $(this).hide();

    $.get('citations/' + $citationRow.attr('id') + '/unremove');

    e.preventDefault();
    return false;
  });

  $('.btn-citation-edit').tooltip({title: 'Edit'});
  $('.btn-citation-add-up').tooltip({title: 'Add above'});
  $('.btn-citation-add-down').tooltip({title: 'Add below'});
  $('.btn-citation-remove').tooltip({title: 'Remove'});
  $('.btn-citation-unremove').tooltip({title: 'Undo remove'});

  $('.timeago').timeago();

  if (requiresRefresh) {
    var refresh = function() {
      $.get('status').done(function(data) {
	if (data['status'] == 'finished' || data['status'] == 'failed') {
          window.location.reload(true);
	}
      }); 
    };
    setTimeout(refresh, 5000);
  }
});

