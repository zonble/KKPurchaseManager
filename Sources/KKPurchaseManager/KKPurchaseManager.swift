import Foundation
#if os(OSX) || os(iOS) || os(tvOS)
import StoreKit

/// The protocol that a delegate for KKPurchaseManager need to conform.
@objc public protocol KKPurchaseManagerDelegate: class {

	/// The method that notifies the delegate that KKPurchaseManager
	/// has updates its list for products. Tt might be called after
	/// calling `updateProducts` or chnaging the propery
	/// `productsIDSet`.
	///
	/// - Parameter manager: the manager.
	@objc func purchaseManagerDidUpdateProducts(_ manager: KKPurchaseManager)

	/// The method that notofies the delegate that KKPurchaseManager
	/// has purchase one or more products.
	///
	/// - Parameters:
	///   - manager: the manager.
	///   - transations: the successful transactions.
	@objc func purchaseManager(_ manager: KKPurchaseManager, didPurchase transations: [SKPaymentTransaction])

	/// The method that notofies the delegate that KKPurchaseManager
	/// has failed to purchase one or more products.
	///
	/// - Parameters:
	///   - manager: the manager.
	///   - transations: the failed transactions.
	@objc func purchaseManager(_ manager: KKPurchaseManager, didFailPurchasing transations: [SKPaymentTransaction])

	/// Implement the method if you wish to set application user name
	/// while doing purchases. Optional.
	///
	/// - Parameter manager: the manager.
	/// - Returns: the application user name that you specify.
	@objc optional func purchaseManagerDidAskApplicatonUserName(_ manager: KKPurchaseManager) -> String?

	/// The method is called when KKPurchaseManager found transactions
	/// are removed. Optional.
	///
	/// - Parameters:
	///   - manager: the manager.
	///   - transations: the removed transactions.
	@objc optional func purchaseManager(_ manager: KKPurchaseManager, didRemove transations: [SKPaymentTransaction])

	/// The method is called after you call
	/// `restoreCompletedTransactions` and the manager fails to
	/// restore receipts of made transactions. Receipts that are for
	/// subscription type purchase could be restored.
	///
	/// - Parameters:
	///   - manager: the manager.
	///   - transations: the restored transactions.
	@objc optional func purchaseManager(_ manager: KKPurchaseManager, didRestore transations: [SKPaymentTransaction])

	/// The method is called after you call
	/// `restoreCompletedTransactions` and the manager fails to
	/// restore receipts due to various errors, such as networking
	/// error, and so on.
	///
	/// - Parameters:
	///   - manager: the manager.
	///   - error: the error causes that you cannot restore receipts.
	@objc optional func purchaseManager(_ manager: KKPurchaseManager, didFailRestoring error: Error)

	/// If the manager should start purchasing a product or not.
	///
	/// Since iOS 11, Apple allows you to promote IAP products on the
	/// page for your app in the App Store app, you can create a deep
	/// link for your IAP product and put it on your website as
	/// well. Once the user tap on the link, iOS opens your app and
	/// notify KKPurchaseManager to call the delegate method. You can
	/// decide if the user could continue the flow and complete the
	/// transaction, depending on your business logic.
	///
	/// - Parameters:
	///   - manager: the manager.
	///   - payment: the payment object.
	///   - product: the product.
	/// - Returns: if the manager should start purchasing the product or not.
	@objc optional func purchaseManager(_ manager: KKPurchaseManager, shouldAdd payment:SKPayment, for product: SKProduct) -> Bool
}

enum KKPurchaseManagerError :Error {
	case notObservingPaymentQueue
	case productAlreadyInPaymentQueue
}

extension KKPurchaseManagerError: LocalizedError {
    public var errorDescription: String? {
		switch self {
		case .notObservingPaymentQueue:
			return NSLocalizedString("You did not start to observe the payment queue yet. Please call `startObservingPaymentQueue` at first.", comment: "")
		case .productAlreadyInPaymentQueue:
			return NSLocalizedString("The product is already in the payment queue.", comment: "")
		}
	}
}

//MARK: -

/// A helper that helps to do In-app Purchase. The manager manipulates
/// various API for IAP in one place including fetching the list of
/// products, purchasing products, and restoring receipts for
/// completed transactions.
@objc public class KKPurchaseManager: NSObject {

	/// The delegate object of the class. See `KKPurchaseManagerDelegate`.
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

	/// Start observing the payment queue.
	@objc public func startObservingPaymentQueue() {
		SKPaymentQueue.default().add(self)
		self.running = true
		self.resetProducts()
		self.updateProducts()
	}

	/// Stop observing the payment queue.
	@objc public func stopObservingPaymentQueue() {
		SKPaymentQueue.default().remove(self)
		self.running = false
		self.resetProducts()
	}

	/// Start to fetch SKProduct objects from StoreKit API. You should
	/// call the method after setting the `productsIDSet` property.
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
	/// Once you call the method, the following delegate methods
	///
	/// - purchaseManager(_, didPurchase:)
	/// - purchaseManager(_, didFailPurchasing:)
	///
	/// would be called.
	///
	/// - Parameters:
	///   - product: the product to purchase.
	///   - quantity: the quantity.
	/// - Throws: KKPurchaseManagerError.
	@objc public func purchase(product: SKProduct, quantity: Int) throws {
		if self.running == false {
			throw KKPurchaseManagerError.notObservingPaymentQueue
		}

		for transaction in SKPaymentQueue.default().transactions {
			if transaction.transactionState != .purchasing {
				continue
			}
			if transaction.payment.productIdentifier == product.productIdentifier {
				throw KKPurchaseManagerError.productAlreadyInPaymentQueue
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
	///
	/// Once you call the method. The following delegate methods
	///
	/// - purchaseManager(_:, didRestore:)
	/// - purchaseManager(_:, didFailRestoring:)
	///
	/// would be called.
	@objc public func restoreCompletedTransactions() {
		SKPaymentQueue.default().restoreCompletedTransactions()
	}

}

//MARK: -
extension KKPurchaseManager: SKProductsRequestDelegate, SKPaymentTransactionObserver {

	//MARK: SKProductsRequestDelegate

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

	//MARK: SKPaymentTransactionObserver

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
