//
//  AmityPostDetailViewController.swift
//  AmityUIKit
//
//  Created by sarawoot khunsri on 2/14/21.
//  Copyright © 2021 Amity. All rights reserved.
//

import UIKit

/// A view controller for providing post and relevant comments.
public final class AmityPostDetailViewController: AmityViewController {
    
    // MARK: - IBOutlet Properties
    @IBOutlet private var tableView: AmityPostTableView!
    @IBOutlet private var commentComposeBarView: AmityPostDetailCompostView!
    @IBOutlet private var commentComposeBarBottomConstraint: NSLayoutConstraint!
    private var optionButton: UIBarButtonItem!
    
    // MARK: - Post Protocol Handler
    private var postHeaderProtocolHandler: AmityPostHeaderProtocolHandler?
    private var postFooterProtocolHandler: AmityPostFooterProtocolHandler?
    private var postProtocolHandler: AmityPostProtocolHandler?
    
    // MARK: - Properties
    private var screenViewModel: AmityPostDetailScreenViewModelType
    private var selectedIndexPath: IndexPath?
    private var referenceId: String?
    private var expandedIds: [String] = []
    private var showReplyIds: [String] = []
    
    private var parentComment: AmityCommentModel? {
        didSet {
            commentComposeBarView.replyingUsername = parentComment?.displayName
        }
    }
    
    // MARK: - Initializer
    init(withPostId postId: String) {
        let postController = AmityPostController()
        let commentController = AmityCommentController()
        let reactionController = AmityReactionController()
        let childrenController = AmityCommentChildrenController(postId: postId)
        screenViewModel = AmityPostDetailScreenViewModel(withPostId: postId,
                                                             postController: postController,
                                                             commentController: commentController,
                                                             reactionController: reactionController,
                                                             childrenController: childrenController)
        super.init(nibName: AmityPostDetailViewController.identifier, bundle: AmityUIKitManager.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public static func make(withPostId postId: String) -> AmityPostDetailViewController {
        return AmityPostDetailViewController(withPostId: postId)
    }
    
    // MARK: - View Lifecycle
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupNavigationBar()
        setupTableView()
        setupComposeBarView()
        setupProtocolHandler()
        setupScreenViewModel()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setBackgroundColor(with: .white)
        AmityKeyboardService.shared.delegate = self
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.reset()
    }
    
    // MARK: Setup Post Protocol Handler
    private func setupProtocolHandler() {
        postHeaderProtocolHandler = AmityPostHeaderProtocolHandler(viewController: self)
        postHeaderProtocolHandler?.delegate = self
        
        postFooterProtocolHandler = AmityPostFooterProtocolHandler(viewController: self)
        postFooterProtocolHandler?.delegate = self
        
        postProtocolHandler = AmityPostProtocolHandler(viewController: self, tableView: tableView)
    }
    
    // MARK: - Setup ViewModel
    private func setupScreenViewModel() {
        screenViewModel.delegate = self
        screenViewModel.action.fetchPost()
        screenViewModel.action.fetchComments()
    }
    
    // MARK: Setup views
    private func setupView() {
        view.backgroundColor = AmityColorSet.backgroundColor
    }
    
    private func setupNavigationBar() {
        optionButton = UIBarButtonItem(image: AmityIconSet.iconOption, style: .plain, target: self, action: #selector(optionTap))
        optionButton.tintColor = AmityColorSet.base
        navigationItem.rightBarButtonItem = optionButton
    }
    
    private func setupTableView() {
        tableView.registerCustomCell()
        tableView.registerPostCell()
        tableView.register(cell: AmityCommentTableViewCell.self)
        tableView.register(cell: AmityPostDetailDeletedTableViewCell.self)
        tableView.register(cell: AmityViewMoreReplyTableViewCell.self)
        tableView.register(cell: AmityDeletedReplyTableViewCell.self)
        tableView.backgroundColor = AmityColorSet.backgroundColor
        tableView.showsVerticalScrollIndicator = false
        tableView.keyboardDismissMode = .onDrag
        tableView.separatorStyle = .none
        tableView.tableFooterView = UIView()
        tableView.postDelegate = self
        tableView.postDataSource = self
    }
    
    private func setupComposeBarView() {
        commentComposeBarView.delegate = self
        commentComposeBarView.isHidden = true
    }
    
    @objc private func optionTap() {
        guard let post = screenViewModel.post else {
            assertionFailure("Post should not be nil")
            return
        }
        if post.isOwner {
            let bottomSheet = BottomSheetViewController()
            let contentView = ItemOptionView<TextItemOption>()
            bottomSheet.isTitleHidden = true
            bottomSheet.sheetContentView = contentView
            bottomSheet.modalPresentationStyle = .overFullScreen
            
            let editOption = TextItemOption(title: AmityLocalizedStringSet.PostDetail.editPost.localizedString) { [weak self] in
                guard let strongSelf = self else { return }
                AmityEventHandler.shared.editPostDidTap(from: strongSelf, postId: post.postId)
            }
            let deleteOption = TextItemOption(title: AmityLocalizedStringSet.PostDetail.deletePost.localizedString) { [weak self] in
                // delete option
                let alert = UIAlertController(title: AmityLocalizedStringSet.PostDetail.deletePostTitle.localizedString, message: AmityLocalizedStringSet.PostDetail.deletePostMessage.localizedString, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: AmityLocalizedStringSet.General.cancel.localizedString, style: .cancel, handler: nil))
                alert.addAction(UIAlertAction(title: AmityLocalizedStringSet.General.delete.localizedString, style: .destructive, handler: { [weak self] _ in
                    self?.screenViewModel.deletePost()
                    self?.navigationController?.popViewController(animated: true)
                }))
                self?.present(alert, animated: true, completion: nil)
            }
            
            contentView.configure(items: [editOption, deleteOption], selectedItem: nil)
            present(bottomSheet, animated: false, completion: nil)
        } else {
            screenViewModel.action.getPostReportStatus()
        }
    }
    
}

// MARK: - AmityPostTableViewDelegate
extension AmityPostDetailViewController: AmityPostTableViewDelegate {
    
