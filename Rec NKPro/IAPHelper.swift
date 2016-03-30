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
  case FullVersion = "FullVersion"
  
  var productId: String {
    return "net.nkpro.RecNKPro." + rawValue
  }
  
  init?(productId: String) {
    self.init(rawValue: productId.stringByReplacingOccurrencesOfString("net.nkpro.RecNKPro.", withString: ""))
  }
}

class IAPHelper: NSObject {
  
  static let IAPHelperPurchaseNotification = "IAPHelperPurchaseNotification"
  static let FullVersionKey = "FullVersionKey"
  
  static let iapHelper = IAPHelper(prodIds: Set([
    RecPurchase.FullVersion
    ].map { $0.productId }))
  
  typealias ProductsRequestCompletionHandler = (products: [SKProduct]?) -> ()
  
  
  
  var setFullVersion = false {
    didSet {
      //print("CHANGE Full Version = \(setFullVersion)")
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
    if let setFullVersion = NSUserDefaults.standardUserDefaults().valueForKey(IAPHelper.FullVersionKey)?.boolValue {
      self.setFullVersion = setFullVersion
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
    if transaction.error?.code != SKErrorCode.PaymentCancelled.rawValue {
      print("Transaction error: \(transaction.error?.localizedDescription)")
    }
    SKPaymentQueue.defaultQueue().finishTransaction(transaction)
  }
  
  private func deliverPurchaseNotificationForIdentifier(identifier: String?) {
    guard let identifier = identifier else { return }
    NSNotificationCenter.defaultCenter().postNotificationName(self.dynamicType.IAPHelperPurchaseNotification, object: identifier)
  }
  
}


