import Foundation

#if os(OSX) || os(iOS) || os(tvOS)
import StoreKit

private let kReceiptsStoreKey = "KKBOXStore"
private let kICloudStoreKey = "KKBOXiCloud"
private let kReceiptsKey = "KKBOXReceipts"
private let kAccessDateKey = "KKBOXAccessDate"

private let KKIAPReceiptKey = "receipt"
private let KKIAPProductIDKey = "product_id"
private let KKIAPTransactionIDKey = "trans_id"
private let KKIAPOriginalTransactionIDKey = "original_trans_id"
private let KKIAPPurchaseDateKey = "purchase_date"

private let kTransactionIDKey = "transactionID"
private let kOriginalTransactionIDKey = "originalTransactionID"
private let kProductIDKey = "productID"
private let kReceiptDataKey = "receiptData"
private let kPurchaseDateKey = "purchaseDate"
private let kOriginalPurchaseDateKey = "originalPurchaseDate"
private let kReceivedDateKey = "receivedDate"
private let kReceiverKey = "receiver"
private let kConsumedKey = "consumed"

@objc public class KKReceipt: NSObject, NSCoding {
	@objc public fileprivate(set) var transactionID: String = ""
	@objc public fileprivate(set) var originalTransactionID: String = ""
	@objc public fileprivate(set) var productID: String = ""
	@objc public fileprivate(set) var receipt: Data = Data()

	@objc public fileprivate(set) var purchaseDate: Date = Date(timeIntervalSince1970: 0)
	@objc public fileprivate(set) var originalPurchaseDate: Date?
	@objc public fileprivate(set) var receivedDate: Date = Date(timeIntervalSince1970: 0)

	@objc public fileprivate(set) var isConsumed = true

	public required init?(coder aDecoder: NSCoder) {
		super.init()
		self.transactionID = aDecoder.decodeObject(forKey: kTransactionIDKey) as? String ?? ""
		self.originalTransactionID = aDecoder.decodeObject(forKey: kOriginalTransactionIDKey) as? String  ?? ""
		self.productID = aDecoder.decodeObject(forKey: kProductIDKey) as? String ?? ""
		self.receipt = aDecoder.decodeObject(forKey: kReceiptDataKey) as? Data ?? Data()
		self.purchaseDate = aDecoder.decodeObject(forKey: kPurchaseDateKey) as? Date ?? Date(timeIntervalSince1970: 0)
		self.receivedDate = aDecoder.decodeObject(forKey: kReceivedDateKey) as? Date ?? Date(timeIntervalSince1970: 0)
		self.originalPurchaseDate = aDecoder.decodeObject(forKey: kOriginalPurchaseDateKey) as? Date
		self.isConsumed = aDecoder.decodeBool(forKey: kConsumedKey)
	}

	public func encode(with aCoder: NSCoder) {
		aCoder.encode(self.transactionID, forKey: kTransactionIDKey)
		aCoder.encode(self.originalTransactionID, forKey: kOriginalTransactionIDKey)
		aCoder.encode(self.productID, forKey: kProductIDKey)
		aCoder.encode(self.receipt, forKey: kReceiptDataKey)
		aCoder.encode(self.purchaseDate, forKey: kPurchaseDateKey)
		aCoder.encode(self.receivedDate, forKey: kReceivedDateKey)
		if self.originalPurchaseDate != nil {
			aCoder.encode(self.originalPurchaseDate, forKey: kOriginalPurchaseDateKey)
		}
		aCoder.encode(self.isConsumed, forKey: kConsumedKey)
	}
}

@objc public class KKReceiptsStorage: NSObject {

