#if canImport(StoreKit) && canImport(SwiftUI)
import Foundation
import StoreKit
import SwiftUI

/// SwiftUI has a `Transaction` too -- the animation-context one -- so the bare
/// name is ambiguous in any file that imports both. Naming the StoreKit type
/// once here keeps the rest of the file readable without qualifying every use.
private typealias StoreTransaction = StoreKit.Transaction

/// The one-off purchase that turns the menu banner off.
///
/// StoreKit is a system framework, so this lives in the package directly under
/// `canImport`, the same way Game Center does. `AdSlot` needs its indirection
/// because the Google SDK is a third-party binary that would stop the package
/// building on Linux; StoreKit simply is not there, and the file compiles to
/// nothing.
///
/// Entitlement is read from StoreKit every launch rather than cached in
/// `UserDefaults`. A local flag is a thing that can be wrong -- stale after a
/// refund, missing on a new device, forgeable on a jailbroken one -- and
/// `currentEntitlements` is already the answer.
@MainActor
@Observable
public final class RemoveAdsStore {
    public static let shared = RemoveAdsStore()

    /// Must match the product ID in App Store Connect exactly. A mismatch does
    /// not error; the product list simply comes back empty.
    public static let productID = "com.killjoy00.goldrush.removeads"

    public private(set) var product: Product?
    public private(set) var isPurchased = false
    public private(set) var isWorking = false
    public private(set) var failure: String?

    private var updates: Task<Void, Never>?

    private init() {}

    /// Reads the entitlement, loads the product, and starts listening.
    ///
    /// The listener matters more than it looks: a purchase can complete when
    /// the app is not the one that started it -- Ask to Buy approved later,
    /// Family Sharing, a restore performed on another device. Without it the
    /// banner would stay until the next launch.
    public func start() async {
        if updates == nil {
            updates = Task { [weak self] in
                for await update in StoreTransaction.updates {
                    await self?.absorb(update)
                }
            }
        }
        await refreshEntitlement()
        await loadProduct()
    }

    public func refreshEntitlement() async {
        var owned = false
        for await entitlement in StoreTransaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            if transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                owned = true
            }
        }
        isPurchased = owned
    }

    private func loadProduct() async {
        do {
            product = try await Product.products(for: [Self.productID]).first
            if product == nil {
                // Nearly always one of two things, and both are configuration
                // rather than code: the Paid Applications agreement is not
                // active, or the product is not approved for this build yet.
                failure = "This purchase isn't available right now."
            }
        } catch {
            failure = error.localizedDescription
        }
    }

    public func purchase() async {
        guard let product, !isWorking else { return }
        isWorking = true
        failure = nil
        defer { isWorking = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                await absorb(verification)
            case .userCancelled:
                break
            case .pending:
                // Ask to Buy. The listener above picks it up when it clears.
                failure = "Waiting for approval. The ads will go once it's approved."
            @unknown default:
                break
            }
        } catch {
            failure = error.localizedDescription
        }
    }

    /// Required by App Review for a non-consumable, and genuinely needed: a
    /// player reinstalling or moving to a new device has already paid.
    public func restore() async {
        guard !isWorking else { return }
        isWorking = true
        failure = nil
        defer { isWorking = false }
        do {
            try await AppStore.sync()
            await refreshEntitlement()
            if !isPurchased {
                failure = "No previous purchase found on this Apple Account."
            }
        } catch {
            failure = error.localizedDescription
        }
    }

    private func absorb(_ result: VerificationResult<StoreTransaction>) async {
        // An unverified transaction is one StoreKit could not authenticate.
        // It is ignored rather than trusted: the cost of being wrong is a
        // player who paid and still sees a banner, which `restore()` fixes,
        // against handing the purchase to anyone who forges a receipt.
        guard case .verified(let transaction) = result else { return }
        if transaction.productID == Self.productID, transaction.revocationDate == nil {
            isPurchased = true
        }
        await transaction.finish()
    }
}

/// The purchase sheet.
public struct RemoveAdsView: View {
    private let store = RemoveAdsStore.shared
    private let onDone: () -> Void

    public init(onDone: @escaping () -> Void) {
        self.onDone = onDone
    }

    /// Whether the buy button should *look* available.
    ///
    /// A capture simulator has no App Store account and, until the product
    /// exists in App Store Connect, nothing to load either -- so the real
    /// sheet there is a greyed button over a red "isn't available" line. That
    /// is the wrong picture to hand a reviewer looking for where the purchase
    /// lives. Only the appearance is overridden; `disabled` still tracks the
    /// real product, so the capture cannot start a purchase. No price is
    /// invented: without a product the button simply reads "Remove ads".
    private var looksAvailable: Bool {
        #if DEBUG
        if ScreenshotMode.isActive { return true }
        #endif
        return store.product != nil
    }

    private var visibleFailure: String? {
        #if DEBUG
        if ScreenshotMode.isActive { return nil }
        #endif
        return store.failure
    }

    public var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "nosign")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.gold)
                .padding(.top, 8)

            Text("Remove ads")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.goldBright)

            Text("A one-time purchase that takes the banner off the menu for good. It stays with your Apple Account, so it follows you to a new device.")
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.parchment.opacity(0.75))
                .padding(.horizontal, 24)

            if let failure = visibleFailure {
                Text(failure)
                    .font(.system(size: 12))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.danger)
                    .padding(.horizontal, 24)
            }

            if store.isPurchased {
                Label("Purchased — thank you", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.gold)
            } else {
                Button {
                    Task { await store.purchase() }
                } label: {
                    Group {
                        if store.isWorking {
                            ProgressView().tint(Theme.dirt)
                        } else {
                            // The price comes from StoreKit, never a literal:
                            // it is already localised, and it is right when
                            // the price changes without a new build.
                            Text(store.product.map { "Remove ads — \($0.displayPrice)" }
                                 ?? "Remove ads")
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(looksAvailable ? Theme.gold : Theme.dirtLight,
                                in: RoundedRectangle(cornerRadius: 13))
                    .foregroundStyle(looksAvailable
                                     ? Theme.dirt : Theme.parchment.opacity(0.5))
                }
                .disabled(store.product == nil || store.isWorking)

                Button {
                    Task { await store.restore() }
                } label: {
                    Text("Restore purchase")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.parchment.opacity(0.8))
                }
                .disabled(store.isWorking)
            }

            Button("Done") { onDone() }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.parchment.opacity(0.55))
                .padding(.top, 2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.top, 26)
        .centredColumn()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .task { await store.start() }
        .onChange(of: store.isPurchased) { _, purchased in
            // Nothing left to do on this screen once it is bought.
            if purchased { onDone() }
        }
    }
}
#endif
