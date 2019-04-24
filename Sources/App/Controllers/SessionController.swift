import Vapor

final class SessionController {
    static var `default` = SessionController()
    
    private var sessions = [SocketSession]()
    
    private init() {}
    
    func send(_ data: Data) throws {
        sessions.map { $0.socket }.forEach { $0.send(data) }
    }
    
    func add(_ session: SocketSession) { sessions.append(session) }
    
    func add(_ socket: WebSocket, req: Request) throws {
        let id = try req.parameters.next(SocketSession.ID.self)
        add(.init(id: id, socket: socket))
    }
}
