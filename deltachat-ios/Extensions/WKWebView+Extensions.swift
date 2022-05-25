//
//  SearchWKWebView.swift
//  SearchWKWebView
//
//  Created by Scott Stahurski on 1/9/19.
//
import Foundation
import WebKit

extension WKWebView {

    func highlightAllOccurencesOf(string: String) {
        
        guard let path = Bundle.main.url(forResource: "search", withExtension: "js", subdirectory: "Assets") else {
            logger.error("internal search js not found")
            return
        }
        do {
            let data: Data = try Data(contentsOf: path)
            let jsCode: String = String(decoding: data, as: UTF8.self)
            
            print(jsCode)
            
            // inject the search code
            self.evaluateJavaScript(jsCode, completionHandler: { result, error in
                if let error = error {
                    logger.error(error)
                }
            })
            // search function
            let searchString = "WKWebView_HighlightAllOccurencesOfString('\(string)')"
            // perform search
            self.evaluateJavaScript(searchString, completionHandler: { result, error in
                if let error = error {
                    logger.error(error)
                }
            })
        } catch {
            logger.error("could not load javascript: \(error)")

        }
    }
    
    func handleSearchResultCount( completionHandler: @escaping (_ count:Int) -> Void ) {
        // count function
        let countString  = "WKWebView_SearchResultCount"
        
        // get count
        self.evaluateJavaScript(countString) { (result, error) in
            if error == nil {
                if result != nil {
                        let count = result as! Int
                        completionHandler(count)
                }
            }
        }
    }
    
    
    func removeAllHighlights() {
        self.evaluateJavaScript("WKWebView_RemoveAllHighlights()", completionHandler: nil)
    }
    
    func searchNext() {
        self.evaluateJavaScript("WKWebView_SearchNext()", completionHandler: nil)
    }
    
    func searchPrevious() {
        self.evaluateJavaScript("WKWebView_SearchPrev()", completionHandler: nil)
    }
}
