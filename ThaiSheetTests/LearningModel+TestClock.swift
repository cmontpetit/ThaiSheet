//
//  LearningModel+TestClock.swift
//  ThaiSheetTests
//

import Foundation
@testable import ThaiSheet

extension LearningModel {
    /// Moves the model's clock forward two months on every reading, past the
    /// longest SRS interval. Each recorded review is then due, so a test can
    /// walk a card through the stages with consecutive answers.
    func advanceClockOnEachReview() {
        var time = Date()
        clock = {
            time = time.addingTimeInterval(60 * 86_400)
            return time
        }
    }
}
