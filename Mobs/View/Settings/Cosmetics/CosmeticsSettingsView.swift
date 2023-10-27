import SwiftUI

struct Icon: Identifiable {
    var id: UUID = .init()
    var name: String
    var image: String
    var price: Float
}

let plainIcon = Icon(name: "Plain", image: "AppIconNoBackground", price: 1.99)

private let myIcons = [
    plainIcon,
    Icon(name: "Halloween", image: "AppIconNoBackgroundHalloween", price: 1.99),
    Icon(
        name: "Halloween pumpkin",
        image: "AppIconNoBackgroundHalloweenPumpkin",
        price: 1.99
    ),
]

func isInMyIcons(image: String) -> Bool {
    return myIcons.contains(where: { icon in
        icon.image == image
    })
}

private let allIcons = [
    plainIcon,
    Icon(name: "King", image: "AppIconNoBackgroundKing", price: 1.99),
    Icon(name: "Heart", image: "AppIconNoBackgroundHeart", price: 1.99),
    Icon(name: "Basque", image: "AppIconNoBackgroundBasque", price: 1.99),
    Icon(name: "Looking", image: "AppIconNoBackgroundLooking", price: 1.99),
    Icon(name: "Tetris", image: "AppIconNoBackgroundTetris", price: 1.99),
    Icon(name: "Halloween", image: "AppIconNoBackgroundHalloween", price: 1.99),
    Icon(
        name: "Halloween pumpkin",
        image: "AppIconNoBackgroundHalloweenPumpkin",
        price: 1.99
    ),
    Icon(name: "Eyebrows", image: "AppIconNoBackgroundEyebrows", price: 1.99),
    Icon(name: "South Korea", image: "AppIconNoBackgroundSouthKorea", price: 1.99),
    Icon(name: "China", image: "AppIconNoBackgroundChina", price: 1.99),
    Icon(name: "United Kingdom", image: "AppIconNoBackgroundUnitedKingdom", price: 1.99),
    Icon(name: "Sweden", image: "AppIconNoBackgroundSweden", price: 1.99),
    Icon(name: "United States", image: "AppIconNoBackgroundUnitedStates", price: 1.99),
    Icon(name: "Millionaire", image: "AppIconNoBackgroundMillionaire", price: 9.99),
    Icon(name: "Billionaire", image: "AppIconNoBackgroundBillionaire", price: 24.99),
    Icon(name: "Trillionaire", image: "AppIconNoBackgroundTrillionaire", price: 99.99),
]

struct CosmeticsSettingsView: View {
    @EnvironmentObject var model: Model
    @State var isPresentingBuyPopup = false

    private func getIconsInStock() -> [Icon] {
        return allIcons.filter { icon in
            !isInMyIcons(image: icon.image)
        }
    }

    private func setAppIcon(iconImage: String) {
        var iconImage: String? = iconImage.replacingOccurrences(
            of: "NoBackground",
            with: ""
        )
        if iconImage == "AppIcon" {
            iconImage = nil
        }
        UIApplication.shared.setAlternateIconName(iconImage) { error in
            if let error {
                logger.error("Failed to change app icon with error \(error)")
            }
        }
    }

    var body: some View {
        Form {
            Section {
                Picker("", selection: $model.iconImage) {
                    ForEach(myIcons) { icon in
                        HStack {
                            Text("")
                            Image(icon.image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                            Spacer()
                            Text(icon.name)
                        }
                        .tag(icon.image)
                    }
                }
                .onChange(of: model.iconImage) { iconImage in
                    model.database.iconImage = iconImage
                    model.store()
                    setAppIcon(iconImage: iconImage)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("My icons")
            } footer: {
                Text("Displayed in main view and as app icon.")
            }
            Section {
                List {
                    ForEach(getIconsInStock()) { icon in
                        HStack {
                            Text("")
                            Image(icon.image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                            Spacer()
                            Text(icon.name)
                            Button(action: {
                                isPresentingBuyPopup = true
                            }, label: {
                                Text("$\(String(format: "%.02f", icon.price))")
                            })
                            .padding([.leading], 10)
                            .alert(
                                "The store is closed",
                                isPresented: $isPresentingBuyPopup
                            ) {}
                        }
                        .tag(icon.image)
                    }
                }
            } header: {
                Text("Icons in store")
            } footer: {
                Text("Support MOBS developers by buying icons.")
            }
        }
        .navigationTitle("Cosmetics")
    }
}
