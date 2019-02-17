import Stripe

extension StripeSource {
    var name: String? {
        if let card = card {
            return card.brand + " " + card.last4
        }
        return nil
    }
}
