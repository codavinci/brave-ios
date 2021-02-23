// Copyright 2020 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import UIKit
import PanModal
import Static
import Shared
import BraveShared
import BraveUI

#if canImport(SwiftUI)
import SwiftUI
#endif

enum MenuButton: Int, CaseIterable {
    case rewards, settings, history, bookmarks, downloads, add, share
    
    var title: String {
        switch self {
        // This string should not be translated.
//        case .shields: return "Brave Shields"
        case .rewards: return "Brave Rewards"
//        case .vpn: return "Brave VPN"
        case .bookmarks: return Strings.bookmarksMenuItem
        case .history: return Strings.historyMenuItem
        case .settings: return Strings.settingsMenuItem
        case .add: return Strings.addToMenuItem
        case .share: return Strings.shareWithMenuItem
        case .downloads: return Strings.downloadsMenuItem
        }
    }
    
    var icon: UIImage {
        switch self {
//        case .shields: return #imageLiteral(resourceName: "settings-shields")
        case .rewards: return #imageLiteral(resourceName: "settings-brave-rewards")
//        case .vpn: return #imageLiteral(resourceName: "vpn_menu_icon").template
        case .bookmarks: return #imageLiteral(resourceName: "menu_bookmarks").template
        case .history: return #imageLiteral(resourceName: "menu-history").template
        case .settings: return #imageLiteral(resourceName: "menu-settings").template
        case .add: return #imageLiteral(resourceName: "menu-add-bookmark").template
        case .share: return #imageLiteral(resourceName: "nav-share").template
        case .downloads: return #imageLiteral(resourceName: "menu-downloads").template
        }
    }
}

@available(iOS 13.0, *)
struct MenuItem: Equatable, Identifiable {
    enum ViewKind {
        /// A default cell which shows a normal button which when pressed can do something
        case button(_ selection: () -> Void)
        /// Displays a custom view which can display and handle its own state
        case custom(_ view: (MenuItem) -> AnyView)
    }
    var id = UUID()
    var icon: UIImage
    var title: String
    var viewKind: ViewKind
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

@available(iOS 13.0, *)
struct TableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle()) // Needed or taps don't activate on empty space
            .background(Color.black.opacity(configuration.isPressed ? 0.1 : 0.0))
    }
}

@available(iOS 13.0, *)
struct MenuItemHeaderView: View {
    var icon: UIImage
    var title: String
    
    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(uiImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(6)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
            Text(verbatim: title)
        }
        .foregroundColor(Color(Theme.of(nil).colors.tints.home))
    }
}

@available(iOS 13.0, *)
struct NewMenuView<Content: View>: View {
    var content: Content
    
    var body: some View {
        ScrollView(.vertical) {
            content
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
        }
    }
}

@available(iOS 13.0, *)
struct MenuItemButton: View {
    var icon: UIImage
    var title: String
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            MenuItemHeaderView(icon: icon, title: title)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 48.0, alignment: .leading)
        }
        .buttonStyle(TableButtonStyle())
        .accentColor(Color(Theme.of(nil).colors.tints.home))
    }
}

@available(iOS 13.0, *)
struct VPNView: View {
    var icon: UIImage
    var title: String
    var vpnProductInfo: VPNProductInfo
    var displayVPNDestination: (UIViewController) -> Void
    
    @State private var isVPNStatusChanging: Bool = BraveVPN.reconnectPending
    @State private var isErrorShowing: Bool = false
    
    private var isVPNEnabled: Binding<Bool> {
        Binding(
            get: { BraveVPN.isConnected },
            set: { toggleVPN($0) }
        )
    }
    
    private func toggleVPN(_ enabled: Bool) {
        let vpnState = BraveVPN.vpnState
        
        if !VPNProductInfo.isComplete {
            isErrorShowing = true
            // Reattempt to connect to the App Store to get VPN prices.
            vpnProductInfo.load()
            return
        }
        isVPNStatusChanging = true
        switch BraveVPN.vpnState {
        case .notPurchased, .purchased, .expired:
            guard let vc = vpnState.enableVPNDestinationVC else { return }
            displayVPNDestination(vc)
        case .installed:
            // Do not modify UISwitch state here, update it based on vpn status observer.
            enabled ? BraveVPN.reconnect() : BraveVPN.disconnect()
        }
    }
    
    var body: some View {
        Button(action: { toggleVPN(!BraveVPN.isConnected) }) {
            HStack {
                MenuItemHeaderView(icon: icon, title: title)
                Spacer()
                if isVPNStatusChanging {
                    Text("Loading")
                }
                Toggle("", isOn: isVPNEnabled)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 48.0, alignment: .leading)
        }
        .buttonStyle(TableButtonStyle())
        .alert(isPresented: $isErrorShowing) {
            Alert(
                title: Text(verbatim: Strings.VPN.errorCantGetPricesTitle),
                message: Text(verbatim: Strings.VPN.errorCantGetPricesBody),
                dismissButton: .default(Text(verbatim: Strings.OKString))
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .NEVPNStatusDidChange)) { _ in
            isVPNStatusChanging = false
        }
    }
}

