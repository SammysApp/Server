import Vapor

final class OrderSessionController {
    static var `default` = OrderSessionController()
    
    private var sessions = [SocketSession]()
    
    private init() {}
    
    func send(_ order: PurchasedOrder) throws {
        let data = try JSONEncoder().encode(order)
        sessions.map { $0.socket }.forEach { $0.send(data) }
    }
    
    func add(_ session: SocketSession) { sessions.append(session) }
    
    func add(_ socket: WebSocket, req: Request) throws {
        let id = try req.parameters.next(SocketSession.ID.self)
        add(.init(id: id, socket: socket))
    }
}
