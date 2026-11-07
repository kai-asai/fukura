import UIKit

final class KeyboardViewController: UIInputViewController {
    private enum Layout {
        case letters
        case numbers
        case symbols
    }

    private var snippets: [Snippet] = []
    private var buffer = ""
    private var candidate: Snippet?
    private var layout: Layout = .letters
    private var isShifted = false

    private let appGroupID = "group.com.kaiasai.fukura"
    private let candidateButton = UIButton(type: .system)
    private let rowsStack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        loadSnippets()
        buildKeyboard()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadSnippets()
        updateCandidate()
    }

    private func loadSnippets() {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            snippets = []
            return
        }
        let url = container.appendingPathComponent("snippets.json")
        guard let data = try? SnippetValidator.readDataCheckingSize(from: url),
              let file = try? JSONDecoder().decode(SnippetFile.self, from: data),
              let valid = try? SnippetValidator.validate(file) else {
            snippets = []
            return
        }
        snippets = valid.sorted {
            if $0.trigger.count == $1.trigger.count {
                return $0.trigger < $1.trigger
            }
            return $0.trigger.count > $1.trigger.count
        }
    }

    private func buildKeyboard() {
        view.backgroundColor = .secondarySystemBackground

        let root = UIStackView()
        root.axis = .vertical
        root.spacing = 4
        root.translatesAutoresizingMaskIntoConstraints = false

        let candidateRow = UIStackView()
        candidateRow.axis = .horizontal
        candidateRow.spacing = 4

        let triggerButton = makeKey(title: ";") { [weak self] in
            self?.typeCharacter(";")
        }
        triggerButton.accessibilityLabel = "スニペット記号"
        triggerButton.widthAnchor.constraint(equalToConstant: 44).isActive = true
        candidateRow.addArrangedSubview(triggerButton)

        candidateButton.setTitle("候補なし", for: .normal)
        candidateButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        candidateButton.titleLabel?.lineBreakMode = .byTruncatingTail
        candidateButton.backgroundColor = .tertiarySystemBackground
        candidateButton.layer.cornerRadius = 7
        candidateButton.accessibilityHint = "候補があるときにタップすると展開します"
        candidateButton.addTarget(self, action: #selector(expandCandidate), for: .touchUpInside)
        candidateButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
        candidateRow.addArrangedSubview(candidateButton)
        root.addArrangedSubview(candidateRow)

        rowsStack.axis = .vertical
        rowsStack.spacing = 4
        root.addArrangedSubview(rowsStack)

        view.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
            root.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            root.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -4)
        ])

        renderLayout()
        updateCandidate()
    }

    private func renderLayout() {
        rowsStack.arrangedSubviews.forEach {
            rowsStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        switch layout {
        case .letters:
            addCharacterRow(Array("qwertyuiop").map(String.init))
            addCharacterRow(Array("asdfghjkl").map(String.init))
            addActionCharacterRow(
                leadingTitle: isShifted ? "⇧●" : "⇧",
                characters: Array("zxcvbnm").map(String.init),
                leadingAction: { [weak self] in self?.toggleShift() },
                trailingTitle: "⌫",
                trailingAction: { [weak self] in self?.deleteBackward() }
            )
            addBottomRow(layoutTitle: "123", layoutAction: { [weak self] in self?.showNumbers() })

        case .numbers:
            addCharacterRow(Array("1234567890").map(String.init))
            addCharacterRow(["-", "/", ":", ";", "(", ")", "¥", "&", "@", "\""])
            addActionCharacterRow(
                leadingTitle: "#+=",
                characters: [".", ",", "?", "!", "'"],
                leadingAction: { [weak self] in self?.showSymbols() },
                trailingTitle: "⌫",
                trailingAction: { [weak self] in self?.deleteBackward() }
            )
            addBottomRow(layoutTitle: "ABC", layoutAction: { [weak self] in self?.showLetters() })

        case .symbols:
            addCharacterRow(["[", "]", "{", "}", "#", "%", "^", "*", "+", "="])
            addCharacterRow(["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"])
            addActionCharacterRow(
                leadingTitle: "123",
                characters: [".", ",", "?", "!", "'"],
                leadingAction: { [weak self] in self?.showNumbers() },
                trailingTitle: "⌫",
                trailingAction: { [weak self] in self?.deleteBackward() }
            )
            addBottomRow(layoutTitle: "ABC", layoutAction: { [weak self] in self?.showLetters() })
        }
    }

    private func addCharacterRow(_ characters: [String]) {
        let row = makeRow()
        characters.forEach { character in
            let title = layout == .letters && isShifted ? character.uppercased() : character
            row.addArrangedSubview(makeKey(title: title) { [weak self] in
                self?.typeCharacter(character)
            })
        }
        rowsStack.addArrangedSubview(row)
    }

    private func addActionCharacterRow(
        leadingTitle: String,
        characters: [String],
        leadingAction: @escaping () -> Void,
        trailingTitle: String,
        trailingAction: @escaping () -> Void
    ) {
        let row = makeRow()
        row.addArrangedSubview(makeKey(title: leadingTitle, style: .special, action: leadingAction))
        characters.forEach { character in
            let title = layout == .letters && isShifted ? character.uppercased() : character
            row.addArrangedSubview(makeKey(title: title) { [weak self] in
                self?.typeCharacter(character)
            })
        }
        row.addArrangedSubview(makeKey(title: trailingTitle, style: .special, action: trailingAction))
        rowsStack.addArrangedSubview(row)
    }

    private func addBottomRow(layoutTitle: String, layoutAction: @escaping () -> Void) {
        let row = makeRow(distribution: .fill)

        let layoutButton = makeKey(title: layoutTitle, style: .special, action: layoutAction)
        layoutButton.widthAnchor.constraint(equalToConstant: 56).isActive = true
        row.addArrangedSubview(layoutButton)

        if needsInputModeSwitchKey {
            let globeButton = makeKey(title: "🌐", style: .special, action: nil)
            globeButton.accessibilityLabel = "次のキーボード"
            globeButton.addTarget(
                self,
                action: #selector(handleInputModeList(from:with:)),
                for: .allTouchEvents
            )
            globeButton.widthAnchor.constraint(equalToConstant: 48).isActive = true
            row.addArrangedSubview(globeButton)
        }

        let spaceButton = makeKey(title: "空白") { [weak self] in
            self?.insertSpace()
        }
        spaceButton.accessibilityLabel = "空白"
        row.addArrangedSubview(spaceButton)

        let returnButton = makeKey(title: "改行", style: .accent) { [weak self] in
            self?.insertReturn()
        }
        returnButton.widthAnchor.constraint(equalToConstant: 66).isActive = true
        row.addArrangedSubview(returnButton)

        rowsStack.addArrangedSubview(row)
    }

    private func makeRow(
        distribution: UIStackView.Distribution = .fillEqually
    ) -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 4
        row.distribution = distribution
        row.heightAnchor.constraint(equalToConstant: 39).isActive = true
        return row
    }

    private enum KeyStyle {
        case normal
        case special
        case accent
    }

    private func makeKey(
        title: String,
        style: KeyStyle = .normal,
        action: (() -> Void)?
    ) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: title.count > 2 ? 15 : 20, weight: .regular)
        button.setTitleColor(.label, for: .normal)
        button.layer.cornerRadius = 6
        button.layer.cornerCurve = .continuous
        button.backgroundColor = switch style {
        case .normal: .systemBackground
        case .special: .tertiarySystemFill
        case .accent: .systemBlue.withAlphaComponent(0.2)
        }
        if let action {
            button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        }
        return button
    }

    private func typeCharacter(_ character: String) {
        let text = layout == .letters && isShifted ? character.uppercased() : character
        textDocumentProxy.insertText(text)
        appendToBuffer(text)

        if layout == .letters && isShifted {
            isShifted = false
            renderLayout()
        }
    }

    private func appendToBuffer(_ text: String) {
        let maxLength = snippets.map { $0.trigger.count }.max() ?? 0
        buffer = String((buffer + text).suffix(maxLength))
        updateCandidate()
    }

    private func updateCandidate() {
        candidate = snippets.first { buffer.hasSuffix($0.trigger) }
        if let candidate {
            candidateButton.setTitle("展開: \(candidate.body)", for: .normal)
            candidateButton.isEnabled = true
            candidateButton.accessibilityLabel = "展開候補、\(candidate.body)"
        } else {
            candidateButton.setTitle(snippets.isEmpty ? "辞書をfukura本体で設定してください" : "候補なし", for: .normal)
            candidateButton.isEnabled = false
            candidateButton.accessibilityLabel = "候補なし"
        }
    }

    private func toggleShift() {
        isShifted.toggle()
        renderLayout()
    }

    private func showLetters() {
        layout = .letters
        isShifted = false
        renderLayout()
    }

    private func showNumbers() {
        layout = .numbers
        renderLayout()
    }

    private func showSymbols() {
        layout = .symbols
        renderLayout()
    }

    private func deleteBackward() {
        textDocumentProxy.deleteBackward()
        if !buffer.isEmpty {
            buffer.removeLast()
        }
        updateCandidate()
    }

    private func insertSpace() {
        textDocumentProxy.insertText(" ")
        clearMatch()
    }

    private func insertReturn() {
        textDocumentProxy.insertText("\n")
        clearMatch()
    }

    private func clearMatch() {
        buffer = ""
        candidate = nil
        updateCandidate()
    }

    @objc private func expandCandidate() {
        guard let candidate else {
            return
        }
        for _ in 0..<candidate.trigger.count {
            textDocumentProxy.deleteBackward()
        }
        textDocumentProxy.insertText(candidate.body)
        clearMatch()
    }
}