    func tableView(_ tableView: AmityPostTableView, didSelectRowAt indexPath: IndexPath) {
        // load more reply did tap
        if tableView.cellForRow(at: indexPath)?.reuseIdentifier == AmityViewMoreReplyTableViewCell.identifier {
            screenViewModel.action.getReplyComments(at: indexPath.section)
        }
    }
    
    func tableView(_ tableView: AmityPostTableView, heightForFooterInSection section: Int) -> CGFloat {
        return section == 0 ? 0 : 1.0
    }
    
    func tableView(_ tableView: AmityPostTableView, viewForFooterInSection section: Int) -> UIView? {
        let separatorView = UIView(frame: CGRect(x: tableView.separatorInset.left, y: 0.0, width: tableView.frame.width - tableView.separatorInset.right - tableView.separatorInset.left, height: 1.0))
        separatorView.backgroundColor = AmityColorSet.secondary.blend(.shade4)
        return separatorView
    }
    
}

// MARK: - AmityPostTableViewDataSource
extension AmityPostDetailViewController: AmityPostTableViewDataSource {
    
    func numberOfSections(in tableView: AmityPostTableView) -> Int {
        return screenViewModel.dataSource.numberOfSection()
    }
    
    func tableView(_ tableView: AmityPostTableView, numberOfRowsInSection section: Int) -> Int {
        return screenViewModel.dataSource.numberOfItems(tableView, in: section)
    }
    
