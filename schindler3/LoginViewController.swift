//
//  LoginViewController.swift
//  schindler3
//
//  Created by Matthew Lilley on 13/04/2019.
//  Copyright © 2019 Matt Lilley. All rights reserved.
//

import Foundation
import UIKit

class LoginViewController: UIViewController {
    @IBOutlet weak var username: UITextField!
    @IBOutlet weak var password: UITextField!
    @IBOutlet weak var login: UIButton!
    var delegate: ListViewController!
    override func viewDidLoad() {
        super.viewDidLoad()
        login.addTarget(self, action:#selector(LoginViewController.loginButtonPressed(button:)), for: .touchUpInside);
    }
    
    @objc func loginButtonPressed(button: UIButton) {
        let defaults = UserDefaults.standard
        if let user = username.text, let pass = password.text {
            defaults.set(user, forKey: "user_id")
            defaults.set(pass, forKey: "password")
        }
        dismiss(animated: true, completion: nil);
        delegate.login()
    }
}
