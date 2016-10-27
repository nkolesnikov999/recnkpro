//
//  PicturePageViewController.swift
//  Rec NKPro
//
//  Created by NK on 07.04.16.
//  Copyright © 2016 Nikolay Kolesnikov. All rights reserved.
//

import UIKit

protocol PicturePageViewControllerDelegate: class {
  var currentIndex: Int { get set }
}

class PicturePageViewController: UIPageViewController {
  
  weak var mainDelegate: PicturePageViewControllerDelegate?
  
  var picturesList = PicturesList.pList.pictures
  var currentIndex: Int!
  var oldIndex: Int = 0
  var newIndex: Int = 0 {
    willSet {
      //print("Will: \(newIndex)")
      oldIndex = newIndex
    }
    didSet {
      //print("Did: \(newIndex)")
      indexChanged(newIndex)
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    dataSource = self
    delegate = self
    
    // 1
    if let viewController = viewPictureController(currentIndex ?? 0) {
      let viewControllers = [viewController]
      // 2
      setViewControllers(
        viewControllers,
        direction: .forward,
        animated: false,
        completion: nil
      )
    }
  }
  
  func viewPictureController(_ index: Int) -> PictureViewController? {
    if let storyboard = storyboard,
      let page = storyboard.instantiateViewController(withIdentifier: "PictureViewController")
        as? PictureViewController {
      if picturesList.count > 0 {
        page.picture = picturesList[index]
      }
      page.pictureIndex = index
      return page
    }
    return nil
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  func indexChanged(_ index: Int) {
    
      // what direction are we moving in?
      let direction: UIPageViewControllerNavigationDirection = index < oldIndex ? .reverse : .forward
      // set the new page, animated!
      if let pictureVC = viewPictureController(index) {
        if index != oldIndex {
          setViewControllers([pictureVC], direction: direction, animated: true, completion: nil)
        }
      }
  }

  
}

extension PicturePageViewController: UIPageViewControllerDataSource {
  func pageViewController(_ pageViewController: UIPageViewController,
                          viewControllerBefore viewController: UIViewController) -> UIViewController? {
    
    if let viewController = viewController as? PictureViewController {
      var index = viewController.pictureIndex
      guard index != NSNotFound && index != 0 else { return nil }
      index = index! - 1
      return viewPictureController(index!)
    }
    return nil
  }
  
  // 2
  func pageViewController(_ pageViewController: UIPageViewController,
                          viewControllerAfter viewController: UIViewController) -> UIViewController? {
    if picturesList.count == 0 { return nil }
    if let viewController = viewController as? PictureViewController {
      var index = viewController.pictureIndex
      guard index != NSNotFound else { return nil }
      index = index! + 1
      guard index != picturesList.count else {return nil}
      return viewPictureController(index!)
    }
    return nil
  }
}

extension PicturePageViewController: UIPageViewControllerDelegate {
  
  func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
    if let currentTutorialPage = pageViewController.viewControllers![0] as? PictureViewController {
      currentIndex = currentTutorialPage.pictureIndex
      mainDelegate?.currentIndex = currentTutorialPage.pictureIndex
    }
  }
}

