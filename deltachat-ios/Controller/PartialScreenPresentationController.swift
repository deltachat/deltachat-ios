import Foundation
import UIKit

class PartialScreenPresentationController: UIPresentationController {
    let blurEffectView: UIVisualEffectView
    var tapGestureRecognizer: UITapGestureRecognizer = UITapGestureRecognizer()
    @objc func dismiss(){
        self.presentedViewController.dismiss(animated: true, completion: nil)
    }
    
    override init(presentedViewController: UIViewController, presenting presentingViewController: UIViewController?) {
        let blurEffect = UIBlurEffect(style: UIBlurEffect.Style.dark)
           blurEffectView = UIVisualEffectView(effect: blurEffect)
           super.init(presentedViewController: presentedViewController, presenting: presentingViewController)
           tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.dismiss))
           blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
           self.blurEffectView.isUserInteractionEnabled = true
           self.blurEffectView.addGestureRecognizer(tapGestureRecognizer)
    }
    
   override var frameOfPresentedViewInContainerView: CGRect{
       guard let containerView = self.containerView else {
           return CGRect()
       }
       return CGRect(origin: CGPoint(x: 0, y: containerView.frame.height / 2),
                     size: CGSize(width: containerView.frame.width,
                                  height:containerView.frame.height / 2))
   }

   override func dismissalTransitionWillBegin() {
       self.presentedViewController.transitionCoordinator?.animate(alongsideTransition: { (UIViewControllerTransitionCoordinatorContext) in
           self.blurEffectView.alpha = 0
       }, completion: { (UIViewControllerTransitionCoordinatorContext) in
           self.blurEffectView.removeFromSuperview()
       })
   }

   override func presentationTransitionWillBegin() {
       self.blurEffectView.alpha = 0
       self.containerView?.addSubview(blurEffectView)
       self.presentedViewController.transitionCoordinator?.animate(alongsideTransition: { (UIViewControllerTransitionCoordinatorContext) in
           self.blurEffectView.alpha = 1
       }, completion: { (UIViewControllerTransitionCoordinatorContext) in

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