    func tableView(_ tableView: AmityPostTableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let viewModel = screenViewModel.item(at: indexPath)
        switch viewModel {
        case .post(let postComponent):
            var cell: UITableViewCell
            if let clientComponent = tableView.feedDataSource?.getUIComponentForPost(post: postComponent._composable.post, at: indexPath.section) {
                cell = clientComponent.getComponentCell(tableView, at: indexPath)
            } else {
                cell = postComponent.getComponentCell(tableView, at: indexPath)
            }
            (cell as? AmityPostHeaderProtocol)?.delegate = postHeaderProtocolHandler
            (cell as? AmityPostFooterProtocol)?.delegate = postFooterProtocolHandler
            (cell as? AmityPostProtocol)?.delegate = postProtocolHandler
            return cell
        case .comment(let comment):
            if comment.isDeleted {
                let cell: AmityPostDetailDeletedTableViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.configure(deletedAt: comment.updatedAt)
                return cell
            }
            
            let cell: AmityCommentTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            let shouldActionShow = screenViewModel.post?.isCommentable ?? false
            let layout: AmityCommentViewLayout = .comment(contentExpanded: false, shouldActionShow: shouldActionShow, shouldLineShow: viewModel.isReplyType)
            cell.configure(with: comment, layout: layout)
            cell.labelDelegate = self
            cell.actionDelegate = self
            return cell
        case .replyComment(let comment):
            if comment.isDeleted {
                let cell: AmityDeletedReplyTableViewCell = tableView.dequeueReusableCell(for: indexPath)
                return cell
            }
            let cell: AmityCommentTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            let shouldActionShow = screenViewModel.post?.isCommentable ?? false
            let layout: AmityCommentViewLayout = .reply(contentExpanded: false, shouldActionShow: shouldActionShow, shouldLineShow: viewModel.isReplyType)
            cell.configure(with: comment, layout: layout)
            cell.labelDelegate = self
            cell.actionDelegate = self
            return cell
        case .loadMoreReply:
            let cell: AmityViewMoreReplyTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            return cell
        }
    }
    
}

extension AmityPostDetailViewController: AmityPostDetailScreenViewModelDelegate {
    
    // MARK: Post
    func screenViewModelDidUpdateData(_ viewModel: AmityPostDetailScreenViewModelType) {
        tableView.reloadData()
        if let post = screenViewModel.post {
            commentComposeBarView.configure(with: post)
        }
    }
    
    func screenViewModelDidUpdatePost(_ viewModel: AmityPostDetailScreenViewModelType) {
        // Do something with success
    }
    
    func screenViewModelDidLikePost(_ viewModel: AmityPostDetailScreenViewModelType) {
        tableView.feedDelegate?.didPerformActionLikePost()
    }
    
    func screenViewModelDidUnLikePost(_ viewModel: AmityPostDetailScreenViewModelType) {
        tableView.feedDelegate?.didPerformActionUnLikePost()
    }
    
    func screenViewModel(_ viewModel: AmityPostDetailScreenViewModelType, didReceiveReportStatus isReported: Bool) {
        let bottomSheet = BottomSheetViewController()
        let contentView = ItemOptionView<TextItemOption>()
        bottomSheet.isTitleHidden = true
        bottomSheet.sheetContentView = contentView
        bottomSheet.modalPresentationStyle = .overFullScreen
        
        if isReported {
            let unreportOption = TextItemOption(title: AmityLocalizedStringSet.General.undoReport.localizedString) { [weak self] in
                self?.screenViewModel.action.unreportPost()
            }
            contentView.configure(items: [unreportOption], selectedItem: nil)
        } else {
            let reportOption = TextItemOption(title: AmityLocalizedStringSet.General.report.localizedString) { [weak self] in
                self?.screenViewModel.action.reportPost()
            }
            contentView.configure(items: [reportOption], selectedItem: nil)
        }
        present(bottomSheet, animated: false, completion: nil)
    }
    
    // MARK: Comment
    func screenViewModelDidCreateComment(_ viewModel: AmityPostDetailScreenViewModelType) {
        // Do something with success
    }
    
    func screenViewModelDidDeleteComment(_ viewModel: AmityPostDetailScreenViewModelType) {
        // Do something with success
    }
    func screenViewModelDidEditComment(_ viewModel: AmityPostDetailScreenViewModelType) {
        // Do something with success
    }
    
    func screenViewModelDidLikeComment(_ viewModel: AmityPostDetailScreenViewModelType) {
        tableView.feedDelegate?.didPerformActionLikeComment()
    }
    
    func screenViewModelDidUnLikeComment(_ viewModel: AmityPostDetailScreenViewModelType) {
        tableView.feedDelegate?.didPerformActionUnLikeComment()
    }
    
    func screenViewModel(_ viewModel: AmityPostDetailScreenViewModelType, didFinishWithMessage message: String) {
        AmityHUD.show(.success(message: message.localizedString))
    }
    
