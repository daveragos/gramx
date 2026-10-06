import Flutter
import UIKit
import UserNotifications
import app_links

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let launchLinks = LaunchLinkForwarder()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // FlutterAppDelegate passes notification callbacks on to plugins, so
    // flutter_local_notifications can show alerts while the app is open and
    // hear when one is tapped.
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    engineBridge.pluginRegistry.registrar(forPlugin: "LaunchLinkForwarder")?
      .addSceneDelegate(launchLinks)
  }
}

/// Hands the link that launched the app to app_links. It hears links that
/// arrive while the app runs, but a launch link comes with the scene's
/// connection, which it doesn't look at.
final class LaunchLinkForwarder: NSObject, FlutterSceneLifeCycleDelegate {
  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    guard let url = connectionOptions?.urlContexts.first?.url else { return false }
    AppLinks.shared.handleLink(url: url)
    return false
  }
}
