//
//  PaddingLabel.swift
//  Rec NKPro
//
//  Created by NK on 06.11.16.
//  Copyright © 2016 Nikolay Kolesnikov. All rights reserved.
//

import UIKit
class PaddingLabel: UILabel {
  
  let topInset = CGFloat(0)
  let bottomInset = CGFloat(0)
  let leftInset = CGFloat(10)
  let rightInset = CGFloat(10)
  
  override func drawText(in rect: CGRect)
  {
    let insets: UIEdgeInsets = UIEdgeInsets(top: topInset, left: leftInset, bottom: bottomInset, right: rightInset)
    super.drawText(in: UIEdgeInsetsInsetRect(rect, insets))
  }
  override public var intrinsicContentSize: CGSize
  {
    var intrinsicSuperViewContentSize = super.intrinsicContentSize
    intrinsicSuperViewContentSize.height += topInset + bottomInset
    intrinsicSuperViewContentSize.width += leftInset + rightInset
    return intrinsicSuperViewContentSize
  }

  // Override -sizeThatFits: for Springs & Struts code
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let superSizeThatFits = super.sizeThatFits(size)
    let width = superSizeThatFits.width + leftInset + rightInset
    let heigth = superSizeThatFits.height + topInset + bottomInset
    return CGSize(width: width, height: heigth)
  }
}
