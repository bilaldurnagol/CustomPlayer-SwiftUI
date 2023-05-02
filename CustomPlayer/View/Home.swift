//
//  Home.swift
//  CustomPlayer
//
//  Created by Bilal Durnagöl on 1.05.2023.
//

import SwiftUI
import AVKit

struct Home: View {
    
    // MARK: - PROPERTIES
    
    var size: CGSize
    var safeArea: EdgeInsets
    @State private var player: AVPlayer? = {
        if let bundle = Bundle.main.path(forResource: "Sample Video", ofType: "mov") {
            return .init(url: URL(filePath: bundle))
        }
        return nil
    }()
    @State private var showPlayerControls: Bool = false
    @State private var isPlaying: Bool = false
    @State private var timeoutTask: DispatchWorkItem?
    @GestureState private var isDragging: Bool = false
    @State private var isFinishedPlaying: Bool = false
    @State private var isSeeking: Bool = false
    @State private var progress: CGFloat = 0.0
    @State private var lastDraggedProgress: CGFloat = 0
    @State private var isObserverAdded: Bool = false
    
    // MARK: - BODY
    var body: some View {
        VStack(spacing: 0) {
            let videoPlayerSize: CGSize = .init(width: size.width, height: size.height / 3.5)
            
            /// custom video player
            ZStack {
                if let player {
                    CustomVideoPlayer(player: player)
                        .overlay {
                            Rectangle()
                                .fill(.black.opacity(0.4))
                                .opacity(showPlayerControls || isDragging ? 1.0 : 0.0)
                            /// Animating Dragging State
                                .animation(.easeInOut(duration: 0.35), value: isDragging)
                                .overlay {
                                    PlayBackControls()
                                }
                        }
                        .overlay(content: {
                            HStack(spacing: 60) {
                                DoubleTapSeek {
                                    /// Seeking 15 sec backward
                                    let seconds = player.currentTime().seconds - 15
                                    player.seek(to: .init(seconds: seconds, preferredTimescale: 1))
                                }
                                
                                DoubleTapSeek(isForward: true) {
                                    /// Seeking 15 sec forward
                                    let seconds = player.currentTime().seconds + 15
                                    player.seek(to: .init(seconds: seconds, preferredTimescale: 1))
                                }
                            }
                        })
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                showPlayerControls.toggle()
                            }
                            
                            /// Timing Out Controls, Only If the Video is Playing
                            if isPlaying {
                                timeoutControls()
                            }
                        }
                        .overlay(alignment: .bottom) {
                            VideoSeekerView(videoPlayerSize)
                        }
                }
              
            }
            .frame(width: videoPlayerSize.width, height: videoPlayerSize.height)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(1...5, id: \.self) { index in
                        GeometryReader {
                            let size = $0.size
                            
                            Image("Thumb \(index)")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: size.width, height: size.height)
                                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        }
                        .frame(height: 220)
                    }
                }
                .padding(.horizontal, 15)
                .padding(.top, 30)
                .padding(.bottom, 15 + safeArea.bottom)
            }
        }
        .padding(.top, safeArea.top)
        .onAppear {
            guard !isObserverAdded else { return }
            /// Adding Observer to update seeker when the video is playing
            player?.addPeriodicTimeObserver(forInterval: .init(seconds: 1, preferredTimescale: 1), queue: .main, using: { time in
                /// Calculating Video Progress
                if let currentPlayerItem = player?.currentItem {
                    let totalDuration = currentPlayerItem.duration.seconds
                    guard let currentDuration = player?.currentTime().seconds else { return }
                    
                    let calculatedProgress = currentDuration / totalDuration
                    
                    if !isSeeking {
                        progress = calculatedProgress
                        lastDraggedProgress = progress
                    }
                    
                    if calculatedProgress == 1 {
                        /// Video Finished Playing
                        isFinishedPlaying = true
                        isPlaying = false
                    }
                }
            })
            isObserverAdded = true
        }
    }
    
    /// Video Seeker View
    @ViewBuilder
    func VideoSeekerView(_ videoSize: CGSize) -> some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(.gray)
            
            Rectangle()
                .fill(.red)
                .frame(width: max(size.width * progress, 0))
        }
        .frame(height: 3.0)
        .overlay(alignment: .leading) {
            Circle()
                .fill(.red)
                .frame(width: 15, height: 15)
                .scaleEffect(showPlayerControls || isDragging ? 1 : 0.001, anchor: progress * size.width > 15 ? .trailing : .leading)
            /// for more dragging space
                .frame(width: 50, height: 50)
                .contentShape(Rectangle())
            /// Moving Along side with gesture progress
                .offset(x: size.width * progress)
                .gesture(DragGesture()
                    .updating($isDragging, body: { _, out, _ in
                        out = true
                    })
                    .onChanged({ value in
                        /// Cancelling Existing Timeout Task
                        if let timeoutTask {
                            timeoutTask.cancel()
                        }
                        /// Calculating Progress
                        let translationX: CGFloat = value.translation.width
                        let calculatedProgress = (translationX / videoSize.width) +
                        lastDraggedProgress
                        
                        progress = max(min(calculatedProgress, 1), 0)
                        isSeeking = true
                        
                    })
                    .onEnded({ value in
                        /// Storing last known proggress
                        lastDraggedProgress = progress
                        /// Seeking Video To Dragged Time
                        if let currentPlayerTime = player?.currentItem {
                            let totalDuration = currentPlayerTime.duration.seconds
                            player?.seek(to: .init(seconds: totalDuration * progress, preferredTimescale: 1))
                            
                            /// Re-Scheduling Timeout Task
                            if isPlaying {
                                timeoutControls()
                            }
                            
                            /// Releasing with slight delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                isSeeking = false
                            }
                        }
                    })
                )
                .offset(x: progress * videoSize.width > 15 ? -15 : 0)
                .frame(width: 15, height: 15)
        }
    }
    
    /// Playback Controls View
    @ViewBuilder
    func PlayBackControls() -> some View {
        HStack(spacing: 25) {
            Button {
                
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.title2)
                    .fontWeight(.ultraLight)
                    .foregroundColor(.white)
                    .padding(15)
                    .background {
                        Circle()
                            .fill(.black.opacity(0.35))
                    }
            }
            /// Disabling Button
            /// Since we hane no antion's for it
            .disabled(true)
            .opacity(0.6)
            
            Button {
                if isFinishedPlaying {
                    /// Setting Video to Start and Playing Again
                    isFinishedPlaying = false
                    player?.seek(to: .zero)
                    progress = .zero
                    lastDraggedProgress = .zero
                }
                
                /// Changing video status to play/pause based on user input
                if isPlaying {
                    /// Pause Video
                    player?.pause()
                    /// Cancelling Timeout Task when the video is Paused
                    if let timeoutTask {
                        timeoutTask.cancel()
                    }
                } else {
                    /// Play Video
                    player?.play()
                    timeoutControls()
                }
                
                withAnimation(.easeInOut(duration: 0.2)) {
                    isPlaying.toggle()
                }
            } label: {
                /// Changing Icon based on Video Status
                /// Changing Icon When Video was Finished Playing
                Image(systemName: isFinishedPlaying ? "arrow.clockwise" : (isPlaying ? "pause.fill" : "play.fill"))
                    .font(.title)
                    .foregroundColor(.white)
                    .padding(15)
                    .background {
                        Circle()
                            .fill(.black.opacity(0.35))
                    }
            }
            .scaleEffect(1.1)
            
            Button {
                
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.title2)
                    .fontWeight(.ultraLight)
                    .foregroundColor(.white)
                    .padding(15)
                    .background {
                        Circle()
                            .fill(.black.opacity(0.35))
                    }
            }
            /// Disabling Button
            /// Since we hane no antion's for it
            .disabled(true)
            .opacity(0.6)

        }
        /// Hidding Controls When Dragging
        .opacity(showPlayerControls && !isDragging ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: showPlayerControls && !isDragging)
    }
    
    /// Timig Out Play back controls
    /// After some 2-5 Seconds
    func timeoutControls() {
        /// Cancelling Already Pending Timeout Task
        if let timeoutTask {
            timeoutTask.cancel()
        }
        
        timeoutTask = .init(block: {
            withAnimation(.easeInOut(duration: 0.35)) {
                showPlayerControls = false
            }
        })
        
        /// Scheduling Task
        if let timeoutTask {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: timeoutTask)
        }
    }
}

// MARK: - PREVIEW

struct Home_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
