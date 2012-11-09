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
    if (metaTags[i].name === "dc.identifier") {
      identifier = metaTags[i].content;
      break;
    }
  }

  var cssLinkTag = document.createElement("link");
  cssLinkTag.setAttribute("rel", "stylesheet");
  cssLinkTag.setAttribute("type", "text/css");
  cssLinkTag.setAttribute("href", "http://localhost:9393/css/widget.css");
  headTag.appendChild(cssLinkTag);

  var dataScriptTag = document.createElement("script");

  if (identifier != null) {
    dataScriptTag.setAttribute("src", "http://localhost:9393/widget?doi=" + identifier);
  } else {
    dataScriptTag.setAttribute("src", "http://localhost:9393/widget/noid");
  }

  bodyTag.appendChild(dataScriptTag);  
})();