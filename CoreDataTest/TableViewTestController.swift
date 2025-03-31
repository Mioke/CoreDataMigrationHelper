//
//  TableViewTestController.swift
//  CoreDataTest
//
//  Created by KelanJiang on 2024/10/23.
//

import UIKit

struct Element {
  let id: Int
  
  class Cell: UITableViewCell {
    
    static let reuseIdentifier: String = "Element.Cell"
    
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
    
    var id: Int = 0
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
      super.init(style: style, reuseIdentifier: reuseIdentifier)
    }
  }
}



class TableViewTestController: UIViewController {
  
  @IBOutlet weak var tableView: UITableView!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Do any additional setup after loading the view.
    tableView.delegate = self
    tableView.dataSource = self
    
    tableView.register(Element.Cell.self, forCellReuseIdentifier: Element.Cell.reuseIdentifier)
    tableView.isPrefetchingEnabled = false

    tableView.reloadData()
    
    
  }
  
  @IBAction func reload(_ sender: Any) {
    print("---------------------------------")
    tableView.reloadData()
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

extension TableViewTestController: UITableViewDelegate, UITableViewDataSource {
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    10
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
//    var cell = tableView.dequeueReusableCell(withIdentifier: Element.Cell.reuseIdentifier)
//    
//    if cell == nil {
//      cell = Element.Cell.init(style: UITableViewCell.CellStyle.default, reuseIdentifier: Element.Cell.reuseIdentifier)
//    }
    
    let cell = tableView.dequeueReusableCell(withIdentifier: Element.Cell.reuseIdentifier, for: indexPath)
    
    guard let cell = cell as? Element.Cell else { fatalError() }
    
    print("\(cell.id) -> \(indexPath.row)")
    cell.id = indexPath.row
  
    return cell
  }
  
  
}
