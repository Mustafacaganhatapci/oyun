import Combine
import Network

/// Ağ durumu. Oyunun HİÇBİR yerinde oynanışı engellemez — Orbeon çevrimdışı
/// tam çalışır. Yalnızca "reklamı görmüyorsun, çünkü bağlantın yok" gibi
/// durumları doğru anlatabilmek için izlenir.
final class Connectivity: ObservableObject {
    static let shared = Connectivity()

    @Published private(set) var isOnline = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "orbeon.connectivity")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            DispatchQueue.main.async {
                guard let self, self.isOnline != online else { return }
                self.isOnline = online
            }
        }
        monitor.start(queue: queue)
    }
}
