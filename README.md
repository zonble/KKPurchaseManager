# KKPurchaseManager

> ⚠️ **Note:** This library was written in the 2010 era and is built on the legacy
> **StoreKit 1** APIs (`SKPaymentQueue`, `SKProduct`, `SKPaymentTransaction`, etc.).
> If you are starting a new project, Apple's modern
> [StoreKit 2](https://developer.apple.com/storekit/) (introduced in iOS 15 /
> macOS 12) with its async/await API is strongly recommended instead.

A manager that makes In-App Purchase easier.

A wrapper around the legacy StoreKit 1 APIs for In-App Purchase (IAP), covering
product fetching, purchasing, and receipt restoration. Supports iOS, macOS, and
tvOS.

## Requirements

| Platform | Minimum version |
|----------|----------------|
| iOS      | 7.0            |
| macOS    | 10.9           |
| tvOS     | 9.0            |

Written in Swift. Requires ARC.

## Installation

### CocoaPods

```ruby
pod 'KKPurchaseManager'
```

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/zonble/KKPurchaseManager.git", from: "0.1.0")
]
```

## Classes

### `KKPurchaseManager`

The central class that wraps `SKPaymentQueue` and `SKProductsRequest`. It handles:

- Fetching `SKProduct` objects for a set of product IDs.
- Adding payments to `SKPaymentQueue` and observing transaction updates.
- Restoring previously completed transactions.
- Forwarding all results to a delegate (`KKPurchaseManagerDelegate`).

#### Key properties

| Property | Description |
|----------|-------------|
| `delegate` | The `KKPurchaseManagerDelegate` that receives purchase events. |
| `productsIDSet` | Set of product identifier strings to fetch from StoreKit. Setting this automatically triggers a product fetch while the manager is running. |
| `products` | The `[SKProduct]` objects returned by the last successful product request. |
| `running` | `true` after `startObservingPaymentQueue()` is called. |

#### Key methods

```swift
// Start/stop observing SKPaymentQueue
manager.startObservingPaymentQueue()
manager.stopObservingPaymentQueue()

// Trigger or reset product fetching
manager.updateProducts()
manager.resetProducts()

// Purchase a product (throws KKPurchaseManagerError)
try manager.purchase(product: skProduct, quantity: 1)

// Restore completed transactions
manager.restoreCompletedTransactions()
```

#### `KKPurchaseManagerDelegate`

| Method | Notes |
|--------|-------|
| `purchaseManagerDidUpdateProducts(_:)` | Called when the product list is refreshed. |
| `purchaseManager(_:didPurchase:)` | Called with successfully purchased `SKPaymentTransaction` objects. |
| `purchaseManager(_:didFailPurchasing:)` | Called with failed transactions. |
| `purchaseManager(_:didRestore:)` | *(optional)* Called after a successful restore. |
| `purchaseManager(_:didFailRestoring:)` | *(optional)* Called when restore fails. |
| `purchaseManager(_:didRemove:)` | *(optional)* Called when transactions are removed from the queue. |
| `purchaseManagerDidAskApplicatonUserName(_:)` | *(optional)* Return a value to set `SKMutablePayment.applicationUsername`. |
| `purchaseManager(_:shouldAdd:for:)` | *(optional)* Controls whether a promoted IAP (iOS 11+) should proceed. |

---

### `KKReceiptsStorage`

A local receipt cache backed by `UserDefaults` (with optional iCloud sync via
`NSUbiquitousKeyValueStore`). Each receipt is represented by a `KKReceipt` object
that stores the transaction ID, product ID, raw receipt data, and purchase dates.

#### `KKReceipt` properties

| Property | Type | Description |
|----------|------|-------------|
| `transactionID` | `String` | The StoreKit transaction identifier. |
| `originalTransactionID` | `String` | The original transaction identifier (useful for renewals). |
| `productID` | `String` | The IAP product identifier. |
| `receipt` | `Data` | The raw receipt data for this transaction. |
| `purchaseDate` | `Date` | When the purchase was made. |
| `originalPurchaseDate` | `Date?` | The date of the original purchase (subscriptions). |
| `receivedDate` | `Date` | When the receipt was recorded locally. |
| `isConsumed` | `Bool` | Whether the receipt has been uploaded / processed. |

#### `KKReceiptsStorage` key methods

```swift
let storage = KKReceiptsStorage()

// Add new receipts (duplicates filtered by transactionID)
storage.add(receipts: newReceipts)

// Access all receipts, or only unprocessed ones
storage.allReceipts
storage.allReceiptsNotUploadedYet  // receipts where isConsumed == false

// Mark receipts as processed
storage.markReceiptsAsConsumed(with: transactionIDSet)

// Remove stale receipts
storage.removeReceipts(purchasedBefore: someDate)
storage.removeAllReceipts()

// iCloud sync
storage.copyToICloud()
storage.copyToICloud(receipts: specificReceipts)
```

---

### StoreKit Extensions

#### `SKProductSubscriptionPeriod` (iOS/macOS/tvOS 11.2+)

Adds `localizedDescription` and `localizedDescription(with:)` to produce a
human-readable subscription period string (e.g. "1 month", "3 months") using
`DateComponentsFormatter`.

#### `SKProductDiscount` (iOS/macOS/tvOS 11.2+)

Adds `localizedPrice` to format the discount price according to the product's
`priceLocale` using `NumberFormatter`.

## License

Apache 2.0 – see [LICENSE.txt](LICENSE.txt).
