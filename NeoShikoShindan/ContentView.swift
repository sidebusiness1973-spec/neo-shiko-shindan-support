import SwiftUI
import StoreKit
import Observation
// Neo思考診断。既存の ContentView.swift を丸ごと置き換えて使います。
// プロジェクト作成時の NeoShikoShindanApp.swift は変更しません。
private enum ThoughtAxis: Int, CaseIterable, Identifiable {
    case economy, society, international, governance, change
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .economy: return "経済政策"
        case .society: return "社会と文化"
        case .international: return "国際関係"
        case .governance: return "自由と統治"
        case .change: return "政策の進め方"
        }
    }
    var lowLabel: String {
        switch self {
        case .economy: return "市場の裁量"
        case .society: return "慣習の継承"
        case .international: return "国内の裁量"
        case .governance: return "公共の管理"
        case .change: return "段階的な変更"
        }
    }
    var highLabel: String {
        switch self {
        case .economy: return "再分配"
        case .society: return "制度の更新"
        case .international: return "国際協調"
        case .governance: return "個人の自由"
        case .change: return "迅速な変更"
        }
    }
}
private struct ThoughtQuestion {
    let axis: ThoughtAxis
    let statement: String
    // +1: 同意するほど highLabel 側。-1: 同意するほど lowLabel 側。
    let direction: Int
}
private enum QuizMode: String, Codable {
    case basic, deep
    var questions: [ThoughtQuestion] {
        self == .deep ? QuizContent.deepQuestions : QuizContent.questions
    }
    var title: String { self == .deep ? "じっくり診断" : "無料診断" }
}
private struct ThoughtResult: Identifiable, Codable {
    let id: UUID
    let date: Date
    let scores: [Int]
    // 旧バージョンの履歴には mode がなく、nil を無料診断として扱う。
    let mode: QuizMode?
    var isPremium: Bool { mode == .deep }
    init(scores: [Int], mode: QuizMode) {
        id = UUID()
        date = Date()
        self.scores = scores
        self.mode = mode
    }
    var isValid: Bool {
        scores.count == ThoughtAxis.allCases.count &&
        scores.allSatisfy { (0...100).contains($0) }
    }
}
private struct QuizDraft: Codable {
    let questionIndex: Int
    let answers: [Int]
    // 旧バージョンの下書きも読めるように任意項目にする。
    let mode: QuizMode?
    var selectedMode: QuizMode { mode ?? .basic }
    var isValid: Bool {
        answers.count == selectedMode.questions.count &&
        selectedMode.questions.indices.contains(questionIndex) &&
        answers.allSatisfy { (-1...4).contains($0) }
    }
}
private enum HistoryDateFormatter {
    static let japanese: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter
    }()
}
private enum AppLinks {
    // 公開したプライバシーポリシーの URL を設定してから申請する。
    static let privacyPolicy = URL(string: "https://sidebusiness1973-spec.github.io/neo-shiko-shindan-support/privacy-policy.html")
}
private enum QuizContent {
    static let questions: [ThoughtQuestion] = [
        .init(axis: .economy, statement: "所得の多い人への課税を増やし、公共サービスを充実させたい。", direction: 1),
        .init(axis: .society, statement: "社会制度は、生活様式の変化に合わせて見直すべきだ。", direction: 1),
        .init(axis: .international, statement: "国際的な合意をつくるためなら、国内政策の自由度が多少狭まってもよい。", direction: 1),
        .init(axis: .governance, statement: "公共の安全のため、個人の行動に一定の制限を設けてもよい。", direction: -1),
        .init(axis: .change, statement: "制度の問題が明らかなら、幅広い合意を待つより早く変更したい。", direction: 1),
        .init(axis: .economy, statement: "企業活動への規制は抑え、競争に任せる範囲を広げたい。", direction: -1),
        .init(axis: .society, statement: "長く続いてきた慣習は、変える前にその役割を十分に確かめたい。", direction: -1),
        .init(axis: .international, statement: "国際機関との協調より、国内で決められることを優先したい。", direction: -1),
        .init(axis: .governance, statement: "行政による監視や情報収集は、原則として最小限にとどめたい。", direction: 1),
        .init(axis: .change, statement: "政策は試験導入と検証を重ねて、少しずつ広げたい。", direction: -1),
        .init(axis: .economy, statement: "生活に欠かせない分野では、公的な支援を今より厚くしたい。", direction: 1),
        .init(axis: .society, statement: "家族や働き方に関する法律は、多様な選択に対応できるよう変えたい。", direction: 1),
        .init(axis: .international, statement: "気候変動など国境を越える課題では、各国共通のルールを重視したい。", direction: 1),
        .init(axis: .governance, statement: "不快に感じる意見でも、表現の自由はできるだけ広く守りたい。", direction: 1),
        .init(axis: .change, statement: "大きな制度改革は、影響を確認しながら段階的に進めたい。", direction: -1),
        .init(axis: .economy, statement: "公共サービスを広げるより、税負担を抑えて使い道を個人に任せたい。", direction: -1),
        .init(axis: .society, statement: "新しい価値観を制度に反映する際は、従来の規範との連続性を大切にしたい。", direction: -1),
        .init(axis: .international, statement: "外交では、多国間の枠組みより個別の国益に沿う判断を優先したい。", direction: -1),
        .init(axis: .governance, statement: "社会的な混乱を防ぐためなら、行政の権限を広げることも必要だ。", direction: -1),
        .init(axis: .change, statement: "課題が深刻なら、現行制度を部分修正するより抜本的に変えたい。", direction: 1)
    ]
    // 具体的な場面で、二つの価値をどう選ぶかを考える追加の20問。
    static let extraQuestions: [ThoughtQuestion] = [
        .init(axis: .economy, statement: "物価が上がり財源も限られるなら、一律の減税より、困っている世帯への支援を優先したい。", direction: 1),
        .init(axis: .society, statement: "新しい働き方が広がるなら、従来の雇用制度を守るより、多様な働き方に合う制度へ改めたい。", direction: 1),
        .init(axis: .international, statement: "環境対策で自国企業の負担が増えても、各国が守る共通の基準をつくりたい。", direction: 1),
        .init(axis: .governance, statement: "安全のための監視策でも、効果が明確でなければ個人の行動を記録すべきではない。", direction: 1),
        .init(axis: .change, statement: "制度の欠点が確認できたら、十分な試験期間を待たずに全国へ変更を広げたい。", direction: 1),
        .init(axis: .economy, statement: "地域の商店を元気にするなら、補助金を増やすより、新しい店が参入しやすい環境を整えたい。", direction: -1),
        .init(axis: .society, statement: "長く続く地域の行事は、参加者が減っても、まず現在の形を残す方法を探したい。", direction: -1),
        .init(axis: .international, statement: "国際的な取り決めと国内の事情がぶつかるなら、自国で判断できる範囲を広く残したい。", direction: -1),
        .init(axis: .governance, statement: "災害時には、個人の移動の自由より、行政が避難や立ち入りを統一して管理することを重視したい。", direction: -1),
        .init(axis: .change, statement: "新制度に期待が集まっていても、影響が読めなければ限られた地域で試してから広げたい。", direction: -1),
        .init(axis: .economy, statement: "子育て支援を広げるなら、各家庭に任せるより、税を使って利用できるサービスを増やしたい。", direction: 1),
        .init(axis: .society, statement: "家族の形が変わっているなら、従来の規則との違いがあっても、制度の選択肢を増やしたい。", direction: 1),
        .init(axis: .international, statement: "感染症のような国境を越える問題では、国内独自の対応より、各国の情報共有と共同対策を優先したい。", direction: 1),
        .init(axis: .governance, statement: "本人の同意がない個人情報の収集は、公共目的でも例外をできるだけ狭くしたい。", direction: 1),
        .init(axis: .change, statement: "効果が見込める改革なら、実施後に改善する前提で早めに始めたい。", direction: 1),
        .init(axis: .economy, statement: "生活費への支援では、政府が使い道を決めるより、各自が自由に使える減税を選びたい。", direction: -1),
        .init(axis: .society, statement: "制度を改めるときは、今の暮らしに合わない面があっても、まず従来の仕組みとのつながりを守りたい。", direction: -1),
        .init(axis: .international, statement: "国際協力を進める場合も、国内の予算の使い方は各国が独自に決めるべきだ。", direction: -1),
        .init(axis: .governance, statement: "大きな事故を防ぐためなら、一定期間は行政による情報収集を広げてもよい。", direction: -1),
        .init(axis: .change, statement: "改革に賛成でも、社会への影響を確かめるまでは実施範囲を小さく保ちたい。", direction: -1)
    ]
    static let deepQuestions = questions + extraQuestions
    static let answerLabels = [
        "強く反対", "やや反対", "どちらともいえない", "やや賛成", "強く賛成"
    ]
    // 回答 0...4 を -2...+2 に変換し、各軸の設問数で 0...100 に換算する。
    static func scores(for answers: [Int], mode: QuizMode) -> [Int]? {
        let questions = mode.questions
        guard answers.count == questions.count,
              answers.allSatisfy({ answerLabels.indices.contains($0) }),
              questions.allSatisfy({ abs($0.direction) == 1 }) else { return nil }
        var totals = Array(repeating: 0, count: ThoughtAxis.allCases.count)
        var counts = Array(repeating: 0, count: ThoughtAxis.allCases.count)
        for (question, answer) in zip(questions, answers) {
            totals[question.axis.rawValue] += (answer - 2) * question.direction
            counts[question.axis.rawValue] += 1
        }
        guard counts.allSatisfy({ $0 > 0 }) else { return nil }
        return totals.indices.map { index in
            let range = 4 * counts[index]
            return Int((Double(totals[index] + 2 * counts[index]) /
                        Double(range) * 100).rounded())
        }
    }
    static func description(for score: Int, axis: ThoughtAxis) -> String {
        if score <= 31 { return axis.lowLabel + "を重視" }
        if score <= 43 { return axis.lowLabel + "をやや重視" }
        if score < 57 { return "両方を考慮" }
        if score < 69 { return axis.highLabel + "をやや重視" }
        return axis.highLabel + "を重視"
    }
    static func headline(for scores: [Int]) -> String {
        guard scores.count == ThoughtAxis.allCases.count else { return "多面的な考え方" }
        guard let axis = mascotAxis(for: scores) else { return "バランスを重視するタイプ" }
        let preference = scores[axis.rawValue] >= 50 ? axis.highLabel : axis.lowLabel
        return preference + "を重視するタイプ"
    }
    static func mascotAxis(for scores: [Int]) -> ThoughtAxis? {
        guard scores.count == ThoughtAxis.allCases.count else { return nil }
        let deviations = scores.map { abs($0 - 50) }
        guard let largest = deviations.max(), largest >= 19,
              let index = deviations.firstIndex(of: largest) else { return nil }
        return ThoughtAxis(rawValue: index)
    }
    static func reflection(for scores: [Int]) -> (summary: String, question: String) {
        guard let axis = mascotAxis(for: scores) else {
            return (
                "\(ThoughtAxis.allCases.count)つの軸の中で、特に一方向へ大きく寄った軸はありません。テーマごとに異なる面を見ている結果です。",
                "場面や条件が変わったとき、一番答えが変わりそうなテーマはどれでしょう？"
            )
        }
        let high = scores[axis.rawValue] >= 50
        switch (axis, high) {
        case (.economy, true):
            return ("今回の回答では、経済政策で再分配を重視する傾向が目立ちました。", "支援を広げるなら、財源と支援対象をどう決めたいですか？")
        case (.economy, false):
            return ("今回の回答では、経済政策で市場の裁量を重視する傾向が目立ちました。", "市場に任せる分野と、公的支援が必要な分野をどう分けたいですか？")
        case (.society, true):
            return ("今回の回答では、社会制度の更新を重視する傾向が目立ちました。", "制度を変えるとき、従来の仕組みのどんな役割を残したいですか？")
        case (.society, false):
            return ("今回の回答では、慣習の継承を重視する傾向が目立ちました。", "慣習を保ちながら、新しい暮らし方にどう対応したいですか？")
        case (.international, true):
            return ("今回の回答では、国際協調を重視する傾向が目立ちました。", "各国で協力するとき、国内で決める余地をどこに残したいですか？")
        case (.international, false):
            return ("今回の回答では、国内の裁量を重視する傾向が目立ちました。", "国境を越える課題では、どこまで共通のルールが必要でしょう？")
        case (.governance, true):
            return ("今回の回答では、個人の自由を重視する傾向が目立ちました。", "公共の安全と個人の自由がぶつかるとき、何を判断基準にしますか？")
        case (.governance, false):
            return ("今回の回答では、公共の管理を重視する傾向が目立ちました。", "安全のための制度にも、どんな権限の歯止めが必要でしょう？")
        case (.change, true):
            return ("今回の回答では、迅速な変更を重視する傾向が目立ちました。", "早く変えるとき、影響を確かめる方法は何がよいでしょう？")
        case (.change, false):
            return ("今回の回答では、段階的な変更を重視する傾向が目立ちました。", "検証を続けながら、急ぐべき課題をどう見分けたいですか？")
        }
    }
    static func deepPrompt(for axis: ThoughtAxis, score: Int) -> String {
        if (44...56).contains(score) {
            return "\(axis.title)は中間に近い結果です。どんな条件なら\(axis.lowLabel)と\(axis.highLabel)のどちらを選びますか？"
        }
        let focus = score > 50 ? axis.highLabel : axis.lowLabel
        let alternative = score > 50 ? axis.lowLabel : axis.highLabel
        return "\(axis.title)では\(focus)を重視しました。\(alternative)を選ぶ人が大切にしている点も考えると、判断は変わりますか？"
    }
    static func focusAxes(for scores: [Int]) -> [ThoughtAxis] {
        guard scores.count == ThoughtAxis.allCases.count else { return [] }
        return Array(ThoughtAxis.allCases.sorted {
            abs(scores[$0.rawValue] - 50) > abs(scores[$1.rawValue] - 50)
        }.prefix(2))
    }
    static func monthlyPrompt(for date: Date = .now) -> String {
        let prompts = [
            "今年、最も変えたい仕組みは何ですか。急ぐ理由も一つ書いてみましょう。",
            "安心のために必要なルールと、自由を狭めすぎるルールの境目はどこですか。",
            "支援を広げるとしたら、何を優先し、その費用をどうまかないますか。",
            "自分と違う考えの人が大切にしているものを一つ挙げてみましょう。",
            "国内の判断と国際協力がぶつかったとき、何を基準に選びますか。",
            "最近考えが変わった話題はありますか。きっかけは何でしたか。",
            "昔から続く仕組みで残したい点と、改めたい点を一つずつ挙げてみましょう。",
            "制度の変更を試すなら、どんな結果を見て次の判断をしますか。",
            "自分が少数派になったときにも守ってほしいルールは何ですか。",
            "公共サービスと個人の選択、どちらを優先したい場面がありますか。",
            "半年で最も関心が変わった分野はどれですか。結果を比べてみましょう。",
            "来年の自分に問い直したいテーマを一つ選び、今の理由を残しましょう。"
        ]
        let month = Calendar.current.component(.month, from: date)
        return prompts[month - 1]
    }
}
@MainActor
@Observable
private final class PremiumSubscription {
    // App Store Connectの自動更新サブスクリプションの製品IDと一致させる。
    static let productID = "com.neoshikoshindan.premium.monthly"

