//
//  AmityCommentController.swift
//  AmityUIKit
//
//  Created by sarawoot khunsri on 2/13/21.
//  Copyright © 2021 Amity. All rights reserved.
//

import UIKit
import AmitySDK

protocol AmityCommentControllerProtocol: AmityCommentFetchCommentPostControllerProtocol,
                                         AmityCommentCreateControllerProtocol,
                                         AmityCommentEditorControllerProtocol,
                                         AmityCommentFlaggerControllerProtocol { }

final class AmityCommentController: AmityCommentControllerProtocol {
    
    private let fetchCommentPostController: AmityCommentFetchCommentPostControllerProtocol = AmityCommentFetchCommentPostController()
    private let createController: AmityCommentCreateControllerProtocol = AmityCommentCreateController()
    private let editorController: AmityCommentEditorControllerProtocol = AmityCommentEditorController()
    private let flaggerController: AmityCommentFlaggerControllerProtocol = AmityCommentFlaggerController()
    
}

// MARK: - Fetch Comment Post
extension AmityCommentController {
    func getCommentsForPostId(withReferenceId postId: String, referenceType: AmityCommentReferenceType, filterByParentId isParent: Bool, parentId: String?, orderBy: AmityOrderBy, includeDeleted: Bool, completion: ((Result<[AmityCommentModel], AmityError>) -> Void)?) {
        fetchCommentPostController.getCommentsForPostId(withReferenceId: postId, referenceType: referenceType, filterByParentId: isParent, parentId: parentId, orderBy: orderBy, includeDeleted: includeDeleted, completion: completion)
    }
}

// MARK: - Create
extension AmityCommentController {
    func createComment(withReferenceId postId: String, referenceType: AmityCommentReferenceType, parentId: String?, text: String, completion: ((AmityComment?, Error?) -> Void)?) {
        createController.createComment(withReferenceId: postId, referenceType: referenceType, parentId: parentId, text: text, completion: completion)
    }
}

// MARK: - Comment Editor
extension AmityCommentController {
    func delete(withComment comment: AmityCommentModel, completion: AmityRequestCompletion?) {
        editorController.delete(withComment: comment, completion: completion)
    }
    
    func edit(withComment comment: AmityCommentModel, text: String, completion: AmityRequestCompletion?) {
        editorController.edit(withComment: comment, text: text, completion: completion)
    }
}

// MARK: - Flagger
extension AmityCommentController {
    func report(withCommentId commentId: String, completion: AmityRequestCompletion?) {
        flaggerController.report(withCommentId: commentId, completion: completion)
    }
    
    func unreport(withCommentId commentId: String, completion: AmityRequestCompletion?) {
        flaggerController.unreport(withCommentId: commentId, completion: completion)
    }
    
    func getReportStatus(withCommentId commentId: String, completion: ((Bool) -> Void)?) {
        flaggerController.getReportStatus(withCommentId: commentId, completion: completion)
    }
}
