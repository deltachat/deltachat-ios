import Foundation
import UIKit

class PartialScreenPresentationController: UIPresentationController {
    let blurEffectView: UIVisualEffectView
    private var direction: CGFloat = 0

    lazy var tapGestureRecognizer: UITapGestureRecognizer = {
        return UITapGestureRecognizer(target: self, action: #selector(dismiss))
    }()

    lazy var panGestureRecognizer: UIPanGestureRecognizer = {
        return UIPanGestureRecognizer(target: self, action: #selector(didPan(pan:)))
    }()

    @objc func dismiss() {
        self.presentedViewController.dismiss(animated: true, completion: nil)
    }
    
    @objc func didPan(pan: UIPanGestureRecognizer) {
            guard let view = pan.view, let superView = view.superview,
                let presented = presentedView, let container = containerView else { return }

            let location = pan.translation(in: superView)
            let velocity = pan.velocity(in: superView)

            let maxPresentedY = container.frame.height / 2
            switch pan.state {
            case .changed:
                if location.y < 0 {
                    break
                }
                presented.frame.origin.y =  maxPresentedY + location.y
            case .ended:
                if velocity.y > 100 && location.y  > 0 {
                    presentedViewController.dismiss(animated: true, completion: nil)
                } else {
                    let offset = maxPresentedY + (maxPresentedY / 3)
                    switch presented.frame.origin.y {
                    case 0...offset:
                        UIView.animate(withDuration: 0.3, delay: 0.0, options: .curveEaseInOut, animations: {
                            presented.frame.origin.y = maxPresentedY
                        })
                    default:
                        presentedViewController.dismiss(animated: true, completion: nil)
                    }
                }
            default:
                break
            }
        }

    override init(presentedViewController: UIViewController, presenting presentingViewController: UIViewController?) {
        let blurEffect = UIBlurEffect(style: UIBlurEffect.Style.dark)
        blurEffectView = UIVisualEffectView(effect: blurEffect)
        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurEffectView.isUserInteractionEnabled = true
        blurEffectView.addGestureRecognizer(tapGestureRecognizer)
        presentedViewController.view.addGestureRecognizer(panGestureRecognizer)
    }

   override var frameOfPresentedViewInContainerView: CGRect {
       guard let containerView = self.containerView else {
           return CGRect()
       }
       return CGRect(origin: CGPoint(x: 0,
                                     y: containerView.frame.height / 2),
                     size: CGSize(width: containerView.frame.width,
                                  height: containerView.frame.height / 2))
   }

   override func dismissalTransitionWillBegin() {
       self.presentedViewController.transitionCoordinator?.animate(alongsideTransition: { _ in
           self.blurEffectView.alpha = 0
       }, completion: { _ in
           self.blurEffectView.removeFromSuperview()
       })
   }

   override func presentationTransitionWillBegin() {
       self.blurEffectView.alpha = 0
       self.containerView?.addSubview(blurEffectView)
       self.presentedViewController.transitionCoordinator?.animate(alongsideTransition: { _ in
           self.blurEffectView.alpha = 1
       })
   }

   override func containerViewWillLayoutSubviews() {
       super.containerViewWillLayoutSubviews()
       presentedView!.layer.masksToBounds = true
       presentedView!.layer.cornerRadius = 10
   }

   override func containerViewDidLayoutSubviews() {
       super.containerViewDidLayoutSubviews()
       self.presentedView?.frame = frameOfPresentedViewInContainerView
       blurEffectView.frame = containerView!.bounds
   }
}

final class PartialScreenModalTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {

    init(from presented: UIViewController, to presenting: UIViewController) {
        super.init()
    }

    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        return PartialScreenPresentationController(presentedViewController: presented, presenting: presenting)
    }
    
}
