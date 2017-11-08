//
//  ContactViewController.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 08.11.17.
//  Copyright © 2017 Jonas Reinsch. All rights reserved.
//

import UIKit

class ContactViewController: UIViewController {

    var coordinator: Coordinator
    var contacts: [Int] = []
    
    
    init(coordinator: Coordinator) {
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        let c_contact = mrmailbox_get_known_contacts(mailboxPointer, nil)
        
        let len = carray_count(c_contact)
        
        
        
        //let con = convert(length: len, data: c_contact)
        
        
        
    }
    
    func convert(length: UInt32, data: UnsafePointer<UInt32>) -> [UInt32] {
        
        let buffer = UnsafeBufferPointer(start: data, count: Int(length));
        return Array(buffer)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
