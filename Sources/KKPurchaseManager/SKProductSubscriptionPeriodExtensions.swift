import Foundation
import StoreKit

extension SKProductSubscriptionPeriod {

	/// A localized description for a product subscription period.
	@objc var localizedDescription: String? {
		get {
			return self.localizedDescription(with: .full)
		}
	}

	/// A localized description for a product subscription period by a
	/// given unit style.
	///
	/// - Parameter unitStyle: the descrioption in short, or full format.
	/// - Returns: the formatted string.
	@objc func localizedDescription(with unitStyle: DateComponentsFormatter.UnitsStyle) -> String? {
		let formatter = DateComponentsFormatter()
		formatter.unitsStyle = unitStyle
		var components = DateComponents()
		switch self.unit {
		case .day:
			components.day = self.numberOfUnits
		case .week:
			components.day = self.numberOfUnits * 7
		case .month:
			components.month = self.numberOfUnits
		case .year:
			components.year = self.numberOfUnits
		}
		return formatter.string(from: components)
	}
}
