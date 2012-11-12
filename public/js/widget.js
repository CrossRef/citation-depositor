function __depositor_callback(content) {
  var containerTag = document.getElementById("__depositor");
  containerTag.innerHTML = content;
}

(function() {
  var headTag = document.getElementsByTagName("head")[0];
  var bodyTag = document.getElementsByTagName("body")[0];
  var metaTags = document.getElementsByTagName("meta");
  var identifier = null;

  for (var i=0; i<metaTags.length; i++) {
    if (metaTags[i].name.toLowerCase() === "dc.identifier") {
      var metaValue = metaTags[i].content;
      var trimmedMetaValue = metaValue.replace(/^\s+|\s+$/g, '');
      if (trimmedMetaValue.slice(0, 4).toLowerCase() === 'doi:') {
        identifier = trimmedMetaValue.slice(4);
      } else {
	identifier = trimmedMetaValue;
      }
      break;
    }
  }

  var cssLinkTag = document.createElement("link");
  cssLinkTag.setAttribute("rel", "stylesheet");
  cssLinkTag.setAttribute("type", "text/css");
  cssLinkTag.setAttribute("href", "http://depositor.labs.crossref.org/css/widget.css");
  headTag.appendChild(cssLinkTag);

  var dataScriptTag = document.createElement("script");

  if (identifier != null) {
    dataScriptTag.setAttribute("src", "http://depositor.labs.crossref.org/widget?doi=" + identifier);
  } else {
    dataScriptTag.setAttribute("src", "http://depositor.labs.crossref.org/widget/noid");
  }

  bodyTag.appendChild(dataScriptTag);  
})();