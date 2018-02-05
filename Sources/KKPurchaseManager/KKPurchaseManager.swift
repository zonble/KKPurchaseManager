import Foundation
import StoreKit

@objc public protocol KKPurchaseManagerDelegate: class {
	@objc func purchaseManagerDidUpdateProducts(_ manager: KKPurchaseManager)
	@objc func purchaseManager(_ manager: KKPurchaseManager, didPurchase transations: [SKPaymentTransaction])
	@objc func purchaseManager(_ manager: KKPurchaseManager, didFailPurchasing transations: [SKPaymentTransaction])

	@objc optional func purchaseManagerDidAskApplicatonUserName(_ manager: KKPurchaseManager) -> String?

	@objc optional func purchaseManager(_ manager: KKPurchaseManager, didRemove transations: [SKPaymentTransaction])
	@objc optional func purchaseManager(_ manager: KKPurchaseManager, didRestore transations: [SKPaymentTransaction])
	@objc optional func purchaseManager(_ manager: KKPurchaseManager, didFailRestoring error: Error)

	@objc optional func purchaseManager(_ manager: KKPurchaseManager, shouldAdd payment:SKPayment, for product: SKProduct) -> Bool
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

	@objc public func addTransactionObserver() {
		SKPaymentQueue.default().add(self)
		self.running = true
		self.resetProducts()
		self.updateProducts()
	}

	@objc public func removeTransactionObserver() {
		SKPaymentQueue.default().remove(self)
		self.running = false
		self.resetProducts()
	}

	@objc public func updateProducts() {
		NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(updateProducts), object: nil)
		self.productRequest?.cancel()
		self.productRequest = nil

		if self.productsIDSet.count == 0 {
			return
		}
		self.productRequest = SKProductsRequest(productIdentifiers: self.productsIDSet)
		self.productRequest?.delegate = self
		self.productRequest?.start()
	}

	@objc public func resetProducts() {
		NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(updateProducts), object: nil)
		self.productRequest?.cancel()
		self.productRequest = nil
		self.productsIDSet = Set<String>()
		self.products = [SKProduct]()
	}

	@objc public func purchase(product: SKProduct) {
		for transaction in SKPaymentQueue.default().transactions {
			if transaction.transactionState != .purchasing {
				continue
			}
			if transaction.payment.productIdentifier == product.productIdentifier {
				return
			}
		}
		let payment = SKMutablePayment(product: product)
		if let name = self.delegate?.purchaseManagerDidAskApplicatonUserName?(self) {
			payment.applicationUsername = name
		}
		SKPaymentQueue.default().add(payment)
	}

	@objc public func restoreCompletedTransactions() {
		SKPaymentQueue.default().restoreCompletedTransactions()
	}

	//MARK:-

	public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
		NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(updateProducts), object: nil)
		let products = response.products.filter {
			self.productsIDSet.contains($0.productIdentifier)
		}
		self.products = products
		DispatchQueue.main.async {
			self.delegate?.purchaseManagerDidUpdateProducts(self)
		}
	}

	public func request(_ request: SKRequest, didFailWithError error: Error) {
		self.perform(#selector(updateProducts), with: nil, afterDelay: 30)
	}

	//MARK:-

	public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
		var purchasedTransactions = [SKPaymentTransaction]()
		var failedTransactions = [SKPaymentTransaction]()
		for transaction in transactions {
			switch transaction.transactionState {
			case .purchased:
				purchasedTransactions.append(transaction)
			case .failed:
				failedTransactions.append(transaction)
				queue.finishTransaction(transaction)
			default:
				break
			}
		}

		if purchasedTransactions.count > 0 {
			DispatchQueue.main.async {
				self.delegate?.purchaseManager(self, didPurchase: purchasedTransactions)
			}
		}

		if failedTransactions.count > 0 {
			DispatchQueue.main.async {
				self.delegate?.purchaseManager(self, didFailPurchasing: failedTransactions)
			}
		}

	}

	public func paymentQueue(_ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
		self.delegate?.purchaseManager?(self, didRemove: transactions)
	}

	public func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
		self.delegate?.purchaseManager?(self, didFailRestoring: error)
	}

	public func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
		self.delegate?.purchaseManager?(self, didRestore: queue.transactions)
	}

	public func paymentQueue(_ queue: SKPaymentQueue, shouldAddStorePayment payment: SKPayment, for product: SKProduct) -> Bool {
		if let result = self.delegate?.purchaseManager?(self, shouldAdd: payment, for: product) {
			return result
		}
		return false
	}

}

