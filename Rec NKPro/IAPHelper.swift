//
//  IAPHelper.swift
//  Rec NKPro
//
//  Created by NK on 19.01.16.
//  Copyright © 2016 Nikolay Kolesnikov. All rights reserved.
//

import Foundation
import StoreKit

enum RecPurchase: String {
  case RemoveAds = "RemoveAds"
  case ChangeLogo5000 = "ChangeLogo5000"
  case ChangeLogo1000 = "ChangeLogo1000"
  case ChangeLogo = "ChangeLogo"
  
  var productId: String {
    return "net.nkpro.RecNKPro." + rawValue
  }
  
  init?(productId: String) {
    self.init(rawValue: productId.stringByReplacingOccurrencesOfString("net.nkpro.RecNKPro.", withString: ""))
  }
}

class IAPHelper: NSObject {
  
  static let IAPHelperPurchaseNotification = "IAPHelperPurchaseNotification"
  static let RemoveAdKey = "RemoveAdKey"
  static let ChangeLogoKey = "ChangeLogoKey"
  
  static let iapHelper = IAPHelper(prodIds: Set([
    RecPurchase.RemoveAds,
    RecPurchase.ChangeLogo,
    RecPurchase.ChangeLogo1000,
    RecPurchase.ChangeLogo5000
    ].map { $0.productId }))
  
  typealias ProductsRequestCompletionHandler = (products: [SKProduct]?) -> ()
  
  
  
  var setChangeLogo = false {
    didSet {
      print("CHANGE LOGO = \(setChangeLogo)")
    }
  }
  
  var setRemoveAd = false {
    didSet {
      print("REMOVE AD = \(setRemoveAd)")
    }
  }
  
  private let productIdentifiers: Set<String>
  private var productsRequest: SKProductsRequest?
  private var productRequestCompletionHandler: ProductsRequestCompletionHandler?
  
  init(prodIds: Set<String>) {
    productIdentifiers = prodIds
    super.init()
    SKPaymentQueue.defaultQueue().addTransactionObserver(self)
    loadSettings()
  }

}

extension IAPHelper {
  
  func requestProducts(completionHandler: ProductsRequestCompletionHandler) {
    productsRequest?.cancel()
    productRequestCompletionHandler = completionHandler
    
    productsRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
    productsRequest?.delegate = self
    productsRequest?.start()
  }
  
  func buyProduct(product: SKProduct) {
    let payment = SKPayment(product: product)
    SKPaymentQueue.defaultQueue().addPayment(payment)
  }
  
  func restorePurchases() {
    SKPaymentQueue.defaultQueue().restoreCompletedTransactions()
  }
  
  private func loadSettings() {
    if let setRemoveAd = NSUserDefaults.standardUserDefaults().valueForKey(IAPHelper.RemoveAdKey)?.boolValue {
      self.setRemoveAd = setRemoveAd
    }
    if let setChangeLogo = NSUserDefaults.standardUserDefaults().valueForKey(IAPHelper.ChangeLogoKey)?.boolValue {
      self.setChangeLogo = setChangeLogo
    }
  }
  
  func saveSettings(key: String) {
    NSUserDefaults.standardUserDefaults().setValue(true, forKey: key)
    NSUserDefaults.standardUserDefaults().synchronize()
  }
  
}

extension IAPHelper: SKProductsRequestDelegate {
  
  func productsRequest(request: SKProductsRequest, didReceiveResponse response: SKProductsResponse) {
    productRequestCompletionHandler?(products: response.products)
    productRequestCompletionHandler = .None
    productsRequest = .None
  }
  
  func request(request: SKRequest, didFailWithError error: NSError) {
    print("Error: \(error.localizedDescription)")
    productRequestCompletionHandler?(products: .None)
    productRequestCompletionHandler = .None
    productsRequest = .None
  }
}

extension IAPHelper: SKPaymentTransactionObserver {
  
  func paymentQueue(queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
    for transaction in transactions {
      switch transaction.transactionState {
      case .Purchased:
        completeTransaction(transaction)
      case .Restored:
        restoreTransaction(transaction)
      case .Failed:
        failedTransaction(transaction)
      default:
        print("Unhandled transaction state")
      }
    }
  }
  
  private func completeTransaction(transaction: SKPaymentTransaction) {
    deliverPurchaseNotificationForIdentifier(transaction.payment.productIdentifier)
    SKPaymentQueue.defaultQueue().finishTransaction(transaction)
  }
  
  private func restoreTransaction(transaction: SKPaymentTransaction) {
    deliverPurchaseNotificationForIdentifier(transaction.originalTransaction?.payment.productIdentifier)
    SKPaymentQueue.defaultQueue().finishTransaction(transaction)
  }
  
  private func failedTransaction(transaction: SKPaymentTransaction) {
    if transaction.error?.code != SKErrorPaymentCancelled {
      print("Transaction error: \(transaction.error?.localizedDescription)")
    }
    SKPaymentQueue.defaultQueue().finishTransaction(transaction)
  }
  
  private func deliverPurchaseNotificationForIdentifier(identifier: String?) {
    guard let identifier = identifier else { return }
    NSNotificationCenter.defaultCenter().postNotificationName(self.dynamicType.IAPHelperPurchaseNotification, object: identifier)
  }
  
}


