import Foundation
#if os(OSX) || os(iOS) || os(tvOS)
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

/// A helper that helps to do In-app Purchase.
@objc public class KKPurchaseManager: NSObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {

	/// The delegate object of the class.
	@objc public weak var delegate: KKPurchaseManagerDelegate?

	/// A set of desired product IDs. Once the product ID set is set, and
	/// the manager has started to observe SKPaymentQueue, the manager
	/// starts to fetch SKProduct objects via StoreKit.
	@objc public var productsIDSet: Set<String> = Set<String>() {
		didSet {
			self.resetProducts()
			if self.running == false {
				return
			}
			self.updateProducts()
		}
	}

	/// The fetched In-App Purchase products.
	@objc public private (set) var products: [SKProduct] = [SKProduct]()

	/// If the manager is observing the default SKPaymentQueue.
	@objc public private (set) var running = false
	private var productRequest: SKProductsRequest?

	deinit {
		SKPaymentQueue.default().remove(self)
		NotificationCenter.default.removeObserver(self)
	}

	/// Start observing the transactrion queue.
	@objc public func addTransactionObserver() {
		SKPaymentQueue.default().add(self)
		self.running = true
		self.resetProducts()
		self.updateProducts()
	}

	/// Stop observing the transactrion queue.
	@objc public func removeTransactionObserver() {
		SKPaymentQueue.default().remove(self)
		self.running = false
		self.resetProducts()
	}

	/// Start to fetch SKProduct objects from StoreKit API.
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

	/// Reset the list of current products.
	@objc public func resetProducts() {
		NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(updateProducts), object: nil)
		self.productRequest?.cancel()
		self.productRequest = nil
		self.productsIDSet = Set<String>()
		self.products = [SKProduct]()
	}


	/// Start to purchase one or more product.
	///
	/// - Parameters:
	///   - product: the product to purchase.
	///   - quantity: the quantity.
	@objc public func purchase(product: SKProduct, quantity: Int) {
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
		payment.quantity = quantity
		SKPaymentQueue.default().add(payment)
	}

	/// Start to restore completed transactions.
	@objc public func restoreCompletedTransactions() {
		SKPaymentQueue.default().restoreCompletedTransactions()
	}

	//MARK: - SKProductsRequestDelegate

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

	//MARK: - SKPaymentTransactionObserver

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

#endif
