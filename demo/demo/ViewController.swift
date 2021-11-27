//
//  ViewController.swift
//  demo
//
//  Created by Leavez on 2019/04/16.
//  Copyright © 2019 binary. All rights reserved.
//

import UIKit
import SnapKit
import ABC




class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
         let obj = ABC()
         obj.run()
        
        // Do any additional setup after loading the view.
        view.backgroundColor = .white
        
        
        let btn = UIButton()
        btn.backgroundColor = .red
        
        view.addSubview(btn)
        
        btn.snp.makeConstraints { make in
            make.left.equalToSuperview().inset(100)
            make.top.equalToSuperview().inset(100)
            make.width.height.equalTo(100)
        }
        
        
    }


}

