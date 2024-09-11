// Based on https://github.com/rbaron/catprinter
// MIT License

import Collections
import CoreBluetooth
import CoreImage
import Foundation

private let catPrinterDispatchQueue = DispatchQueue(label: "com.eerimoq.cat-printer")

protocol CatPrinterDelegate: AnyObject {
    func catPrinterState(_ catPrinter: CatPrinter, state: CatPrinterState)
}

enum CatPrinterState {
    case disconnected
    case discovering
    case connecting
    case connected
}

private enum DitheringAlgorithm {
    case floydSteinberg
    case atkinson
}

private enum JobState {
    case idle
    case waitingForReady
    case writingChunks
}

private class CurrentJob {
    let data: Data
    var offset: Int = 0
    let mtu: Int
    var state: JobState = .idle

    init(data: Data, mtu: Int) {
        self.data = data
        self.mtu = mtu
    }

    func setState(state: JobState) {
        guard state != self.state else {
            return
        }
        logger.debug("cat-printer: Job state change \(self.state) -> \(state)")
        self.state = state
    }

    func nextChunk() -> Data? {
        guard offset < data.count else {
            return nil
        }
        let chunk = data[offset ..< min(offset + mtu, data.count)]
        guard !chunk.isEmpty else {
            return nil
        }
        offset += chunk.count
        return chunk
    }
}

let catPrinterServices = [
    CBUUID(string: "0000af30-0000-1000-8000-00805f9b34fb"),
]

private let printId = CBUUID(string: "AE01")
private let notifyId = CBUUID(string: "AE02")

private struct PrintJob {
    let image: CIImage
}

class CatPrinter: NSObject {
    private var state: CatPrinterState = .disconnected
    private var centralManager: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var printCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    private let context = CIContext()
    private var printJobs: Deque<PrintJob> = []
    private var currentJob: CurrentJob?
    private var deviceId: UUID?
    private let ditheringAlgorithm: DitheringAlgorithm = .atkinson
    weak var delegate: (any CatPrinterDelegate)?
    private var tryWriteNextChunkTimer: DispatchSourceTimer?

    func start(deviceId: UUID?) {
        catPrinterDispatchQueue.async {
            self.startInternal(deviceId: deviceId)
        }
    }

    func stop() {
        catPrinterDispatchQueue.async {
            self.stopInternal()
        }
    }

    func print(image: CIImage) {
        catPrinterDispatchQueue.async {
            self.printInternal(image: image)
        }
    }

    func getState() -> CatPrinterState {
        return state
    }

    private func startInternal(deviceId: UUID?) {
        self.deviceId = deviceId
        reset()
        reconnect()
    }

    private func stopInternal() {
        reset()
    }

    private func printInternal(image: CIImage) {
        guard printJobs.count < 10 else {
            logger.info("cat-printer: Too many jobs. Discarding image.")
            return
        }
        printJobs.append(PrintJob(image: image))
        tryPrintNext()
    }

    private func tryPrintNext() {
        guard let peripheral else {
            reconnect()
            return
        }
        guard currentJob == nil else {
            return
        }
        guard let printJob = printJobs.popFirst() else {
            return
        }
        let image: [[Bool]]
        do {
            image = try processImage(image: printJob.image)
        } catch {
            logger.info("cat-printer: \(error)")
            return
        }
        let data = catPrinterPackPrintImageCommands(image: image)
        currentJob = CurrentJob(data: data, mtu: peripheral.maximumWriteValueLength(for: .withoutResponse))
        guard let printCharacteristic, let currentJob else {
            reconnect()
            return
        }
        let message = CatPrinterCommand.getDeviceState().pack()
        peripheral.writeValue(message, for: printCharacteristic, type: .withoutResponse)
        currentJob.setState(state: .waitingForReady)
    }

    private func tryWriteNextChunk() {
        guard let peripheral, let printCharacteristic else {
            reconnect()
            return
        }
        if let chunk = currentJob?.nextChunk() {
            peripheral.writeValue(chunk, for: printCharacteristic, type: .withoutResponse)
            startTryWriteNextChunkTimer()
        } else {
            currentJob = nil
            tryPrintNext()
        }
    }

    private func processImage(image: CIImage) throws -> [[Bool]] {
        var image = makeMonochrome(image: image)
        image = scaleToPrinterWidth(image: image)
        var pixels = try convertToPixels(image: image)
        switch ditheringAlgorithm {
        case .floydSteinberg:
            pixels = FloydSteinbergDithering().apply(image: pixels)
        case .atkinson:
            pixels = AtkinsonDithering().apply(image: pixels)
        }
        return pixels.map { $0.map { $0 < 127 } }
    }

