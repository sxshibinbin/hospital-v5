// Vendored from record_ios 1.2.1 (pub.flutter-io.cn) — 仅改写 Swift 5.9 语法为 5.7 兼容（Xcode 14.2），
// 逻辑零改动。原文件：ios/record_ios/Sources/record_ios/RecordConfig.swift
import AVFoundation

public enum AudioEncoder: String {
  case aacLc = "aacLc"
  case aacEld = "aacEld"
  case aacHe = "aacHe"
  case amrNb = "amrNb"
  case amrWb = "amrWb"
  case opus = "opus"
  case flac = "flac"
  case pcm16bits = "pcm16bits"
  case wav = "wav"
}

public enum AudioInterruptionMode: Int {
  case none = 0
  case pause = 1
  case pauseResume = 2
}

public class RecordConfig {
  let encoder: String
  let bitRate: Int
  let sampleRate: Int
  let numChannels: Int
  let device: Device?
  let autoGain: Bool
  let echoCancel: Bool
  let noiseSuppress: Bool
  let iosConfig: IosConfig
  let audioInterruption: AudioInterruptionMode
  let streamBufferSize: Int?

  init(encoder: String,
       bitRate: Int,
       sampleRate: Int,
       numChannels: Int,
       device: Device? = nil,
       autoGain: Bool = false,
       echoCancel: Bool = false,
       noiseSuppress: Bool = false,
       iosConfig: IosConfig,
       audioInterruption: AudioInterruptionMode = AudioInterruptionMode.pause,
       streamBufferSize: Int?
  ) {
    self.encoder = encoder
    self.bitRate = bitRate
    self.sampleRate = sampleRate
    self.numChannels = numChannels
    self.device = device
    self.autoGain = autoGain
    self.echoCancel = echoCancel
    self.noiseSuppress = noiseSuppress
    self.iosConfig = iosConfig
    self.audioInterruption = audioInterruption
    self.streamBufferSize = streamBufferSize
  }
}

public class Device {
  let id: String
  let label: String

  init(id: String, label: String) {
    self.id = id
    self.label = label
  }

  init(map: [String: Any]) {
    self.id = map["id"] as! String
    self.label = map["label"] as! String
  }

  func toMap() -> [String: Any] {
    return [
      "id": id,
      "label": label
    ]
  }
}

struct IosConfig {
  let categoryOptions: [AVAudioSession.CategoryOptions]
  let manageAudioSession: Bool
  let allowHapticsAndSystemSoundsDuringRecording: Bool

  init(map: [String: Any]) {
    let comps = map["categoryOptions"] as? String
    // 原版：compactMap { switch $0 { case ...: 裸表达式 } }（switch 表达式 + if 表达式，Swift 5.9+）
    // 改写：显式 return 语句，Swift 5.7 可编译
    let options: [AVAudioSession.CategoryOptions]? = comps?.split(separator: ",").compactMap { comp -> AVAudioSession.CategoryOptions? in
      switch String(comp) {
      case "mixWithOthers":
        return AVAudioSession.CategoryOptions.mixWithOthers
      case "duckOthers":
        return AVAudioSession.CategoryOptions.duckOthers
      case "allowBluetooth":
        #if compiler(>=6.2)
        // For XCode 26.0+, Swift 6.2 version
        return AVAudioSession.CategoryOptions.allowBluetoothHFP
        #else
        // Deprecated in 26.0, not 8.0. Thanks Apple!
        return AVAudioSession.CategoryOptions.allowBluetooth
        #endif
      case "defaultToSpeaker":
        return AVAudioSession.CategoryOptions.defaultToSpeaker
      case "interruptSpokenAudioAndMixWithOthers":
        return AVAudioSession.CategoryOptions.interruptSpokenAudioAndMixWithOthers
      case "allowBluetoothA2DP":
        return AVAudioSession.CategoryOptions.allowBluetoothA2DP
      case "allowAirPlay":
        return AVAudioSession.CategoryOptions.allowAirPlay
      case "overrideMutedMicrophoneInterruption":
        if #available(iOS 14.5, *) {
          return AVAudioSession.CategoryOptions.overrideMutedMicrophoneInterruption
        }
        return nil
      default:
        return nil
      }
    }
    self.categoryOptions = options ?? []
    self.manageAudioSession = map["manageAudioSession"] as? Bool ?? true
    self.allowHapticsAndSystemSoundsDuringRecording = map["allowHapticsAndSystemSoundsDuringRecording"] as? Bool ?? false
  }
}
