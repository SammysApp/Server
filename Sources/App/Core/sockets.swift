import Vapor

public func sockets(_ socketServer: WebSocketServer) {
    guard let socketServer = socketServer as? NIOWebSocketServer else { return }
    
    let sessionController = SessionController.default
    socketServer.get(AppConstants.version, "sessions", SocketSession.ID.parameter, use: sessionController.add)
}
