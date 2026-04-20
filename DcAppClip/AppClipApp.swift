import SwiftUI


let appDeeplinkUrl = URL(string: "delta.chat.deeplink://")!
let appstoreUrl = URL(string: "https://apps.apple.com/app/delta-chat/id1459523234")!

@main
struct AppClipApp: App {

    @State private var mainAppInstalled: Bool?
    @State private var inviteLink: String?
    @Environment(\.openURL) var openURL

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 24) {
                Spacer()

                Image("AppIconImage")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(radius: 30, y: 20)

                Text("Delta Chat")
                    .font(.largeTitle)
                    .bold()

                Spacer()

                if mainAppInstalled == true {
                    Text("You have Delta Chat installed, you can remove this App Clip")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                } else if mainAppInstalled == false {
                    if inviteLink != nil {
                        Text("Install Delta Chat to accept this invite link")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }

                    Button(action: {
                        openURL(appstoreUrl)
                    }, label: {
                        Label("Get Delta Chat", systemImage: "arrow.down.circle.fill")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    })
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 50)
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                guard let link = userActivity.webpageURL?.absoluteString else { return }
                UserDefaults(suiteName: "group.chat.delta.ios")?.set(link, forKey: "appClipInviteLink")
                inviteLink = link
                openURL(appDeeplinkUrl) { mainAppInstalled = $0 }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
                    // if the user opened the app clip from the homescreen
                    // this makes sure to open the main app.
                    openURL(appDeeplinkUrl) { mainAppInstalled = $0 }
                }
            }
        }
    }
}
