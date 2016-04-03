/*
* Copyright (c) 2016 Razeware LLC
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
* THE SOFTWARE.
*/

import UIKit

extension UIImage {
  
  func thumbnailOfSize(rect: CGSize) -> UIImage {
    
    let finalsize = CGSizeMake(rect.width, rect.height)
    let scaleX = finalsize.width/self.size.width
    let scaleY = finalsize.height/self.size.height
    
    let scale = max(scaleX, scaleY)
    let widthRect = self.size.width * scale
    let heightRect = self.size.height * scale
    var xRect: CGFloat = 0
    var yRect: CGFloat = 0
    
    if scaleX != scale {
      xRect = (finalsize.width - widthRect) / 2
    }

    if scaleY != scale {
      yRect = (finalsize.height - heightRect) / 2
    }
    
    let rect = CGRectMake( xRect, yRect, widthRect, heightRect)
    //print("RECT: \(rect)")
    
    UIGraphicsBeginImageContextWithOptions(finalsize, false, 0)
    drawInRect(rect)
    let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return thumbnail
  }
  
}
