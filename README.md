# deltachat-ios
Email-based instant messaging for iOS.

- after cloning, go to the top level directory of the project and run 'pod install' (See https://guides.cocoapods.org/using/getting-started.html for an introduction to CocoaPods)

- then, open deltachat-ios.xcworkspace (*not* deltachat-ios.xcodeproj ), e.g. by running 'open deltachat-ios.xcworkspace' in the shell.


### Roadmap / TODO for 'minimal viable version'

- [X] use new deltachat-core-api and
 adapt threads to the following scheme:
 https://deltachat.github.io/api/
 (the current ios-implementation relies on
 threads created by deltachat-core; this is no longer done)
- [X] threads should be created when going to foreground
 and removed when going to background.
 we could say, for the first version, we're a foreground app
 and figure out background things later
- [X] order: new group, new contact
- [ ] allow group creation
      (afaik groups created on other devices are
      already displayed), leave out group settings
       and settings for contact for now
- [ ] ui-polishing, eg.
  - [ ] smarter time/date display
    (time beside messages, date as headlines)
  - [ ] adapt avatars (use the colored images from the chatlist
    also in the chat, no avatars beside outgoing messages
  - [ ] show e-mail-address in the chat-title and/or open profile
    when clicking on chat-title
    (subtitle) dc_chat_get_subtitle
- [ ] add a progress indicator while doing the configuration
- [ ] allow sending of images
      and taking+sending photos directly from the camera.
      (videos and voice messages
      and other attachments can be done in a later version)
- [ ] allow advanced configuration options on setup
      to make sure users can connect if the autoconfig fails
      (imap-server, imap-port, imap-flags, same for smtp -
      if not yet implemented
      (cannot test currently, iphone-battery is empty))
- [ ] text drafts (not really important at first)
      is included in dc_chat_get_subtitle
