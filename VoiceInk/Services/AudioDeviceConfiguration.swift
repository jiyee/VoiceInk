import Foundation
import AVFoundation
import CoreAudio
import os

class AudioDeviceConfiguration {
    private static let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "AudioDeviceConfiguration")
    
    static func configureAudioSession(with deviceID: AudioDeviceID) throws -> AudioStreamBasicDescription {
        var propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        var streamFormat = AudioStreamBasicDescription()
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamFormat,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var isAlive: UInt32 = 0
        var aliveSize = UInt32(MemoryLayout<UInt32>.size)
        var aliveAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsAlive,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let aliveStatus = AudioObjectGetPropertyData(
            deviceID,
            &aliveAddress,
            0,
            nil,
            &aliveSize,
            &isAlive
        )
        
        if aliveStatus != noErr || isAlive == 0 {
            logger.error("Device \(deviceID) is not alive or ready")
            throw AudioConfigurationError.failedToGetDeviceFormat(status: aliveStatus)
        }
        
        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &streamFormat
        )
        
        if status != noErr {
            logger.error("Failed to get device format: \(status)")
            throw AudioConfigurationError.failedToGetDeviceFormat(status: status)
        }
        
        streamFormat.mFormatID = kAudioFormatLinearPCM
        streamFormat.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked
        
        return streamFormat
    }
    
    static func configureAudioUnit(_ audioUnit: AudioUnit, with deviceID: AudioDeviceID) throws {
        var deviceIDCopy = deviceID
        let propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        let resetStatus = AudioUnitReset(audioUnit, kAudioUnitScope_Global, 0)
        if resetStatus != noErr {
            logger.error("Failed to reset audio unit: \(resetStatus)")
        }
        
        logger.info("Configuring audio unit for device ID: \(deviceID)")
        let setDeviceResult = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceIDCopy,
            propertySize
        )
        
        if setDeviceResult != noErr {
            logger.error("Failed to set audio unit device: \(setDeviceResult)")
            logger.error("Device ID: \(deviceID)")
            if let deviceName = AudioDeviceManager.shared.getDeviceName(deviceID: deviceID) {
                logger.error("Failed device name: \(deviceName)")
            }
            throw AudioConfigurationError.failedToSetAudioUnitDevice(status: setDeviceResult)
        }
        
        logger.info("Successfully configured audio unit")
        Thread.sleep(forTimeInterval: 0.1)
    }
    
    static func createDeviceChangeObserver(
        handler: @escaping () -> Void,
        queue: OperationQueue = .main
    ) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AudioDeviceChanged"),
            object: nil,
            queue: queue,
            using: { _ in handler() }
        )
    }
}

enum AudioConfigurationError: LocalizedError {
    case failedToGetDeviceFormat(status: OSStatus)
    case failedToSetAudioUnitDevice(status: OSStatus)
    case failedToGetAudioUnit
    
    var errorDescription: String? {
        switch self {
        case .failedToGetDeviceFormat(let status):
            return "Failed to get device format: \(status)"
        case .failedToSetAudioUnitDevice(let status):
            return "Failed to set audio unit device: \(status)"
        case .failedToGetAudioUnit:
            return "Failed to get audio unit from input node"
        }
    }
} 