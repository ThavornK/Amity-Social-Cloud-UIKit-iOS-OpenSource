//
//  AmityAudioRecorder.swift
//  AmityUIKit
//
//  Created by Sarawoot Khunsri on 3/12/2563 BE.
//  Copyright © 2563 BE Amity. All rights reserved.
//

import UIKit
import AVFoundation

enum AmityAudioRecorderState {
    case finish
    case finishWithMaximumTime
    case notFinish
    case timeTooShort
}

protocol AmityAudioRecorderDelegate: AnyObject {
    func requestRecordPermission(isAllowed: Bool)
    func displayDuration(_ duration: String)
    func finishRecording(state: AmityAudioRecorderState)
    func voiceMonitoring(radius: CGFloat)
}

final class AmityAudioRecorder: NSObject {
    
    static let shared = AmityAudioRecorder()
    
    private var session: AVAudioSession!
    private var recorder: AVAudioRecorder!
    
    let fileName = "amity-uikit-recording.m4a"
    private var minimumTimeout: Int = 1
    private var maximumTimeout: Int = 60
    private var duration: TimeInterval = 0.0 {
        didSet {
            displayDuration()
        }
    }
    private var timer: Timer?
    private var isRecord = false
    // MARK: - Delegatee
    weak var delegate: AmityAudioRecorderDelegate?
    
    // MARK: - Properties
    func requestPermission() {
        if session == nil {
            session = AVAudioSession.sharedInstance()
        }
        switch session.recordPermission {
        case .granted:
            break
        default:
            do {
                try session.setCategory(.record)
                try session.setActive(true)
                session.requestRecordPermission() { [weak self] allowed in
                    self?.delegate?.requestRecordPermission(isAllowed: allowed)
                }
            } catch {
                delegate?.requestRecordPermission(isAllowed: false)
                print(error.localizedDescription)
            }
        }
        
    }
    
    func startRecording() {
        recording()
    }
    
    func stopRecording(withDelete isDelete: Bool = false) {
        if isDelete {
            deleteFile()
            finishRecording(state: .notFinish)
        } else {
            if Int(duration) <= minimumTimeout {
                deleteFile()
                finishRecording(state: .timeTooShort)
            } else {
                finishRecording(state: .finish)
            }
        }
    }
    
    func updateFilename(withFilename newFileName: String) {
        AmityFileCache.shared.updateFile(for: .audioDirectory, originFilename: fileName, destinationFilename: newFileName + ".m4a")
    }
    
    func getAudioFileURL() -> URL? {
        return AmityFileCache.shared.getCacheURL(for: .audioDirectory, fileName: fileName)
    }
    
    func getDataFile() -> Data? {
        if let _ = AmityFileCache.shared.getCacheURL(for: .audioDirectory, fileName: fileName) {
            return AmityFileCache.shared.convertToData(for: .audioDirectory, fileName: fileName)
        }
        return nil
    }
}

private extension AmityAudioRecorder {
    
    func recording() {
        isRecord = true
        switch session.recordPermission {
        case .granted:
            let audioFileUrl = AmityFileCache.shared.getFileURL(for: .audioDirectory, fileName: fileName)
            
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            do {
                recorder = try AVAudioRecorder(url: audioFileUrl, settings: settings)
                recorder.delegate = self
                recorder.isMeteringEnabled = true
                recorder.record()
                
                timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] (timer) in
                    self?.recorder.updateMeters()
                    self?.duration += timer.timeInterval
                    self?.monitoring()
                })
                
            } catch {
                finishRecording(state: .notFinish)
            }
        default:
            delegate?.requestRecordPermission(isAllowed: false)
        }
    }
    
    func monitoring() {
        delegate?.voiceMonitoring(radius: normalizeSoundLevel(level: recorder.averagePower(forChannel: 0)))
        if Int(duration) == maximumTimeout {
            finishRecording(state: .finishWithMaximumTime)
        }
    }
    
    private func normalizeSoundLevel(level: Float) -> CGFloat {
        let level = max(0.2, CGFloat(level) + 50) / 2 // between 0.1 and 25
        return CGFloat(level * (250 / 25)) // scaled to max at 250
    }
    
    func finishRecording(state: AmityAudioRecorderState) {
        if recorder != nil {
            recorder.stop()
            recorder = nil
            isRecord = false
            timer?.invalidate()
            delegate?.finishRecording(state: state)
            duration = 0
        }
    }
 
    func displayDuration() {
        let time = Int(duration)
        let minutes = Int(time) / 60 % 60
        let seconds = Int(time) % 60
        let display = String(format:"%01i:%02i", minutes, seconds)
        delegate?.displayDuration(display)
    }
    
    func deleteFile() {
        AmityFileCache.shared.deleteFile(for: .audioDirectory, fileName: fileName)
    }
}

extension AmityAudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {

    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("Error while recording audio \(error!.localizedDescription)")
    }
}



