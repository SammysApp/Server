import Vapor

public func sockets(_ socketServer: WebSocketServer) {
    guard let socketServer = socketServer as? NIOWebSocketServer else { return }
    
    let orderSessionController = OrderSessionController.default
    socketServer.get(AppConstants.version, "orderSessions", SocketSession.ID.parameter, use: orderSessionController.add)
}
