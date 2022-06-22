
// We're using a global variable to store the number of occurrences
var WKWebView_CurrentlySelected = -1;
var WKWebView_SearchResultCount = 0;

// helper function, recursively searches in elements and their child nodes
function WKWebView_HighlightAllOccurencesOfStringForElement(element,keyword) {
    
    if (element) {
        if (element.nodeType == 3) {        // Text node
            while (true) {
                var value = element.nodeValue;  // Search for keyword in text node
                var idx = value.toLowerCase().indexOf(keyword);
                
                if (idx < 0) break;             // not found, abort
                
                var span = document.createElement("span");
                var text = document.createTextNode(value.substr(idx,keyword.length));
                span.appendChild(text);
                span.setAttribute("class","WKWebView_Highlight");
                span.style.backgroundColor="yellow";
                span.style.color="black";
                text = document.createTextNode(value.substr(idx+keyword.length));
                element.deleteData(idx, value.length - idx);
                var next = element.nextSibling;
                element.parentNode.insertBefore(span, next);
                element.parentNode.insertBefore(text, next);
                element = text;
                WKWebView_SearchResultCount++;  // update the counter
                
            }
        } else if (element.nodeType == 1) { // Element node
            if (WKWebView_isElementVisible(element) && element.nodeName.toLowerCase() != 'select') {
                for (var i=element.childNodes.length-1; i>=0; i--) {
                    WKWebView_HighlightAllOccurencesOfStringForElement(element.childNodes[i],keyword);
                }
            }
        }
    }
}

function WKWebView_SearchNext(){
    WKWebView_jump(1);
}
function WKWebView_SearchPrev(){
    WKWebView_jump(-1);
}

function WKWebView_jump(increment){
    prevSelected = WKWebView_CurrentlySelected;
    WKWebView_CurrentlySelected = WKWebView_CurrentlySelected + increment;
    
    if (WKWebView_CurrentlySelected < 0){
        WKWebView_CurrentlySelected = WKWebView_SearchResultCount + WKWebView_CurrentlySelected;
    }
    
    if (WKWebView_CurrentlySelected >= WKWebView_SearchResultCount){
        WKWebView_CurrentlySelected = WKWebView_CurrentlySelected - WKWebView_SearchResultCount;
    }
    
    prevEl = document.getElementsByClassName("WKWebView_Highlight")[prevSelected];
    
    if (prevEl){
        prevEl.style.backgroundColor="yellow";
    }
    el = document.getElementsByClassName("WKWebView_Highlight")[WKWebView_CurrentlySelected];
    el.style.backgroundColor="orange";
    
    el.scrollIntoView(true);
}


// the main entry point to start the search
function WKWebView_HighlightAllOccurencesOfString(keyword) {
    WKWebView_RemoveAllHighlights();
    WKWebView_HighlightAllOccurencesOfStringForElement(document.body, keyword.toLowerCase());
    WKWebView_HandleFocus();
}

// ensures the webview can become the first reponder by adding a hidden contentEditable div
function WKWebView_HandleFocus() {
    var searchFocusDiv = document.getElementById("WKWebView_SearchFocus");
    if (WKWebView_SearchResultCount > 0) {
        if (searchFocusDiv == null) {
            searchFocusDiv = document.createElement("div");
            searchFocusDiv.setAttribute("contenteditable", "true");
            searchFocusDiv.id="WKWebView_SearchFocus";
            searchFocusDiv.style.height = "0";
            searchFocusDiv.style.width = "0";
            searchFocusDiv.style.overflow = "hidden";
            searchFocusDiv.style.outline = "0px solid transparent";
            document.body.appendChild(searchFocusDiv);
        }
        WKWebView_SearchNext();
    } /*else {
        if (searchFocusDiv != null) {
            searchFocusDiv.parentNode.removeChild(searchFocusDiv);
        }
    }*/
}

function WKWebview_Focus() {
    console.log("WKWebview_Focus_WebView");
    document.getElementById("WKWebView_SearchFocus").focus();
    var el = document.getElementsByClassName("WKWebView_Highlight")[WKWebView_CurrentlySelected];
    el.scrollIntoView(true);
}

function WKWebview_ResignFocus() {
    console.log("WKWebview_Focus_WebView");
    var searchFocusDiv = document.getElementById("WKWebView_SearchFocus");
    if (searchFocusDiv != null) {
        searchFocusDiv.parentNode.removeChild(searchFocusDiv);
    }
}

// helper function, recursively removes the highlights in elements and their childs
function WKWebView_RemoveAllHighlightsForElement(element) {
    if (element) {
        if (element.nodeType == 1) {
            if (element.getAttribute("class") == "WKWebView_Highlight") {
                var text = element.removeChild(element.firstChild);
                element.parentNode.insertBefore(text,element);
                element.parentNode.removeChild(element);
                return true;
            } else {
                var normalize = false;
                for (var i=element.childNodes.length-1; i>=0; i--) {
                    if (WKWebView_RemoveAllHighlightsForElement(element.childNodes[i])) {
                        normalize = true;
                    }
                }
                if (normalize) {
                    element.normalize();
                }
            }
        }
    }
    return false;
}

// the main entry point to remove the highlights
function WKWebView_RemoveAllHighlights() {
    
    WKWebView_SearchResultCount = 0;
    WKWebView_CurrentlySelected = -1;
    
    WKWebView_RemoveAllHighlightsForElement(document.body);
}

function WKWebView_isElementVisible(element) {
    var style = window.getComputedStyle(element);
    var isvisible = style.width > "0" &&
    style.height > "0" &&
    style.opacity > "0" &&
    style.display !=='none' &&
    style.visibility !== 'hidden';
    return isvisible;
}
