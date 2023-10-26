import SwiftUI

struct SceneSettingsView: View {
    @EnvironmentObject var model: Model
    @State private var showingAddWidget = false
    @State private var showingAddButton = false
    @State private var expandedWidget: SettingsSceneWidget?
    var scene: SettingsScene
    @State var cameraSelection: String

    var widgets: [SettingsWidget] {
        model.database.widgets
    }

    var buttons: [SettingsButton] {
        model.database.buttons
    }

    func submitName(name: String) {
        scene.name = name
        model.store()
    }

    private func widgetHasPosition(id: UUID) -> Bool {
        if let widget = model.findWidget(id: id) {
            return widget.type == .image || widget.type == .browser || widget
                .type == .time
        } else {
            logger.error("Unable to find widget type")
            return false
        }
    }

    private func widgetHasSize(id: UUID) -> Bool {
        if let widget = model.findWidget(id: id) {
            return widget.type == .image || widget.type == .browser
        } else {
            logger.error("Unable to find widget type")
            return false
        }
    }

    private func createSceneWidget(widget: SettingsWidget) -> SettingsSceneWidget {
        let sceneWidget = SettingsSceneWidget(widgetId: widget.id)
        switch widget.type {
        case .time:
            sceneWidget.x = 91
            sceneWidget.y = 1
            sceneWidget.width = 8
            sceneWidget.height = 5
        case .image:
            sceneWidget.width = 30
            sceneWidget.height = 40
        case .browser:
            sceneWidget.width = 30
            sceneWidget.height = 40
        default:
            break
        }
        return sceneWidget
    }

    var body: some View {
        Form {
            NavigationLink(destination: NameEditView(
                name: scene.name,
                onSubmit: submitName
            )) {
                TextItemView(name: "Name", value: scene.name)
            }
            Section {
                Picker("", selection: $cameraSelection) {
                    ForEach(cameraTypes, id: \.self) { cameraType in
                        Text(cameraType)
                    }
                }
                .onChange(of: cameraSelection) { cameraType in
                    scene.cameraType = SettingsSceneCameraType(rawValue: cameraType)!
                    model.sceneUpdated(store: true)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Camera")
            }
            Section {
                List {
                    ForEach(scene.widgets) { widget in
                        if let realWidget = widgets
                            .first(where: { item in item.id == widget.widgetId })
                        {
                            Button(action: {
                                if expandedWidget !== widget {
                                    expandedWidget = widget
                                } else {
                                    expandedWidget = nil
                                }
                            }, label: {
                                HStack {
                                    DraggableItemPrefixView()
                                    Toggle(isOn: Binding(get: {
                                        widget.enabled
                                    }, set: { value in
                                        widget.enabled = value
                                        model.sceneUpdated()
                                    })) {
                                        HStack {
                                            Text("")
                                            Image(
                                                systemName: widgetImage(
                                                    widget: realWidget
                                                )
                                            )
                                            Text(realWidget.name)
                                        }
                                    }
                                }
                            })
                            .foregroundColor(.primary)
                            if expandedWidget === widget &&
                                (widgetHasPosition(id: realWidget.id) ||
                                    widgetHasSize(id: realWidget.id))
                            {
                                SceneWidgetSettingsView(
                                    hasPosition: widgetHasPosition(id: realWidget.id),
                                    hasSize: widgetHasSize(id: realWidget.id),
                                    widget: widget
                                )
                            }
                        }
                    }
                    .onMove(perform: { froms, to in
                        scene.widgets.move(fromOffsets: froms, toOffset: to)
                        model.sceneUpdated()
                    })
                    .onDelete(perform: { offsets in
                        scene.widgets.remove(atOffsets: offsets)
                        model.sceneUpdated()
                    })
                }
                AddButtonView(action: {
                    showingAddWidget = true
                })
                .popover(isPresented: $showingAddWidget) {
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                showingAddWidget = false
                            }, label: {
                                Text("Cancel")
                                    .padding(5)
                                    .foregroundColor(.blue)
                            })
                        }
                        Form {
                            Section("Widget name") {
                                ForEach(widgets) { widget in
                                    Button(action: {
                                        scene.widgets
                                            .append(createSceneWidget(widget: widget))
                                        model.sceneUpdated(imageEffectChanged: true)
                                        showingAddWidget = false
                                    }, label: {
                                        IconAndTextView(
                                            image: widgetImage(widget: widget),
                                            text: widget.name
                                        )
                                    })
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("Widgets")
            } footer: {
                Text("Widgets are stacked from back to front.")
            }
            Section {
                List {
                    ForEach(scene.buttons) { button in
                        if let realButton = model.findButton(id: button.buttonId) {
                            HStack {
                                DraggableItemPrefixView()
                                Toggle(isOn: Binding(get: {
                                    button.enabled
                                }, set: { value in
                                    button.enabled = value
                                    model.sceneUpdated()
                                })) {
                                    IconAndTextView(
                                        image: realButton.systemImageNameOff,
                                        text: realButton.name
                                    )
                                }
                            }
                        }
                    }
                    .onMove(perform: { froms, to in
                        scene.buttons.move(fromOffsets: froms, toOffset: to)
                        model.sceneUpdated()
                    })
                    .onDelete(perform: { offsets in
                        scene.buttons.remove(atOffsets: offsets)
                        model.sceneUpdated()
                    })
                }
                AddButtonView(action: {
                    showingAddButton = true
                })
                .popover(isPresented: $showingAddButton) {
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                showingAddButton = false
                            }, label: {
                                Text("Cancel")
                                    .padding(5)
                                    .foregroundColor(.blue)
                            })
                        }
                        Form {
                            Section("Button name") {
                                ForEach(buttons) { button in
                                    Button(action: {
                                        scene.addButton(id: button.id)
                                        model.sceneUpdated()
                                        showingAddButton = false
                                    }, label: {
                                        IconAndTextView(
                                            image: button.systemImageNameOff,
                                            text: button.name
                                        )
                                    })
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("Buttons")
            } footer: {
                Text("Buttons appear from bottom to top.")
            }
        }
        .navigationTitle("Scene")
        .onAppear {
            model.selectedSceneId = scene.id
            model.sceneUpdated()
        }
    }
}
