import SwiftUI

struct DjiDeviceScannerSettingsView: View {
    private let djiScanner: DjiDeviceScanner = .shared
    @Environment(\.dismiss) var dismiss
    var onChange: (String) -> Void
    @State var selectedId: String

    var body: some View {
        Form {
            Section {
                if djiScanner.discoveredDevices.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else {
                    Picker("", selection: $selectedId) {
                        ForEach(djiScanner.discoveredDevices.map { device in
                            InlinePickerItem(
                                id: device.identifier.uuidString,
                                text: device.name ?? String(localized: "Unknown")
                            )
                        }) { item in
                            Text(item.text)
                                .tag(item.id)
                        }
                    }
                    .onChange(of: selectedId) { item in
                        onChange(item)
                        dismiss()
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            } footer: {
                Text("""
                Make sure your DJI device is powered on and that no other apps are connected to \
                it via Bluetooth. Make sure the Moblin device is relatively near the DJI device. \
                If you still dont see your DJI device, turn your DJI device off and then on again.
                """)
            }
        }
        .onAppear {
            djiScanner.startScanningForDevices()
        }
        .onDisappear {
            djiScanner.stopScanningForDevices()
        }
        .navigationTitle("Device")
        .toolbar {
            SettingsToolbar()
        }
    }
}
