# KKPurchaseManager

> ⚠️ **Note:** This class was written in the 2010 era and uses the legacy StoreKit 1
> APIs (`SKPaymentQueue`, `SKProduct`, etc.). If you are starting a new project,
> Apple's modern [StoreKit 2](https://developer.apple.com/storekit/) (introduced in
> iOS 15 / macOS 12) is strongly recommended instead.

A manager that makes In-App Purchase easier.

A simple wrapper around the legacy StoreKit 1 APIs for In-App Purchase (IAP),
covering product fetching, purchasing, and receipt restoration.
