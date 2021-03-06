//
//  OpenNotSecurePageOperation.swift
//  mauth
//
//  Created by Marat S. on 21/02/16.
//  Copyright © 2016 m4rr. All rights reserved.
//

import Foundation
import WebKit

private let baseUrl🔓 = NSURL(string: "http://wtfismyip.com/text")! // unsecure but trusted website
private let baseUrl🔐 = NSURL(string: "https://wtfismyip.com/text")! // secure copy
private var request🔓 = NSURLRequest(URL: baseUrl🔓, cachePolicy: .ReloadIgnoringCacheData, timeoutInterval: 10)
private var request🔐 = NSURLRequest(URL: baseUrl🔐, cachePolicy: .ReloadIgnoringCacheData, timeoutInterval: 10)

protocol ConnectorDelegate: class {

  func updateLog(prefix: String, _ text: String)

  func connectorDidStartLoad(url: String)

  func connectorDidEndLoad(title: String, url: String)

  func connectorProgress(old old: Float, new: Float)

  func connectorDidGetSecurePageMatchHost()
  
}

//class OpenSecurePageOperation: OpenPageOperation {
//
//}

//class OpenNotSecurePageOperation: OpenPageOperation {
//
//}

final class OpenPageOperation: Operation {

  private weak var webView: WKWebView!
  private weak var delegate: ConnectorDelegate?

  init(webView: WKWebView! = nil, delegate: ConnectorDelegate) {
    assert(webView != nil, "webView should not be nil")

    self.delegate = delegate
    self.webView = webView

    super.init()

    addCondition(MutuallyExclusive<OpenPageOperation>())
  }

  private func isSecureBaseUrl(url: NSURL) -> (secure: Bool, base: Bool) {
    let secure = webView.hasOnlySecureContent // url.scheme == baseUrl🔐.scheme
    let base = url.host == (secure ? baseUrl🔐 : baseUrl🔓).host

    return (secure, base)
  }

  func connectorTryHttp() {
    webView.loadRequest(request🔓)
  }

  func connectorTryHttps() {
    webView.loadRequest(request🔐)
  }

  func checkWillRefresh(completion: (willRefresh: Bool) -> Void) {
    webView.evaluateJavaScript("document.getElementsByTagName('html')[0].outerHTML") { result, error in
      if let html = result as? String, _ = html.rangeOfString("http-equiv=\"refresh\"") {
        return completion(willRefresh: true)
      }

      return completion(willRefresh: false)
    }
  }

  func openDependingPage() {
    if webView.loading {
       webView.stopLoading()
    }

    guard let url = webView.URL where url.absoluteString != "about:blank" else {
      connectorTryHttp()

      return;
    }

    switch isSecureBaseUrl(url) {
    case (secure: false, base: true): // state of maxima's man-in-the-middle
      checkWillRefresh { (willRefresh) -> Void in
        if willRefresh {
          // meta-equiv case
          // wait for <meta http-equiv=refresh> redirect
          ()
        } else {
          // http passed successful case
          // medium well
          self.connectorTryHttps()
        }
      }
      
    case (secure: false, base: false): // state of branded page
      if url.host?.containsString("wi-fi") == false {
        // user clicked on ad, and so a branded page is loaded. go try http.
        connectorTryHttp()
      } else {
        // assume this is the first fake page. (or any other fake pages.)
        dispatch_after_delay_on_main_queue(4.5) {
          self.simulateJS()
        }
        // wait for user action
        //cancel()
      }

    case (secure: true, base: true): // well done
      delegate?.connectorDidGetSecurePageMatchHost()

      finish()

    //case (secure: true, base: false): // ???
    //  connectorTryHttps()

    default:
      // why not?
      connectorTryHttp()
    }
  }

  override func execute() {
    dispatch_async(dispatch_get_main_queue()) {
      self.webView.addObserver(self, forKeyPath: "estimatedProgress", options: [.Old, .New], context: nil)

      self.webView.navigationDelegate = self

      self.openDependingPage()
    }
  }

  override func finished(errors: [NSError]) {
    webView.removeObserver(self, forKeyPath: "estimatedProgress")
  }

}

// MARK: WKNavigationDelegate

extension OpenPageOperation: WKNavigationDelegate {

  func webView(webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    delegate?.connectorDidStartLoad(webView.URL?.absoluteString ?? "")
  }

  func webView(webView: WKWebView, didFinishNavigation navigation: WKNavigation!) {
    delegate?.connectorDidEndLoad(webView.title ?? "title", url: webView.URL?.absoluteString ?? "url")

    openDependingPage()
  }

  func webView(webView: WKWebView, didFailNavigation navigation: WKNavigation!, withError error: NSError) {
    delegate?.updateLog("didFailNavigation", error.description)
  }

  func webView(webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
    delegate?.updateLog("didReceiveServerRedirect", webView.URL?.absoluteString ?? "")
  }

  override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
    guard let keyPath = keyPath, change = change else {
      return;
    }

    switch keyPath {
    case "estimatedProgress":
      if let new = change["new"] as? Float, old = change["old"] as? Float {
        dispatch_async(dispatch_get_main_queue()) {
          self.delegate?.connectorProgress(old: old, new: new)
          //self.progressBar.setProgress(new, animated: old < new)
        }
      }

    default:
      ()
    }
  }

}

// MARK: JavaScript

extension OpenPageOperation {

  func simulateJS() {
    let aClick = [
      "document.querySelector('iframe#branding').contentDocument.body.querySelector('#root #content a').click();",
      "document.querySelector('iframe#branding').contentDocument.body.querySelector('#banner-metro').click();",
    ]

    aClick.forEach { query in
      webView.evaluateJavaScript(query) { result, error in
        if let error = error where error.code == WKErrorCode.JavaScriptExceptionOccurred.rawValue {
          // clicking by defunct selectors guaranteed produce errors
          self.delegate?.updateLog("js click err", "\(error.code)")
        } else {
          self.delegate?.updateLog("js click", "res")
        }
      }
    }
  }

}

