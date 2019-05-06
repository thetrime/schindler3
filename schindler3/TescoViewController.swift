//
//  TescoViewController.swift
//  schindler3
//
//  Created by Matthew Lilley on 05/05/2019.
//  Copyright © 2019 Matt Lilley. All rights reserved.
//

import Foundation
import UIKit
import WebKit

class TescoViewController: UIViewController, WKUIDelegate, WKScriptMessageHandler, WKNavigationDelegate {
    @IBOutlet weak var cancelButton: UIBarButtonItem!
    @IBOutlet weak var webView: WKWebView!
    override func viewDidLoad() {
        super.viewDidLoad()
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.configuration.userContentController.add(self, name: "callbackHandler")
        cancelButton.target = self;
        cancelButton.action = #selector(TescoViewController.cancelButtonPressed(button:));
        let defaults = UserDefaults.standard
        if let userId = defaults.string(forKey:"user_id"), let password = defaults.string(forKey:"password") {
            var urlParser = URLComponents()
            urlParser.queryItems = [
                URLQueryItem(name: "user_id", value: userId),
                URLQueryItem(name: "password", value: password)
            ]
            let urlEncoded = urlParser.percentEncodedQuery!
            let urlString = "https://\(NetworkManager.hostname):\(NetworkManager.port)/tesco?\(urlEncoded)"
            let myURL = URL(string:urlString)
            let myRequest = URLRequest(url: myURL!)
            webView.load(myRequest)
        }
    }
    
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // FIXME: Probably should check this is the expected certificate
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
    
    @objc func cancelButtonPressed(button: UIButton) {
        // Just the same, only do not call the callback
        dismiss(animated: true, completion: nil);
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if(message.name == "callbackHandler") {
            dismiss(animated: true, completion: nil);
        }
    }
    
}