    func screenViewModel(_ viewModel: AmityPostDetailScreenViewModelType, comment: AmityCommentModel, didReceiveCommentReportStatus isReported: Bool) {
        let bottomSheet = BottomSheetViewController()
        let contentView = ItemOptionView<TextItemOption>()
        bottomSheet.sheetContentView = contentView
        bottomSheet.isTitleHidden = true
        bottomSheet.modalPresentationStyle = .overFullScreen
        
        if isReported {
            let unreportOption = TextItemOption(title: AmityLocalizedStringSet.General.undoReport.localizedString) {
                self.screenViewModel.action.unreportComment(withCommentId: comment.id)
            }
            contentView.configure(items: [unreportOption], selectedItem: nil)
        } else {
            let reportOption = TextItemOption(title: AmityLocalizedStringSet.General.report.localizedString) {
                self.screenViewModel.action.reportComment(withCommentId: comment.id)
            }
            contentView.configure(items: [reportOption], selectedItem: nil)
        }
        present(bottomSheet, animated: false, completion: nil)
    }
    
    func screenViewModel(_ viewModel: AmityPostDetailScreenViewModelType, didFinishWithError error: AmityError) {
        switch error {
        case .unknown:
            AmityHUD.show(.error(message: AmityLocalizedStringSet.HUD.somethingWentWrong.localizedString))
        case .bannedWord:
            AmityHUD.show(.error(message: AmityLocalizedStringSet.PostDetail.banndedCommentErrorMessage.localizedString))
        default:
            break
        }
    }
    
}

// MARK: - AmityPostHeaderProtocolHandlerDelegate
extension AmityPostDetailViewController: AmityPostHeaderProtocolHandlerDelegate {
    
    func headerProtocolHandlerDidPerformAction(_ handler: AmityPostHeaderProtocolHandler, action: AmityPostProtocolHeaderHandlerAction, withPost post: AmityPostModel) {
        switch action {
        case .tapOption:
            screenViewModel.action.getPostReportStatus()
        case .tapDelete:
            screenViewModel.action.deletePost()
        case .tapReport:
            screenViewModel.action.reportPost()
        case .tapUnreport:
            screenViewModel.action.reportPost()
        }
    }
    
}

// MARK: - AmityPostFooterProtocolHandlerDelegate
extension AmityPostDetailViewController: AmityPostFooterProtocolHandlerDelegate {
    
    func footerProtocolHandlerDidPerformAction(_ handler: AmityPostFooterProtocolHandler, action: AmityPostFooterProtocolHandlerAction, withPost post: AmityPostModel) {
        switch action {
        case .tapLike:
            if post.isLiked {
                screenViewModel.action.unlikePost()
            } else {
                screenViewModel.action.likePost()
            }
        case .tapComment:
            parentComment = nil
            if post.isGroupMember {
                _ = commentComposeBarView.becomeFirstResponder()
            }
        }
    }
    
}

// MARK: - AmityPostDetailCompostViewDelegate
extension AmityPostDetailViewController: AmityPostDetailCompostViewDelegate {
    
    func composeViewDidTapReplyDismiss(_ view: AmityPostDetailCompostView) {
        parentComment = nil
    }
    
    func composeViewDidTapExpand(_ view: AmityPostDetailCompostView) {
        var editTextViewController: AmityEditTextViewController
        if let parentComment = parentComment {
            // create reply
            let header = String.localizedStringWithFormat(AmityLocalizedStringSet.PostDetail.replyingTo.localizedString, parentComment.displayName)
            editTextViewController = AmityEditTextViewController.make(headerTitle: header, text: commentComposeBarView.text, editMode: .create)
            editTextViewController.title = AmityLocalizedStringSet.PostDetail.createReply.localizedString
        } else {
            // create comment
            editTextViewController = AmityEditTextViewController.make(text: commentComposeBarView.text, editMode: .create)
            editTextViewController.title = AmityLocalizedStringSet.PostDetail.createComment.localizedString
        }
        editTextViewController.editHandler = { [weak self, weak editTextViewController] text in
            self?.screenViewModel.action.createComment(withText: text, parentId: self?.parentComment?.id)
            self?.parentComment = nil
            self?.commentComposeBarView.resetState()
            editTextViewController?.dismiss(animated: true, completion: nil)
        }
        editTextViewController.dismissHandler = { [weak self, weak editTextViewController] in
            let alertTitle = (self?.parentComment == nil) ? AmityLocalizedStringSet.PostDetail.discardCommentTitle.localizedString : AmityLocalizedStringSet.PostDetail.discardReplyTitle.localizedString
            let alertMessage = (self?.parentComment == nil) ? AmityLocalizedStringSet.PostDetail.discardCommentMessage.localizedString : AmityLocalizedStringSet.PostDetail.discardReplyMessage.localizedString
            let alertController = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: AmityLocalizedStringSet.General.cancel.localizedString, style: .cancel, handler: nil)
            let discardAction = UIAlertAction(title: AmityLocalizedStringSet.General.discard.localizedString, style: .destructive) { _ in
                editTextViewController?.dismiss(animated: true, completion: nil)
            }
            alertController.addAction(cancelAction)
            alertController.addAction(discardAction)
            editTextViewController?.present(alertController, animated: true, completion: nil)
        }
        let navigationController = UINavigationController(rootViewController: editTextViewController)
        navigationController.modalPresentationStyle = .fullScreen
        present(navigationController, animated: true, completion: nil)
    }
    
