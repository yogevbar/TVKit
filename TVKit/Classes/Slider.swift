//
//  Slider.swift
//  Slider
//
//  Created by Jin Sasaki on 2016/05/10.
//  Copyright © 2016年 Jin Sasaki. All rights reserved.
//

import UIKit

public protocol SliderDelegate: class {
    func slider(_ slider: Slider, textWithValue value: Double) -> String

    func sliderDidTap(_ slider: Slider)
    func slider(_ slider: Slider, didChangeValue value: Double)
    func slider(_ slider: Slider, didUpdateFocusInContext context: UIFocusUpdateContext, withAnimationCoordinator coordinator: UIFocusAnimationCoordinator)
}

public extension SliderDelegate {
    func slider(_ slider: Slider, textWithValue value: Double) -> String { return "\(Int(value))" }

    func sliderDidTap(_ slider: Slider) {}
    func slider(_ slider: Slider, didChangeValue value: Double) {}
    func slider(_ slider: Slider, didUpdateFocusInContext context: UIFocusUpdateContext, withAnimationCoordinator coordinator: UIFocusAnimationCoordinator) {}
}

@IBDesignable
open class Slider: UIView {

    // MARK: - Public
    @IBInspectable open var value: Double = 0 {
        didSet {
            updateViews()
            delegate?.slider(self, didChangeValue: value)
        }
    }
    @IBInspectable open var max: Double = 100 {
        didSet {
            updateViews()
        }
    }
    @IBInspectable open var min: Double = 0 {
        didSet {
            updateViews()
        }
    }

    @IBOutlet open fileprivate(set) weak var barView: UIView!
    @IBOutlet open fileprivate(set) weak var seekerView: UIView!
    @IBOutlet open fileprivate(set) weak var seekerLabel: UILabel!
    @IBOutlet open fileprivate(set) weak var leftLabel: UILabel!
    @IBOutlet open fileprivate(set) weak var rightLabel: UILabel!
    @IBOutlet open fileprivate(set) weak var indicator: UIActivityIndicatorView!
    @IBOutlet open fileprivate(set) weak var rightImageView: UIImageView!
    @IBOutlet open fileprivate(set) weak var leftImageView: UIImageView!

    open weak var delegate: SliderDelegate?

    open var animationSpeed: Double = 1.0
    open var decelerationRate: CGFloat = 0.92
    open var decelerationMaxVelocity: CGFloat = 1000

    open func setValue(_ value: Double, animated: Bool) {
        stopDeceleratingTimer()
        if distance == 0 {
            self.value = value
            return
        }
        let duration = fabs(self.value - value) / distance * animationSpeed
        self.value = value
        if animated {
            UIView.animate(withDuration: duration, animations: {
                self.setNeedsLayout()
                self.layoutIfNeeded()
            })
        } else {
            self.value = value
        }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
        updateViews()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
        updateViews()
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        layoutIfNeeded()
        updateViews()
    }

    open override var canBecomeFocused : Bool {
        return true
    }

