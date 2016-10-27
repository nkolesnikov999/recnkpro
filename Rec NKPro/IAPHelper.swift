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
    self.init(rawValue: productId.replacingOccurrences(of: "net.nkpro.RecNKPro.", with: ""))
  }
}

class IAPHelper: NSObject {
  
  static let IAPHelperPurchaseNotification = "IAPHelperPurchaseNotification"
  static let FullVersionKey = "FullVersionKey"
  
  static let iapHelper = IAPHelper(prodIds: Set([
    RecPurchase.FullVersion
    ].map { $0.productId }))
  
  typealias ProductsRequestCompletionHandler = (_ products: [SKProduct]?) -> ()
  
  
  
  var setFullVersion = false {
    didSet {
      //print("CHANGE Full Version = \(setFullVersion)")
    }
  }
  
  fileprivate let productIdentifiers: Set<String>
  fileprivate var productsRequest: SKProductsRequest?
  fileprivate var productRequestCompletionHandler: ProductsRequestCompletionHandler?
  
  init(prodIds: Set<String>) {
    productIdentifiers = prodIds
    super.init()
    SKPaymentQueue.default().add(self)
    loadSettings()
  }

}

extension IAPHelper {
  
  func requestProducts(_ completionHandler: @escaping ProductsRequestCompletionHandler) {
    productsRequest?.cancel()
    productRequestCompletionHandler = completionHandler
    
    productsRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
    productsRequest?.delegate = self
    productsRequest?.start()
  }
  
  func buyProduct(_ product: SKProduct) {
    let payment = SKPayment(product: product)
    SKPaymentQueue.default().add(payment)
  }
  
  func restorePurchases() {
    SKPaymentQueue.default().restoreCompletedTransactions()
  }
  
  fileprivate func loadSettings() {
    if let setFullVersion = (UserDefaults.standard.value(forKey: IAPHelper.FullVersionKey) as AnyObject).boolValue {
      self.setFullVersion = setFullVersion
    }
  }
  
  func saveSettings(_ key: String) {
    UserDefaults.standard.setValue(true, forKey: key)
    UserDefaults.standard.synchronize()
  }
  
}

extension IAPHelper: SKProductsRequestDelegate {
  
  func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
    productRequestCompletionHandler?(response.products)
    productRequestCompletionHandler = .none
    productsRequest = .none
  }
  
  func request(_ request: SKRequest, didFailWithError error: Error) {
    print("Error: \(error.localizedDescription)")
    productRequestCompletionHandler?(.none)
    productRequestCompletionHandler = .none
    productsRequest = .none
  }
}

extension IAPHelper: SKPaymentTransactionObserver {
  
  func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
    for transaction in transactions {
      switch transaction.transactionState {
      case .purchased:
        completeTransaction(transaction)
      case .restored:
        restoreTransaction(transaction)
      case .failed:
        failedTransaction(transaction)
      default:
        print("Unhandled transaction state")
      }
    }
  }
  
  fileprivate func completeTransaction(_ transaction: SKPaymentTransaction) {
    deliverPurchaseNotificationForIdentifier(transaction.payment.productIdentifier)
    SKPaymentQueue.default().finishTransaction(transaction)
  }
  
  fileprivate func restoreTransaction(_ transaction: SKPaymentTransaction) {
    deliverPurchaseNotificationForIdentifier(transaction.original?.payment.productIdentifier)
    SKPaymentQueue.default().finishTransaction(transaction)
  }
  
  fileprivate func failedTransaction(_ transaction: SKPaymentTransaction) {
    if let transactionError = transaction.error as? NSError {
      if transactionError.code != SKError.Code.paymentCancelled.rawValue {
        print("Transaction error: \(transactionError.localizedDescription)")
      }
    }
    SKPaymentQueue.default().finishTransaction(transaction)
  }
  
  fileprivate func deliverPurchaseNotificationForIdentifier(_ identifier: String?) {
    guard let identifier = identifier else { return }
    NotificationCenter.default.post(name: Notification.Name(rawValue: type(of: self).IAPHelperPurchaseNotification), object: identifier)
  }
  
}


