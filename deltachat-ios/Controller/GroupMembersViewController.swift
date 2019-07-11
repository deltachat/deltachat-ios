import UIKit

class NewGroupViewController: GroupMembersViewController {
  weak var coordinator: NewGroupCoordinator?

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "New Group"
    navigationController?.navigationBar.prefersLargeTitles = false
    let groupCreationNextButton = UIBarButtonItem(title: "Next", style: .done, target: self, action: #selector(nextButtonPressed))
    navigationItem.rightBarButtonItem = groupCreationNextButton
    contactIds = Utils.getContactIds()
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
  }

  @objc func nextButtonPressed() {
    coordinator?.showGroupNameController(contactIdsForGroup: selectedContactIds)
  }
}

class AddGroupMembersViewController: GroupMembersViewController {
  private var chatId: Int?

  private lazy var resetButton: UIBarButtonItem = {
    let button = UIBarButtonItem(title: "Reset", style: .plain, target: self, action: #selector(resetButtonPressed))
    button.isEnabled = false
    return button
  }()

  override var selectedContactIds: Set<Int> {
    didSet {
      resetButton.isEnabled = !selectedContactIds.isEmpty
    }
  }

  private lazy var chat: MRChat? = {
    if let chatId = chatId {
      return MRChat(id: chatId)
    }
    return nil
  }()

  private lazy var chatMemberIds: [Int] = {
    if let chat = chat {
      return chat.contactIds
    }
    return []
  }()

  private lazy var memberCandidateIds: [Int] = {
    var contactIds = Set(Utils.getContactIds()) // turn into set to speed up search
    for member in chatMemberIds {
      contactIds.remove(member)
    }
    return Array(contactIds)
  }()

  init(chatId: Int) {
    super.init()
    self.chatId = chatId
  }

  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    super.contactIds = memberCandidateIds
    super.navigationItem.rightBarButtonItem = resetButton
    title = "Add Group Members"
    // Do any additional setup after loading the view.
  }

  override func viewWillDisappear(_: Bool) {
    guard let chatId = chatId else {
      return
    }
    for contactId in selectedContactIds {
      dc_add_contact_to_chat(mailboxPointer, UInt32(chatId), UInt32(contactId))
    }
  }

  @objc func resetButtonPressed() {
    selectedContactIds = []
    tableView.reloadData()
  }
}

class GroupMembersViewController: UITableViewController {
  let contactCellReuseIdentifier = "contactCell"

  var contactIds: [Int] = [] {
    didSet {
      tableView.reloadData()
    }
  }

  var selectedContactIds: Set<Int> = []

  init() {
    super.init(nibName: nil, bundle: nil)
    hidesBottomBarWhenPushed = true
  }

  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    tableView.register(ContactCell.self, forCellReuseIdentifier: contactCellReuseIdentifier)
  }

  override func numberOfSections(in _: UITableView) -> Int {
    return 1
  }

  override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
    return contactIds.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard let cell: ContactCell = tableView.dequeueReusableCell(withIdentifier: contactCellReuseIdentifier, for: indexPath) as? ContactCell else {
      fatalError("shouldn't happen")
    }

    let row = indexPath.row
    let contactRow = row

    let contact = MRContact(id: contactIds[contactRow])
    cell.nameLabel.text = contact.name
    cell.emailLabel.text = contact.email
    cell.initialsLabel.text = Utils.getInitials(inputName: contact.name)
    cell.accessoryType = selectedContactIds.contains(contactIds[row]) ? .checkmark : .none
    cell.setColor(contact.color)

    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let row = indexPath.row
    if let cell = tableView.cellForRow(at: indexPath) {
      tableView.deselectRow(at: indexPath, animated: true)
      let contactId = contactIds[row]
      if selectedContactIds.contains(contactId) {
        selectedContactIds.remove(contactId)
        cell.accessoryType = .none
      } else {
        selectedContactIds.insert(contactId)
        cell.accessoryType = .checkmark
      }
    }
  }
}
