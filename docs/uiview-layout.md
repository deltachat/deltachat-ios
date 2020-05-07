# UIView layout thoughts

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
  - typically subclasses, says apple
  
- "delegate"
  - a "delegate" is a set of functions, defined by a protocol, to receive events as `didSelect()` [2]
  - the functions in the "delegate" are called by the "delegator"
  - both, "delegator" and "delegate" may be view controllers,
    eg. ViewControllerA ("delegator") is sending an event to ViewControllerB ("delegate")
  - in practise, subclasses just override functions defined by "delegate" protocol, as `didSelect()`
  - used view controllers the system provides

- "coordinator"
  - convention, no requirement from UIKit
  - defined as an empty protocol class from where other derive
  - they take the view controller as argument on construction
    and call eg. `pushViewController()` to go to other views
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
  - _similar to "Application" on android_
    
- `UIApplicationDelegate`
  - a "delegate" (see "view delegate" for definition)
    for events on application-level as `applicationWillEnterForeground()`
  - we need to derive from `UIApplicationDelegate` and pass this to `UIApplicationMain`
  - `UIApplication.shared.delegate` will keep a reference to our delegate
  - we can store "app globals" here, as DcContext


## holding references

a tricky part (see eg. [3]) seems to be to hold the correct type of rerences to the UIViewControllers.

TODO: what are the requirements?


## what is needed? what adds unneeded complexity?

- "delegates" are needed to get events from the system

- we need some dead-simple way to persist the objects that need persistance

- do we need our own delegates? or just call funcions directly as needed?
  what is the current state?

- is the overhead of "coordinator" really needed and helpful?
  - why not just call eg. `pushViewController()` and make sure it is persisted as needed
    (coordinators would not help on that imu anyway, see bug at [3])
  - TODO: `AppCoordinator` is also derived from NSObject - is there a know reason for that?
  - seem not to help on making code readable - esp. as all coordinators are in a separate file
  - i think the "coordinator" as they are used now are of very limited use,
  
- remove "coordinator protocol" and do not use?
  - in general, for some minor adaptions, a simple flag eg. hiding some elements
    appear much more readable to me that having several levels of abstraction
  - when we really come to the point where we need to reuse things, 
    we can add these things as needed (or use parameters on creation "flag"),
    i think, in the current state, coordinators create more harm than use.


## some sources

[1] https://developer.apple.com/documentation/uikit/uiapplication

[2] delegator/delegate: https://stackoverflow.com/questions/7052926/what-is-the-purpose-of-an-ios-delegate https://developer.apple.com/library/archive/documentation/General/Conceptual/DevPedia-CocoaCore/Delegation.html
  
[3] weak coordinator bug: https://github.com/deltachat/deltachat-ios/issues/675
  
