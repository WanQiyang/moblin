import SwiftUI

struct StreamWizardSummarySettingsView: View {
    @EnvironmentObject private var model: Model

    var body: some View {
        Form {
            if model.wizardPlatform == .twitch {
                Section {
                    TextValueView(name: "Channel name", value: model.wizardTwitchChannelName)
                    TextValueView(name: "Channel id", value: model.wizardTwitchChannelId)
                } header: {
                    Text("Twitch")
                }
            } else if model.wizardPlatform == .kick {
                Section {
                    TextValueView(name: "Channel name", value: model.wizardKickChannelName)
                    TextValueView(name: "Chatroom id", value: model.wizardKickChatroomId)
                } header: {
                    Text("Kick")
                }
            } else if model.wizardPlatform == .youTube {
                Section {
                    TextValueView(name: "API key", value: model.wizardYouTubeApiKey)
                    TextValueView(name: "Video id", value: model.wizardYouTubeVideoId)
                } header: {
                    Text("YouTube")
                }
            } else if model.wizardPlatform == .afreecaTv {
                Section {
                    TextValueView(name: "Channel name", value: model.wizardAfreecaTvChannelName)
                    TextValueView(name: "Video id", value: model.wizardAfreecsTvCStreamId)
                } header: {
                    Text("AfreecaTV")
                }
            }
            if model.wizardNetworkSetup == .obs {
                Section {
                    TextValueView(name: "IP address or domain name", value: model.wizardObsAddress)
                    TextValueView(name: "Port", value: model.wizardObsPort)
                } header: {
                    Text("OBS")
                }
            } else if model.wizardNetworkSetup == .belaboxCloudObs {
                Section {
                    TextValueView(name: "Ingest URL", value: model.wizardBelaboxUrl)
                } header: {
                    Text("BELABOX cloud")
                }
            } else if model.wizardNetworkSetup == .direct {
                Section {
                    if model.wizardPlatform == .twitch {
                        TextValueView(name: "Nearby ingest endpoint", value: model.wizardDirectIngest)
                        TextValueView(name: "Stream key", value: model.wizardDirectStreamKey)
                    } else if model.wizardPlatform == .kick {
                        TextValueView(name: "Stream URL", value: model.wizardDirectIngest)
                        TextValueView(name: "Stream key", value: model.wizardDirectStreamKey)
                    } else if model.wizardPlatform == .youTube {
                        TextValueView(name: "Stream URL", value: model.wizardDirectIngest)
                        TextValueView(name: "Stream key", value: model.wizardDirectStreamKey)
                    } else if model.wizardPlatform == .afreecaTv {
                        TextValueView(name: "Stream URL", value: model.wizardDirectIngest)
                        TextValueView(name: "Stream key", value: model.wizardDirectStreamKey)
                    }
                } header: {
                    Text("Direct")
                }
            }
            if model.wizardPlatform != .custom {
                if model.wizardObsRemoteControlEnabled {
                    Section {
                        TextValueView(name: "URL", value: model.wizardObsRemoteControlUrl)
                        TextValueView(name: "Password", value: model.wizardObsRemoteControlPassword)
                    } header: {
                        Text("OBS remote control")
                    }
                }
                Section {
                    TextValueView(name: "BTTV emotes", value: yesOrNo(model.wizardChatBttv))
                    TextValueView(name: "FFZ emotes", value: yesOrNo(model.wizardChatFfz))
                    TextValueView(name: "7TV emotes", value: yesOrNo(model.wizardChatSeventv))
                } header: {
                    Text("Chat")
                }
            }
            Section {
                TextField("Name", text: $model.wizardName)
            } header: {
                Text("Stream name")
                    .disableAutocorrection(true)
            }
            Section {
                HStack {
                    Spacer()
                    Button {
                        model.createStreamFromWizard()
                        model.isPresentingWizard = false
                        model.isPresentingSetupWizard = false
                    } label: {
                        Text("Create")
                    }
                    .disabled(model.wizardName.isEmpty)
                    Spacer()
                }
            }
        }
        .navigationTitle("Summary and stream name")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
