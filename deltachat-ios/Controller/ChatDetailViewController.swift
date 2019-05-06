//
//  ChatDetailViewController.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 04.05.19.
//  Copyright © 2019 Jonas Reinsch. All rights reserved.
//

import UIKit

// TODO: checkout if it makes sense to  run group chats and single chats within this chatDetailViewController or maybe seperate these

class ChatDetailViewController: UIViewController {
  weak var coordinator: ChatDetailCoordinator?

  init(chatId _: Int) {
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = UIColor.white

    // Do any additional setup after loading the view.
  }

  /*
   // MARK: - Navigation

   // In a storyboard-based application, you will often want to do a little preparation before navigation
   override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
   // Get the new view controller using segue.destination.
   // Pass the selected object to the new view controller.
   }
   */
}