@available(iOS 13.0, *)
class NewMenuController: UINavigationController, PanModalPresentable {
    
    private var menuNavigationDelegate: MenuNavigationControllerDelegate?
    
    init<MenuContent: View>(@ViewBuilder content: (NewMenuController) -> MenuContent) {
        super.init(nibName: nil, bundle: nil)
        viewControllers = [NewMenuHostingController(content: { content(self) })]
        menuNavigationDelegate = MenuNavigationControllerDelegate(panModal: self)
    }
    
    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError()
    }
    
    func presentInnerMenu(_ viewController: UIViewController, expandToLongForm: Bool = true) {
        let container = NewMenuNavigationController(rootViewController: viewController)
        container.delegate = menuNavigationDelegate
        container.modalPresentationStyle = .overCurrentContext // over to fix the dismiss animation
        container.viewWillDisappear = {
            if !self.isDismissing {
                self.panModalSetNeedsLayoutUpdate()
                //                self.panModalTransition(to: .shortForm)
            }
        }
        present(container, animated: true) {
            self.panModalSetNeedsLayoutUpdate()
        }
        if expandToLongForm {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.panModalTransition(to: .longForm)
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationBar.isTranslucent = false
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }
    
    private var isDismissing: Bool = false
    
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        if let _ = presentedViewController as? NewMenuNavigationController,
           presentingViewController?.presentedViewController === self {
            isDismissing = true
            presentingViewController?.dismiss(animated: flag, completion: completion)
        } else {
            super.dismiss(animated: flag, completion: completion)
        }
    }
    
    private var isPresentingInnerMenu: Bool {
        if let _ = presentedViewController as? NewMenuNavigationController {
            return true
        }
        return false
    }
    
    var panScrollable: UIScrollView? {
        // For SwiftUI:
        //  - in iOS 13, ScrollView will exist within a host view
        //  - in iOS 14, it will be a direct subview
        // For UIKit:
        //  - UITableViewController's view is a UITableView, thus the view itself is a UIScrollView
        //  - For our non-UITVC's, the scroll view is a usually a subview of the main view
        func _scrollViewChild(in parentView: UIView, depth: Int = 0) -> UIScrollView? {
            if depth > 2 { return nil }
            if let scrollView = parentView as? UIScrollView {
                return scrollView
            }
            for view in parentView.subviews {
                if let scrollView = view as? UIScrollView {
                    return scrollView
                }
                if !view.subviews.isEmpty, let childScrollView = _scrollViewChild(in: view, depth: depth + 1) {
                    return childScrollView
                }
            }
            return nil
        }
        if let vc = presentedViewController, !vc.isBeingPresented {
            if let nc = vc as? UINavigationController, let vc = nc.topViewController {
                let scrollView = _scrollViewChild(in: vc.view)
                return scrollView
            }
            let scrollView = _scrollViewChild(in: vc.view)
            return scrollView
        }
        guard let topVC = topViewController else { return nil }
        topVC.view.layoutIfNeeded()
        return _scrollViewChild(in: topVC.view)
    }
    var longFormHeight: PanModalHeight {
        .maxHeight
    }
    var shortFormHeight: PanModalHeight {
        isPresentingInnerMenu ? .maxHeight : .contentHeight(320)
    }
    var allowsExtendedPanScrolling: Bool {
        true
    }
    var cornerRadius: CGFloat {
        10.0
    }
    var anchorModalToLongForm: Bool {
        isPresentingInnerMenu
    }
    var panModalBackgroundColor: UIColor {
        UIColor(white: 0.0, alpha: 0.5)
    }
    var dragIndicatorBackgroundColor: UIColor {
        UIColor(white: 0.95, alpha: 1.0)
    }
    var transitionDuration: Double {
        0.35
    }
    var springDamping: CGFloat {
        0.85
    }
}

@available(iOS 13.0, *)
class NewMenuHostingController<MenuContent: View>: UIHostingController<NewMenuView<MenuContent>> {
    
    init(@ViewBuilder content: () -> MenuContent) {
        super.init(rootView: NewMenuView(content: content()))
    }
    
    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        view.backgroundColor = Theme.of(nil).colors.home
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
}

private class MenuNavigationControllerDelegate: NSObject, UINavigationControllerDelegate {
    weak var panModal: (UIViewController & PanModalPresentable)?
    init(panModal: UIViewController & PanModalPresentable) {
        self.panModal = panModal
        super.init()
    }
    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        panModal?.panModalSetNeedsLayoutUpdate()
    }
}

class NewMenuNavigationController: UINavigationController {
    var viewWillDisappear: (() -> Void)?
    
    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        viewController.navigationItem.rightBarButtonItem = .init(barButtonSystemItem: .done, target: self, action: #selector(tappedDone))
        super.pushViewController(viewController, animated: animated)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Needed or else pan modal top scroll insets are messed up for some reason
        navigationBar.isTranslucent = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewWillDisappear?()
    }

    @objc private func tappedDone() {
        dismiss(animated: true) { [viewWillDisappear] in
            viewWillDisappear?()
        }
    }
}