    func composeView(_ view: AmityPostDetailCompostView, didPostText text: String) {
        screenViewModel.action.createComment(withText: text, parentId: parentComment?.id)
        parentComment = nil
        commentComposeBarView.resetState()
    }
    
}

// MARK: - AmityKeyboardServiceDelegate
extension AmityPostDetailViewController: AmityKeyboardServiceDelegate {
    
    func keyboardWillChange(service: AmityKeyboardService, height: CGFloat, animationDuration: TimeInterval) {
        let offset = height > 0 ? view.safeAreaInsets.bottom : 0
        commentComposeBarBottomConstraint.constant = -height + offset
        view.setNeedsUpdateConstraints()
        view.layoutIfNeeded()
    }
    
}

extension AmityPostDetailViewController: AmityExpandableLabelDelegate {
    
    public func expandableLabeldidTap(_ label: AmityExpandableLabel) {
        // Intentionally left empty
    }
    
    public func willExpandLabel(_ label: AmityExpandableLabel) {
        tableView.beginUpdates()
    }
    
    public func didExpandLabel(_ label: AmityExpandableLabel) {
        let point = label.convert(CGPoint.zero, to: tableView)
        if let indexPath = tableView.indexPathForRow(at: point) as IndexPath?,
           case .comment(let comment) = screenViewModel.dataSource.item(at: indexPath) {
            expandedIds.append(comment.id)
            DispatchQueue.main.async { [weak self] in
                self?.tableView.scrollToRow(at: indexPath, at: .top, animated: true)
            }
        }
        tableView.endUpdates()
    }
    
    public func willCollapseLabel(_ label: AmityExpandableLabel) {
        tableView.beginUpdates()
    }
    
    public func didCollapseLabel(_ label: AmityExpandableLabel) {
        let point = label.convert(CGPoint.zero, to: tableView)
        if let indexPath = tableView.indexPathForRow(at: point) as IndexPath?,
           case .comment(let comment) = screenViewModel.dataSource.item(at: indexPath) {
            expandedIds = expandedIds.filter({ $0 != comment.id })
            DispatchQueue.main.async { [weak self] in
                self?.tableView.scrollToRow(at: indexPath, at: .top, animated: true)
            }
        }
        tableView.endUpdates()
    }
    
}

extension AmityPostDetailViewController: AmityCommentTableViewCellDelegate {
    
    func commentCellDidTapAvatar(_ cell: AmityCommentTableViewCell, userId: String) {
        AmityEventHandler.shared.userDidTap(from: self, userId: userId)
    }
    
    func commentCellDidTapReadMore(_ cell: AmityCommentTableViewCell) {
        //
    }
    
