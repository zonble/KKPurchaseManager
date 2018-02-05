import Foundation
#if os(OSX) || os(iOS) || os(tvOS)
import StoreKit

@available(OSX 10.13.2, *)
@available(iOS 11.2, *)
@available(tvOS 11.2, *)
extension SKProductDiscount {

	/// The localized price of a SKProductDiscount object.
	var localizedPrice: String? {
		get {
			let formatter = NumberFormatter()
			formatter.numberStyle = .currency
			formatter.locale = self.priceLocale
			return formatter.string(from: self.price)
		}
	}
}

@available(OSX 10.13.2, *)
@available(iOS 11.2, *)
@available(tvOS 11.2, *)
extension SKProductDiscount.PaymentMode {

	/// The localized title for SKProductDiscount.PaymentMode
	var localizedTitle: String {
		switch self {
		case .payAsYouGo:
			return NSLocalizedString("Pay as you go", comment: "Pay as you go")
		case .payUpFront:
			return NSLocalizedString("Pay up front", comment: "Pay up front")
		case .freeTrial:
			return NSLocalizedString("Free trial", comment: "Free trial")
		}
	}
}

#endif
