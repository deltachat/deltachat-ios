import Foundation
import Speech
import AVFoundation
import DcCore

/// Transcribes voice messages using on-device recognition only.
final class VoiceMessageTranscriber {
    private var recognizer: SFSpeechRecognizer?
    private var task: SFSpeechRecognitionTask?
    private var completion: ((Result<String, Error>) -> Void)?
    private var recognitionGeneration = 0

    deinit {
        task?.cancel()
    }

    static var isAvailable: Bool {
        if #available(iOS 26.0, *), SpeechTranscriber.isAvailable {
            return true
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale.current) else { return false }
        return recognizer.isAvailable && recognizer.supportsOnDeviceRecognition
    }

    func transcribe(fileURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        self.completion = completion
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            finish(.failure(TranscriptionError.unavailable))
            return
        }
        if #available(iOS 26.0, *), SpeechTranscriber.isAvailable {
            Task { [weak self] in
                guard let self else { return }
                do {
                    if let text = try await self.transcribeOnDevice(fileURL: fileURL) {
                        await MainActor.run { self.finish(.success(text)) }
                        return
                    }
                } catch {}
                await MainActor.run { self.transcribeLegacy(fileURL: fileURL) }
            }
            return
        }
        transcribeLegacy(fileURL: fileURL)
    }

    private func transcribeLegacy(fileURL: URL) {
        guard let recognizer = SFSpeechRecognizer(locale: Locale.current),
              recognizer.isAvailable,
              recognizer.supportsOnDeviceRecognition else {
            finish(.failure(TranscriptionError.unavailable))
            return
        }
        self.recognizer = recognizer

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self else { return }
                guard status == .authorized else {
                    self.finish(.failure(TranscriptionError.permissionDenied))
                    return
                }

                self.recognize(fileURL: fileURL)
            }
        }
    }

    @available(iOS 26.0, *)
    private func transcribeOnDevice(fileURL: URL) async throws -> String? {
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current),
              SpeechTranscriber.installedLocales.contains(where: { $0.identifier == locale.identifier }) else {
            return nil
        }
        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let file = try AVAudioFile(forReading: fileURL)
        async let text = transcriber.results.reduce("") {
            $0 + String($1.text.characters)
        }
        if let lastSample = try await analyzer.analyzeSequence(from: file) {
            try await analyzer.finalizeAndFinish(through: lastSample)
        } else {
            await analyzer.cancelAndFinishNow()
        }
        let result = try await text
        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            throw TranscriptionError.noSpeech
        }
        return trimmed
    }

    private func recognize(fileURL: URL) {
        guard let recognizer else { return }
        recognitionGeneration += 1
        let generation = recognitionGeneration
        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = true
        request.taskHint = .dictation
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self, self.recognitionGeneration == generation else { return }
                if let error {
                    self.finish(.failure(error))
                } else if let result, result.isFinal {
                    let text = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.finish(text.isEmpty ? .failure(TranscriptionError.noSpeech) : .success(text))
                }
            }
        }
    }

    private func finish(_ result: Result<String, Error>) {
        guard let completion else { return }
        recognitionGeneration += 1
        self.completion = nil
        task = nil
        recognizer = nil
        completion(result)
    }

    private enum TranscriptionError: LocalizedError {
        case unavailable
        case permissionDenied
        case noSpeech

        var errorDescription: String? {
            switch self {
            case .unavailable: return String.localized("voice_transcription_unavailable")
            case .permissionDenied: return String.localized("voice_transcription_permission_denied")
            case .noSpeech: return String.localized("voice_transcription_no_speech")
            }
        }
    }
}

/// Transcripts are private to this device and separate from the message text.
enum VoiceTranscriptionStore {
    private static func key(accountId: Int, messageId: Int) -> String {
        "voiceTranscription.\(accountId).\(messageId)"
    }

    static func transcript(accountId: Int, messageId: Int, fileURL: URL?) -> String? {
        guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path),
              let entry = UserDefaults.standard.dictionary(forKey: key(accountId: accountId, messageId: messageId)),
              entry["file"] as? String == fileURL.path else { return nil }
        return entry["text"] as? String
    }

    static func save(_ text: String, accountId: Int, messageId: Int, fileURL: URL) {
        UserDefaults.standard.set(["file": fileURL.path, "text": text], forKey: key(accountId: accountId, messageId: messageId))
    }

    static func remove(accountId: Int, messageIds: [Int]) {
        for messageId in messageIds {
            UserDefaults.standard.removeObject(forKey: key(accountId: accountId, messageId: messageId))
        }
    }

    static func removeAll(accountId: Int) {
        let prefix = "voiceTranscription.\(accountId)."
        for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