	/// All receipts in the storage.
	@objc public private(set) var allReceipts: [KKReceipt] = {
		guard let dictionary = UserDefaults.standard.dictionary(forKey: kReceiptsStoreKey),
			let data = dictionary[kReceiptsKey] as? Data else {
			return [KKReceipt]()
		}
		return NSKeyedUnarchiver.unarchiveObject(with: data) as? [KKReceipt] ?? [KKReceipt]()
		}() {
		didSet {
			let data = NSKeyedArchiver.archivedData(withRootObject: self.allReceipts)
			let dictionary = [
				kReceiptsKey: data,
				kAccessDateKey: NSKeyedArchiver.archivedData(withRootObject: Date())
			]
			UserDefaults.standard.set(dictionary, forKey: kReceiptsStoreKey)
			UserDefaults.standard.synchronize()
		}
	}

	/// All receipts that are not marked as uploaeded in the storage.
	@objc public var allReceiptsNotUploadedYet: [KKReceipt] {
		return self.allReceipts.filter { $0.isConsumed == false }
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
	}

	override init() {
		super.init()
	}

	/// Add new receipts to the storage.
	///
	/// - Parameter receipts: the receipt objects.
	@objc public func add(receipts: [KKReceipt]) {
		let transactionIDSet = Set<String>(self.allReceipts.map { $0.transactionID })
		var receiptsCopy = self.allReceipts
		let filteredReceipts = receipts.filter { receipt in
			transactionIDSet.contains(receipt.transactionID)
		}
		receiptsCopy.append(contentsOf: filteredReceipts)
		self.allReceipts = receiptsCopy
	}

	/// Removes all receipts in the storage.
	@objc public func removeAllReceipts() {
		self.allReceipts = [KKReceipt]()
	}

	/// Removes receipts that are too old.
	///
	/// - Parameter date: receipts for purchases that made before the date will be removed from the storage.
	@objc public func removeReceipts(purchasedBefore date: Date) {
		let filteredReceipts = self.allReceipts.filter { receipt in
			guard let originalPurchaseDate = receipt.originalPurchaseDate else {
				return true
			}
			return originalPurchaseDate.compare(date) == .orderedDescending
		}
		self.allReceipts = filteredReceipts
	}

	@objc public func markReceiptsAsConsumed(with transactionIDs: Set<String>) -> [KKReceipt] {
		let receiptsCopy = self.allReceipts
		var newlyMarked = [KKReceipt]()
		receiptsCopy.forEach { receipt in
			if transactionIDs.contains(receipt.transactionID) {
				receipt.isConsumed = true
				newlyMarked.append(receipt)
			}
		}
		self.allReceipts = receiptsCopy
		return newlyMarked
	}
}

@objc extension KKReceiptsStorage {

	/// Copy local receipts to iCloud.
	///
	/// - Parameter receipts: the receipts to copy.
	@objc public func copyToICloud(receipts: [KKReceipt]) {
		var existingReceipts: [KKReceipt] = {
			guard let dictionary = NSUbiquitousKeyValueStore.default.dictionary(forKey: kReceiptsStoreKey),
			let data = dictionary[kReceiptsKey] as? Data,
			let existingReceipts = NSKeyedUnarchiver.unarchiveObject(with: data) as? [KKReceipt] else {
				return [KKReceipt]()
			}
			return existingReceipts
		}()

		let transactionIDSet = Set<String>(existingReceipts.map { $0.transactionID })
		let filteredReceipts = receipts.filter{ receipt in
			return transactionIDSet.contains(receipt.transactionID) == false
		}
		existingReceipts.append(contentsOf: filteredReceipts)
		let data = NSKeyedArchiver.archivedData(withRootObject: self.allReceipts)
		let dictionary = [
			kReceiptsKey: data,
			kAccessDateKey: NSKeyedArchiver.archivedData(withRootObject: Date())
		]
		NSUbiquitousKeyValueStore.default.set(dictionary, forKey: kReceiptsStoreKey)
		NSUbiquitousKeyValueStore.default.synchronize()
		// Also leave a local copy.
		UserDefaults.standard.set(dictionary, forKey: kICloudStoreKey)
		UserDefaults.standard.synchronize()
	}

	/// Copy all local receipts to iCloud.
	@objc public func copyToICloud() {
		self.copyToICloud(receipts: self.allReceipts)
	}

}

#endif

