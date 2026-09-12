import CoreAudioKit
import SwiftUI

public class H9AudioUnitViewController: AUViewController, AUAudioUnitFactory {
    private var audioUnit: H9AudioUnit?

    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        let unit = try H9AudioUnit(componentDescription: componentDescription, options: [])
        audioUnit = unit
        DispatchQueue.main.async { [weak self] in
            self?.embedSwiftUIViewIfReady()
        }
        return unit
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize = NSSize(width: 640, height: 420)
        embedSwiftUIViewIfReady()
    }

    private func embedSwiftUIViewIfReady() {
        guard isViewLoaded, let audioUnit, view.subviews.isEmpty else { return }
        let viewModel = H9RemoteViewModel(
            audioUnit: audioUnit,
            parameterTreeBuilder: audioUnit.parameterTreeBuilder
        )
        let hosting = NSHostingController(rootView: H9RemoteView(viewModel: viewModel))
        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}
