# code layout thoughts

## view definitions
  
- `UIView`
  - basic element to build UI, buttons, labels, layouts etc.
  - rectangle area
  - can contain other `UIView` objects
  - _similar to "View" on android_

- `UIViewController`
  - contains at least one `UIView`
  - _similar to "Acticity" on android_

- `UITabBarController`
  - manages a number of `UIViewController` accessible via a button bar (abottom)
  - typically not subclassed, says apple

- `UINavigationController`
  - manage a stack of `UIViewController` and a navigation bar (atop)
  - performs horizontal view transitions for pushed and popped views
    (via `pushViewController()`, `popViewController()`)
  - typically subclassed, says apple
  
- "delegate"
  - a "delegate" is a set of functions, defined by a protocol, to receive events as `didSelect()` [2]
  - the functions in the "delegate" are called by the "delegator"
  - both, "delegator" and "delegate" may be view controllers,
    eg. ViewControllerA ("delegator") is sending an event to ViewControllerB ("delegate")
  - in practise, subclasses just override functions defined by "delegate" protocol, as `didSelect()`
  - used by view controllers the system provides

- "coordinator"
  - convention, no requirement from UIKit
  - defined as an empty protocol class from where other derive
  - they typically take a `UINavigationController` as argument on construction
    and call eg. `pushViewController()` to navigate to other view controllers
  - stored as a member of the view controller
  - everything done there could also be done in a view controller directly
  - when derived from an abstract base class, in theory, this helps on making things more reusable
    by removing the navigation from the view, see next point

- "coordinator protocol"
  - convention to define a base for coordinators having the same interface
  - eg. ContactDetailCoordinatorProtocol


## app definitions

- `UIApplication`
  - every app has exactly one instance of `UIApplication` [1]
  - typically not subclassed
  - created by calling `UIApplicationMain()`
    or by adding the attribute `@UIApplicationMain` to a class derived from `UIApplicationDelegate`
  - main entry point is `application(_:didFinishLaunchingWithOptions:)` [4]
  - _similar to "Application" on android_
    
- `UIApplicationDelegate`
  - a "delegate" (see "view delegate" for definition)
    for events on application-level as `applicationWillEnterForeground()`
  - we need to derive from `UIApplicationDelegate` and pass this to `UIApplicationMain`
  - `UIApplication.shared.delegate` will keep a reference to our delegate
  - we can store "app globals" here, as DcContext

- `UIWindow`
  - backdrop for the ui, dispatches events, derived from `UIView`
  - stored in `UIApplication.shared.delegate.window`,
  - created in `application(_:didFinishLaunchingWithOptions:)`;
    in pure iOS13 apps set in SceneDelegate
  - an app typically has only one window
  - `window.rootViewController` is the anchor of all view controllers


## holding references

a tricky part (see eg. [3]) seems to be to hold
the correct type of references to the UIViewControllers.

- at least one "strong" (normal) reference is needed somewhere.

- only "weak" or "unowned" references are not sufficient
  ("weak" always needs unwrap and may be come nil at any time,
  "unowned" is kind of always-unwrapped "weak").

- currently, we hold strong references to the coordinators
  which hold strong references to the view controllers


## what is needed? what adds unneeded complexity?

- "delegates" are needed to get events from the system

- we need some dead-simple way to persist the objects that need persistence

- do we need our own delegates? or just call functions directly as needed?
  what is the current state?

- is the overhead of "coordinator" really needed and helpful?
  - why not just call eg. `pushViewController()` and make sure it is persisted as needed
    (coordinators would not help on that imu anyway, see bug at [3])
  - TODO: `AppCoordinator` is also derived from NSObject - is there a know reason for that?
  - seem not to help on making code readable - esp. as all coordinators are in a separate file
  - i think the "coordinator" as they are used now are of very limited use,

- however, the coordinator get the UINavigationContoller as argument, so there is some use

- remove "coordinator protocol" and do not use?
  - in general, for some minor adaptions, a simple flag eg. hiding some elements
    appear much more readable to me that having several levels of abstraction
  - when we really come to the point where we need to reuse things, 
    we can add these things as needed (or use parameters on creation "flag"),
    i think, in the current state, coordinators create more harm than use.

- the tearing up of navigator/coordinator into two files is
  unfortunate, in swiftUI, this is re-combined to a single file,
  child-class and a makeCoordinator() called by SwiftUI:
  https://developer.apple.com/tutorials/swiftui/interfacing-with-uikit

- rules of thumb to minimze impact of **logging:**
  - only log vars that are anyway there, do not calculate or get vars only for logging
  - do only log relevant information
  - logging is there to help on issues.
	to not decelerate things, there is no strict format or depth buerocracy.
	logging may be adapted, also temporary, different areas may have different depths etc.


## notification system

- `NotificationCenter.default.post()`
  post events to all observers _synchronously_ on the same thread;
  this may not be the thread the observer registered itself [5].
  Observers may receive the event in any random thread therefore.

- best practise [6] would be that the observers assume,
  they receive the notification in any thread
  and call `DispatchQueue.main.async` where actually needed.
  for new code, we should use that approach, it won't hurt.

- however, existing code might assume
  that the notification arrives in main thread;
  therefore, we also call `DispatchQueue.main.async` for sending events out.

- using always main thread for sending/receiving and adding/remove observers
  also avoids other multithreading-issues of NotificationCenter itself,
  see https://lapcatsoftware.com/articles/nsnotificationcenter-is-threadsafe-not.html
  for details.

tl;dr: post from main thread and also add/remove observers from main thread.
on receiving, assume, things will block.

## notification system: adding and removing observers

- for the `addObserver()` variant returning an object
  (overview at https://developer.apple.com/documentation/foundation/notificationcenter )
  always save the object as `NSObjectProtocol` not as `Any?` -
  otherwise you risk to mix addObserver() functions as also
  the non-return variant can be saved as `Any?`
  (Swift allows saving "no return type" as `Any?`)

- call `removeObserver(self)` only in deinit,
  otherwise use `removeObserver(self, name, obj)` or `removeObserver(obj)`


## some sources

[1] https://developer.apple.com/documentation/uikit/uiapplication

[2] delegator/delegate: https://stackoverflow.com/questions/7052926/what-is-the-purpose-of-an-ios-delegate https://developer.apple.com/library/archive/documentation/General/Conceptual/DevPedia-CocoaCore/Delegation.html
  
[3] weak coordinator bugs: https://github.com/deltachat/deltachat-ios/issues/675,
https://github.com/deltachat/deltachat-ios/issues/323
  
[4] https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1622921-application

[5] https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Notifications/Articles/Threading.html#//apple_ref/doc/uid/20001289-CEGJFDFG

[6] https://medium.com/@hadhi631/myths-and-facts-about-nsnotifcation-posting-and-receiving-df7f5729b19f

