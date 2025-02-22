//
//  ControlPanelViewController+Ext.swift
//  IVPN iOS app
//  https://github.com/ivpn/ios-app
//
//  Created by Juraj Hilje on 2020-03-02.
//  Copyright (c) 2020 Privatus Limited.
//
//  This file is part of the IVPN iOS app.
//
//  The IVPN iOS app is free software: you can redistribute it and/or
//  modify it under the terms of the GNU General Public License as published by the Free
//  Software Foundation, either version 3 of the License, or (at your option) any later version.
//
//  The IVPN iOS app is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
//  or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
//  details.
//
//  You should have received a copy of the GNU General Public License
//  along with the IVPN iOS app. If not, see <https://www.gnu.org/licenses/>.
//

import Foundation
import JGProgressHUD

// MARK: - UITableViewDelegate -

extension ControlPanelViewController {
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.row == 0 { return 100 }
        if indexPath.row == 1 && Application.shared.settings.connectionProtocol.tunnelType() != .openvpn { return 0 }
        if indexPath.row == 1 { return 44 }
        if indexPath.row == 3 && !UserDefaults.shared.isMultiHop { return 0 }
        if indexPath.row == 4 { return 52 }
        if indexPath.row == 6 && !UserDefaults.shared.networkProtectionEnabled { return 0 }
        if indexPath.row == 8 { return 236 }
        if indexPath.row == 9 { return 0 }

        return 85
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.row == 2 {
            if let topViewController = UIApplication.topViewController() as? MainViewController {
                topViewController.performSegue(withIdentifier: "ControlPanelSelectServer", sender: nil)
                NotificationCenter.default.post(name: Notification.Name.HideConnectToServerPopup, object: nil)
            }
        }
        
        if indexPath.row == 3 {
            if let topViewController = UIApplication.topViewController() as? MainViewController {
                topViewController.performSegue(withIdentifier: "ControlPanelSelectExitServer", sender: nil)
                NotificationCenter.default.post(name: Notification.Name.HideConnectToServerPopup, object: nil)
            }
        }
        
        if indexPath.row == 6 && Application.shared.network.type != NetworkType.none.rawValue {
            selectNetworkTrust(network: Application.shared.network, sourceView: controlPanelView.networkView) { trust in
                if Application.shared.connectionManager.needToReconnect(network: Application.shared.network, newTrust: trust) {
                    self.showReconnectPrompt {
                        self.controlPanelView.networkView.update(trust: trust)
                        Application.shared.connectionManager.reconnect()
                    }
                } else {
                    self.controlPanelView.networkView.update(trust: trust)
                    Application.shared.connectionManager.evaluateConnection(network: Application.shared.network, newTrust: trust)
                }
            }
        }
        
        if indexPath.row == 7 {
            guard evaluateIsLoggedIn() else {
                return
            }
            
            guard evaluateIsServiceActive() else {
                return
            }
            
            guard Application.shared.connectionManager.status.isDisconnected() else {
                showConnectedAlert(message: "To change protocol, please first disconnect", sender: controlPanelView.protocolLabel)
                return
            }
            
            if let topViewController = UIApplication.topViewController() as? MainViewController {
                topViewController.performSegue(withIdentifier: "MainScreenSelectProtocol", sender: nil)
            }
        }
    }
    
}

// MARK: - WGKeyManagerDelegate -

extension ControlPanelViewController {
    
    override func setKeyStart() {
        hud.indicatorView = JGProgressHUDIndeterminateIndicatorView()
        hud.detailTextLabel.text = "Generating new keys..."
        
        if let topViewController = UIApplication.topViewController() {
            hud.show(in: topViewController.view)
        }
    }
    
    override func setKeySuccess() {
        hud.dismiss()
        connectionExecute()
    }
    
    override func setKeyFail() {
        hud.dismiss()
        
        if AppKeyManager.isKeyExpired {
            showAlert(title: "Failed to automatically regenerate WireGuard keys", message: "Cannot connect using WireGuard protocol: regenerating WireGuard keys failed. This is likely because of no access to an IVPN API server. You can retry connection, regenerate keys manually from preferences, or select another protocol. Please contact support if this error persists.")
        } else {
            showAlert(title: "Failed to regenerate WireGuard keys", message: "There was a problem generating and uploading WireGuard keys to IVPN server.")
        }
    }
    
}