    enum ProductLoadState: Equatable {
        case idle, loading, loaded, empty, invalidProduct
        case failed(String)
    }

    private(set) var product: Product?
    private(set) var productLoadState: ProductLoadState = .idle
    private(set) var isPremium = false
    private(set) var loading = false
    private(set) var purchasePending = false

    func observeUpdates() async {
        for await update in Transaction.updates {
            if case .verified(let transaction) = update,
               transaction.productID == Self.productID {
                await transaction.finish()
            }
            await refreshEntitlement()
        }
    }

    func loadProduct() async throws {
        loading = true
        defer { loading = false }
        product = nil
        productLoadState = .loading
        let bundleID = Bundle.main.bundleIdentifier ?? "nil"
        print("[StoreKit Diagnostic] Product query started. bundleID=\(bundleID), productIDs=[\(Self.productID)]")

        do {
            let products = try await Product.products(for: [Self.productID])
            let receivedIDs = products.map(\.id)
            print("[StoreKit Diagnostic] Product query completed. count=\(products.count), productIDs=\(receivedIDs)")

            guard let loadedProduct = products.first else {
                productLoadState = .empty
                print("[StoreKit Diagnostic] Product query returned an empty array.")
                throw SubscriptionError.productUnavailable
            }

            guard loadedProduct.type == .autoRenewable,
                  loadedProduct.subscription?.subscriptionPeriod.unit == .month,
                  loadedProduct.subscription?.subscriptionPeriod.value == 1 else {
                productLoadState = .invalidProduct
                print("[StoreKit Diagnostic] Product has an unexpected type or subscription period. productID=\(loadedProduct.id), type=\(loadedProduct.type)")
                throw SubscriptionError.productUnavailable
            }

            product = loadedProduct
            print("[StoreKit Diagnostic] displayPrice=\(loadedProduct.displayPrice), price=\(loadedProduct.price), locale=\(loadedProduct.priceFormatStyle.locale)")

            if let storefront = await Storefront.current {
                print("[StoreKit Diagnostic] storefront.id=\(storefront.id), storefront.countryCode=\(storefront.countryCode)")
            } else {
                print("[StoreKit Diagnostic] Storefront.current=nil")
            }

            productLoadState = .loaded
            await refreshEntitlement()
        } catch {
            product = nil
            if productLoadState == .loading {
                productLoadState = .failed(error.localizedDescription)
            }
            print("[StoreKit Diagnostic] Product query failed. errorType=\(String(reflecting: type(of: error))), error=\(String(reflecting: error)), localizedDescription=\(error.localizedDescription)")
            throw error
        }
    }

