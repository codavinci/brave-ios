/* This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import Shared
import Data
import BraveShared
import BraveRewards

/// Sometimes during heavy operations we want to prevent user from navigating back, changing screen etc.
protocol NavigationPrevention {
    func enableNavigationPrevention()
    func disableNavigationPrevention()
}

class SyncWelcomeViewController: SyncViewController {
    private var overlayView: UIView?
    
    private var isLoading: Bool = false {
        didSet {
            overlayView?.removeFromSuperview()
            
            // Toggle 'restore' button.
            navigationItem.rightBarButtonItem?.isEnabled = !isLoading
            
            // Prevent dismissing the modal by swipe when migration happens.
            if #available(iOS 13.0, *) {
                navigationController?.isModalInPresentation = isLoading == true
            }
            
            if !isLoading { return }
            
            let overlay = UIView().then {
                $0.backgroundColor = UIColor.black.withAlphaComponent(0.5)
                let activityIndicator = UIActivityIndicatorView().then { indicator in
                    indicator.startAnimating()
                    indicator.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                }
                
                $0.addSubview(activityIndicator)
            }
            
            view.addSubview(overlay)
            overlay.snp.makeConstraints {
                $0.edges.equalToSuperview()
            }
            
            overlayView = overlay
        }
    }
    
    private var syncServiceObserver: BraveSyncServiceObserver?
    private var syncDeviceInfoObserver: BraveSyncDeviceObserver?
    
    lazy var mainStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.distribution = .equalSpacing
        stackView.alignment = .fill
        stackView.spacing = 8
        return stackView
    }()

    lazy var syncImage: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "sync-art"))
        // Shrinking image a bit on smaller devices.
        imageView.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 250), for: .vertical)
        imageView.contentMode = .scaleAspectFit

        return imageView
    }()

    lazy var textStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 4
        return stackView
    }()

    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 20, weight: UIFont.Weight.semibold)
        label.text = Strings.braveSync
        label.textAlignment = .center
        return label
    }()

    lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 15, weight: UIFont.Weight.regular)
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textAlignment = .center
        label.text = Strings.braveSyncWelcome
        label.setContentHuggingPriority(UILayoutPriority(rawValue: 250), for: .horizontal)

        return label
    }()

    lazy var buttonsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 4
        return stackView
    }()

    lazy var newToSyncButton: RoundInterfaceButton = {
        let button = RoundInterfaceButton(type: .roundedRect)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(Strings.newSyncCode, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: UIFont.Weight.bold)
        button.appearanceTextColor = .white
        button.backgroundColor = BraveUX.braveOrange
        button.addTarget(self, action: #selector(newToSyncAction), for: .touchUpInside)

        button.snp.makeConstraints { make in
            make.height.equalTo(50)
        }

        return button
    }()

    lazy var existingUserButton: RoundInterfaceButton = {
        let button = RoundInterfaceButton(type: .roundedRect)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(Strings.scanSyncCode, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: UIFont.Weight.semibold)
        button.setTitleColor(BraveUX.greyH, for: .normal)
        button.addTarget(self, action: #selector(existingUserAction), for: .touchUpInside)
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = Strings.sync

        view.addSubview(mainStackView)
        mainStackView.snp.makeConstraints { make in
            make.top.equalTo(self.view.safeArea.top)
            // This VC doesn't rotate, no need to check for left and right safe area constraints.
            make.left.right.equalTo(self.view).inset(16)
            make.bottom.equalTo(self.view.safeArea.bottom).inset(32)
        }

        // Adding top margin to the image.
        let syncImageStackView = UIStackView(arrangedSubviews: [UIView.spacer(.vertical, amount: 60), syncImage])
        syncImageStackView.axis = .vertical
        mainStackView.addArrangedSubview(syncImageStackView)

        textStackView.addArrangedSubview(titleLabel)
        // Side margins for description text.
        let descriptionStackView = UIStackView(arrangedSubviews: [UIView.spacer(.horizontal, amount: 8),
                                                                  descriptionLabel,
                                                                  UIView.spacer(.horizontal, amount: 8)])

        textStackView.addArrangedSubview(descriptionStackView)
        mainStackView.addArrangedSubview(textStackView)

        buttonsStackView.addArrangedSubview(newToSyncButton)
        buttonsStackView.addArrangedSubview(existingUserButton)
        mainStackView.addArrangedSubview(buttonsStackView)
        
        handleSyncSetupFailure()
    }
    
    /// Sync setup failure is handled here because it can happen from few places in children VCs(new chain, qr code, codewords)
    /// This makes all presented Sync View Controllers to dismiss, cleans up any sync setup and shows user a friendly message.
    private func handleSyncSetupFailure() {
        syncServiceObserver = BraveSyncServiceObserver { [weak self] in
            guard let self = self else { return }
            print("SYNC SERVICE STATUS - In Sync Group: \(BraveSyncAPI.shared.isInSyncGroup)")
            
            //bvc?.present(SyncAlerts.initializationError, animated: true)
            if !BraveSyncAPI.shared.isInSyncGroup {
                self.dismiss(animated: true)

                let bvc = (UIApplication.shared.delegate as? AppDelegate)?.browserViewController

                bvc?.present(SyncAlerts.initializationError, animated: true)
            }
        }
    }
    
    @objc func newToSyncAction() {
        migrationCheck { [weak self] in
            guard let self = self else { return }
            
            let addDevice = SyncSelectDeviceTypeViewController()
            addDevice.syncInitHandler = { (title, type) in
                func pushAddDeviceVC() {
                    guard BraveSyncAPI.shared.isInSyncGroup else {
                        addDevice.disableNavigationPrevention()
                        let alert = UIAlertController(title: Strings.syncUnsuccessful, message: Strings.syncUnableCreateGroup, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: Strings.OKString, style: .default, handler: nil))
                        addDevice.present(alert, animated: true, completion: nil)
                        return
                    }

                    let view = SyncAddDeviceViewController(title: title, type: type)
                    view.doneHandler = self.pushSettings
                    view.navigationItem.hidesBackButton = true
                    self.navigationController?.pushViewController(view, animated: true)
                }
                
                if BraveSyncAPI.shared.isInSyncGroup {
                    pushAddDeviceVC()
                    return
                }

                addDevice.enableNavigationPrevention()
                self.syncDeviceInfoObserver = BraveSyncDeviceObserver {
                    self.syncDeviceInfoObserver = nil
                    pushAddDeviceVC()
                }
                
                BraveSyncAPI.shared.joinSyncGroup(codeWords: BraveSyncAPI.shared.getSyncCode())
                BraveSyncAPI.shared.syncEnabled = true
            }

            self.navigationController?.pushViewController(addDevice, animated: true)
        }
    }
    
    @objc func existingUserAction() {
        migrationCheck { [weak self] in
            guard let self = self else { return }
            
            let pairCamera = SyncPairCameraViewController()
            
            pairCamera.syncHandler = { codeWords in
                pairCamera.enableNavigationPrevention()
                
                self.syncDeviceInfoObserver = BraveSyncDeviceObserver {
                    self.syncDeviceInfoObserver = nil
                    pairCamera.disableNavigationPrevention()
                    self.pushSettings()
                }
     
                BraveSyncAPI.shared.joinSyncGroup(codeWords: codeWords)
                BraveSyncAPI.shared.syncEnabled = true
            }
            
            self.navigationController?.pushViewController(pairCamera, animated: true)
        }
    }
    
    private func migrationCheck(completion: @escaping (() -> Void)) {
        if Preferences.Chromium.migrationBookmarks.value {
            completion()
            return
        }
        
        let alert = UIAlertController(title: Strings.syncV2MigrationTitle,
                                      message: Strings.syncV2MigrationMessage, preferredStyle: .alert)
        
        let okAction = UIAlertAction(title: Strings.syncV2MigrationOKButton, style: .default) { [weak self] _ in
            guard let self = self else { return }
            self.isLoading = true
            
            Migration.braveCoreBookmarksMigrator?.migrate({ [weak self] success in
                guard let self = self else { return }
                self.isLoading = false
                
                if !success {
                    let alert = UIAlertController(title: Strings.syncV2MigrationErrorTitle,
                                                  message: Strings.syncV2MigrationErrorMessage,
                                                  preferredStyle: .alert)
                    
                    let cancelAction = UIAlertAction(title: Strings.OKString, style: .cancel)
                    alert.addAction(cancelAction)
                    
                    self.present(alert, animated: true)
                }
            })
        }
        let cancelAction = UIAlertAction(title: Strings.cancelButtonTitle, style: .cancel)
        
        alert.addAction(okAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    private func pushSettings() {
        let syncSettingsVC = SyncSettingsTableViewController(style: .grouped)
        syncSettingsVC.disableBackButton = true
        navigationController?.pushViewController(syncSettingsVC, animated: true)
    }
}
