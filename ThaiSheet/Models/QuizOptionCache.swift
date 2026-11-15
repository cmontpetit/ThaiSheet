import Foundation

/// Presentation changes aren't a new quiz. Romanization and consonant-name mode
/// are: their displayed choices can differ, even for the same Thai character.
struct QuizOptionContext: Equatable {
    let cardID: String
    let romanization: RomanizationScheme
}

struct QuizOptionCache<Value> {
    private var context: QuizOptionContext?
    private(set) var value: Value

    init(value: Value) {
        self.value = value
    }

    mutating func update(for context: QuizOptionContext, generate: () -> Value) {
        guard self.context != context else { return }
        value = generate()
        self.context = context
    }
}
