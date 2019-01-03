import Vapor
import Stripe

final class StripeController: RouteCollection {
	func boot(router: Router) throws {
		let stripeRoute = router.grouped("stripe")
		stripeRoute.post(CustomerCreateData.self, at: "customers", use: createCustomer)
		stripeRoute.post(ChargeCreateData.self, at: "charges", use: createCharge)
		stripeRoute.post(EphemeralKeyCreateData.self, at: "ephemeral_keys", use: createEphemeralKey)
	}
	
	func stripeClient(_ req: Request) throws -> StripeClient {
		return try req.make(StripeClient.self)
	}
	
	func createCustomer(_ req: Request, data: CustomerCreateData)
		throws -> Future<StripeCustomer> {
		return try stripeClient(req).customer.create(
			email: data.email
		)
	}
	
	func createCharge(_ req: Request, data: ChargeCreateData)
		throws -> Future<StripeCharge> {
		return try stripeClient(req).charge.create(
			amount: data.amount,
			currency: .usd,
			customer: data.customer,
			source: data.source
		)
	}
	
	func createEphemeralKey(_ req: Request, data: EphemeralKeyCreateData)
		throws -> Future<StripeEphemeralKey> {
		return try stripeClient(req).ephemeralKey.create(
			customer: data.customer,
			apiVersion: data.version
		)
	}
}

struct CustomerCreateData: Content {
	let email: String?
}

struct ChargeCreateData: Content {
	/// In cents.
	let amount: Int
	/// Required if provided source requires customer. Will charge customer's default source if no source provided.
	let customer: String?
	let source: String?
}

struct EphemeralKeyCreateData: Content {
	let customer: String
	let version: String?
}
