import Foundation
import TwitchChat

struct Post: Hashable {
    var id: Int
    var user: String
    var message: String
}

final class TwitchChatMobs {
    private var twitchChat: TwitchChat!
    private var model: Model
    private var task: Task<Void, Error>?
    private var id = 0
    private var connected: Bool = false

    init(model: Model) {
        self.model = model
    }

    func isConnected() -> Bool {
        return connected
    }

    func start(channelName: String) {
        task = Task.init {
            var reconnectTime = firstReconnectTime
            logger.info("twitch: chat: \(channelName): Connecting")
            while true {
                twitchChat = TwitchChat(
                    token: "SCHMOOPIIE",
                    nick: "justinfan67420",
                    name: channelName
                )
                do {
                    connected = true
                    for try await message in self.twitchChat.messages {
                        reconnectTime = firstReconnectTime
                        await MainActor.run {
                            if self.model.chatPosts.count > 6 {
                                self.model.chatPosts.removeFirst()
                            }
                            let post = Post(
                                id: self.id,
                                user: message.sender,
                                message: message.text
                            )
                            self.model.chatPosts.append(post)
                            self.model.numberOfChatPosts += 1
                            self.id += 1
                        }
                    }
                } catch {
                    logger.warning("twitch: chat: \(channelName): Got error \(error)")
                }
                connected = false
                logger.info("twitch: chat: \(channelName): Disconnected")
                try await Task.sleep(nanoseconds: UInt64(reconnectTime * 1_000_000_000))
                reconnectTime = nextReconnectTime(reconnectTime)
                logger.info("twitch: chat: \(channelName): Reconnecting")
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
