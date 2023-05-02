//
//  CustomVideoPlayer.swift
//  CustomPlayer
//
//  Created by Bilal Durnagöl on 1.05.2023.
//

import SwiftUI
import AVKit

/// Custom View Player
struct CustomVideoPlayer: UIViewControllerRepresentable {
  
    // MARK: - PROPERTIES
    
    var player: AVPlayer
    
    // MARK: - METHOD(s)
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        
    }
}