    open override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)

        if context.nextFocusedView == self {
            coordinator.addCoordinatedAnimations({ () -> Void in
                self.seekerView.transform = CGAffineTransform(translationX: 0, y: -12)
                self.seekerLabelBackgroundInnerView.backgroundColor = UIColor.white
                self.seekerLabel.textColor = UIColor.black
                self.seekerLabelBackgroundView.layer.shadowOpacity = 0.5
                self.seekLineView.layer.shadowOpacity = 0.5
                }, completion: nil)

        } else if context.previouslyFocusedView == self {
            coordinator.addCoordinatedAnimations({ () -> Void in
                self.seekerView.transform = CGAffineTransform.identity
                self.seekerLabelBackgroundInnerView.backgroundColor = UIColor.lightGray
                self.seekerLabel.textColor = UIColor.white
                self.seekerLabelBackgroundView.layer.shadowOpacity = 0
                self.seekLineView.layer.shadowOpacity = 0
                }, completion: nil)
        }
    }

    // MARK: - Private
    @IBOutlet fileprivate(set) weak var seekerViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet fileprivate(set) weak var seekLineView: UIView!
    @IBOutlet fileprivate(set) weak var seekerLabelBackgroundView: UIView!
    @IBOutlet fileprivate(set) weak var seekerLabelBackgroundInnerView: UIView!

    fileprivate var seekerViewLeadingConstraintConstant: CGFloat = 0
    fileprivate weak var deceleratingTimer: Timer?
    fileprivate var deceleratingVelocity: CGFloat = 0
    fileprivate var distance: Double {
        return fabs(max - min)
    }

    fileprivate func commonInit() {
        let bundle = Bundle(path: Bundle(for: type(of: self)).path(forResource: "TVKit", ofType: "bundle")!)
        let nib = UINib(nibName: "Slider", bundle: bundle)
        let view = nib.instantiate(withOwner: self, options: nil).first as! UIView
        addSubview(view)

        view.translatesAutoresizingMaskIntoConstraints = false
        let bindings = ["view": view]
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[view]|",
            options:NSLayoutFormatOptions(rawValue: 0),
            metrics:nil,
            views: bindings))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[view]|",
            options:NSLayoutFormatOptions(rawValue: 0),
            metrics:nil,
            views: bindings))

        barView.layer.cornerRadius = 6

        seekerLabelBackgroundInnerView.layer.cornerRadius = 4
        seekerLabelBackgroundInnerView.layer.masksToBounds = true
        seekerLabelBackgroundView.layer.cornerRadius = 4
        seekerLabelBackgroundView.layer.shadowRadius = 3
        seekerLabelBackgroundView.layer.shadowOpacity = 0
        seekerLabelBackgroundView.layer.shadowOffset = CGSize(width: 1, height: 1)

        seekLineView.layer.shadowRadius = 3
        seekLineView.layer.shadowOpacity = 0
        seekLineView.layer.shadowOffset = CGSize(width: 1, height: 1)

        leftLabel.text = "\(min)"
        rightLabel.text = "\(max)"

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGesture.delegate = self
        addGestureRecognizer(panGesture)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        addGestureRecognizer(tapGesture)
    }

    dynamic fileprivate func handlePanGesture(_ panGestureRecognizer: UIPanGestureRecognizer) {
        let translation = panGestureRecognizer.translation(in: self)
        let velocity = panGestureRecognizer.velocity(in: self)
        switch panGestureRecognizer.state {
        case .began:
            stopDeceleratingTimer()
            seekerViewLeadingConstraintConstant = seekerViewLeadingConstraint.constant
        case .changed:
            let leading = seekerViewLeadingConstraintConstant + translation.x / 5
            setValueWithPercentage(Double(leading / barView.frame.width))
        case .ended, .cancelled:
            seekerViewLeadingConstraintConstant = seekerViewLeadingConstraint.constant

            let direction: CGFloat = velocity.x > 0 ? 1 : -1
            deceleratingVelocity = fabs(velocity.x) > decelerationMaxVelocity ? decelerationMaxVelocity * direction : velocity.x
            deceleratingTimer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(handleDeceleratingTimer(_:)), userInfo: nil, repeats: true)
        default:
            break
        }
    }

    dynamic fileprivate func handleTapGesture(_ tapGestureRecognizer: UITapGestureRecognizer) {
        stopDeceleratingTimer()
        delegate?.sliderDidTap(self)
    }

    dynamic fileprivate func handleDeceleratingTimer(_ timer: Timer) {
        let leading = seekerViewLeadingConstraintConstant + deceleratingVelocity * 0.01
        setValueWithPercentage(Double(leading / barView.frame.width))
        seekerViewLeadingConstraintConstant = seekerViewLeadingConstraint.constant

        deceleratingVelocity *= decelerationRate
        if !isFocused || fabs(deceleratingVelocity) < 1 {
            stopDeceleratingTimer()
        }
    }

    fileprivate func stopDeceleratingTimer() {
        deceleratingTimer?.invalidate()
        deceleratingTimer = nil
        deceleratingVelocity = 0
    }

    fileprivate func setValueWithPercentage(_ percentage: Double) {
        self.value = distance * Double(percentage > 1 ? 1 : (percentage < 0 ? 0 : percentage)) + min
    }

    fileprivate func updateViews() {
        if distance == 0 { return }
        seekerViewLeadingConstraint.constant = barView.frame.width * CGFloat((value - min) / distance)
        seekerLabel.text = delegate?.slider(self, textWithValue: value) ?? "\(Int(value))"
    }
}


extension Slider: UIGestureRecognizerDelegate {
    open override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let panGestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer {
            let translation = panGestureRecognizer.translation(in: self)
            if fabs(translation.x) > fabs(translation.y) {
                return isFocused
            }
        }
        return false
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
