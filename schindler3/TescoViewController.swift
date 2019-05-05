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

class TescoViewController: UIViewController, WKUIDelegate, WKScriptMessageHandler {
    @IBOutlet weak var cancelButton: UIBarButtonItem!
    @IBOutlet weak var webView: WKWebView!
    override func viewDidLoad() {
        super.viewDidLoad()
        webView.uiDelegate = self
        webView.configuration.userContentController.add(self, name: "callbackHandler")
        cancelButton.target = self;
        cancelButton.action = #selector(TescoViewController.cancelButtonPressed(button:));
        let myURL = URL(string:"http://192.168.1.10:9007/xtesco?user_id=matt&password=notverysecretatall")
        let myRequest = URLRequest(url: myURL!)
        webView.load(myRequest)
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
