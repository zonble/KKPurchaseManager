import Foundation
import StoreKit

@objc public protocol KKPurchaseManagerDelegate: class {
	@objc func purchaseManagerDidUpdateProducts(_ manager: KKPurchaseManager)
	@objc func purchaseManager(_ manager: KKPurchaseManager, didPurchaseProducts transations: [SKPaymentTransaction])
	@objc func purchaseManager(_ manager: KKPurchaseManager, purchaseProductsDidFail transations: [SKPaymentTransaction])
	@objc func purchaseManager(_ manager: KKPurchaseManager, shouldAdd payment:SKPayment, for product: SKProduct) -> Bool
	@objc func purchaseManagerDidAskApplicatonUserName(_ manager: KKPurchaseManager) -> String?
}

public class KKPurchaseManager: NSObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {
	weak var delegate: KKPurchaseManagerDelegate?
	public var productsIDSet: Set<String> = Set<String>() {
		didSet {
			self.resetProducts()
			if self.running == false {
				return
			}
			self.updateProducts()
		}
	}
	public private (set) var products: [SKProduct] = [SKProduct]()
	public private (set) var running = false
	private var productRequest: SKProductsRequest?

	deinit {
		SKPaymentQueue.default().remove(self)
		NotificationCenter.default.removeObserver(self)
	}

	public func addTransactionObserver() {
		SKPaymentQueue.default().add(self)
		self.running = true
		self.resetProducts()
		self.updateProducts()
	}

	public func removeTransactionObserver() {
		SKPaymentQueue.default().remove(self)
		self.running = false
		self.resetProducts()
	}

	public func updateProducts() {
		self.productRequest?.cancel()
		self.productRequest = nil

		if self.productsIDSet.count == 0 {
			return
		}
		self.productRequest = SKProductsRequest(productIdentifiers: self.productsIDSet)
		self.productRequest?.delegate = self
		self.productRequest?.start()
	}

	public func purchase(product: SKProduct) {
		for transaction in SKPaymentQueue.default().transactions {
			if transaction.transactionState != .purchasing {
				continue
			}
			if transaction.payment.productIdentifier == product.productIdentifier {
				return
			}
		}
		let payment = SKMutablePayment(product: product)
		if let name = self.delegate?.purchaseManagerDidAskApplicatonUserName(self) {
			payment.applicationUsername = name
		}
		SKPaymentQueue.default().add(payment)
	}

	public func resetProducts() {
		self.productRequest?.cancel()
		self.productRequest = nil
		self.productsIDSet = Set<String>()
		self.products = [SKProduct]()
	}


	public func restoreCompletedTransactions() {
		SKPaymentQueue.default().restoreCompletedTransactions()
	}

	public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
		
	}

	public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
	}

	public func paymentQueue(_ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
	}

	public func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
	}

	public func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
	}
}

