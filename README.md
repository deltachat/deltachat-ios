# deltachat-ios

Email-based instant messaging for iOS.

## How to build with Xcode

    $ git clone git@github.com:deltachat/deltachat-ios.git
    $ cd deltachat-ios
    $ open deltachat-ios.xcworkspace # do not: open deltachat-ios.xcodeproj
    
This should open Xcode. Then make sure that at the top left in Xcode there is *deltachat-ios* selected as scheme (see screenshot below).

![Screenshot](supporting_images/screenshot_scheme_selection.png)

Now build and run - e.g. by pressing Cmd-r - or click on the triangle at the top:

![Screenshot](supporting_images/screenshot_build_and_run.png)

## Roadmap / TODO for 'minimal viable version'

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
- [X] allow group creation (leave out group settings
      and settings for contact for now)
- [X] text drafts support
- [X] support DC_EVENT_HTTP_GET event
- [ ] add a progress indicator while doing the configuration
- [ ] allow sending of images
      and taking+sending photos directly from the camera.
      (videos and voice messages
      and other attachments can be done in a later version)
- [ ] ui-polishing, eg.
  - [ ] improve group creation UI
  - [ ] smarter time/date display
    (time beside messages, date as headlines)
  - [ ] adapt avatars (use the colored images from the chatlist
    also in the chat, no avatars beside outgoing messages
  - [ ] show e-mail-address in the chat-title and/or open profile
    when clicking on chat-title
    (subtitle) dc_chat_get_subtitle
- [ ] allow advanced configuration options on setup
      to make sure users can connect if the autoconfig fails
      (imap-server, imap-port, imap-flags, same for smtp -
      if not yet implemented
      (cannot test currently, iphone-battery is empty))

## Beta Changelog

Betas are distributed via Testflight

### Beta 3 (upcoming, not yet released)

- support automatic configuration via DC_EVENT_HTTP_GET event
- progress indicator while doing the configuration

### Beta 2

- new deltachat-core-api (no more polling, much faster)
- groups can be created
- text drafts support

### Beta 1:

- UI: colored initial circles
- screens and menus now more closely resemble the Android version, while staying true to iOS conventions

