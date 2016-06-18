//
//  NeatViewController.swift
//  mauth
//
//  Created by Marat S. on 11.12.15. (First vesion — on 20.09.15: commit 2b3a696.)
//  Copyright © 2015 m4rr. All rights reserved.
//

import UIKit
import WebKit
import PureLayout
import PKHUD

/**

 Firstly loaded http-page that redirected to the auth page.
 Tap on ad loads an ad-page.
 After that trying to load a https-page.

 */

class NeatViewController: UIViewController {
  
  private lazy var webView = WKWebView()
  @IBOutlet weak var navBar: UIView!
  @IBOutlet weak var addressLabel: UILabel!
  @IBOutlet weak var progressBar: UIProgressView!
  @IBOutlet weak var logTextView: UITextView!
  @IBOutlet var quickOpenView: UIView!

  let operationQueue = OperationQueue()
  lazy var reachability = Reachability.reachabilityForInternetConnection()

  override func viewDidLoad() {
    super.viewDidLoad()

    setupQuickOpenView()
    setupWebView()
    startOperating(self)
    subscribeNotifications()

    let _ = LogManager(webView: webView)
  }

  deinit {
    unsubscribeNotifications()
  }

  override func updateViewConstraints() {
    webView.autoPinEdge(.Left, toEdge: .Left, ofView: view)
    webView.autoPinEdge(.Right, toEdge: .Right, ofView: view)
    webView.autoPinEdge(.Top, toEdge: .Bottom, ofView: navBar)
    webView.autoPinEdge(.Bottom, toEdge: .Bottom, ofView: view)

    quickOpenView.autoAlignAxis(.Horizontal, toSameAxisOfView: logTextView)
    quickOpenView.autoAlignAxis(.Vertical, toSameAxisOfView: logTextView)

    super.updateViewConstraints()
  }

  private func subscribeNotifications() {
    NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(NeatViewController.startOperating(_:)), name: didBecomeActiveNotification, object: nil)
  }

  private func unsubscribeNotifications() {
    NSNotificationCenter.defaultCenter().removeObserver(self)
  }

  private func setupWebView() {
    let config = WKWebViewConfiguration()
    config.allowsInlineMediaPlayback = false
    config.suppressesIncrementalRendering = false

    if #available(iOS 9.0, *) {
      config.allowsAirPlayForMediaPlayback = false
      config.allowsPictureInPictureMediaPlayback = false
      config.requiresUserActionForMediaPlayback = true
    } else {
      config.mediaPlaybackRequiresUserAction = true
      config.mediaPlaybackAllowsAirPlay = false
    }

    //let cutAudioUserScript = WKUserScript(source: "var x = document.getElementsByClassName('audio'); var i; for (i = 0; i < x.length; i++) { x[i].outerHTML = ''; }", injectionTime: .AtDocumentEnd, forMainFrameOnly: false)
    //config.userContentController.addUserScript(userScript)

    webView = WKWebView(frame: view.bounds, configuration: config)

    if #available(iOS 9.0, *) {
        webView.customUserAgent = "Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; WOW64; Trident/5.0; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET CLR 3.0.30729; Media Center PC 6.0; InfoPath.3; .NET4.0C; .NET4.0E; FerrariGT)" // vertu user-agent :)
    } else {
        // Fallback on earlier versions
    }

    webView.alpha = 0.3

    view.insertSubview(webView, atIndex: 0)

    view.updateConstraintsIfNeeded()
  }

  private func setupQuickOpenView() {
    view.addSubview(quickOpenView)
    //quickOpenView.layer.borderColor = UIColor(white: 0.8, alpha: 1).CGColor
    quickOpenView.layer.borderWidth = 0
    quickOpenView.layer.cornerRadius = 2
    quickOpenView.layer.shadowColor = UIColor(white: 0.5, alpha: 1).CGColor
    quickOpenView.layer.shadowOffset = CGSize(width: 0, height: 2)
    quickOpenView.layer.shadowOpacity = 1
    quickOpenView.layer.shadowRadius = 5

    quickOpenView.subviews.forEach {
      $0.layer.cornerRadius = 2
    }
  }

  private lazy var auther: MosMetroAuth = MosMetroAuth(logger: self.updateLog)

  private func tryItAuto() -> Void {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) { () -> Void in
      self.auther.go()
    }
  }

  /// This also used via selector.
  internal func startOperating(sender: NSObject) {
    hideQuickOpen()

    switch sender {
    case is UIButton: // retry button tap
      ()
    case let x where x == self: // viewDidLoad
      return tryItAuto()
    case is NSNotification: // app did become active
      ()
    default: // wtf
      ()
    }

    if #available(iOS 9.0, *) {
      webView.loadHTMLString("", baseURL: nil)
    } else {

    }

    checkWiFi()
  }

  internal func startOperatingWithWiFi() {
    let operation = OpenPageOperation(webView: webView, delegate: self)
    operationQueue.addOperation(operation)
  }

  @IBAction func retryButtonTap(sender: UIButton) {
    updateLog("⤴\u{fe0e}", NSLocalizedString("Retry", comment: "Retry (log)")) // ⎋

    startOperating(sender)
  }

  // Shake-shake-shake.
  override func canBecomeFirstResponder() -> Bool {
    return true
  }

  // Shake gesture to view source code.
  override func motionEnded(motion: UIEventSubtype, withEvent event: UIEvent?) {
    if motion == .MotionShake {
      performSegueWithIdentifier("show-source-code", sender: nil)
    }
  }

  // Unwind from source code viewer to here.
  @IBAction func unwindToNeat(segue: UIStoryboardSegue) {

  }

}

