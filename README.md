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
- [X] add a progress indicator while doing the configuration
- [X] allow advanced configuration options on setup
      to make sure users can connect if the autoconfig fails
      (imap-server, imap-port, imap-flags, same for smtp)
- [X] allow re-configuring (e.g. after changing the IMAP/SMTP password) at
      an arbitrary point in time
- [X] allow sending of images
      and taking+sending photos directly from the camera.
      (videos and voice messages
      and other attachments can be done in a later version)
- [ ] reception of images
- [ ] ui-polishing, eg.
  - [ ] improve group creation UI
  - [ ] smarter time/date display
    (time beside messages, date as headlines)
  - [ ] adapt avatars (use the colored images from the chatlist
    also in the chat, no avatars beside outgoing messages
  - [ ] show e-mail-address in the chat-title and/or open profile
    when clicking on chat-title
    (subtitle) dc_chat_get_subtitle
- [ ] read address book for contact suggestions
- [ ] check notifications, currently there is only a vibrate,
      however, we should keep in mind that the first version
      may be a "foreground" app, so "system notifications" may
      be delayed to a later version
- [ ] check how to solve this: new messages are only seen if a chat is closed and shown again (similar to that). No tune, no number at icon. https://github.com/deltachat/deltachat-ios/issues/9#issue-356157986

## Testing

Betas are distributed via Testflight. Click on this link

https://testflight.apple.com/join/WVoYFOZe

on your iPhone or iPad to try Deltachat iOS Beta.

## Changelog

### Beta 5
2018-10-01

- allow advanced configuration options on setup to make sure users can connect if the autoconfig fails (imap-server, imap-port, imap-flags, same for smtp)

### Beta 4
2018-09-18

- display last DC_EVENT_ERROR string upon configuration failure

### Beta 3
2018-09-17

- support automatic configuration via DC_EVENT_HTTP_GET event
- progress indicator while doing the configuration
- fixes iPad crash

### Beta 2
2018-07-26

- new deltachat-core-api (no more polling, much faster)
- groups can be created
- text drafts support

### Beta 1
2018-06-11

- UI: colored initial circles
- screens and menus now more closely resemble the Android version, while staying true to iOS conventions
