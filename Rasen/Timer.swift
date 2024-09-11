// Copyright 2024 Cii
//
// This file is part of Rasen.
//
// Rasen is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Rasen is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Rasen.  If not, see <http://www.gnu.org/licenses/>.

import Dispatch

final class OneshotTimer {
    private(set) var workItem: DispatchWorkItem?
    private var cancelClosure: (() -> ())?
    func start(afterTime: Double,
               dispatchQueue: DispatchQueue,
               beginClosure: () -> (),
               waitClosure: () -> (),
               cancelClosure: @escaping () -> (),
               endClosure: @escaping () -> ()) {
        if isWait {
            self.workItem?.cancel()
            self.workItem = nil
            waitClosure()
        } else {
            beginClosure()
        }
        var workItem: DispatchWorkItem!
        workItem = DispatchWorkItem(block: { [weak self] in
            if !(workItem?.isCancelled ?? false) {
                workItem = nil
                self?.workItem = nil
                endClosure()
            } else {
                workItem = nil
                self?.workItem = nil
            }
        })
        dispatchQueue.asyncAfter(deadline: DispatchTime.now() + afterTime,
                                 execute: workItem)
        self.workItem = workItem
        self.cancelClosure = cancelClosure
    }
    var isWait: Bool {
        if let workItem {
            !workItem.isCancelled
        } else {
            false
        }
    }
    func cancel() {
        if isWait {
            workItem?.cancel()
            workItem = nil
            cancelClosure?()
        }
    }
}

extension DispatchSource {
    static func scheduledTimer(withTimeInterval t: Double,
                               block: @escaping () -> ()) -> any DispatchSourceTimer {
        let dsTimer = DispatchSource.makeTimerSource()
        dsTimer.schedule(deadline: .now(), repeating: t)
        dsTimer.setEventHandler(handler: block)
        dsTimer.resume()
        return dsTimer
    }
}
