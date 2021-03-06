//
//  AttachmentsViewModel.swift
//
//  Created on 08/04/2020.
//  Copyright © 2020 WildAid. All rights reserved.
//

import SwiftUI
import RealmSwift

class AttachmentsViewModel: ObservableObject, Identifiable {

    private var attachments: Attachments?
    @Published var id: String = UUID().uuidString
    @Published var photoIDs: [String] = []
    @Published var notes: [NoteViewModel] = []
    // TODO: Remove when SwiftUI handles refresh automatically
    @Published var refreshState = false

    var isEmpty: Bool { photoIDs.isEmpty && notes.isEmpty }

    convenience init (_ attachments: Attachments?) {
        self.init()
        if let attachments = attachments {
            self.attachments = attachments
            for index in attachments.photoIDs.indices {
                photoIDs.append(attachments.photoIDs[index])
            }
            for index in attachments.notes.indices {
                notes.append(NoteViewModel(text: attachments.notes[index]))
            }
        } else {
            self.attachments = Attachments()
        }
    }

    func save(clearModel: Bool = false) -> Attachments? {
        if attachments == nil || clearModel { attachments = Attachments() }
        guard let attachments = attachments else { return nil }
        attachments.photoIDs.removeAll()
        attachments.photoIDs.append(objectsIn: photoIDs.compactMap {
            $0.isEmpty ? nil : $0
        })
        attachments.notes.removeAll()
        attachments.notes.append(objectsIn: notes.compactMap {
            $0.isEmpty ? nil : $0.text
        })
        return attachments
    }

    func clone(withoutNotes: Bool = true) -> AttachmentsViewModel {
        let clone = AttachmentsViewModel()
        if let photoIDs = attachments?.photoIDs {
            for index in photoIDs.indices {
                clone.photoIDs.append(photoIDs[index])
            }
        }
        if !withoutNotes {
            if let notes = attachments?.notes {
                for index in notes.indices {
                    clone.notes.append(NoteViewModel(text: notes[index]))
                }
            }
        }
        return clone
    }

    func refresh() {
        refreshState.toggle()
    }
}