// MARK: - ServerViewControllerDelegate -

extension ControlPanelViewController: ServerViewControllerDelegate {
    
    func reconnectToFastestServer() {
        if Application.shared.connectionManager.status == .connected {
            needsToReconnect = true
            Application.shared.connectionManager.resetRulesAndDisconnect(reconnectAutomatically: true)
            DispatchQueue.delay(0.5) {
                Pinger.shared.ping()
            }
        }
    }
    
}

// MARK: - SessionManagerDelegate -

extension ControlPanelViewController {
    
    override func createSessionSuccess() {
        connect()
    }
    
    override func createSessionServiceNotActive() {
        connect()
    }
    
    override func createSessionTooManySessions(error: Any?) {
        if let error = error as? ErrorResultSessionNew {
            if let data = error.data {
                if data.upgradable {
                    NotificationCenter.default.addObserver(self, selector: #selector(newSession), name: Notification.Name.NewSession, object: nil)
                    NotificationCenter.default.addObserver(self, selector: #selector(forceNewSession), name: Notification.Name.ForceNewSession, object: nil)
                    UserDefaults.shared.set(data.limit, forKey: UserDefaults.Key.sessionsLimit)
                    UserDefaults.shared.set(data.upgradeToUrl, forKey: UserDefaults.Key.upgradeToUrl)
                    present(NavigationManager.getUpgradePlanViewController(), animated: true, completion: nil)
                    return
                }
            }
        }
        
        showCreateSessionAlert(message: "You've reached the maximum number of connected devices")
    }
    
    override func createSessionAuthenticationError() {
        logOut(deleteSession: false)
        present(NavigationManager.getLoginViewController(), animated: true)
    }
    
    override func createSessionFailure(error: Any?) {
        if let error = error as? ErrorResultSessionNew {
            showErrorAlert(title: "Error", message: error.message)
        }
        updateStatus(vpnStatus: Application.shared.connectionManager.status)
    }
    
    override func sessionStatusNotFound() {
        guard !UserDefaults.standard.bool(forKey: "-UITests") else { return }
        logOut(deleteSession: false)
        present(NavigationManager.getLoginViewController(), animated: true)
    }
    
    override func deleteSessionStart() {
        hud.indicatorView = JGProgressHUDIndeterminateIndicatorView()
        hud.detailTextLabel.text = "Deleting active session..."
        
        if let topViewController = UIApplication.topViewController() {
            hud.show(in: topViewController.view)
        }
    }
    
    override func deleteSessionSuccess() {
        hud.delegate = self as? JGProgressHUDDelegate
        hud.dismiss()
    }
    
    override func deleteSessionFailure() {
        hud.delegate = self as? JGProgressHUDDelegate
        hud.indicatorView = JGProgressHUDErrorIndicatorView()
        hud.detailTextLabel.text = "There was an error deleting session"
        
        if let topViewController = UIApplication.topViewController() {
            hud.show(in: topViewController.view)
        }
        
        hud.dismiss(afterDelay: 2)
    }
    
    override func deleteSessionSkip() {
        present(NavigationManager.getLoginViewController(), animated: true)
    }
    
    func showCreateSessionAlert(message: String) {
        showActionSheet(title: message, actions: ["Log out from all other devices", "Try again"], sourceView: self.controlPanelView.connectSwitch) { index in
            switch index {
            case 0:
                self.sessionManager.createSession(force: true)
            case 1:
                self.sessionManager.createSession()
            default:
                break
            }
        }
    }
    
}

// MARK: - UIAdaptivePresentationControllerDelegate -

extension ControlPanelViewController: UIAdaptivePresentationControllerDelegate {
    
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        NotificationCenter.default.removeObserver(self, name: Notification.Name.TermsOfServiceAgreed, object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name.NewSession, object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name.ForceNewSession, object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name.ServiceAuthorized, object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name.SubscriptionActivated, object: nil)
        updateStatus(vpnStatus: Application.shared.connectionManager.status)
    }
    
}
