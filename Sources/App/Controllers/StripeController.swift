import Vapor
import Stripe

final class StripeController: RouteCollection {
	func boot(router: Router) throws {
		let stripeRoute = router.grouped("stripe")
		stripeRoute.post(CreateCustomerData.self, at: "customers", use: createCustomer)
		stripeRoute.post(CreateChargeData.self, at: "charges", use: createCharge)
		stripeRoute.post(CreateEphemeralKeyData.self, at: "ephemeral_keys", use: createEphemeralKey)
	}
	
	func stripeClient(_ req: Request) throws -> StripeClient {
		return try req.make(StripeClient.self)
	}
	
	func createCustomer(_ req: Request, data: CreateCustomerData)
		throws -> Future<StripeCustomer> {
		return try stripeClient(req).customer.create(
			email: data.email
		)
	}
	
	func createCharge(_ req: Request, data: CreateChargeData)
		throws -> Future<StripeCharge> {
		return try stripeClient(req).charge.create(
			amount: data.amount,
			currency: .usd,
			customer: data.customer,
			source: data.source
		)
	}
	
	func createEphemeralKey(_ req: Request, data: CreateEphemeralKeyData)
		throws -> Future<StripeEphemeralKey> {
		return try stripeClient(req).ephemeralKey.create(
			customer: data.customer,
			apiVersion: data.version
		)
	}
}

struct CreateCustomerData: Content {
	let email: String?
}

struct CreateChargeData: Content {
	/// In cents.
	let amount: Int
	/// Required if provided source requires customer. Will charge customer's default source if no source provided.
	let customer: String?
	let source: String?
}

struct CreateEphemeralKeyData: Content {
	let customer: String
	let version: String?
}
