//
//  AmityMessageModel.swift
//  AmityUIKit
//
//  Created by Sarawoot Khunsri on 17/8/2563 BE.
//  Copyright © 2563 Amity Communication. All rights reserved.
//

import UIKit
import AmitySDK

public final class AmityMessageModel {
    public var object: AmityMessage
    public var messageId: String
    public var userId: String
    public var displayName: String?
    public var syncState: AmitySyncState
    public var isDeleted: Bool
    public var isEdited: Bool
    public var messageType: AmityMessageType
    public var createdAtDate: Date
    public var date: String
    public var time: String
    public var data: [AnyHashable : Any]?
    
    public var isOwner: Bool {
        return userId == AmityUIKitManagerInternal.shared.client.currentUserId
    }
    
    public init(object: AmityMessage) {
        self.object = object
        self.messageId = object.messageId
        self.userId = object.userId
        self.displayName = object.user?.displayName ?? AmityLocalizedStringSet.General.anonymous.localizedString
        self.syncState = object.syncState
        self.isDeleted = object.isDeleted
        self.isEdited = AmityMessageModel.isEdited(createdAtDate: object.createdAtDate, editedAtDate: object.editedAtDate)
        self.messageType = object.messageType
        self.createdAtDate = object.createdAtDate
        self.date = AmityDateFormatter.Message.getDate(date: self.isEdited ? object.editedAtDate : object.createdAtDate)
        self.time = AmityDateFormatter.Message.getTime(date: self.isEdited ? object.editedAtDate : object.createdAtDate)
        self.data = object.data
    }
    
    
    class Readmore {
        var shouldShowReadmore: Bool?
        var isExpanded: Bool?
        
        private init() { }
        
        init(shouldShowReadmore: Bool? = nil, isExpanded: Bool? = nil) {
            self.shouldShowReadmore = shouldShowReadmore
            self.isExpanded = isExpanded
        }
    }
    
    static func isEdited(createdAtDate: Date, editedAtDate: Date) -> Bool {
        return editedAtDate > createdAtDate
    }
}

public class AmityMessageReadmoreModel {
    public var shouldShowReadmore: Bool?
    public var isExpanded: Bool?
    public var messageId: String
    
    public init(messageId: String, shouldShowReadmore: Bool? = nil, isExpanded: Bool? = nil) {
        self.messageId = messageId
        self.shouldShowReadmore = shouldShowReadmore
        self.isExpanded = isExpanded
    }
}
