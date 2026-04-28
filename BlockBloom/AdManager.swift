import GoogleMobileAds
import UIKit

class AdManager: NSObject {
    static let shared = AdManager()

    // Test ID — App Store'a çıkmadan önce gerçek ID ile değiştirilecek
    private let rewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313"

    private var rewardedAd: RewardedAd?
    private var onReward: (() -> Void)?
    private var isLoading = false

    private override init() {
        super.init()
    }

    /// AdMob'u başlat — GameViewController.viewDidLoad'da çağrılır
    static func setup() {
        MobileAds.shared.start()
    }

    /// Rewarded ad'ı ön yükle
    func preload() {
        guard !isLoading, rewardedAd == nil else { return }
        isLoading = true
        RewardedAd.load(with: "ca-app-pub-3940256099942544/1712485313",
                        request: Request()) { [weak self] ad, error in
            self?.isLoading = false
            if let error {
                print("[AdManager] Yükleme hatası: \(error.localizedDescription)")
                return
            }
            self?.rewardedAd = ad
            self?.rewardedAd?.fullScreenContentDelegate = self
            print("[AdManager] Rewarded ad hazır")
        }
    }

    /// Reklamı göster. Ödül alındığında onReward çağrılır.
    func showRewardedAd(from viewController: UIViewController, onReward: @escaping () -> Void) {
        guard let ad = rewardedAd else {
            print("[AdManager] Reklam henüz hazır değil, yükleniyor...")
            preload()
            return
        }
        self.onReward = onReward
        ad.present(from: viewController) { [weak self] in
            self?.onReward?()
            self?.onReward = nil
        }
    }

    var isReady: Bool { rewardedAd != nil }
}

// MARK: - FullScreenContentDelegate
extension AdManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        rewardedAd = nil
        preload()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("[AdManager] Gösterim hatası: \(error)")
        rewardedAd = nil
        preload()
    }
}