    private func makeMonochrome(image: CIImage) -> CIImage {
        let filter = CIFilter.colorMonochrome()
        filter.inputImage = image
        filter.color = .white
        filter.intensity = 1
        return filter.outputImage ?? image
    }

    private func scaleToPrinterWidth(image: CIImage) -> CIImage {
        let scale = 384 / image.extent.width
        return image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    }

    private func convertToPixels(image: CIImage) throws -> [[UInt8]] {
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            throw "Failed to create core graphics image"
        }
        guard let data = cgImage.dataProvider?.data else {
            throw "Failed to get data"
        }
        var length = CFDataGetLength(data)
        guard let data = CFDataGetBytePtr(data) else {
            throw "Failed to get length"
        }
        guard cgImage.bitsPerComponent == 8 else {
            throw "Expected 8 bits per component, but got \(cgImage.bitsPerComponent)"
        }
        guard cgImage.bitsPerPixel == 32 else {
            throw "Expected 32 bits per pixel, but got \(cgImage.bitsPerPixel)"
        }
        length = min(length, 4 * Int(image.extent.width * image.extent.height))
        var pixels: [[UInt8]] = []
        for rowOffset in stride(from: 0, to: length, by: 4 * Int(image.extent.width)) {
            var row: [UInt8] = []
            for columnOffset in stride(from: 0, to: 4 * Int(image.extent.width), by: 4) {
                if data[rowOffset + columnOffset + 3] != 255 {
                    row.append(255)
                } else {
                    row.append(data[rowOffset + columnOffset])
                }
            }
            pixels.append(row)
        }
        return pixels
    }

    private func reset() {
        centralManager = nil
        peripheral = nil
        printCharacteristic = nil
        notifyCharacteristic = nil
        printJobs.removeAll()
        currentJob = nil
        stopTryWriteNextChunkTimer()
        setState(state: .disconnected)
    }

    private func reconnect() {
        peripheral = nil
        printCharacteristic = nil
        notifyCharacteristic = nil
        currentJob = nil
        setState(state: .discovering)
        stopTryWriteNextChunkTimer()
        centralManager = CBCentralManager(delegate: self, queue: catPrinterDispatchQueue)
    }

    private func setState(state: CatPrinterState) {
        guard state != self.state else {
            return
        }
        logger.info("cat-printer: State change \(self.state) -> \(state)")
        self.state = state
        delegate?.catPrinterState(self, state: state)
    }

    private func startTryWriteNextChunkTimer() {
        tryWriteNextChunkTimer = DispatchSource.makeTimerSource(queue: catPrinterDispatchQueue)
        tryWriteNextChunkTimer!.schedule(deadline: .now() + 0.1)
        tryWriteNextChunkTimer!.setEventHandler { [weak self] in
            self?.tryWriteNextChunk()
        }
        tryWriteNextChunkTimer!.activate()
    }

    private func stopTryWriteNextChunkTimer() {
        tryWriteNextChunkTimer?.cancel()
        tryWriteNextChunkTimer = nil
    }
}

extension CatPrinter: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            centralManager?.scanForPeripherals(withServices: catPrinterServices)
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData _: [String: Any],
                        rssi _: NSNumber)
    {
        guard peripheral.identifier == deviceId else {
            return
        }
        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
        setState(state: .connecting)
    }

    func centralManager(_: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error _: Error?) {
        logger.info("cat-printer: centralManager didFailToConnect \(peripheral)")
    }

    func centralManager(_: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices(nil)
    }

    func centralManager(
        _: CBCentralManager,
        didDisconnectPeripheral _: CBPeripheral,
        error _: Error?
    ) {
        reconnect()
    }
}

extension CatPrinter: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices _: Error?) {
        if let service = peripheral.services?.first {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(
        _: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error _: Error?
    ) {
        for characteristic in service.characteristics ?? [] {
            switch characteristic.uuid {
            case printId:
                printCharacteristic = characteristic
            case notifyId:
                notifyCharacteristic = characteristic
                peripheral?.setNotifyValue(true, for: characteristic)
            default:
                break
            }
        }
        if printCharacteristic != nil && notifyCharacteristic != nil {
            setState(state: .connected)
            tryPrintNext()
        }
    }

    func peripheral(_: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error _: Error?) {
        guard let value = characteristic.value, let currentJob else {
            return
        }
        guard let command = CatPrinterCommand(data: value) else {
            return
        }
        switch currentJob.state {
        case .idle:
            break
        case .waitingForReady:
            switch command {
            case .getDeviceState:
                currentJob.setState(state: .writingChunks)
                tryWriteNextChunk()
            default:
                break
            }
        case .writingChunks:
            switch command {
            case .writePacing:
                tryWriteNextChunk()
            default:
                break
            }
        }
    }
}
