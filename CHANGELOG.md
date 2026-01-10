# Delta Chat iOS Changelog

## Unreleased

- Truncate file names in the middle, not at the end; important information are more often at the end
- Fix: Online indicator in the chat navigation bar now updates correctly when returning from background
- Fix: Allow iframe srcdoc in webxdc 


## v2.35.0
2026-01

- Scanning a QR code with a relay ask for adding it as additional transport
- Ask for device owner verification on profile deletion
- Better logging
- Longer call ringing time
- Add fallback TURN server for experimental calls
- Prefill DNS cache
- Improve error message on adding relays
- Show relays in log
- Set explicit relay limit to 5
- Remove deprecated "real-time apps" switch
- Simplify automatic deletion options
- Fix: Show input-bar after QR scan immediately
- Fix: Remove sometimes misleading "Please wait..." after QR code scan
- Fix: Do not set normalized name for existing chats and contacts; it takes too long sometimes
- Fix: Show relays in connectivity view by their hostname
- Fix: Synchronize default relay immediately after changing it
- Fix: Let securejoin succeed even if the chat was deleted in the meantime
- Fix: Ask before sharing via a direct-share link
- Fix: Show "Mark Read" icon on iOS 14/15
- Fix: Open chat after creating contact manually
- Fix: Add manually added contacts to member list
- Fix: Adding contacts manually is not possible for groups
- Update translations and local help
- Update to core 2.35.0


## v2.33.0
2025-12

- Handle additional transports
- Remove sending ASM as it is about sharing profile with non-chat apps which is not supported;
  use "Add Second Device" instead
- metadata protection: protect To:, Date:, and Autocrypt: headers
- better multi-device: synchronize group creation across devices
- data saving: do not send Autocrypt header in read receipts
- improve onboarding speed
- Share flow rework
- New "Advanced / Multi-Device Mode" option instead of "Delete from server"
- Links in messages are now highlighted
- Improve navigation in offline help
- Opened in-chat apps got an 'About Apps' menu item
- Address at 'Edit Transport' cannot be edited
- Open geo: url and invite links from webxdc
- stop scanning system address book as it does no longer help on getting in contact
- Add members to channels by QR codes
- Channel QR codes can be withdrawn and revived
- Add storage usage information to "Settings / Advanced / View Log"
- When deleting a profile, only ask once
- Use same 'All media' tab order as desktop and android
- Remove "Watch Sent Folder" preference
- Update chatmail relay list
- Added experimental debug calls option
- Fix: Case-insensitive search for non-ASCII chat and contact names
- Fix: handle "webm" videos as files as not supported on iOS natively
- Fix: Hide member count, if not yet known
- Fix: Share to Delta Chat when already in Delta Chat now works
- Fix: Drag and Dropping text into the chat
- Fix: Don't show removed chats in widget
- Fix: Fixed bug where camera would activate when not on the scanning screen
- Fix: Fixed bug where sharing files through the share extension did not work
- Fix: Sort system messages to the bottom of the chat
- Fix: Rounded corners while long-tapping a message bubble
- Fix app getting stale (set SQLite busy timeout to 1 minute on iOS)
- Fix: Unify font of lettered avatars
- Update translations and local help
- Update core to 2.33.0


## v2.22.1
2025-10

- Disappearing messages options range from 5 minutes to 1 year now
- Share email address for email contacts instead of vCard
- In case of errors, tapping message text or status opens "message info" directly
- Flatten profile menu
- Show possible notification issues prominently in settings
- Show addresses for address contacts only
- Option to copy contact profile's "Encryption Info" to the clipboard
- User colors get a more consistent appearance
- Create user colors based on cryptographic identity instead of address
- Withdraw all QR codes when one QR code is withdrawn
- Support TLS 1.3 session resumption
- Fix: Do not let blocked and unaccepted contact ring the recipients device
- Fix avatar color in vcards
- Fix removing Exif data from corrupted images
- Fix: Make calendar files available as an attachment
- Fix transparency of larger stickers
- Fix: do not show letter icon for partially downloaded messages
- Fix: notifications now show up while the app is inactive in foreground (eg when in the app switcher)
- Fix group creation and verification issues
- Update translations and local help
- Update to core v2.22.0


## v2.11.0
2025-08

- Allow to clone email chats
- Fix: Prevent the drag preview from showing upside down when long pressing reaction on an image
- Fix some small bugs
- Add Estonian translation
- Update translations and local help
- Update to core 2.11.0


## v2.10.0
2025-08

- Do not enlarge default icons as 'Saved Messages' or 'Device Chat'
- Show 'Saved Messages' icon in title
- When tapping an email address, open existing encrypted chat, if any
- Update translations
- Update to core 2.10.0


## v2.9.0
2025-08

- Fix: Display correct timer value for ephemeral timer changes
- Fix sometimes wrong daymarkers
- Fix: Disable non-functional 'disappearing messages' in classic email chats
- Fix: Don't enlage email chats avatar placeholder
- Fix contacts in global search sometimes displaying superfluous and wrong time
- Update translations
- Update to core 2.9.0


## v2.8.0
2025-07

- Separate between unencrypted and encrypted chats, avoiding mixing of encrypted/unencrypted messages in the same chat
- Removed padlocks, as encrypted is the default "normal" state. Instead, unencrypted email is marked with a small letter icon
- Classic email chats get a big letter icon making it easy to recognize
- Green checkmarks removed where they mostly refer to encryption, which is the default now. They are still used for profile's "Introduced by"
- Add "e2ee encrypted" info message to all e2ee chats
- Option to create a new email with subject and recipients
- Extend webxdc view into safe area
- Open media tabs deterministically at 'Apps'
- Move 'Edit Group Name' to three-dot-menu
- Sort apps by "recently updated"
- Add bio to vcards
- Images with huge pixel sizes are sent as "Files"
- Improve sorting "Saved Messages"
- Improve logging and error handling
- Replace "Broadcast Lists" experiment by "Channels"
- Indicate which message was scrolled to (eg by tapping a quote or a notification)
- Easier recognizable date headlines
- Fix: No longer missing notifications when app was terminated by the system
- Fix: More resilient members adding (by ordering recipients by time of addition)
- Fix connection getting stuck sometimes (by handling errors when draining FETCH responses)
- Fix some timeout errors
- Fix updating avatars when scanning other's QR code
- Fix realtime late join
- After some time, add a device message asking to donate. Can't wait? Donate today at https://delta.chat/donate
- Update translations
- Update to core 2.8.0


## v1.58.6
2025-06

- Access "Apps & Media" by an dedicated icon in chat's upper right corner
- "All Apps & Media" are available from the settings
- Clearer app lists by removing redundant "App" subtitle
- Speed up opening profiles
- Improve hint for app drafts
- Show 'Disappearing Messages' state alrady in menu
- Fix sending voice messages if "Settings / Chats / Media Quality" is set to "Worse Quality"
- Fix: align avatar in groups to message
- Fix: return correct results when searching for a space
- Fix: show video recoding and similar errors in an alert
- Fix: video compression on iOS 16
- Fix: attaching GIFs and webP from gallery
- Fix: drag and drop videos on iOS 15
- Fix: attaching files on iOS 15
- Fix: properly close webxdc
- Fix message bubble ghosting
- Update translations and local help
- Using core 1.159.5


## v1.58.5
2025-05

- Save multiple selected messages in one go
- Improve voice message UI
- Fix bitrate for "worse" outgoing media quality
- Fix notification sound
- Using core 1.159.5


## v1.58.4
2025-05

- Nicer profile, focusing on recognizing contacts
- Fix adding chats from different profiles to widget
- Fix: Show errors if changing address fails
- Fix staging webxdc apps
- Fix long tapping chats on iPad
- Update translations and local help
- Update to core 1.159.5


## v1.58.3
2025-05

- Select and send multiple images at the same time
- Recode videos to reasonable quality and size
- Attach images and videos as original files
- Support pasted GIFs
- Notifications in Notification Center are grouped by chat
- More characters in notification before truncating
- Fix: separate multiple notifications coming in at the same time
- Fix: tapping a notification when app was terminated now opens the notifications context
- Fix: keep message in edit on app switches
- Fix old chats with failed securure join rendered without input bar sometimes
- Update translations and local help
- Update to core 1.159.3


## v1.58.1
2025-04

- Modernise "Close" button in overlay sheets
- Full-screen display of own avatar from "your profile" settings
- Tapping info messages with contacts open the contact's profile
- Hide superfluous "Show Classic E-mails" advanced setting for chatmail
- Add a message with further information when securejoin times out (instead of allowing to send unencrypted)
- Forwarding messages do not inherit "Edited" state
- Contact encryption info show adresses
- Data saving: do not send messages to the server if user is the only member of the chat in single-device usage
- Protect metadata: encrypt message's sent date
- Do not fail to send messages in groups if some encryption keys are missing
- Synchronize contact name changes across devices
- Hide address in primary settings screen, so it cannot be passed around without e2ee info
- Show self bio summary in primary settings screen
- Fix: make vcards compatible to Proton Mail again
- Fix: encrypt broadcast list and make them work again with chatmail
- Fix changing group names that was not working in some situations
- Fix: do not show outdated message text in "Message Info" of an edited message
- Update translations and local help
- Update to core 1.159.1


## v1.54.5
2025-03

