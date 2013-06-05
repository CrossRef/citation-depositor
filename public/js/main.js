$(document).ready(function() {

  // Animation
  $(".masthead ").hide();
  $(".masthead h1").fadeTo(0, 0);
  $(".masthead .byline").fadeTo(0, 0);
  $(".masthead .btn").fadeTo(0, 0);
  // 
  $('.masthead').slideDown(600, 'swing', function() {
    $('.masthead h1').delay(300).fadeTo( 300 , 1 , function() {
      $(".masthead .byline").fadeTo(300, 1, function() {
        $(".masthead .btn").delay(600).fadeTo(300, 1);
      });    
    });
  });

  // Navigation
  $(".dropdown a").click(function() {
    $(this).parent().children('ul').toggleClass("visuallyhidden");
  });

  function refreshResultList() {
    var val = $("#citation-textarea").text();
    $("#match-result").load("/dois/search?q=" + encodeURIComponent(val)).done(function() {
	addResultRowClickHandlers();
    });
  }

  function refreshDoiResult() {
    var val = $("#doi-input").val();
    $.get("/dois/info?doi=" + encodeURIComponent(val)).done(function(data) {
      if (data['status'] == 'ok') {
	$("#search-result-owner").text(data['owner_name']);
	$("#search-result-prefix").text(data['owner_prefix']);
	if (data['info']) {  
	  $("#search-result").html(data['info']['fullCitation']);
        }
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
    $("#upload-form").attr("action", "/deposit/" + pdfName + "/doi");
    $("#btn-next-doi").removeClass('disabled');
    $(".before-upload").hide();
    // $("#pick-button").unbind("click");
    $("#pick-button").html("<a href=\"#\" class=\"text-success\" id=\"pick-button\">" + pdfFilename + "</a>");
    $("#pick-button").removeClass("btn").addClass("");
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

  var makeSucc = function(text) {
    var $succ = $('<li>').addClass('text-success').append($('<i>').addClass('icon-ok-sign'));
    $succ.append(text);
    return $succ;
  };

  var makeFail = function(text) {
    var $fail = $('<li>').addClass('text-error').append($('<i>').addClass('icon-remove-sign'));
    $fail.append(text);
    return $fail;
  };

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

      var $container = $('#check-result');
      var $content = $('<ul>').addClass('icons').attr('style', 'margin-top: 1em;');
      $container.html('');

      var lines = [];

      if (data['has_meta']) {
	lines.push(makeSucc('The dc.identifier meta tag is present with a correctly formatted DOI.'));
      } else {
	lines.push(makeFail('The dc.identifier meta tag is missing, or it is not correctly formatted.'));
      }

      if (data['has_widget']) {
	lines.push(makeSucc('The references widget script tag is present.'));
      } else {
	lines.push(makeFail('The references widget script tag is missing.'));
      }

      if (data['has_content']) {
	lines.push(makeSucc('The references widget content div tag is present.'));
      } else {
	lines.push(makeFail('The references widget content div tag is missing.'));
      }

      if (data['doi']) {
	if (data['has_citations']) {
	  lines.push(makeSucc('The DOI has citations deposited with CrossRef.'));
	} else {
	  lines.push(makeFail('The DOI has no citations deposited. You may not have deposited any citations for this DOI, or the deposit may be queued for processing into the CrossRef database.'));
	}

	var $info = $('<li>').addClass('text-info').append($('<i>').addClass('icon-info-sign'));
	$info.append('The DOI on this landing page is ' + data['doi']);
	$content.append($info);
      }

      $.each(lines, function(idx, e) {
	$content.append(e);
      });

      $container.append($content);
    });

    e.preventDefault();
    return false;
  });

  var applyCitationRowCallbacks = function() {
    $('.citation-row').unbind('hover');
    $('.btn-citation-edit').unbind('click');
    $('.btn-citation-remove').unbind('click');
    $('.btn-citation-unremove').unbind('click');
    $('.btn-citation-add-up').unbind('click');
    $('.btn-citation-add-down').unbind('click');


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

    var insertCitation = function($citationRow, above) {
      var $newCitationRow = $citationRow.clone();
      var $citationText = $newCitationRow.find('.citation-text');
      
      $newCitationRow.find('.citation-body').hide();
      $newCitationRow.find('.citation-text').show();
      $newCitationRow.find('.citation-number').text('');

      if (above) {
	$newCitationRow.insertBefore($citationRow);
      } else {
	$newCitationRow.insertAfter($citationRow);
      }

      var index = parseInt($citationRow.attr('id'));

      if (!above) {
	index = index + 1;
      }

      $citationText.removeAttr('disabled');
      $citationText.focus();
      $citationText.blur(function(e) {
	if ($.trim($citationText.val()) == '') {
	  $newCitationRow.remove();
	} else {
	  $newCitationRow.find('.citation-loading-text').show();
	  $citationText.attr('disabled', 'disabled');
	  $.post('citations/' + index + '/insert', {text: $citationText.val()}).done(function(data) {
	    data = data['citation'];
	    $newCitationRow.find('.citation-loading-text').hide();
	    $citationText.hide();
	    $newCitationRow.find('.citation-str').text(data['text']);
	    $newCitationRow.find('.citation-str').removeClass('text-error');
	    $newCitationRow.find('.citation-str').css('text-decoration', 'none');
	    $newCitationRow.find('.btn-citation-remove').show();
	    $newCitationRow.find('.btn-citation-unremove').hide();
	    $newCitationRow.find('.citation-body').show();
	    $newCitationRow.find('.citation-controls').hide();
	    var $doiText = $newCitationRow.find('.citation-doi-text');
	    if (data['match']) {
	      $doiText.html('');
	      $doiText.addClass('text-success').removeClass('text-error');
	      $doiText.append($('<i>').addClass('icon-ok-circle').addClass('icon-white'));
	      $doiText.append(' Matched to ');
	      $doiText.append($('<strong>').text(data['doi']));
	    } else {
	      $doiText.html('');
	      $doiText.addClass('text-error').removeClass('text-success');
	      $doiText.append($('<i>').addClass('icon-remove-circle').addClass('icon-white'));
	      $doiText.append(' Not matched to a DOI');
	    }

	    $('.citation-row').each(function(index) {
	      $(this).find('.citation-number').text((index+1) + '.');
	      $(this).attr('id', index);
	    });

	    applyCitationRowCallbacks();
	  });
	}
	
	e.preventDefault();
	return false;
      });
    };

    $('.btn-citation-add-up').click(function(e) {
      var $citationRow = $(this).parents('.citation-row');
      insertCitation($citationRow, true);
      e.preventDefault();
      return false;
    });

    $('.btn-citation-add-down').click(function(e) {
      var $citationRow = $(this).parents('.citation-row');
      insertCitation($citationRow, false);
      e.preventDefault();
      return false;
    });
  };

  applyCitationRowCallbacks();

  $('.timeago').timeago();

  if (requiresRefresh) {
    var refresh = function() {
      $.get('status').done(function(data) {
	if (data['status'] == 'finished' || data['status'] == 'failed') {
          window.location.reload(true);
	} else {
          setTimeout(refresh, 5000);
	}
      }); 
    };
    setTimeout(refresh, 5000);
  }
});