// MARK: ConnectorDelegate

extension NeatViewController: ConnectorDelegate {

  func updateLog(items: String...) -> Void {
    updateLog(items)
  }

  func updateLog(items: [String]) -> Void {
    let text = items.reduce(String()) {
      $0 + $1 + " "
    }
    dispatch_async_on_main_queue {
      self.logTextView.text = text + "\n" + (self.logTextView.text ?? "")
    }
  }

  func connectorDidStartLoad(url: String) {
    addressLabel.text = url

    updateLog("▶", url)
  }

  func connectorDidEndLoad(title: String, url: String) {
    addressLabel.text = url

    updateLog("◼", url)
  }

  func connectorProgress(old old: Float, new: Float) {
    progressBar.setProgress(new, animated: old < new)

    UIView.animateWithDuration(0.5) {
      self.progressBar.alpha = new < 1 ? 1 : 0
    }
  }

  func connectorDidGetSecurePageMatchHost() {
    showSuccessHUD()
    showQuickOpen()
  }

  private func showSuccessHUD() {
    PKHUD.sharedHUD.contentView = PKHUDSuccessView()
    PKHUD.sharedHUD.dimsBackground = false
    PKHUD.sharedHUD.userInteractionOnUnderlyingViewsEnabled = true
    PKHUD.sharedHUD.show()
    PKHUD.sharedHUD.hide(afterDelay: 2.0)
  }

  private func hideQuickOpen() {
    quickOpenView.hidden = true
  }

  private func showQuickOpen() {
    quickOpenView.alpha = 0
    quickOpenView.hidden = false

    UIView.animateWithDuration(0.25, delay: 0, options: .CurveEaseIn,
      animations: {
        self.quickOpenView.alpha = 1
      }, completion: nil)
  }

}

// MARK: UI Actions

extension NeatViewController {

  private func openURL(urlString: String) {
    guard let url = NSURL(string: urlString) else {
      return
    }

    if UIApplication.sharedApplication().canOpenURL(url) {
       UIApplication.sharedApplication().openURL(url)
    }
  }

  @IBAction func openTwitter(sender: UIButton) {
    openURL("twitter://")
  }

  @IBAction func openFacebook(sender: UIButton) {
    openURL("fb://")
  }

  @IBAction func openVk(sender: UIButton) {
    openURL("vk://")
  }

  @IBAction func openInstagram(sender: UIButton) {
    openURL("instagram://")
  }

  @IBAction func openSafari(sender: UIButton) {
    openURL("https://www.apple.com")
  }

  @IBAction func rateOnAppStore(sender: UIButton) {
    let appId = "1041801794"
    //let appLink = "itms-apps://itunes.apple.com/app/id" + appId
    //let appLink = "https://itunes.apple.com/app/moskva.-metro.-avtorizacia/id1041801794?mt=8"
    let appLink = "https://itunes.apple.com/app/viewContentsUserReviews?id=\(appId)"
    openURL(appLink)
  }

}

/// Parttern matching of Optional<String> for the "accessibilityIdentifier" case.
func ~=(lhs: String, rhs: String?) -> Bool {
  return lhs == rhs
}