    func commentCellDidTapLike(_ cell: AmityCommentTableViewCell) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        switch screenViewModel.item(at: indexPath) {
        case .comment(let comment), .replyComment(let comment):
            if comment.isLiked {
                screenViewModel.action.unlikeComment(withCommendId: comment.id)
            } else {
                screenViewModel.action.likeComment(withCommendId: comment.id)
            }
        case .post, .loadMoreReply:
            break
        }
    }
    
    func commentCellDidTapReply(_ cell: AmityCommentTableViewCell) {
        guard let indexPath = tableView.indexPath(for: cell),
            case .comment(let comment) = screenViewModel.item(at: indexPath) else { return }
        parentComment = comment
        _ = commentComposeBarView.becomeFirstResponder()
    }
    
    func commentCellDidTapOption(_ cell: AmityCommentTableViewCell) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        switch screenViewModel.item(at: indexPath) {
        case .comment(let comment), .replyComment(let comment):
            presentOptionBottomSheet(comment: comment)
        case .post, .loadMoreReply:
            break
        }
    }
    
    private func presentOptionBottomSheet(comment: AmityCommentModel) {
        // Comment options
        if comment.isOwner {
            let bottomSheet = BottomSheetViewController()
            let contentView = ItemOptionView<TextItemOption>()
            bottomSheet.sheetContentView = contentView
            bottomSheet.isTitleHidden = true
            bottomSheet.modalPresentationStyle = .overFullScreen
            
            let editOptionTitle = comment.isParent ? AmityLocalizedStringSet.PostDetail.editComment.localizedString : AmityLocalizedStringSet.PostDetail.editReply.localizedString
            let deleteOptionTitle = comment.isParent ? AmityLocalizedStringSet.PostDetail.deleteComment.localizedString : AmityLocalizedStringSet.PostDetail.deleteReply.localizedString
            
            let editOption = TextItemOption(title: editOptionTitle) { [weak self] in
                guard let strongSelf = self else { return }
                let editTextViewController = AmityCommentEditorViewController.make(text: comment.text)
                editTextViewController.title = comment.isParent ? AmityLocalizedStringSet.PostDetail.editComment.localizedString : AmityLocalizedStringSet.PostDetail.editReply.localizedString
                editTextViewController.editHandler = { [weak self] text in
                    self?.screenViewModel.action.editComment(with: comment, text: text)
                    editTextViewController.dismiss(animated: true, completion: nil)
                }
                editTextViewController.dismissHandler = { [weak editTextViewController] in
                    let alertTitle = comment.isParent ? AmityLocalizedStringSet.PostDetail.discardCommentTitle.localizedString : AmityLocalizedStringSet.PostDetail.discardReplyTitle.localizedString
                    let alertMessage = comment.isParent ? AmityLocalizedStringSet.PostDetail.discardEditedCommentMessage.localizedString : AmityLocalizedStringSet.PostDetail.discardEditedReplyMessage.localizedString
                    let alertController = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
                    let cancelAction = UIAlertAction(title: AmityLocalizedStringSet.General.cancel.localizedString, style: .cancel, handler: nil)
                    let discardAction = UIAlertAction(title: AmityLocalizedStringSet.General.discard.localizedString, style: .destructive) { _ in
                        editTextViewController?.dismiss(animated: true, completion: nil)
                    }
                    alertController.addAction(cancelAction)
                    alertController.addAction(discardAction)
                    editTextViewController?.present(alertController, animated: true, completion: nil)
                }
                let nvc = UINavigationController(rootViewController: editTextViewController)
                nvc.modalPresentationStyle = .fullScreen
                strongSelf.present(nvc, animated: true, completion: nil)
            }
            let deleteOption = TextItemOption(title: deleteOptionTitle) { [weak self] in
                let alertTitle = comment.isParent ? AmityLocalizedStringSet.PostDetail.deleteCommentTitle.localizedString : AmityLocalizedStringSet.PostDetail.deleteReplyTitle.localizedString
                let alertMessage = comment.isParent ? AmityLocalizedStringSet.PostDetail.deleteCommentMessage.localizedString : AmityLocalizedStringSet.PostDetail.deleteReplyMessage.localizedString
                let alert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: AmityLocalizedStringSet.General.cancel.localizedString, style: .cancel, handler: nil))
                alert.addAction(UIAlertAction(title: AmityLocalizedStringSet.General.delete.localizedString, style: .destructive) { [weak self] _ in
                    self?.screenViewModel.action.deleteComment(with: comment)
                })
                self?.present(alert, animated: true, completion: nil)
            }
            
            contentView.configure(items: [editOption, deleteOption], selectedItem: nil)
            present(bottomSheet, animated: false, completion: nil)
        } else {
            // get report status for comment and then trigger didReceiveCommentReportStatus on delegate
            screenViewModel.action.getCommentReportStatus(with: comment)
        }
    }
    
}