- Edit your messages (#2621, #2611)
- Delete your messages for everyone (#2621, #2611)
- Search "Saved Messages" from title bar (it was available in profile before) (#2630, #2633)
- Remove "Manage Keys" and "Import Autocrypt Setup Message"; use "Add Second Device" instead
- Allow better avatar (profile picture) quality
- Remove notifications from chat that was deleted from other device
- When a chat is deleted, also delete its messages from server
- Add mute option "8 hours"
- Improve deletion confirmation for "Device Messages"
- Fix decompression get stuck, leading to random errors sometimes
- Fix rare crash when switching server and server reports bad quota
- Fix names of explicitly attached files (#2628)
- Fix hiding of "disappearing messages" icon in edit mode
- Fix rare crash when viewing avatars
- Fixed more minor bugs
- Update translations
- Update core to 1.157.2


## v1.54.3
2025-03

- Sync message and chat deletion to other devices
- Do not allow non-members to change ephemeral timer settings of groups
- Properly display padlock when the message is not sent over the network
- Allow scanning multiple QR-invitation codes without needing to wait for completion to scan the next one
- When reactions are seen in one device, remove notification from your other devices
- Don't disturb with notification when someone leave a group
- Share files generated by webxdc apps directly (#2606)
- Tweak menu order (#2604)
- Save space by Deduplicating files on sending (#2612)
- Accessibility: voice over reads a reaction summary for messages (#2608)
- Detect incompatible profiles from newer app version when importing them
- Prepare the app for receiving edited messages (#2611)
- Prepare the app for receiving message deletion requests (#2611)
- Show sender in "Saved Messages"
- Fix: Hide read-only chats on forwarding and sort list accordingly (#2436)
- Fix: Let 'Cancel' work as expecting when forwarding messages (#2436)
- Fix: Preserve filenames on sharing (#2605)
- Fix parsing some messages
- Update translations and local help
- Update core to 1.156.2


## v1.54.0
2025-02

- Improve "message menu": many options are now faster accessible (#2586)
- When forwarding to "Saved Messages", if possible, save the message including context (#2587)
- Copy scanned QR code text to clipboard (#2582, #2594)
- Improve "All media empty" and "Block contact" wordings (#2580)
- Unify buttons and icons (#2584)
- Hide unneeded buttons in contact profiles (#2589, #2590)
- Fix "Add Second Device" issues when scanning older QR codes (#2599)
- Fix vcards reading issues (#2599)
- Fix: Allow to share contacts that do not have a chat (#2583)
- Fix: update attach menu when location streaming is enabled/disabled (#2598)
- Update translations and local help
- Update core to 1.155.4


## v1.52.2
2025-01

- Add option to "Save" a message to the messages' context menu (#2527)
- Saved messages are marked by a little star (#2527)
- In the "Saved Messages" chat, messages are shown in context and have an option to go to the original (#2527)
- New group consistency algorithm (#2564)
- The app now requires less storage by deduplicating newly received/sent files (#2564)
- Show 'unconnected' and 'updating' states in profile switcher (#2553)
- Access recently used apps from app-picker ("Attach / Apps") (#2530)
- Add 'Paste from Clipboard' to onboarding QR code scanners (#2559)
- Detect Stickers when dropped, pasted or picked from Gallery (#2535)
- Modernize menus (#2545, #2558)
- Clearer icons (#2555)
- Clearer QR code reset options (#2570)
- Fix adding sticker from keyboard on iOS 18 (#2569)
- Fix: In 'View Log', hide keyboard when scrolling down (#2541)
- Fix: Experimental location sharing now ends at the specified interval even if you don't move (#2537)
- Fix crash on profile deletion (#2554)
- Fix hiding of the bottom bar when archive is opened (#2560)
- Fix: Show error message when voice recording permissions are missing (#2555)
- Fix rare issue where some messages are not synced between multiple devices (#2564)
- Fix: do not allow private replies info-messages resulting in invalid chat (#2571)
- minimum system version is iOS 14 now (all iOS 13 devices can upgrade to iOS 14) (#2459)
- Update translations and local help (#2561, #2564)
- Update core to 1.155.2


## v1.50.5
2025-01

- More modern attach menu (#2522)
- Attach mini apps using the App-picker from the attach menu (#2450)
- Show the apps-tab unconditionally (#2526)
- Append dropped URLs to text field instead of attaching as file (#2523)
- Drag images from a chat and drop it to another chat or even to another app (use a second finger for navigating!) (#2509)
- Paste .webp images via drag'n'drop (#2507)
- Add "Copy Image" to messages' conext menu (#2508)
- Long-tap a proxy to share or delete (#2521)
- "Message Info" is moved to messages' context menu at "More Options / ..." (#2510)
- To easier differ between multiple profiles, set a "Private Tag" (long tap profile switcher) (#2511)
- In profile switcher's context menu, you have quick access to "Mute Notifications" for a profile (#2511)
- Sort profiles to top in profile switcher, see context menu (#2519)
- Allow cancelling profile edits, force a name when editing profile (#2506)
- Fix scrolling issue when cancelling a screen (#2504)
- Fix layout of 'No contacts found' message (#2517)
- Fix position of 'Attach Contact's 'Cancel' button (#2532)
- Using core 1.153.0


## v1.50.4
2025-01

- Access your favorite apps and chats from the Homescreen using our shiny new widget (requires iOS 17) (#2406, #2449)
- Add and remove apps and chats to that widget (#2426, #2449)
- In favour to the new widget, the old "Add to Homescreen" option, that stopped working on most recent OS, got removed (#2456)
- More modern look for the settings pages (#2474)
- Add option to toggle notifications for mentions (as replies or reactions) in groups (#2434)
- Access system notification settings directly from the new notification settings (#2434)
- Long-tap links for copying to clipboard (#2445)
- Hide address in titles: protect against over-the-shoulder-attacks, improve screenshot privacy, clear UX (#2447)
- Prevent automatic limited access alert (#2480)
- Much smoother, motion reduced message list when using attach or other options (#2481)
- mark holiday notice messages as bot-generated
- prefer to encrypt even if peers have their preference to "no preference"
- start ephemeral messages timers when the chat is archived or noticed"
- Fix: Never change Sticker to Image if file has non-image extension
- Fix crashes when scanning some shadowsocks proxy QR codes
- Fix: Don't consider punctuation and control chars as part of file extension
- Fix: don't mark contacts as bot when receiving location-only and sync messages
- Fix: No notification and 30 sec stale app when NSE crashed in background from running out of memory (#2477)
- Fix: Disappearing message input field after cancelled gallery selection (#2392)
- Fix: Don't show message-input when forwarding (#2435)
- Fix: Don't change navigation-bar-appearance when visiting wallpape settings (#2496)
- minimum system version is iOS 13 now (#2459)
- Update translations and local help
- Update core to 1.153.0


## v1.50.3
2024-12

- Don't change order of proxies when selecting a new one (#2414)
- Add info messages about implicit membership changes if group member list is recreate
- Show a Webxdc-app in chat (#2413)
- Fix encrypted messages failures on some accounts (ignore garbage at the end of keys)
- Fix: Don't add "Failed to send message to ..." info messages to group chats
- Fix: Add self-addition message to chat when recreating member list
- Fix not showing "Notifications: Connected" even though PUSH is available (do not subscribe to heartbeat if already subscribed to PUSH)
- Fix "Show Full Message" being empty sometimes (if multiple text parts are cut)
- Update to core 1.152.0


## v1.50.1
2024-12

- Show notifications for reactions on own messages (#2331)
- Icons for Dark-mode and tint colors (#2425)
- offer to open http-links detected as proxy also in the browser (#6237)
- Improve compatibility with classic email clients in the outgoing messages
- Use Rustls for connections with strict TLS
- Mark Saved Messages chat as protected
- Allow the user to replace maps integration
- QR codes for adding contacts and joining groups provide help when opened in a normal browser
- Encrypt notification tokens
- Webxdc can now trigger notifications
- Webxdc can now deep-link to internal sections when you click their info-messages in chat
- Use privacy-preserving webxdc addresses
- fix: Trim whitespace from scanned QR codes
- fix quotes: Line-before-quote may be up to 120 character long instead of 80
- fix: Prevent accidental wrong-password-notifications
- fix: Remove footers from "Show Full Message..."
- fix: Only add "member added/removed" messages if they actually do that
- fix: Update state of message when fully downloading it
- fix: send message: Do not fail if the message does not exist anymore
- fix: Do not percent-encode dot when passing to autoconfig server (so, fix handling of some servers)
- fix displaynames not being updated when intially scanned by a QR code
- update to core 1.151.5


## v1.48.4
2024-11

- Add an option to use Proxy-servers (#2382, #2390)
- Show on Chatlist if there are Proxy-servers (#2383)
- Detect Proxy-servers in Chat-messages (#2389)
- Share Proxy-servers with your friends, family and allies (#2394)
- Scan Proxy-QR-Codes (#2404)
- fix: no startup delay when processing PUSH notifications in parallel, just show "Updating..." in title bar
- fix: show forward-icon on iOS 15 and older
- using core 1.148.6


## v1.48.3
2024-11

- do not miss new messages when being inside a chat, the "Back" button now has an "unread" badge
- no more useless scrolling and jumping when opening a chat and during chatting. solid!
- select multiple chats or messages with two-finger pan gestures
- improve chatlist swipe gestures: trailing to mute/archive/delete - leading to pin/mark-read
- allow to mute or unmute multiple selected chats at the same time
- open "Invite Links" (i.delta.chat) direclty inside the app
- check device owner (Passcode, Fingerprint, FaceID) on "Add Second Device", "Export" and "Password & Account"
- save traffic by supporting "IMAP COMPRESS"
- automatic reconfiguration, e.g. switching to implicit TLS if STARTTLS port stops working
- parallelize IMAP and SMTP connection attempts
- improve DNS caching
- always use preloaded DNS results
- prioritize cached results if DNS resolver returns many results
- always move auto-generated messages to DeltaChat folder
- ignore invalid securejoin messages silently
- delete messages from a chatmail server immediately by default
- make resending pending messages possible
- don't SMTP-send messages to self-chat if BccSelf is disabled
- HTTP(S) tunneling
- don't put displayname into From/To/Sender if it equals to address
- hide sync messages from INBOX (use IMAP APPEND command to upload sync messages)
- more verbose SMTP connection establishment errors
- log unexpected message state when resending fails
- smoother backup and "Add Second Device" progress bars
- assign messages to ad-hoc group with matching name and members
- use stricter TLS checks for HTTPS downloads (eg. Autoconfig)
- improve logging for failed QR code scans, AEAP, Autocrypt and sending errors
- show more context for the "Cannot establish guaranteed..." info message
- show images beside swipe gesture buttons
- simplifiy "Delete From Server" options for chatmail
- allow to copy text from "Message Info"
- show file name in "Message Info"
- add "Learn More" button to "Manage keys"
- cleanup chatlist's multi-select action bar
- show root SMTP connection failure in connectivity view
- fix memory leak when opening some view controller
- fix: don't ask for image access when opening gallery because it is not needed
- fix: when entering message-multi-select-mode via "Long tap / More Options", leave search mode
- fix sometimes missing input field or action bar
- fix: show multi-account notification also in the first 30 seconds when the app goes to background
- fix warning about wrong password
- fix app getting stale when receiving a PUSH notifications takes longer
- fix app getting stale on network changes
- fix: skip IDLE if we got unsolicited FETCH
- fix PUSH notifications not working during the frist 30 seconds after putting app to background
- fix: show correct number of messages affected by "Clear Chat"
- fix: recognize stickers sent from the keyboard as such also on iOS 18
- fix: Sort received outgoing message down if it's fresher than all non fresh messages
- fix: shorten message text in locally sent messages too
- fix: Set http I/O timeout to 1 minute rather than whole request timeout
- fix: don't sync QR code token before populating the group
- fix: do not get stuck if the message to download does not exist anymore
- fix: do not attempt to reference info messages
- fix: do not get stuck if there is an error transferring backup
- fix: make it possible to cancel ongoing backup transfer
- fix: reset quota when entering a new address
- fix: better detection of file extensions
- fix: "database locked" errors
- fix: never initialize realtime channels if realtime is disabled
- fix reception of realtime channels
- fix: normalize proxy URLs
- fix connections getting stuck in "Updating..." sometimes
- update translations and local help
- update to core 1.148.6


## v1.46.10
2024-09

- Add "Share invite link"-button to "QR Invite Code"-Screen (#2276)
- Enhance "edit name" dialog (#2286)
- Share contact from "contact profile" (#2273)
- Share Log as file (#2205)
- Tune down "copy to clipboard" on "contact profile" (#2274)
- "Invite friends" from settings and "New Chat" (#2277)
- Hide email in "New chat"-list for trusted contacts (#2272)
- Hide option to add contacts manually when chatmail (#2283)
- Fix a bug that the message-timestamp didn't update occasionally (#2270)
- Show contact when tapping on their name in Reactions-overview (#2259)
- Mark bots as ... bots (#2254)
- Improve chat-deletion-confirmation (#2254)
- Improve security and QR-code generation
- fix encryption compatibility with old Delta Chat clients
- fix moving outgoing auto-generated messages to the "DeltaChat" folder
- fix: try to create "INBOX.DeltaChat" if "DeltaChat" is not possible for some provider
- fix receiving messages with "DeltaChat" folder cannot be selected
- Update to core 1.142.12


## v1.46.9
2024-08

- Update translations
- Minor UI/UX-fixes (#2260)
- Support more modern QR-codes for backups
- using core 1.142.2


## v1.46.8
2024-08

- Mute based on profiles (#2245)
- Add default reactions if there are none (yet) (#2241)
- End search when tapping on "Chats" multiple times (#2239)
- Small code improvements that help make development easier (#2230, #2234, #2236, #2250, #2251)
- Reduce memory footprint (#2235)
- search non-english messages case-insensitive
- display attached contact's names in summaries and quotes
- protect From: and To: metadata where possible
- do not reveal sender's language metadata in read receipts
- allow importing contacts exported by Proton Mail
- no unarchiving of groups on member removal messages
- improve caching of DNS results
- focus on name for QR code titles
- report first error instead of the last on connection failure
- fix battery drain due to endless IMAP loop
- fix: keep "chatmail" state after failed reconfiguration
- fix issues with failed backup imports
- fix: avoid group creation on member removal messages
- fix downloading partially downloaded messages
- fix various networking bugs
- Minor UI/UX-fixes (#2231, #2247)
- update translations and local help (#2244, $2255)
- update to core 1.142.2


## v1.46.6
2024-07

- add search to "Attach / Contact"
- add option to mark all selected chats as being "Read" (long tap a chat to start select mode)
- add experimental realtime channels to create direct connections between devices
- tint "Delete" buttons red consistently
- fix "Add Second Device" layout for small screens
- fix: don't let keyboard cover parts of the log
- fix message input bar sometimes disappearing
- update translations and local help
- using core 1.140.2


## v1.46.5
2024-06

- contacts can be attached as "Cards" at "Attach / Contact";
  when the receiver taps the cards, guaranteed end-to-end encrypted can be established
- nicer display of "Contact Cards" (vcards), including the contact's avatar
- fewer traffic in larger chatmail groups by allowing more than 50 recipients per time
- tweak chat and gallery context menus
- share voice messages from the chat's context menu at "More Options"
  (images/videos/files can be easier shared from the previews)
- device update message is added as unread only for the first account
- best guess on pasting images and stage them instead of sending immediately;
  stickers, as usually tapped from the keyboard, are still send immediately
- use same "Delete Old Messages" options as on android/desktop
- fix: hide chat's scroll-down-button when the context menu is displayed
- fix input bar showing up when attach menu is opened
- fix migrated address losing verified status and key on experimental AEAP
- fix: allow creation of groups by outgoing messages without recipients
- fix: avoid group splits by preferring ID from encrypted header over references for new groups
- fix: do not fail to send images with wrong extensions
- fix: retry sending MDNs on temporary error
- fix: do not miss new messages while expunging the folder
- fix missing logging info lines
- fix: remove group member locally even if sending fails
- fix: revert group member addition if the corresponding message couldn't be sent
- update translations and local help
- update to core 1.140.2


## v1.46.2
2024-06

- fix: create new profile when scanning/tapping QR codes outside "Add Profile"
- fix: timestamp in vcards is optional
- update translations
- using core 1.139.6


## v1.46.0
2024-05

- new onboarding: you can create a new profile with one tap on "Create New Profile" -
  or use an existing login or second-device-setup as usual
- only show PUSH notifications if there is real content
- make received VCards tappable (attaching VCards is in the making :)
- "Profiles" are names as such throughout the app;
  note that these profiles exist on the device only, there is nothing persisted on the server
- adding contacts manually at "New Chat / New Contact / Add Contact Manually"
- faster reactions: access the reactions directly from the context menu, cleanup menu
- show reactions in summaries
- new map for - still experimental - location streaming (enable at "Settings / Advanced")
- advanced settings resorted, you'll also find "password & account" and "show classic emails" there
- improve resilience by adding references to the last three messages
- one-to-one chats are read-only during reasonable run of securejoin
- if securejoin is taking longer than expected, a warning is shown and messages can be sent
- improve resilience by including more entries in DNS fallback cache
- improve anonymous mailing lists by not adding hostname to Message-ID
- hide folder options if not supported by the used account
- subsequent taps on the "Chats" icon scroll that chatlist to the top
- show sum of unread chats on the chatlist's "Chats" icon
- use "universal logging system", making the logs available in tools like "Console.app"
- show recent log lines at "Advanced / View Log", if supported by the system
- support openpgp4fpr links inside webxdc
- fix: preserve upper-/lowercase of links from HTML-messages
- fix: rescan folders on "Watch Sent Folder" changes
- fix sometimes wrong sender name in "Message Info"
- fix: do not send avatar in securejoin messages before contact verification
- fix: avoid being re-added to groups just left
- fix: do not auto-delete webxdc apps that have recent updates
- fix: improve moving messages on gmail
- fix: improve chat assignments of not downloaded messages
- fix: do not create ad-hoc groups from partial downloads
- fix: improve connectivity on startup by adding backoff for IMAP connections
- fix: mark contact request messages as seen on IMAP server
- fix: convert images to RGB8 before encoding into JPEG to fix sending of large RGBA images
- fix: do not convert large GIF to JPEG
- fix receiving Autocrypt Setup Messages from K-9
- fix: delete expired locations and POIs with deleted chats
- fix: send locations more reliable
- fix: do not fail to send encrypted quotes to unencrypted chats, replace quote by "..." instead
- fix: always use correct "Saved Messages" icon when the chat is recreated
- fix: add white background to transparent avatars
- fix crashes when exporting or importing huge accounts
- fix: remove leading whitespace from subject
- fix problem with sharing the same key by several accounts
- fix busy looping eg. during key import
- fix remote group membership changes always overriding local ones
- fix webxdc links for securejoin
- fix: use the last header of multiple ones with the same name; this is the one DKIM was using
- fix migration of legacy databases
- fix: do not mark the message with locations as seen
- fix crashes when sharing on iPads
- update translations and local help
- update to core 1.139.6


## v1.44.1
2024-03

- show message content in PUSH notifications (unless disabled in the system settings)
- nicer summaries by using some emojis for attachment types
- "Message long-tap / Select More" added for read-only chats
- paste QR codes from any QR code page
- fix: open chats directly at the end, no more visible scrolling
- fix input bar displayed during attach or info sometimes
- fix: do not play a sound or switch on display for muted chat's PUSH notifications
- fix: not not add notifications for reactions
- fix: add white background to transparent avatars
- fix crashes when exporting or importing huge accounts
- fix: remove leading whitespace from subject
- fix problem with sharing the same key by several accounts
- fix busy looping eg. during key import
- fix remote group membership changes always overriding local ones
- update translations
- update to core 1.136.6


## v1.44.0
2024-03

- PUSH notification if supported by providers as chatmail
- send any emoji as reaction 💕
- enlarge the account switcher by swiping up
- offer "Select more" in read-only chats as well
- sync self-avatar and self-signature text across devices
- recognize "Trash" folder by name in case it is not flagged as such by the server
- send group avatars inline so that they do not appear as unexpected attachments
- fix: scroll down on opening chat
- fix sending sync messages on updating self-name etc.
- fix sometimes slow reconnects
- more bug fixes
- update translations and local help
- update to core 1.136.2


## v1.43.1 Testflight
2024-02

- add "Reactions": long tap a message to react to it ❤️
- reactions from others are shown below the messages
- tap a reaction below a message to get reaction details
- sharing QR code now shares "Invite Link":
  if tapped by with Delta Chat users, Delta Chat opens; otherwise the browser opens;
  the server does not get any information about the link details (as "Fragment" is not sent to server)
- copying/pasting QR code data now also supports invite links
- updated "welcome message" now focuses about how to get in contact
- add meaningful info message if provider does not allow unencrypted messages
- new option "Settings / Advanced / Read System Address Book":
  when enabled, the address book addresses are added to the "New Chat" activity
- faster reconnects when switching from a bad or offline network to a working network
- force a display name to be set when using an instant onboarding QR code
- add "Scan QR Code" button to 'New Chat'
- sum up all fresh messages of all accounts in app-icon
- improve notification statistics in "Connectivity View"
- move 'pinned' indicator right for cleaner UI
- focus on name and state for guaranteed e2ee chats; email address and other data are available in the profile
- add device message if outgoing messages are undecryptable
- add "From:" to protected headers for signed-only messages generated by some apps
- sync user actions for ad-hoc groups across devices
- sync contact creation/rename across devices
- encrypt read receipts
- only try to configure non-strict TLS checks if explicitly set
- accept i.delta.chat as well as openpgp4fpr: links
- add link to troubleshooting for "Add as Second Device" on welcome screen and update troubleshooting
- improve status/info message view
- accessibility: add voice over to image/video galleries
- fix chat title layout issue on iOS 16
- fix: just sent message sometimes appears only after re-entering a chat
- fix crashes caused by browsing through large galleries
- fix some images not shown in gallery
- fix: improve sharing large images and videos to Delta Chat
- fix status line sharpness
- fix compatibility issue with 1.42 when using "Add Second Device" or backups
- fix sometimes mangled links
- fix sometimes wrongly marked gossiped keys
- fix: guarantee immediate message deletion if "Delete Messages from Server" is set to "At once"
- fix: Never allow a message timestamp to be a lot in the future
- fix: make IMAP folder handling more resilient
- fix: delete resent messages on receiver side
- fix: do not drop unknown report attachments, such as TLS reports
- fix: be graceful with systems mangling the qr-code-date (macOS, iOS)
- fix unexpected line breaks in messages (by using Quoted-Printable MIME)
- fix: avoid retry sending for servers not returning a response code in time (force BCC-self)
- fix partially downloaded messages getting stuck in "Downloading..."
- fix inconsistent QR scan states (track forward and backward verification separately, mark 1:1 chat as verified as early as possible)
- fix duplicated messages for some providers as "QQ Mail"
- fix: do not remove contents from unencrypted Schleuder mailing lists messages
- fix: reset message error when scheduling resending
- fix marking some one-to-one chats as guaranteed
- fix: avoid multiple resending of messages on slow SMTP servers
- fix: more reliable connectivity information
- fix: delete received outgoing messages from SMTP queue
- fix timestamp of guaranteed e2ee info message for correct message ordering after backup restore
- fix: add padlock to empty part if the whole message is empty
- fix IDLE timeout renewal on keepalives and reduce it to 5 minutes
- fix: fail fast on LIST errors to avoid busy loop when connection is lost
- fix: improve checking if all members of a chat are verified
- fix: same "green checkmark" message order on all platforms
- fix CI by increasing TCP timeouts from 30 to 60 seconds
- update translations and local help
- update to core 1.135.0


## v1.42.8
2023-12

- fix checking for new messages in the background being aborted before finishing fetching the messages
- fix: sync pin/archive across devices also for groups created by non-delta-chats clients
- fix: show padlock in empty part if the whole message is empty
- fix: more reliable message pushing from IMAP implementations as mailbox.org
  (renew IDLE timeout on keepalives and reduce it to 5 minutes)
- update translations
- update to core 1.132.1


## v1.42.7
2023-12

- sync changes on "Your Profile Name", "Show Class Mails", "Read Receipts" options across devices
- immediate feedback when tapping chat titles
- fix crashes and notification issues due to races in shutdown event handler
- fix crashes and notification issues due to account lock file
- fix crashes and notification issues by fading out "encrypted database" experiment introduced in 1.28.0
  (database is still encrypted by the system, for existing "encrypted database" users a messages is shown)
- fix: align "Disappearing Messages" options with the ones used on android/desktop
- fix decryption errors when using multiple private keys
- fix more log in errors for providers as 163.com; this was introduced in 1.42.3
- update translations
- update to core 1.132.0


## v1.42.4
2023-11

- fix possibly infinite IMAP loop on some providers; this was introduced in 1.42.3
- fix log in error on some providers as 163.com; this was introduced in 1.42.3
- fix: do not allow swipe-to-reply on daymarkers or other markers
- fix instructions for how to play unsupported video formats
- update translations and local help
- update to core 1.131.7


## v1.42.3
2023-11

- fix: avoid infinite loop by failing fast on IMAP FETCH parsing errors
- update translations
- update to core 1.131.6


## v1.42.2
2023-11

- fix: do not replace the message with an error in square brackets
  when the sender is not a member of the protected group
- fix: compare addresses on QR code scans and at similar places case-insensitively
- fix: normalize addresses to lower case to catch unrecoverable typos and other rare errors
- fix: fetch contact addresses in a single query
- fix: sync chat name to other devices
- clarify, that encrypted databases will slow down the app and notifications
- update translations and local help
- update to core 1.131.5


## v1.42.1
2023-11

- fix "Member added" message not being a system message sometimes
- fix download button shown when download could be decrypted
- fix missing messages because of misinterpreted server responses (ignore EOF on FETCH)
- fix: re-gossip keys if a group member changed setup
- fix: skip sync when chat name is set to the current one
- fix: ignore unknown sync items to provide forward compatibility
  and to avoid creating empty message bubbles in "Saved Messages"
- update translations and local help
- update to core 1.131.4


## v1.41.8 Testflight
2023-11

- guarantee end-to-end-encryption in one-to-one chats, if possible
- if end-to-end-encryption cannot be guaranteed eg. due to key changes,
  the chat requires a confirmation of the user
- auto-detect if a new group can guaranteed end-to-end encryption
  (replaces experimental "verified groups")
- add "group created instructions" as info message to new chats
- clone group in the group's profile menu
- synchronize Accept/Blocked, Archived, Pinned and Mute across devices
- synchronize "Broadcast Lists" (experimental) across devices
- "QR Invite Code" is available after group creation in the group's profile
- backup filenames include the account name now
- "Broadcast Lists" (experimental) create their own chats on the receiver site
- add "Introduced by" information to contact profiles
- add info messages about implicitly added members
- add hardcoded fallback DNS cache
- more graceful ratelimit for .testrun.org subdomains
- faster message detection on the server
- improve handling of various partly broken encryption states by adding a secondary verified key
- add "Deactivate QR code" option when showing QR codes
  (in addition to deactivate and reactivate QR codes by scanning them)
- give instructions how to play unsupported video formats
- use same voice messages bitrates as on android and respect media quality setting
- add a privacy warning atop of logs
- fix: allow to QR scan groups when 1:1 chat with the inviter is a contact request
- fix: add "Setup Changed" message before the message
- fix: read receipts created or unblock 1:1 chats sometimes
- fix: do not skip actual message parts when group change messages are inserted
- fix broken chat names (encode names in the List-ID to avoid SMTPUTF8 errors)
- fix: mark 1:1 chat as protected when joining a group
- fix: raise lower auto-download limit to 160k
- fix: remove Reporting-UA from read receipt
- fix: do not apply group changes to special chats; avoid adding members to trashed chats
- fix: protect better against duplicate UIDs reported by IMAP servers
- fix: more reliable group consistency by always automatically downloading messages up to 160k
- fix: make sure, a QR scan succeeds if there is some leftover from a previously broken scan
- fix: allow other guaranteed e2ee group recipients to be unverified, only check the sender verification
- fix: switch to "Mutual" encryption preference on a receipt of encrypted+signed message
- fix hang in receiving messages when accidentally going IDLE
- fix: allow verified key changes via "member added" message
- fix: partial messages do not change group state
- fix: don't implicitly delete members locally, add absent ones instead
- fix configure error with "Winmail Pro Mail Server"
- fix: set maximal memory usage for the internal database
- fix: allow setting a draft if verification is broken
- fix joining verified group via QR if contact is not already verified
- fix: sort old incoming messages below all outgoing ones
- fix: do not mark non-verified group chats as verified when using securejoin
- fix: show only chats where we can send to on forwarding or sharing
- fix: improve removing accounts in case the filesystem is busy
- fix: don't show a contact as verified if their key changed since the verification
- fix sorting error with downloaded manually messages
- fix group creation when the initial group message is downloaded manually
- fix connectivity status view for servers not supporting IMAP IDLE
- fix: don't try to send more read receipts if there's a temporary SMTP error
- fix sending images and other files in location steaming mode
- fix connectivity view layout if eg. storage shows values larger than 100%
- fix scanning account-QR-codes on older phones that miss the Let's Encrypt system certificate
- fix: make Thunderbird show encrypted subjects
- fix: do not create new groups if someone replies to a group message with status "failed"
- fix: do not block new group chats if 1:1 chat is blocked
- fix "Show full message" showing a black screen for some messages received from Microsoft Exchange
- fix: skip read-only mailing lists from forwarding/share chat lists
- fix: do not allow dots at the end of email addresses
- fix: do not send images pasted from the keyboard unconditionally as stickers
- fix: forbid membership changes from possible non-members, allow from possible members
- fix: improve group consistency across members
- fix: delete messages from SMTP queue only on user demand
- fix: improve wrapping of email messages on the wire
- fix memory leak in IMAP
- fix: disable 'Add to Home Screen' for iOS 16+ as unsupported
- update provider database
- update translations and local help
- using core 1.131.2


## v1.40.3
2023-10

- fix a crash when opening the connectivity view on newer iOS versions
- minimum system version is iOS 12 now
- using core119


## v1.40.2
2023-10

- update libwebp and other libs
- remove meet.jit.si from default video chat instances as it requires login now
- update translations
- using core119


## v1.40.0
2023-08

- improve IMAP logs
- update "verified icon"
- fix: avoid IMAP move loops when DeltaChat folder is aliased
- fix: accept webxdc updates in mailing lists
- fix: delete webxdc status updates together with webxdc instance
- fix: prevent corruption of large unencrypted webxdc updates
- fix "Member added by me" message appearing sometimes within wrong context
- fix core panic after sending 29 offline messages
- fix: make avatar in qr-codes work on more platforms
- fix: preserve indentation when converting plaintext to HTML
- fix: remove superfluous spaces at start of lines when converting HTML to plaintext
- fix: always rewrite and translate member added/removed messages
- add Luri Bakhtiari translation, update other translations and local help
- update to core119


## v1.38.2
2023-06

- improve group membership consistency
- fix verification issues because of email addresses compared case-sensitive sometimes
- fix empty lines in HTML view
- fix empty links in HTML view
- update translations
- update to core117.0


## v1.37.0 Testflight
2023-06

- view "All Media" of all chats by the corresponding button
- new "Clear Chat" option in the profiles
- remove upper size limit of attachments
- save local storage: compress HTML emails in the database
- save traffic and storage: recode large PNG and other supported image formats
  (large JPEG were always recoded; images send as "File" are still not recorded or changed otherwise)
- also strip metadata from images before sending
  in case they're already small enough and do not require recoding
- strip unicode sequences that are useless but may trick the user (RTLO attacks)
- snappier UI by various speed improvements
- sticky search result headers
- accessibility: adaptive fonts in the welcome screen
- disabled "Read" button in the archive view if there is nothing that can be marked as read
- fix a bug that avoids pinning or archiving the first search results
- fix: exiting messages are no longer downloaded after configuration
- fix: don't allow blocked contacts to create groups
- fix: do not send messages when sending was cancelled while being offline
- fix various bugs and improve logging
- fix: show errors when trying to send locations without access
- update to core116.0


## v1.36.4
2023-04

- add "Paste From Clipboard" to QR code scanner
- fix fetch errors due to erroneous EOF detection in long IMAP responses
- fix crash in search when using the app on macos
- more bug fixes
- update translations and local help
- update to core112.7


## v1.36.1
2023-03

- new, easy method of adding a second device to your account:
  scan the QR code shown at "Settings / Add Second Device" with your new device
- revamped settings dialog
- show non-deltachat emails by default for new installations
  (you can change this at "Settings / Chats and Media)
- resilience against outages by caching DNS results for SMTP connections
  (IMAP connections are already cached since 1.34.11)
- make better use of dark/light mode in "Show full message"
- prefer TLS over STARTTLS during autoconfiguration, set minimum TLS version to 1.2
- use SOCKS5 configuration also for HTTP requests
- improve speed by reorganizing the database connection pool
- improve speed by decrypting messages in parallel
- improve reliability by using read/write instead of per-command timeouts for SMTP
- improve reliability by closing databases sooner
- improve compatibility with encrypted messages from non-deltachat clients
- add menu with links to issues reporting and more to help
- fix: update mute icon in chat's title
- fix: Skip "Show full message" if the additional text is only a footer already shown in the profile
- fix verifications when using for multiple devices
- fix backup imports for backups seemingly work at first
- fix a problem with gmail where (auto-)deleted messages would get archived instead of deleted
- fix deletion of more than 32000 messages at the same time
- update provider database
- update translations
- update to core112.4


## v1.35.0 Testflight
2023-02

- show non-deltachat emails by default for new installations
- add jumbomoji support: messages containing only emoji shown bigger
- verified marker shown right of the chat names now
- show hint on successful backups
- add option to copy QR codes to the clipboard
- show full messages: do not load remote content for requests automatically
- improve freeing of unused space
- cache DNS results for SMTP connections
- use read/write timeouts instead of per-command timeouts for SMTP
- prefer TLS over STARTTLS during autoconfiguration
- fix Securejoin for multiple devices on a joining side
- fix closing of database files, allowing proper shutdowns
- fix some database transactions
- fix a problem with Gmail where (auto-)deleted messages would get archived instead of deleted.
  Move them to the Trash folder for Gmail which auto-deletes trashed messages in 30 days
- fix: clear config cache after backup import. This bug sometimes resulted in the import to seemingly work at first
- speed up connections to the database
- improve logging
- update translations
- update to core110


## v1.34.12
2023-02

- disable SMTP pipelining for now
- improve logging
- update to core107.1


## v1.34.11
2023-01

- introduce DNS cache: if DNS stops working on a network,
  Delta Chat will still be able to connect to IMAP by using previous IP addresses
- speed up sending and improve usability in flaky networks by using SMTP pipelining
- show a dialog on backup success
- allow ogg attachments being shared to apps that can handle them
- add "Copy to Clipboard" option for mailing list addresses
- fix wrong counters shown in gallery sometimes
- fix SOCKS5 connection handling
- fix various bugs and improve logging
- update translations
- update to core107


## v1.34.10
2023-01

- fix: make archived chats visible that don't get unarchived automatically (muted chats):
  add an unread counter and move the archive to the top
- fix: send AVIF, HEIC, TXT, PPT, XLS, XML files as such
- fix: trigger reconnection when failing to fetch existing messages
- fix: do not retry fetching existing messages after failure, prevents infinite reconnection loop
- fix: do not add an error if the message is encrypted but not signed
- fix: do not strip leading spaces from message lines
- fix corner cases on sending quoted texts
- fix STARTTLS connection
- fix: do not treat invalid email addresses as an exception
- fix: flush relative database paths introduced in 1.34.8 in time
- prefer document name over webxdc name for home screen icons
- faster updates of chat lists and contact list
- update translations
- update to core106


## v1.34.8
2022-12

- If a classical-email-user sends an email to a group and adds new recipients,
  the new recipients will become group members
- treat attached PGP keys from classical-email-user as a signal to prefer mutual encryption
- treat encrypted or signed messages from classical-email-user as a signal to prefer mutual encryption
- VoiceOver: improve navigating through messages
- fix migration of old databases
- fix: send ephemeral timer change messages only of the chat is already known by other members
- fix: use relative paths to database and avoid problems eg. on migration to other devices or paths
- fix read/write timeouts for IMAP over SOCKS5
- fix: do not send "group name changes" if no character was modified
- add Greek translation, update other translations
- update to core104


## v1.34.7 Testflight
2022-12

- show audio recorder on half screen
- prevent From:-forgery attacks
- disable Autocrypt & Authres-checking for mailing lists because they don't work well with mailing lists
- small speedups
- improve logging
- fix crash on copy message with iOS 14.8
- fix detection of "All mail", "Trash", "Junk" etc folders
- fix reactions on partially downloaded messages by fetching messages sequentially
- fix a bug where one malformed message blocked receiving any further messages
- fix: set read/write timeouts for IMAP over SOCKS5
- update translations
- update to core103


## v1.34.6 Testflight
2022-11

- improve account switcher: use the icon atop the chatlist to switch, add and edit accounts
- allow removal of references contacts from the "New Chat" list
- show icon beside webxdc info messages
- show more debug info in message info, improve logging
- add default video chat instances
- VoiceOver: read out unread messages in account switch button and account switch view controller
- VoiceOver: improve order of read out content in chatlist
- fix muted VoiceOver after recording voice message
- fix: support mailto:-links in full-message-view
- fix direct share usage with multiple accounts
- fix emojis in webxdc
- fix potential busy loop freeze when marking messages as seen
- fix: suppress welcome messages after account import
- fix: apply language changes to all accounts
- fix chatlist's multi-edit "Cancel" button
- fix images for webxdc using the phaser library
- update translations and local help
- update to core101


## v1.34.1
2022-10

- show the currently selected account in the chatlist;
  a tap on it shows the account selector dialog
- show a "recently seen" dot on avatars if the contact was seen within ten minutes
- order contact and members lists by "last seen"
- support drag'n'drop to delta chat: eg. long tap an image from the system gallery
  and _with a second finger_ navigate to Delta Chat and then to the desired chat
- improve multi-select of messages: add "Copy to Clipboard", show selection count
- allow resending of messages from multi-select
- backup import: allow selection of different backups by a file selector
- show mailing list addresses in profile
- user friendlier system messages as "You changed the group image."
- allow replying with a voice message
- introduce a "Login" QR code that can be generated by providers for easy log in
- allow scanning of "Accounts" and "Logins" QR codes using system camera
- connectivity view shows disabled "Low Data Mode"/"Low Power Mode" as possible cause of problems
- truncate incoming messages by lines instead of just length
- for easier multi device setup, "Send Copy To Self" is enabled by default now
- add webxdc's to the home screen from the webxdc's menu,
  allowing easy access and integration
- add a webxdc selector to the "Attach" menu (the paperclip in message view)
- bigger avatar in message view title
- larger, easier to tap search and mute buttons in profiles
- fix: show gallery's "back" button on iOS 16
- fix: mark "group image changed" as system message on receiver side
- fix: improved error handling for account setup from QR code
- fix: do not emit notifications for blocked chats
- fix: show attached .eml files correctly
- fix: don't prepend the subject to chat messages in mailing lists
- fix: reject webxdc updates from contacts who are not group members
- fix memory leak on account switching
- update translations
- update to core95


## v1.32.0
2022-07

- show post address in mailinglist's profile
- AEAP: show confirmation dialog before changing e-mail address
- AEAP: add a device message after changing e-mail address
- AEAP replaces e-mail addresses only in verified groups for now
- fix opening experimental encrypted accounts
- fix: handle updates for not yet downloaded webxdc instances
- fix: better information on several configuration and non-delivery errors
- fix accessibility hint in multi-select chat list title
- update translations, revise english source
- update to core90


## v1.31.0 Testflight
2022-07

- experimental "Automatic E-mail Address Porting" (AEAP):
  You can configure a new address now, and when receivers get messages
  they will automatically recognize your moving to a new address
- multi-select in chat list: long-tap a chat and select more chats
  for deletion, pinning or archiving
- add 'reply privately' option to group chats
- add search to full-message-views and help
- make bot-commands such as /echo clickable
- adapt document gallery view to system text size
- cleanup series of webxdc-info-messages
- show document and chat name in webxdc titles
- add menu entry access the webxdc's source code
- send normal messages with higher priority than read receipts
- improve chat encryption info, make it easier to find contacts without keys
- improve error reporting when creating a folder fails
- allow mailto: links in webxdc
- combine read receipts and webxdc updates and avoid sending too many messages
- message lines starting with `>` are sent as quotes to non-Delta-Chat clients
- support IMAP ID extension that is required by some providers
- disable gesture to close webxdc to avoid confusion with gestures inside webxdc
- show webxdc icon in quoted webxdc messages
- info messages can be selected in multi-select
- fix: make chat names always searchable
- fix: do not reset database if backup cannot be decrypted
- fix: do not add legacy info-messages on resending webxdc
- fix: let "Only Fetch from DeltaChat Folder" ignore other folders
- fix: Autocrypt Setup Messages updates own key immediately
- fix: do not skip Sent and Spam folders on gmail
- fix: cleanup read-receipts saved by gmail to the Sent folder
- fix: handle decryption errors explicitly and don't get confused by encrypted mail attachments
- fix: repair encrypted mails "mixed up" by Google Workspace "Append footer" function
- fix: use same contact-color if email address differ only in upper-/lowercase
- fix scroll-down button visibility
- fix: allow DeltaChat folder being hidden
- fix: cleanup read receipts storage
- fix: mailing list: remove square-brackets only for first name
- fix: do not use footers from mailinglists as the contact status
- update provider database, add hermes.radio subdomains
- update translations
- update to core88


## v1.30.1
2022-05

- speed up loading of chat messages by a factor of 20
- speed up finding the correct server after logging in
- speed up marking messages as being seen and use fewer network data by batch processing
- speed up messages deletion and use fewer network data for that
- speed up message receiving a bit
- speed up various parts by caching config values
- speed up chat list loading massively
- speed up checking for new messages in background
- revamped welcome screen
- archived+muted chats are no longer unarchived when new messages arrive;
  this behavior is also known by other messengers
- improve voice-over navigation in chat
- add support for webxdc messages
- fix: do not create empty contact requests with "setup changed" messages;
  instead, send a "setup changed" message into all chats we share with the peer
- fix an issue where the app crashes when trying to export a backup
- fix outgoing messages appearing twice with Amazon SES
- fix unwanted deletion of messages that have no Message-ID set or are duplicated otherwise
- fix: assign replies from a different email address to the correct chat
- fix: assign outgoing private replies to the correct chat
- fix: ensure ephemeral timer is started eventually also on rare states
- fix: do not try to use stale SMTP connections
- fix: retry message sending automatically and do not wait for the next message being sent
- fix a bug where sometimes the file extension of a long filename containing a dot was cropped
- fix messages being treated as spam by placing small MIME-headers before the larger Autocrypt:-header
- fix: keep track of QR code joins in database to survive restarts
- fix: automatically accept chats with outgoing messages
- fix connectivity view's "One moment..." message being stuck when there is no network
- fix: select Chinese Traditional and Chinese Simplified accordingly
- fix several issues when checking for new messages in background
- fix: update chat when adding something from the share-extension
- fix scroll-down button not always appearing as expected
- fix: connect to notification service as soon as possible even if there is no network on initial startup
- fix: disable zoom in connectivity view
- fix layout of info-messages in dark-mode
- fix: show download failures
- fix: send locations in the background regardless of other sending activity
- fix rare crashes when stopping IMAP and SMTP
- fix correct message escaping consisting of a dot in SMTP protocol
- fix rendering of quotes in QR code descriptions
- fix: accessibility: do not stop VoiceOver output after sending a voice-message
- various improvements for the VoiceOver navigation in a chat
- fixed memory leaks in chats
- fix wallpaper disappearing sometimes
- fix app crash after providing camera permissions
- fix: allow playing voice messages in background
- fix some scrolling issues in chat view
- fix multi-select message layout (time was sometimes truncated)
- add finnish translation, update other translations
- update provider database
- update to core80


## v1.28.1
2022-02

- fix some missing chatlist updates
- update translations


## v1.28.0
2022-01

- add option to create encrypted database at "Add Account",
  the database passphrase is generated automatically and is stored in the system's keychain,
  subsequent versions will probably get more options to handle passphrases
- add writing support for supported mailinglist types; other mailinglist types stay read-only
- add an option to define a background image that is used in all chats then :)
- "Message Info" show routes
- add option "Your Profile Info / Password and Account / Only Fetch from DeltaChat Folder";
  this is useful if you can configure your server to move chat messages to the DeltaChat folder
- add "Search" and "Mute" as separate buttons to the chat profiles
- the connectivity status now also shows if notifications work as expected
- improve accessibility for the chat requests button bar
- semi-transparent chat input bar at the bottom of the chat view
- show chat title in delete confirmation dialog
- speed up opening chats
- explicit "Watch Inbox folder" and "Watch DeltaChat folder" settings no longer required;
  the folders are watched automatically as needed
- to safe traffic and connections, "Advanced / Watch Sent Folder" is disabled by default;
  as all other IMAP folders, the folder is still checked on a regular base
- detect correctly signed messages from Thunderbird and show them as such
- synchronize Seen status across devices
- more reliable group memberlist and group avatar updates
- recognize MS Exchange read receipts as such
- fix leaving groups
- fix unread count issues in account switcher
- fix scroll-down button for chat requests
- fix layout issues of the chat message input bar in phone's landscape orientation
- add Bulgarian translations, update other translations and local help
- update provider-database
- update to core75


## v1.26.2
2021-12

- re-layout all QR codes and unify appearance among the different platforms
- show when a contact was "Last seen" in the contact's profile
- group creation: skip presetting a draft that is deleted most times anyway
- auto-generated avatars are displayed similar across all platforms now
- speed up returning to chat list
- fix chat assignment when forwarding
- fix group-related system messages appearing as normal messages in multi-device setups
- fix removing members if the corresponding messages arrive disordered
- fix potential issue with disappearing avatars on downgrades
- update translations
- update to core70


## v1.24.5
2021-11

- fix missing stickers, image and video messages on iOS 15
- fix "copy to clipboard" for video chat invites
- update translations
- using core65


## v1.24.4
2021-11

- fix accidental disabling of ephemeral timers when a message is not auto-downloaded
- fix: apply existing ephemeral timer also to partially downloaded messages;
  after full download, the ephemeral timer starts over
- update translations and local help
- update to core65


## v1.24.3
2021-11

- fix messages added on scanning the QR code of an contact
- fix incorrect assignment of Delta Chat replies to classic email threads
- update translations and local help


## v1.24.1
2021-11

- new "In-Chat Search" added; tap the corresponding option in the profile
- new option "Auto-Download Messages": Define the max. messages size to be downloaded automatically -
  larger messages, as videos or large images, can be downloaded manually by a simple tap then
- new: much easier joining of groups via qr-code: nothing blocks
  and you get all progress information in the immediately created group
- new: get warnings before your server runs out of space (if quota is supported by your provider)
- messages are marked as "being read" already when the first recipient opened the message
  (before, that requires 50% of the recipients to open the message)
- contact requests are notified as usual now
- add an option to copy a contact's email address to the clipboard
- force strict certificate checks when a strict certificate was seen on first login
- do not forward group names on forwarding messages
- "Broadcast Lists", as known from other messengers, added as an experimental feature
  (you can enable it at "Settings / Advanced")
- fix: disappearing messages timer now synced more reliable in groups
- fix: improve detection of some mailing list names
- fix "QR process failed" error
- fix DNS and certificate issues
- fix: if account creation was aborted, go to the previously selected account, not to the first
- fix: update app badge counter on archiving a chat directly
- fix: reduce memory consumption of share extension
- fix: update search result when messages update
- fix requesting camera permissions on some devices
- fix: use correct margins on phones with a notch
- fix: update chat profile when chat changes remotely
- fix: no more screen flickering when deleting a chat
- update provider-database
- update translations and local help


## v1.22.1
2021-08

- fix: always reconnect if account creation was cancelled
- update translations


## v1.22.0
2021-08

- added: connectivity view shows quota information, if supported by the provider
- fix account migration, updates are displayed instantly now
- fix forwarding mails containing only quotes
- fix ordering of some system messages
- fix handling of gmail labels
- fix connectivity display for outgoing messages
- fix acceping mailing lists
- fix drafts popping up as message bubbles
- fix connectivity info updates
- update translations and provider database


## v1.21.1 Testflight
2021-08

- fix: avoid possible data loss when the app was not closed gracefully before;
  this bug was introduced in 1.21.0 and not released outside testing groups -
  thanks to all testers!


## 1.21.0 Testflight
2021-07

- added: multi-account functionality: add and switch accounts from the settings
- added: every new "contact request" is shown as a separate chat now,
  you can block or accept or archive or pin them
  (old contact requests are available in "Archived Chats")
- added: the title bar shows if the app is not connected
- added: a tap in the title bar shows connectivity details (also available in settings)
- added: allow defining a video chat instance (eg. any jitsi instance)
- added: send video chat invites
- added: receive video chat invites as such
- added: offer a button for quick scrolling down in a chat
- deactivate and reactivate your own QR codes by just scanning them
- quotes can now refer messages from other chats
- do not show signature in "Saved Messages"
- revert sharing webp files as stickers
- fix date labels stuck in the seventies sometimes
- fix "show in chat"
- fix sharing issues
- fix: crash in gallery
- fix message input bar and share layout for iPad
- fix: keep keyboard open after cancelling drafts and quotes 
- fix displaying of small images
- fix more scrolling issues


## 1.20.5
2021-06

- show status/footer messages in contact profiles
- show stickers as such
- send memojis as stickers
- open chat at the first unread message
- fix downscaling images
- fix outgoing messages popping up in "Saved messages" for some providers
- fix: do not allow deleting contacts with ongoing chats
- fix: ignore drafts folder when scanning
- fix: scan folders also when inbox is not watched
- fix scrolling issues
- fix: not not stack chats on tapping notifications
- fix: show warning if camera access is denied
- fix: do not hide keyboard after sending a message
- fix: hide keyboard when tapping on a search result
- improve error handling and logging
- update translations, local help and provider database


## 1.20.4
2021-05

- fix: remove notifications if the corresponding chat is archived
- fix: less 0xdead10cc exceptions, mark background threads as such
- update translations


## 1.20.3
2021-05

- fix "show in chat" function in profile's gallery and document views
- fix: less 0xdead10cc exceptions in background
- update dependencies
- update translations


## 1.20.2
2021-05

- show total playback time of audio files before starting playback
- show location icon beside messages containing locations
- improve layout of delivery information inside bubbles
- fix: do not start location manager when location streaming is disabled
- fix: do not send read receipts when the screen is off
- fix: delete notifications if the corresponding chat is deleted
- fix: target background issues
- fix crash when receiving some special messages                                
- fix downloading some messages multiple times                                  
- fix formatting of read receipt texts  
- update translations


## 1.20.0
2021-05

- opening the contact request chat marks all contact requests as noticed
  and removes the sticky hint from the chatlist
- if "Show classic mails" is enabled,
  the contact request hint in the corresponding chat
- speed up global search
- improve display of small images
- fix: filter contact list for adding members to verified groups
- fix: re-add headlines for every day
- fix: register for notifications also after qr-code account scanning
- fix a rare crash on chat deletion
- fix: update chat on forwarding to saved-messages
- fix: make links and default user actions work in contact requests
- add Chinese, French, Indonesian, Polish and Ukrainian local help, update other translations


## 1.19.1 Testflight
2021-04

- speed improvements
- fix a rare crash in chatlist


## 1.19.0 Testflight
2021-04

- show answers to generic support-addresses as info@company.com in context
- allow different sender for answers to support-addresses as info@company.com
- show multiple notifications
- group notifications by chats
- speed up chatlist update and global search
- improve detection of quotes
- improve background fetching
- ignore classical mails from spam-folder
- make log accessible on configure at "Log in to your Server / Advanced"
- fix showing configure errors
- add Czech translation, update other translations


## 1.17.1 Testflight
2021-03

- new mailinglist and better bot support
- more reliable notifications about every 20 minutes, typically faster
- tapping notification opens the corresponding chat
- more information and images shown in notifications
- add option to view original-/html-mails
- check all imap folders for new messages from time to time
- allow dialing on tapping a phone number
- use more colors for user avatars
- improve e-mail compatibility
- improve animations and scrolling
- improve compatibility with Outlook.com
  and other providers changing message headers
- scale avatars based on media_quality, fix avatar rotation
- export backups as .tar files
- enable strict TLS for known providers by default
- improve and harden secure join
- show warning for unsupported audio formats
- fix send button state after video draft has been added
- fix background crash
- fix read receipts
- fix decoding of attachment filenames
- fix: exclude muted chats from notified-list
- fix: do not return quoted messages from the trash chat
- much more bug fixes
- add Khmer, Persian, Arabic, Kurdish, Sardinian translations, update other translations
- add Czech local help, update other local help


## 1.16.0
2021-02

- new staging area: images and other files
  can be reviewed and sent together with a description now
- show in chat: go to the the corresponding message
  directly from images or documents in the gallery
- new, redesigned context menus in chat, gallery and document view -
  long-tap a message to feel the difference
- multi-select in chat: long-tap a message and select more messages
  for deletion or forwarding
- improve several accessibility items and texts
- improve keyboard layouts
- fix: profile images can now always be cropped after selection
- fix: hints in empty chats are no longer truncated
- fix swipe-to-reply icon for iOS 11 and 12
- more bug fixes
- update translations and local help


## 1.14.4
2020-12

- fix scrolling bug on ios 14.2
- update translations


## 1.14.3
2020-11

- fix bug that could lead to empty messages being sent
- update translations


## 1.14.2
2020-11

- fix issues when combining bubbles of the same sender
- update translations


## 1.14.1
2020-11

- new swipe-to-reply option
- show impact of the "Delete messages from server" option more clearly
- fix: do not fetch from INBOX if "Watch Inbox folder" is disabled
  and do not fetch messages arriving before re-enabling
- fix: do not use STARTTLS when PLAIN connection is requested
  and do not allow downgrade if STARTTLS is not available
- fix: make "nothing found" hints always visible
- fix: update selected avatars immediately
- update translations


## 1.14.0
2020-11

- disappearing messages: select for any chat the lifetime of the messages
- scroll chat to search result
- fast scrolling through all chat-messages by long tapping the scrollbar
- show quotes in messages as such
- add known contacts from the IMAP-server to the local addressbook on configure
- enable encryption in groups if preferred by the majority of recipients
  (previously, encryption was only enabled if everyone preferred it)
- speed up configuration
- try multiple servers from autoconfig
- check system clock and app date for common issues
- improve multi-device notification handling
- improve detection and handling of video and audio messages
- hide unused functions in "Saved messages" and "Device chat" profiles
- bypass some limits for maximum number of recipients
- add option to show encryption info for a contact
- fix launch if there is an ongoing process
- fix errors that are not shown during configuring
- fix mistakenly unarchived chats
- fix: tons of improvements affecting sending and receiving messages, see
  https://github.com/deltachat/deltachat-core-rust/blob/master/CHANGELOG.md
- update provider database and dependencies
- add Slovak translation, update other translations


## 1.12.3
2020-08

- allow importing backups in the upcoming .tar format
- remove X-Mailer debug header
- try various server domains on configuration
- improve guessing message types from extension
- improve member selection in verified groups
- fix threading in interaction with non-delta-clients
- fix showing unprotected subjects in encrypted messages
- more fixes, update provider database and dependencies


## 1.12.2
2020-08

- add last chats to share suggestions
- fix improvements for sending larger mails
- fix a crash related to muted chats
- fix incorrect dimensions sometimes reported for images
- improve linebreak-handling in HTML mails
- improve footer detection in plain text email
- fix deletion of multiple messages
- more bug fixes


## 1.12.0
2020-07

- use native camera, improve video recording
- streamline profile views and show the number of items
- option to enlarge profile image
- show a device message when the password was changed on the server
- show experimental disappearing-messages state in chat's title bar
- improve sending large messages and GIF messages
- improve receiving messages
- improve error handling when there is no network
- allow avatar deletion in profile and in groups
- fix gallery dark-mode
- fix login issue on ios 11
- more bug fixes


## 1.10.1
2020-07

- new launchscreen
- improve overall stability
- improve message processing
- disappearing messags added as an experimental feature


## 1.10.0
2020-06

- with this version, Delta Chat enters a whole new level of speed,
  messages will be downloaded and sent way faster -
  technically, this was introduced by using so called "async-processing"
- share images and other content from other apps to Delta Chat
- show animated GIF directly in chat
- reworked gallery and document view
- select outgoing media quality
- mute chats
- if a message cannot be delivered to a recipient
  and the server replies with an error report message,
  the error is shown beside the message itself in more cases
- default to "Strict TLS" for some known providers
- improve reconnection handling
- improve interaction with conventional email programs
  by showing better subjects
- improve adding group members
- fix landscape appearance
- fix issues with database locking
- fix importing addresses
- fix memory leaks
- more bug fixes


## v1.8.1
2020-05

- add option for automatic deletion of messages after a given timespan;
  messages can be deleted from device and/or server
- switch to ecc keys; ecc keys are much smaller and faster
  and safe traffic and time this way
- new welcome screen
- add an option to create an account by scanning a qr code, of course,
  this has to be supported by the used provider
- rework qr-code scanning: there is now one view with two tabs
- improve interaction with traditional mail clients
- improve avatar handling on ipad
- debug and log moved to "Settings / Advanced / View log"
- bug fixes
- add Indonesian translation, update other translations


## v1.3.0
2020-03-26

- add global search for chats, contacts, messages - just swipe down in the chatlist
- show padlock beside encrypted messages
- tweak checkmarks for "delivered" and "read by recipient"
- add option "Settings / Advanced / On-demand location streaming" -
  once enabled, you can share your location with all group members by
  taping on the "Attach" icon in a group
- add gallery-options to chat-profiles
- on forwarding, "Saved messages" will be always shown at the top of the list
- streamline confirmation dialogs on chat creation and on forwarding to "Saved messages"
- faster contact-suggestions, improved search for contacts
- improve interoperability eg. with Cyrus server
- fix group creation if group was created by non-delta clients
- fix showing replies from non-delta clients
- fix crash when using empty groups
- several other fixes
- update translations and help


## v1.2.1
2020-03-04

- on log in, for known providers, detailed information are shown if needed;
- in these cases, also the log in is faster
  as needed settings are available in-app
- save traffic: messages are downloaded only if really needed,
- chats can now be pinned so that they stay sticky atop of the chat list
- integrate the help to the app
  so that it is also available when the device is offline
- a 'setup contact' qr scan is now instant and works even when offline -
  the verification is done in background
- unified 'send message' option in all user profiles
- rework user and group profiles
- add options to manage keys at "Settings/Autocrypt/Advanced"
- fix updating names from incoming mails
- fix encryption to Ed25519 keys that will be used in one of the next releases
- several bug fixes, eg. on sending and receiving messages, see
  https://github.com/deltachat/deltachat-core-rust/blob/master/CHANGELOG.md#1250
  for details on that
- add Croatian and Esperanto translations, update other translations

The changes have been done by Alexander Krotov, Allan Nordhøy, Ampli-fier,
Angelo Fuchs, Andrei Guliaikin, Asiel Díaz Benítez, Besnik, Björn Petersen,
ButterflyOfFire, Calbasi, cloudieg, Dmitry Bogatov, dorheim, Emil Lefherz,
Enrico B., Ferhad Necef, Florian Bruhin, Floris Bruynooghe, Friedel Ziegelmayer,
Heimen Stoffels, Hocuri, Holger Krekel, Jikstra, Lin Miaoski, Moo, nayooti,
Nico de Haen, Ole Carlsen, Osoitz, Ozancan Karataş, Pablo, Paula Petersen,
Pedro Portela, polo lancien, Racer1, Simon Laux, solokot, Waldemar Stoczkowski,
Xosé M. Lamas, Zkdc


## v1.1.1
2020-02-02

- fix string shown on requesting permissions


## v1.1.0
2020-01-29

- add a document picker to allow sending files
- show video thumbnails
- support memoji and other images pasted from the clipboard
- improve image quality
- reduce traffic by combining read receipts and some other tweaks
- fix deleting messages from server
- add Korean, Serbian, Tamil, Telugu, Svedish and Bokmål translations
- several bug fixes


## v1.0.2
2020-01-09

- fix crashes on iPad


## v1.0.1
2020-01-07

- handle various qr-code formats
- allow creation of verified groups
- improve wordings on requesting permissions
- bug fixes


## v1.0.0
2019-12-23

Finally, after months of coding and fixing bugs, here it is:
Delta Chat for iOS 1.0 :)

- support for user avatars: select your profile image
  at "settings / my profile info"
  and it will be sent out to people you write to
- previously selected avatars will not be used automatically,
  you have to select a new avatar
- introduce a new "Device Chat" that informs the user about app changes
  and, in the future, problems on the device
- rename the "Me"-chat to "Saved messages",
  add a fresh icon and make it visible by default
- update translations
- bug fixes

The changes of this version and the last beta versions have been done by
Alexander Krotov, Allan Nordhøy, Ampli-fier, Andrei Guliaikin,
Asiel Díaz Benítez, Besnik, Björn Petersen, ButterflyOfFire, Calbasi, cyBerta,
Daniel Boehrsi, Dmitry Bogatov, dorheim, Emil Lefherz, Enrico B., Ferhad Necef,
Florian Bruhin, Floris Bruynooghe, Friedel Ziegelmayer, Heimen Stoffels, Hocuri,
Holger Krekel, Jikstra, Lars-Magnus Skog, Lin Miaoski, Moo, Nico de Haen,
Ole Carlsen, Osoitz, Ozancan Karataş, Pablo, Pedro Portela, polo lancien,
Racer1, Simon Laux, solokot, Waldemar Stoczkowski, Xosé M. Lamas, Zkdc


## v0.960.0
2019-11-24

- allow picking a profile-image for yourself;
  the image will be sent to recipients in one of the next updates:
- streamline group-profile and advanced-loging-settings
- show 'Automatic' for unset advanced-login-settings
- show used settings below advanced-login-setting
- add global option to disable notifications
- update translations
- various bug fixes


## v0.950.0
2019-11-05

- move folder settings to account settings
- improve scanning of qr-codes
- update translations
- various bug fixes


## v0.940.2
2019-10-31

- add "dark mode" for all views
- if a message contains an email, this can be used to start a chat directly
- add "delete mails from server" options
  to "your profile info / password and account"
- add option to delete a single message
- if "show classic emails" is set to "all",
  emails pop up as contact requests directly in the chatlist
- update translations
- various bug fixes


## v0.930.0
2019-10-22

- add "send copy to self" switch
- play voice messages and other audio
- show descriptions for images, video and other files
- show correct delivery states
- show forwarded messages as such
- improve group editing
- show number of unread messages
- update translations
- various bug fixes


## v0.920.0
2019-10-10

- show text sent together with images or files
- improve onboarding error messages
- various bug fixes


## v0.910.0
2019-10-07

- after months of hard work, this release is finally
  based on the new rust-core that brings improved security and speed,
  solves build-problems and also makes future developments much easier.
  there is much more to tell on that than fitting reasonably in a changelog :)
- start writing a changelog
- hide bottom-bar in subsequent views
- fix a bug that makes port and other advaced settings unchangeable after login
- disable dark-mode in the chat view for now
- update translations

The changes have been done Alexander Krotov, Andrei Guliaikin,
Asiel Díaz Benítez, Besnik, Björn Petersen, Calbasi, cyBerta, Dmitry Bogatov,
dorheim, Enrico B., Ferhad Necef, Florian Bruhin, Floris Bruynooghe,
Friedel Ziegelmayer, Heimen Stoffels, Hocuri, Holger Krekel, Jikstra,
Jonas Reinsch, Lars-Magnus Skog, Lin Miaoski, Moo, nayooti, Ole Carlsen,
Osoitz, Ozancan Karataş, Pedro Portela, polo lancien, Racer1, Simon Laux,
solokot, Waldemar Stoczkowski, Zkdc  