    func refreshEntitlement() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID,
               transaction.revocationDate == nil,
               !transaction.isUpgraded {
                active = true
            }
        }
        isPremium = active
        if active { purchasePending = false }
    }

    func purchase() async throws -> Bool {
        guard let product else { throw SubscriptionError.productUnavailable }
        let result = try await product.purchase()
        switch result {
        case .success(.verified(let transaction)):
            await transaction.finish()
            await refreshEntitlement()
            return isPremium
        case .success(.unverified(_, _)):
            throw SubscriptionError.unverified
        case .pending:
            purchasePending = true
            return false
        case .userCancelled:
            return false
        @unknown default:
            return false
        }
    }

    func restore() async throws {
        try await AppStore.sync()
        await refreshEntitlement()
    }

    private enum SubscriptionError: LocalizedError {
        case productUnavailable, unverified
        var errorDescription: String? {
            switch self {
            case .productUnavailable: return "商品を読み込めませんでした。App Store Connectの製品IDと接続を確認してください。"
            case .unverified: return "購入を検証できませんでした。時間をおいて再度お試しください。"
            }
        }
    }
}

private struct PremiumPaywallView: View {
    let store: PremiumSubscription
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?
    @State private var processing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("じっくり考える、もう一歩先へ")
                        .font(.largeTitle.bold())
                    Text("無料の20問に、実際の場面で選ぶ20問を追加。40問の診断を何度でも受けられ、二つの注目軸と月ごとの振り返りを確認できます。")
                    Label("無料の20問・保存済みの履歴はそのまま", systemImage: "checkmark.circle")
                    Label("有料版は40問の診断・詳しい読み解き", systemImage: "checkmark.circle")
                    Label("月替わりの問いと、振り返りメモの保存", systemImage: "checkmark.circle")
                    if let product = store.product {
                        Text("月額\(product.displayPrice)・自動更新")
                            .font(.title2.bold())
                        Text("請求金額はAppleの購入確認画面で確かめてください。解約はApple Accountのサブスクリプション管理から行えます。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("有料版を始める") {
                            Task {
                                processing = true
                                defer { processing = false }
                                do {
                                    if try await store.purchase() { dismiss() }
                                } catch { errorMessage = error.localizedDescription }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(processing)
                        if store.purchasePending {
                            Text("購入の承認待ちです。承認後に自動で利用できるようになります。")
                                .font(.footnote)
                        }
                    } else {
                        switch store.productLoadState {
                        case .idle, .loading:
                            Text("価格を読み込み中です。購入はまだできません。")
                                .foregroundStyle(.secondary)
                            if store.loading { ProgressView() }
                        case .empty:
                            Text("商品が見つかりませんでした。時間をおいて再度お試しください。")
                                .foregroundStyle(.secondary)
                        case .invalidProduct:
                            Text("商品の種類または期間を確認できませんでした。")
                                .foregroundStyle(.secondary)
                        case .failed(let message):
                            Text("価格の読み込みに失敗しました。\(message)")
                                .foregroundStyle(.secondary)
                        case .loaded:
                            EmptyView()
                        }
                        Button("価格を再読み込み") {
                            Task { await loadProduct() }
                        }
                    }
                    Button("購入を復元") {
                        Task {
                            processing = true
                            defer { processing = false }
                            do {
                                try await store.restore()
                                if store.isPremium { dismiss() }
                                else { errorMessage = "有効な購入が見つかりませんでした。" }
                            } catch { errorMessage = error.localizedDescription }
                        }
                    }
                    .disabled(processing)
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        Link("サブスクリプションを管理", destination: url)
                    }
                    if let url = AppLinks.privacyPolicy {
                        Link("プライバシーポリシー", destination: url)
                    }
                    if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                        Link("利用規約（Apple標準）", destination: url)
                    }
                }
                .padding(22)
            }
            .navigationTitle("有料版")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .task { await loadProduct() }
        .alert("購入情報を確認できませんでした", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func loadProduct() async {
        do { try await store.loadProduct() }
        catch { errorMessage = error.localizedDescription }
    }
}
private struct ThoughtDogView: View {
    let axis: ThoughtAxis?
    private var accent: Color {
        switch axis {
        case .some(.economy): return .orange
        case .some(.society): return .pink
        case .some(.international): return .cyan
        case .some(.governance): return .indigo
        case .some(.change): return .green
        case nil: return .purple
        }
    }
    private var symbol: String {
        switch axis {
        case .some(.economy): return "chart.bar.fill"
        case .some(.society): return "heart.fill"
        case .some(.international): return "globe.asia.australia.fill"
        case .some(.governance): return "shield.fill"
        case .some(.change): return "sparkles"
        case nil: return "circle.hexagongrid.fill"
        }
    }
    var body: some View {
        ZStack {
            Circle().fill(accent.opacity(0.13)).frame(width: 152, height: 152)
            Ellipse().fill(Color(red: 0.56, green: 0.34, blue: 0.22))
                .frame(width: 42, height: 78).rotationEffect(.degrees(-31)).offset(x: -59, y: -29)
            Ellipse().fill(Color(red: 0.56, green: 0.34, blue: 0.22))
                .frame(width: 42, height: 78).rotationEffect(.degrees(31)).offset(x: 59, y: -29)
            Circle().fill(Color(red: 0.94, green: 0.75, blue: 0.51))
                .frame(width: 116, height: 116).offset(y: 3)
            Ellipse().fill(Color(red: 1, green: 0.89, blue: 0.71))
                .frame(width: 73, height: 53).offset(y: 30)
            eyes.offset(y: -7)
            Ellipse().fill(.brown).frame(width: 19, height: 13).offset(y: 17)
            Path { path in
                path.move(to: CGPoint(x: 14, y: 2))
                if axis == .change || axis == .international {
                    path.addQuadCurve(to: CGPoint(x: 56, y: 2), control: CGPoint(x: 35, y: 37))
                } else if axis == .governance || axis == .economy {
                    path.addQuadCurve(to: CGPoint(x: 56, y: 2), control: CGPoint(x: 35, y: 23))
                } else {
                    path.addQuadCurve(to: CGPoint(x: 56, y: 2), control: CGPoint(x: 35, y: 30))
                }
            }
            .stroke(.brown, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .frame(width: 70, height: 40).offset(y: 30)
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 37, height: 37)
                .background(accent, in: Circle())
                .offset(x: 61, y: -61)
        }
        .frame(width: 180, height: 180)
        .accessibilityHidden(true)
    }
    @ViewBuilder private var eyes: some View {
        if axis == .society {
            HStack(spacing: 29) {
                Capsule().fill(.brown).frame(width: 16, height: 4).rotationEffect(.degrees(14))
                Capsule().fill(.brown).frame(width: 16, height: 4).rotationEffect(.degrees(-14))
            }
        } else if axis == .economy {
            HStack(spacing: 29) {
                Capsule().fill(.brown).frame(width: 16, height: 4)
                Circle().fill(.brown).frame(width: 9, height: 9)
            }
        } else {
            HStack(spacing: 35) {
                Circle().fill(.brown).frame(width: 9, height: 9)
                Circle().fill(.brown).frame(width: 9, height: 9)
            }
        }
    }
}
struct ContentView: View {
    private enum Screen: Equatable { case home, quiz, review, result, history, comparison, about, privacy, monthly }
    private enum PendingConfirmation {
        case restart
        case delete(UUID)
        case deleteMonthly(String)
    }
    @AppStorage("neo_thought_history_v1") private var storedHistory = ""
    @AppStorage("neo_thought_draft_v1") private var storedDraft = ""
    @AppStorage("neo_thought_monthly_notes_v1") private var storedMonthlyNotes = ""
    @State private var subscription = PremiumSubscription()
    @State private var screen: Screen = .home
    @State private var questionIndex = 0
    @State private var answers = Array(repeating: -1, count: QuizContent.questions.count)
    @State private var quizMode: QuizMode = .basic
    @State private var requestedMode: QuizMode = .basic
    @State private var showingPaywall = false
    @State private var editingFromReview = false
    @State private var currentResult: ThoughtResult?
    @State private var pendingConfirmation: PendingConfirmation?
    @State private var comparisonFirstID = UUID()
    @State private var comparisonSecondID = UUID()
    @State private var showingSaveError = false
    @State private var monthlyText = ""
    private var showingConfirmation: Binding<Bool> {
        Binding(
            get: { pendingConfirmation != nil },
            set: { if !$0 { pendingConfirmation = nil } }
        )
    }
    private var confirmationTitle: String {
        if case .restart = pendingConfirmation { return "最初から診断しますか？" }
        if case .deleteMonthly = pendingConfirmation { return "この月のメモを削除しますか？" }
        return "この診断結果を削除しますか？"
    }
    private var confirmationMessage: String {
        if case .restart = pendingConfirmation {
            return "途中までの回答は消えます。保存済みの診断結果は残ります。"
        }
        return "削除すると元に戻せません。"
    }
    private var decodedHistory: [ThoughtResult]? {
        if storedHistory.isEmpty { return [] }
        guard let data = storedHistory.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([ThoughtResult].self, from: data)
    }
    private var history: [ThoughtResult] {
        (decodedHistory ?? []).filter(\.isValid)
    }
    private var savedDraft: QuizDraft? {
        guard let data = storedDraft.data(using: .utf8),
              let draft = try? JSONDecoder().decode(QuizDraft.self, from: data),
              draft.isValid else { return nil }
        return draft
    }
    private var currentQuestions: [ThoughtQuestion] { quizMode.questions }
    private var monthKey: String {
        let parts = Calendar.current.dateComponents([.year, .month], from: .now)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }
    private var decodedMonthlyNotes: [String: String]? {
        if storedMonthlyNotes.isEmpty { return [:] }
        guard let data = storedMonthlyNotes.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([String: String].self, from: data)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    switch screen {
                    case .home: homeView
                    case .quiz: quizView
                    case .review: reviewView
                    case .result: resultView
                    case .history: historyView
                    case .comparison: comparisonView
                    case .about: aboutView
                    case .privacy: privacyView
                    case .monthly: monthlyView
                    }
                }
                .frame(maxWidth: 620, alignment: .leading)
                .padding(22)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Neo思考診断")
            .toolbar {
                if screen != .home {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("ホーム") { screen = .home }
                    }
                }
            }
        }
        .tint(.indigo)
        .task { await subscription.refreshEntitlement() }
        .task { await subscription.observeUpdates() }
        .sheet(isPresented: $showingPaywall) {
            PremiumPaywallView(store: subscription)
        }
        .alert(confirmationTitle, isPresented: showingConfirmation) {
            if let pendingConfirmation {
                switch pendingConfirmation {
                case .restart:
                    Button("最初から診断する", role: .destructive) {
                        startQuiz(mode: requestedMode)
                        self.pendingConfirmation = nil
                    }
                case .delete(let id):
                    Button("削除", role: .destructive) {
                        deleteResult(id: id)
                        self.pendingConfirmation = nil
                    }
                case .deleteMonthly(let key):
                    Button("削除", role: .destructive) {
                        deleteMonthlyNote(for: key)
                        self.pendingConfirmation = nil
                    }
                }
            }
            Button("キャンセル", role: .cancel) {
                pendingConfirmation = nil
            }
        } message: {
            Text(confirmationMessage)
        }
        .alert("保存できませんでした", isPresented: $showingSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("データを安全に読み書きできませんでした。保存データと端末の空き容量を確認してください。")
        }
    }
    private var homeView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "circle.hexagongrid.fill")
                .font(.system(size: 55))
                .foregroundStyle(.indigo)
            Text("あなたの考えを、\(ThoughtAxis.allCases.count)つの軸から見てみよう")
                .font(.largeTitle.bold())
            Text("経済・社会・国際関係・自由と統治・政策の進め方。\(QuizContent.questions.count)問への回答から、各分野で何を重視するかを表示します。")
                .foregroundStyle(.secondary)
            if let draft = savedDraft {
                Button(action: resumeQuiz) {
                    Text("\(draft.selectedMode.title)の続き（質問 \(draft.questionIndex + 1) / \(draft.selectedMode.questions.count)）")
                        .frame(maxWidth: .infinity)
                        .padding(8)
                }
                .buttonStyle(.borderedProminent)
                Button("無料診断を最初から始める", action: requestNewQuiz)
            } else {
                Button(action: startQuiz) {
                    Text("無料で診断する（約5分）")
                        .frame(maxWidth: .infinity)
                        .padding(8)
                }
                .buttonStyle(.borderedProminent)
            }
            VStack(alignment: .leading, spacing: 9) {
                Label("もっと深く考えたい方へ", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(.indigo)
                Text("場面を選ぶ追加20問、40問のじっくり診断、二つの注目軸、月替わりの問いとメモ。")
                if subscription.isPremium {
                    Button("じっくり診断を始める（40問）", action: requestDeepQuiz)
                        .buttonStyle(.borderedProminent)
                    Button("今月の振り返りを記録する", action: openMonthly)
                } else {
                    Button("有料版の内容を見る") { showingPaywall = true }
                        .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(15)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            if !history.isEmpty {
                Button("過去の結果を見る（\(history.count)件）") {
                    screen = .history
                }
                .frame(maxWidth: .infinity)
            }
            Button {
                screen = .about
            } label: {
                Label("診断のしくみとデータの保存", systemImage: "info.circle")
            }
            Button("プライバシーポリシー") { screen = .privacy }
            Text("診断結果はこの端末内に保存されます。結果は考えを整理するための目安で、政治的立場や投票先を決めるものではありません。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
    private var aboutView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("診断のしくみ")
                .font(.largeTitle.bold())
            Text("無料版は\(QuizContent.questions.count)問。有料版は場面を考える\(QuizContent.extraQuestions.count)問を加えた\(QuizContent.deepQuestions.count)問を、\(ThoughtAxis.allCases.count)つの軸に分けて表示します。")
            ForEach(ThoughtAxis.allCases) { axis in
                VStack(alignment: .leading, spacing: 7) {
                    Text(axis.title).font(.headline)
                    Text("無料：\(QuizContent.questions.filter { $0.axis == axis }.count)問・有料：\(QuizContent.deepQuestions.filter { $0.axis == axis }.count)問")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(axis.lowLabel)　←　50　→　\(axis.highLabel)")
                        .font(.subheadline)
                    Text("数字が高いほど右側の考えを、低いほど左側の考えを重視する目安です。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(15)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            }
            Text("点数の見方")
                .font(.headline)
            Text("回答は「強く反対」から「強く賛成」までの\(QuizContent.answerLabels.count)段階です。設問の向きをそろえて各軸の回答を合計し、その軸の設問数に応じて０〜100に換算します。50が中間です。犬の表情とタイプ名は、50からの差が最も大きい軸を手がかりにした演出です。")
            Text("保存と共有")
                .font(.headline)
            Text("回答の途中経過と完成した結果は、この端末内に保存されます。結果は履歴から１件ずつ削除できます。共有ボタンを押した場合だけ、共有先を選ぶ画面が開きます。")
            Text("有料版の月替わりメモも端末内に保存され、月ごとに削除できます。購入状況はAppleのStoreKitを通じて確認します。")
            if let privacyPolicy = AppLinks.privacyPolicy {
                Link("プライバシーポリシー", destination: privacyPolicy)
            }
            Text("この診断は考えを整理するための簡易的な目安です。政治的立場や投票先を判定するものではありません。")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("ホームに戻る") { screen = .home }
        }
    }
    private var privacyView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("プライバシーポリシー")
                .font(.largeTitle.bold())
            Text("回答の途中経過と診断結果は、この端末内に保存します。回答を再開し、履歴を表示・比較するために使用します。")
            Text("アプリ自体は回答、結果、振り返りメモを開発者のサーバーへ送信しません。広告や解析用の追跡機能はありません。有料版の購入はAppleの仕組みで処理し、アプリでは購入の有効状態を確認します。共有ボタンを押したときだけiOSの共有画面が開きます。共有後の取り扱いは選んだ共有先に従います。")
            Text("履歴は「過去の結果」から１件ずつ削除できます。途中経過は新しい診断の開始時に上書きされ、結果を保存すると削除されます。")
            Text("有料版の月ごとの振り返りメモも端末内に保存します。サブスクリプションを解約してもデータは保持します。")
            if let privacyPolicy = AppLinks.privacyPolicy {
                Link("公開中のプライバシーポリシーを開く", destination: privacyPolicy)
            }
            Button("ホームに戻る") { screen = .home }
        }
    }
    private var monthlyView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("月ごとの振り返り")
                .font(.largeTitle.bold())
            if subscription.isPremium {
                Text("\(monthKey) の問い")
                    .font(.headline)
                Text(QuizContent.monthlyPrompt())
                    .font(.title3)
                TextField("今の考えをメモする", text: $monthlyText, axis: .vertical)
                    .lineLimit(4...8)
                    .textFieldStyle(.roundedBorder)
                Text("メモは1000文字まで保存します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("今月のメモを保存") { saveMonthlyNote() }
                    .buttonStyle(.borderedProminent)
                    .disabled(monthlyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Text("過去のメモ")
                    .font(.headline)
                if let notes = decodedMonthlyNotes {
                    ForEach(notes.keys.sorted(by: >), id: \.self) { key in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(key).font(.headline)
                                Spacer()
                                Button("削除", role: .destructive) {
                                    pendingConfirmation = .deleteMonthly(key)
                                }
                            }
                            Text(notes[key] ?? "")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            } else {
                Text("月ごとの振り返りは有料版で利用できます。保存済みのメモは保持されています。")
                Button("有料版の内容を見る") { showingPaywall = true }
            }
            Button("ホームに戻る") { screen = .home }
        }
    }
    private var quizView: some View {
        let question = currentQuestions[questionIndex]
        return VStack(alignment: .leading, spacing: 20) {
            Text("\(quizMode.title)・質問 \(questionIndex + 1) / \(currentQuestions.count)")
                .font(.headline)
                .foregroundStyle(.indigo)
            ProgressView(value: Double(questionIndex + 1),
                         total: Double(currentQuestions.count))
            Text(question.axis.title)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            Text(question.statement)
                .font(.title2.bold())
                .padding(.vertical, 12)
            ForEach(QuizContent.answerLabels.indices, id: \.self) { index in
                Button {
                    answers[questionIndex] = index
                    saveDraft()
                } label: {
                    HStack {
                        Text(QuizContent.answerLabels[index])
                        Spacer()
                        if answers[questionIndex] == index {
                            Image(systemName: "checkmark.circle.fill")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(10)
                }
                .buttonStyle(.bordered)
                .tint(answers[questionIndex] == index ? .indigo : .gray)
            }
            HStack {
                if questionIndex > 0 {
                    Button("前の質問") {
                        questionIndex -= 1
                        saveDraft()
                    }
                }
                Spacer()
                Button(editingFromReview ? "確認画面に戻る" :
                       questionIndex == currentQuestions.count - 1 ? "回答を確認する" : "次へ") {
                    if editingFromReview || questionIndex == currentQuestions.count - 1 {
                        editingFromReview = false
                        screen = .review
                    } else {
                        questionIndex += 1
                        saveDraft()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(answers[questionIndex] == -1)
            }
            .padding(.top, 10)
        }
    }
    private var reviewView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("回答の確認")
                .font(.largeTitle.bold())
            Text("\(quizMode.title)・\(currentQuestions.count)問")
                .foregroundStyle(.indigo)
            Text("回答を確認してから結果を保存します。変更したい質問を選んでください。")
                .foregroundStyle(.secondary)
            ForEach(currentQuestions.indices, id: \.self) { index in
                let question = currentQuestions[index]
                Button {
                    questionIndex = index
                    editingFromReview = true
                    saveDraft()
                    screen = .quiz
                } label: {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("質問 \(index + 1)・\(question.axis.title)")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(question.statement)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        HStack {
                            Text(answers.indices.contains(index) && (0...4).contains(answers[index])
                                 ? QuizContent.answerLabels[answers[index]] : "未回答")
                                .font(.headline)
                            Spacer()
                            Image(systemName: "pencil")
                        }
                        .foregroundStyle(.indigo)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(15)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("質問 \(index + 1)、\(question.statement)、回答を変更")
            }
            Button {
                finishQuiz()
            } label: {
                Text("結果を保存して見る")
                    .frame(maxWidth: .infinity)
                    .padding(8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(answers.count != currentQuestions.count ||
                      !answers.allSatisfy { (0...4).contains($0) })
        }
    }
    private var resultView: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let result = currentResult, result.isValid {
                Text(result.isPremium ? "じっくり診断の結果・40問" : "無料診断の結果・20問")
                    .font(.headline)
                    .foregroundStyle(.indigo)
                Text(QuizContent.headline(for: result.scores))
                    .font(.largeTitle.bold())
                VStack(spacing: 4) {
                    ThoughtDogView(axis: QuizContent.mascotAxis(for: result.scores))
                    Text(QuizContent.mascotAxis(for: result.scores).map { "\($0.title)に注目するワンコ" } ?? "バランスを考えるワンコ")
                        .font(.headline)
                    Text("表情は診断を楽しむための演出です。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                VStack(alignment: .leading, spacing: 10) {
                    Label("結果の読み解き", systemImage: "lightbulb")
                        .font(.headline)
                        .foregroundStyle(.indigo)
                    Text(QuizContent.reflection(for: result.scores).summary)
                    Text("考えるヒント")
                        .font(.subheadline.bold())
                    Text(QuizContent.reflection(for: result.scores).question)
                        .foregroundStyle(.secondary)
                    Text("これは今回の回答から見える一面です。\(ThoughtAxis.allCases.count)つの軸を合わせてご覧ください。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                if result.isPremium {
                    if subscription.isPremium {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("二つの注目軸を深掘り", systemImage: "sparkles")
                                .font(.headline)
                                .foregroundStyle(.indigo)
                            ForEach(QuizContent.focusAxes(for: result.scores)) { axis in
                                Text(QuizContent.deepPrompt(for: axis, score: result.scores[axis.rawValue]))
                            }
                            Text("今月の振り返り")
                                .font(.headline)
                            Text(QuizContent.monthlyPrompt())
                            Button("今月の考えをメモする", action: openMonthly)
                            Text("同じ設問に時間をおいて答えると、考えの変化を見直せます。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                    } else {
                        Button("詳しい振り返りを見る") { showingPaywall = true }
                            .buttonStyle(.bordered)
                    }
                } else if !subscription.isPremium {
                    Button("追加20問で考えを深掘りする") { showingPaywall = true }
                        .buttonStyle(.bordered)
                }
                Text("数値は各行の右側にある考えをどの程度重視するかの目安です。50が中間です。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ForEach(ThoughtAxis.allCases) { axis in
                    let score = result.scores[axis.rawValue]
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(axis.title).font(.headline)
                            Spacer()
                            Text("\(score) / 100").monospacedDigit()
                        }
                        ProgressView(value: Double(score), total: 100)
                        HStack {
                            Text(axis.lowLabel)
                            Spacer()
                            Text(axis.highLabel)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        Text(QuizContent.description(for: score, axis: axis))
                            .font(.subheadline)
                    }
                    .padding(15)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                }
                Text("複数の軸で異なる方向を重視することも自然です。設問を変えると結果も変わります。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                ShareLink(item: shareText(for: result)) {
                    Label("結果を共有する", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                Button("無料診断をもう一度", action: requestNewQuiz)
                    .buttonStyle(.borderedProminent)
                if subscription.isPremium {
                    Button("じっくり診断を始める", action: requestDeepQuiz)
                        .buttonStyle(.bordered)
                }
                Button("過去の結果を見る") { screen = .history }
            } else {
                Text("表示できる結果がありません。")
                Button("診断を始める", action: requestNewQuiz)
            }
        }
    }
    private var historyView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("過去の結果")
                .font(.largeTitle.bold())
            if history.isEmpty {
                Text("まだ診断結果はありません。")
            }
            if history.count >= 2 {
                Button {
                    let results = history
                    comparisonFirstID = results[results.count - 2].id
                    comparisonSecondID = results[results.count - 1].id
                    screen = .comparison
                } label: {
                    Label("２件の結果を比較する", systemImage: "chart.bar.xaxis")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            ForEach(history.reversed()) { item in
                HStack(spacing: 12) {
                    Button {
                        currentResult = item
                        screen = .result
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(HistoryDateFormatter.japanese.string(from: item.date))
                                .font(.caption)
                            Text(QuizContent.headline(for: item.scores))
                                .font(.headline)
                            Text(item.isPremium ? "じっくり診断・40問" : "無料診断・20問")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    Button {
                        pendingConfirmation = .delete(item.id)
                    } label: {
                        Image(systemName: "trash")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("この診断結果を削除")
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }
    private var comparisonView: some View {
        let results = history
        let first = results.first { $0.id == comparisonFirstID }
        let second = results.first { $0.id == comparisonSecondID }
        return VStack(alignment: .leading, spacing: 18) {
            Text("結果を比較")
                .font(.largeTitle.bold())
            Text("比較元と比較先を選ぶと、\(ThoughtAxis.allCases.count)つの軸の変化を表示します。数値が高いほど各軸の右側にある考えを重視する目安です。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if results.count >= 2 {
                VStack(alignment: .leading, spacing: 12) {
                    Text("比較元").font(.headline)
                    Picker("比較元", selection: $comparisonFirstID) {
                        ForEach(results.reversed()) { item in
                            Text(comparisonLabel(for: item)).tag(item.id)
                        }
                    }
                    .pickerStyle(.menu)
                    Text("比較先").font(.headline)
                    Picker("比較先", selection: $comparisonSecondID) {
                        ForEach(results.reversed()) { item in
                            Text(comparisonLabel(for: item)).tag(item.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            }
            if comparisonFirstID == comparisonSecondID {
                Text("異なる２件を選んでください。")
                    .foregroundStyle(.secondary)
            } else if let first, let second,
                      first.isValid, second.isValid {
                if first.isPremium != second.isPremium {
                    Text("20問と40問では設問数が異なるため、点数の差は参考値です。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Label("比較の見どころ", systemImage: "chart.xyaxis.line")
                        .font(.headline)
                        .foregroundStyle(.indigo)
                    Text(comparisonHighlight(first: first, second: second))
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(15)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                ForEach(ThoughtAxis.allCases) { axis in
                    let before = first.scores[axis.rawValue]
                    let after = second.scores[axis.rawValue]
                    let difference = after - before
                    VStack(alignment: .leading, spacing: 9) {
                        Text(axis.title).font(.headline)
                        HStack {
                            Text("比較元").foregroundStyle(.secondary)
                            Spacer()
                            Text("\(before) / 100").monospacedDigit()
                        }
                        ProgressView(value: Double(before), total: 100)
                            .tint(.gray)
                        HStack {
                            Text("比較先").foregroundStyle(.indigo)
                            Spacer()
                            Text("\(after) / 100").monospacedDigit()
                        }
                        ProgressView(value: Double(after), total: 100)
                            .tint(.indigo)
                        HStack {
                            Text(axis.lowLabel)
                            Spacer()
                            Text(axis.highLabel)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        Text(comparisonDescription(difference: difference, axis: axis))
                            .font(.subheadline.bold())
                    }
                    .padding(15)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                }
                Text("差は回答の違いを示す目安です。考え方の優劣や政治的立場を示すものではありません。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                ShareLink(item: comparisonShareText(first: first, second: second)) {
                    Label("比較結果を共有する", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
            } else {
                Text("比較できる結果がありません。")
                    .foregroundStyle(.secondary)
            }
            Button("過去の結果に戻る") { screen = .history }
        }
    }
    private func comparisonLabel(for result: ThoughtResult) -> String {
        "\(HistoryDateFormatter.japanese.string(from: result.date))・\(result.isPremium ? "40問" : "20問")・\(QuizContent.headline(for: result.scores))"
    }
    private func comparisonDescription(difference: Int, axis: ThoughtAxis) -> String {
        if difference > 0 { return "比較先は＋\(difference)ポイント（\(axis.highLabel)側）" }
        if difference < 0 { return "比較先は\(difference)ポイント（\(axis.lowLabel)側）" }
        return "比較元と比較先は同じ数値です"
    }
    private func comparisonHighlight(first: ThoughtResult, second: ThoughtResult) -> String {
        let differences = ThoughtAxis.allCases.map { axis in
            second.scores[axis.rawValue] - first.scores[axis.rawValue]
        }
        guard let largest = differences.map({ abs($0) }).max(), largest > 0,
              let index = differences.firstIndex(where: { abs($0) == largest }),
              let axis = ThoughtAxis(rawValue: index) else {
            return "\(ThoughtAxis.allCases.count)つの軸はすべて同じ点数でした。"
        }
        let direction = differences[index] > 0 ? axis.highLabel : axis.lowLabel
        return "点数の差が最も大きいのは\(axis.title)です。比較先は\(largest)ポイント、\(direction)側に寄りました。"
    }
    private func comparisonShareText(first: ThoughtResult, second: ThoughtResult) -> String {
        let lines = ThoughtAxis.allCases.map { axis in
            let before = first.scores[axis.rawValue]
            let after = second.scores[axis.rawValue]
            let difference = after - before
            let change = difference > 0 ? "+\(difference)" : "\(difference)"
            return "\(axis.title)：\(before) → \(after)（\(change)ポイント、\(axis.lowLabel) ⇄ \(axis.highLabel)）"
        }
        return ([
            "Neo思考診断・結果の比較",
            "比較元：\(HistoryDateFormatter.japanese.string(from: first.date))（\(first.isPremium ? "40" : "20")問）",
            "比較先：\(HistoryDateFormatter.japanese.string(from: second.date))（\(second.isPremium ? "40" : "20")問）",
            comparisonHighlight(first: first, second: second)
        ] + lines + [
            "数値が高いほど各軸の右側にある考えを重視する目安です。50が中間です。",
            "差は回答の違いを示す目安で、考え方の優劣や政治的立場を示すものではありません。"
        ]).joined(separator: "\n")
    }
    private func requestNewQuiz() {
        requestedMode = .basic
        if savedDraft == nil {
            startQuiz()
        } else {
            pendingConfirmation = .restart
        }
    }
    private func openMonthly() {
        guard subscription.isPremium else {
            showingPaywall = true
            return
        }
        monthlyText = decodedMonthlyNotes?[monthKey] ?? ""
        screen = .monthly
    }
    private func saveMonthlyNote() {
        guard subscription.isPremium, var notes = decodedMonthlyNotes else {
            showingSaveError = true
            return
        }
        let clean = String(monthlyText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1000))
        guard !clean.isEmpty else { return }
        notes[monthKey] = clean
        guard let data = try? JSONEncoder().encode(notes),
              let string = String(data: data, encoding: .utf8) else {
            showingSaveError = true
            return
        }
        storedMonthlyNotes = string
        monthlyText = clean
    }
    private func deleteMonthlyNote(for key: String) {
        guard var notes = decodedMonthlyNotes else {
            showingSaveError = true
            return
        }
        notes.removeValue(forKey: key)
        guard let data = try? JSONEncoder().encode(notes),
              let string = String(data: data, encoding: .utf8) else {
            showingSaveError = true
            return
        }
        storedMonthlyNotes = string
        if key == monthKey { monthlyText = "" }
    }
    private func requestDeepQuiz() {
        guard subscription.isPremium else {
            showingPaywall = true
            return
        }
        requestedMode = .deep
        if savedDraft == nil {
            startQuiz(mode: .deep)
        } else {
            pendingConfirmation = .restart
        }
    }
    private func startQuiz() {
        startQuiz(mode: .basic)
    }
    private func startQuiz(mode: QuizMode) {
        guard mode == .basic || subscription.isPremium else {
            showingPaywall = true
            return
        }
        quizMode = mode
        answers = Array(repeating: -1, count: mode.questions.count)
        questionIndex = 0
        editingFromReview = false
        saveDraft()
        screen = .quiz
    }
    private func resumeQuiz() {
        guard let draft = savedDraft else { return }
        guard draft.selectedMode == .basic || subscription.isPremium else {
            showingPaywall = true
            return
        }
        quizMode = draft.selectedMode
        answers = draft.answers
        questionIndex = draft.questionIndex
        editingFromReview = false
        screen = .quiz
    }
    private func saveDraft() {
        let draft = QuizDraft(questionIndex: questionIndex, answers: answers, mode: quizMode)
        guard let data = try? JSONEncoder().encode(draft),
              let string = String(data: data, encoding: .utf8) else { return }
        storedDraft = string
    }
    private func shareText(for result: ThoughtResult) -> String {
        let lines = ThoughtAxis.allCases.map { axis in
            let score = result.scores[axis.rawValue]
            return "\(axis.title)：\(score) / 100（\(QuizContent.description(for: score, axis: axis))）"
        }
        return ([
            "Neo思考診断の結果",
            result.isPremium ? "じっくり診断・40問" : "無料診断・20問",
            QuizContent.headline(for: result.scores),
            "診断日：\(HistoryDateFormatter.japanese.string(from: result.date))",
            QuizContent.reflection(for: result.scores).summary
        ] + lines + [
            "数値は各行の右側の考えを重視する度合いです。50が中間です。",
            "結果は考えを整理するための目安で、政治的立場や投票先を決めるものではありません。"
        ]).joined(separator: "\n")
    }
    private func finishQuiz() {
        guard quizMode == .basic || subscription.isPremium else {
            showingPaywall = true
            return
        }
        guard answers.count == currentQuestions.count,
              answers.allSatisfy({ (0...4).contains($0) }) else { return }
        guard let scores = QuizContent.scores(for: answers, mode: quizMode) else { return }
        let result = ThoughtResult(scores: scores, mode: quizMode)
        guard let previous = decodedHistory else {
            showingSaveError = true
            return
        }
        var updated = previous
        updated.append(result)
        guard let data = try? JSONEncoder().encode(updated),
              let string = String(data: data, encoding: .utf8) else {
            showingSaveError = true
            return
        }
        storedHistory = string
        currentResult = result
        storedDraft = ""
        screen = .result
    }
    private func deleteResult(id: UUID) {
        guard let previous = decodedHistory else {
            showingSaveError = true
            return
        }
        let updated = previous.filter { $0.id != id }
        guard let data = try? JSONEncoder().encode(updated),
              let string = String(data: data, encoding: .utf8) else { return }
        storedHistory = string
        if currentResult?.id == id {
            currentResult = nil
        }
    }
}
#Preview {
    ContentView()
}
