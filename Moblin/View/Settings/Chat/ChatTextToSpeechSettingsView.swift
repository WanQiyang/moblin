import SwiftUI

struct ChatTextToSpeechSettingsView: View {
    @EnvironmentObject var model: Model
    @State var rate: Float
    @State var volume: Float

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(get: {
                    model.database.chat.textToSpeechDetectLanguagePerMessage!
                }, set: { value in
                    model.database.chat.textToSpeechDetectLanguagePerMessage = value
                    model.store()
                })) {
                    Text("Detect language per message")
                }
                Toggle(isOn: Binding(get: {
                    model.database.chat.textToSpeechSayUsername!
                }, set: { value in
                    model.database.chat.textToSpeechSayUsername = value
                    model.store()
                })) {
                    Text("Say username")
                }
                Toggle(isOn: Binding(get: {
                    model.database.chat.textToSpeechPreferHighQuality!
                }, set: { value in
                    model.database.chat.textToSpeechPreferHighQuality = value
                    model
                        .setPreferHighQualityVoices(prefer: model.database.chat
                            .textToSpeechPreferHighQuality!)
                    model.store()
                })) {
                    Text("Prefer high quality")
                }
                HStack {
                    Text("Preferred gender")
                    Spacer()
                    Picker("", selection: Binding(get: {
                        model.database.chat.textToSpeechGender!.toString()
                    }, set: { value in
                        model.database.chat.textToSpeechGender = SettingsGender.fromString(value: value)
                        model.setSayGender(gender: model.database.chat.textToSpeechGender!)
                        model.store()
                        model.objectWillChange.send()
                    })) {
                        ForEach(genders, id: \.self) {
                            Text($0)
                        }
                    }
                }
                HStack {
                    Image(systemName: "tortoise.fill")
                    Slider(
                        value: $rate,
                        in: 0.3 ... 0.6,
                        step: 0.01,
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            model.database.chat.textToSpeechRate = rate
                            model.store()
                            model.setTextToSpeechRate(rate: rate)
                        }
                    )
                    Image(systemName: "hare.fill")
                }
                HStack {
                    Image(systemName: "volume.1.fill")
                    Slider(
                        value: $volume,
                        in: 0.3 ... 1.0,
                        step: 0.01,
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            model.database.chat.textToSpeechSayVolume = rate
                            model.store()
                            model.setTextToSpeechVolume(volume: volume)
                        }
                    )
                    Image(systemName: "volume.3.fill")
                }
            }
        }
        .navigationTitle("Text to speech")
        .toolbar {
            SettingsToolbar()
        }
    }
}
