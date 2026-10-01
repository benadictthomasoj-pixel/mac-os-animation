import Foundation
import ScreenCaptureKit
import CoreMedia
import os.log

private let logger = Logger(subsystem: "com.antigravity.SiriEdge", category: "SystemAudioMonitor")

/// Manages the low-overhead native ScreenCaptureKit system audio stream.
/// Strictly captures system audio output (never microphone, zero recording/storage, 100% local).
/// Automatically inactive when Music Mode is disabled.
public final class SystemAudioMonitor: NSObject, SCStreamOutput, SCStreamDelegate {
    public static let shared = SystemAudioMonitor()
    
    private var stream: SCStream?
    private let audioQueue = DispatchQueue(label: "com.antigravity.SiriEdge.audioQueue", qos: .userInteractive)
    
    public private(set) var isMonitoring: Bool = false
    private var isStarting: Bool = false
    
    private override init() {
        super.init()
    }
    
    deinit {
        stopMonitoring()
    }
    
    /// Starts low-cost system audio capture if Music Mode is enabled and permission is present.
    public func startMonitoring() {
        guard !isMonitoring, !isStarting else { return }
        
        guard CGPreflightScreenCaptureAccess() else {
            logger.info("ScreenCapture access not granted; system audio capture unavailable.")
            return
        }
        
        isStarting = true
        
        SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { [weak self] content, error in
            guard let self = self else { return }
            self.isStarting = false
            
            if let error = error {
                logger.error("Failed to query SCShareableContent: \(error.localizedDescription)")
                return
            }
            
            guard let display = content?.displays.first else {
                logger.error("No active display found for audio capture filter")
                return
            }
            
            let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
            
            // Minimal, lowest-cost stream configuration (16kHz, mono, 2x2 dummy video at 1 FPS)
            let config = SCStreamConfiguration()
            config.capturesAudio = true
            config.excludesCurrentProcessAudio = true
            config.sampleRate = 16000
            config.channelCount = 1
            config.width = 2
            config.height = 2
            config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
            config.queueDepth = 2
            
            do {
                let newStream = SCStream(filter: filter, configuration: config, delegate: self)
                try newStream.addStreamOutput(self, type: .audio, sampleHandlerQueue: self.audioQueue)
                
                newStream.startCapture { [weak self] startError in
                    guard let self = self else { return }
                    if let startError = startError {
                        logger.error("SCStream start failed: \(startError.localizedDescription)")
                        self.isMonitoring = false
                    } else {
                        self.stream = newStream
                        self.isMonitoring = true
                        logger.info("SystemAudioMonitor started successfully (16kHz Mono)")
                    }
                }
            } catch {
                logger.error("SCStream initialization failed: \(error.localizedDescription)")
                self.isMonitoring = false
            }
        }
    }
    
    /// Stops system audio capture and tears down stream to guarantee 0% CPU when Music Mode is off.
    public func stopMonitoring() {
        guard stream != nil || isMonitoring else { return }
        
        let oldStream = stream
        self.stream = nil
        self.isMonitoring = false
        self.isStarting = false
        
        oldStream?.stopCapture { [weak self] error in
            if let error = error {
                logger.warning("SCStream stop error: \(error.localizedDescription)")
            }
            self?.audioQueue.async {
                AudioEnergyAnalyzer.shared.reset()
            }
        }
        
        logger.info("SystemAudioMonitor stopped (0% audio overhead)")
    }
    
    // MARK: - SCStreamOutput (Runs on dedicated background audioQueue)
    
    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        
        let settings = EdgeSettings.shared
        guard settings.isMusicModeEnabled else {
            stopMonitoring()
            return
        }
        
        AudioEnergyAnalyzer.shared.process(
            sampleBuffer: sampleBuffer,
            reactivityMultiplier: settings.musicReactivityLevel.multiplier,
            beatMultiplier: settings.beatResponseLevel.multiplier
        )
    }
    
    // MARK: - SCStreamDelegate
    
    public func stream(_ stream: SCStream, didStopWithError error: Error) {
        logger.warning("SCStream didStopWithError: \(error.localizedDescription)")
        self.stream = nil
        self.isMonitoring = false
        AudioEnergyAnalyzer.shared.reset()
    }
}
