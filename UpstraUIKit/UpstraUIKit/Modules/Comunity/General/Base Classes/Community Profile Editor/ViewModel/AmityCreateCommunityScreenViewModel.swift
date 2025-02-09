//
//  AmityCreateCommunityScreenViewModel.swift
//  AmityUIKit
//
//  Created by Sarawoot Khunsri on 26/8/2563 BE.
//  Copyright © 2563 Amity. All rights reserved.
//

import UIKit
import AmitySDK

#warning("should be renmae to AmityCommunityProfileEditScreenViewModel")
final class AmityCreateCommunityScreenViewModel: AmityCreateCommunityScreenViewModelType {
    
    private let repository: AmityCommunityRepository
    private var communityModeration: AmityCommunityModeration?
    
    private var communityInfoToken: AmityNotificationToken?
    weak var delegate: AmityCreateCommunityScreenViewModelDelegate?
    var addMemberState: AmityCreateCommunityMemberState = .add
    var community: AmityBoxBinding<AmityCommunityModel?> = AmityBoxBinding(nil)
    private var communityId: String = ""
    var storeUsers: [AmitySelectMemberModel] = [] {
        didSet {
            validate()
        }
    }
    private(set) var selectedCategoryId: String? {
        didSet {
            validate()
        }
    }
    
    private var displayName: String = "" {
        didSet {
            validate()
        }
    }
    private var description: String = "" {
        didSet {
            validate()
        }
    }
    private var isPublic: Bool = true {
        didSet {
            validate()
        }
    }
    private var imageAvatar: UIImage? {
        didSet {
            validate()
        }
    }
    
    private var isAdminPost: Bool = true
    private var imageData: AmityImageData?
    
    init() {
        repository = AmityCommunityRepository(client: AmityUIKitManagerInternal.shared.client)
    }
    
    private var isRequiredFieldExisted: Bool {
        let isRequiredFieldExisted = !displayName.trimmingCharacters(in: .whitespaces).isEmpty && selectedCategoryId != nil
        
        if let community = community.value {
            // Edit community
            let isValueChanged = (displayName != community.displayName) || (description != community.description) || (community.isPublic != isPublic) || (imageAvatar != nil) || (community.categoryId != selectedCategoryId)
            return isRequiredFieldExisted && isValueChanged
        } else {
            if isPublic {
                // Create public community
                return isRequiredFieldExisted
            } else {
                // Create private community
                return isRequiredFieldExisted && !storeUsers.isEmpty
            }
        }
    }
    
    private func validate() {
        delegate?.screenViewModel(self, state: .validateField(status: isRequiredFieldExisted))
    }
}

// MARK: - Data Source
extension AmityCreateCommunityScreenViewModel {
    
    func numberOfMemberSelected() -> Int {
        var userCount = storeUsers.count
        if userCount == 0 {
            addMemberState = .add
        } else if userCount < 8 {
            addMemberState = .adding(number: userCount)
        } else {
            addMemberState = .max(number: userCount)
            userCount = 8
        }
        delegate?.screenViewModel(self, state: .updateAddMember)
        return userCount + 1
    }
    
    func user(at indexPath: IndexPath) -> AmitySelectMemberModel? {
        guard !storeUsers.isEmpty, indexPath.item < storeUsers.count else { return nil }
        return storeUsers[indexPath.item]
    }
    
}
// MARK: - Action
extension AmityCreateCommunityScreenViewModel {
    func textFieldEditingChanged(_ textField: AmityTextField) {
        guard let text = textField.text else { return }
        updateDisplayName(text: text)
    }
    
    private func updateDisplayName(text: String) {
        let count = text.utf16.count
        displayName = text
        delegate?.screenViewModel(self, state: .textFieldOnChanged(text: text, lenght: count))
    }
    
    func textViewDidChanged(_ textView: AmityTextView) {
        guard let text = textView.text else { return }
        updateDescription(text: text)
    }
    
    private func updateDescription(text: String) {
        let count = text.utf16.count
        description = text
        delegate?.screenViewModel(self, state: .textViewOnChanged(text: text, lenght: count, hasValue: count > 0))
    }
    
    func text<T>(_ object: T, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if let textField = object as? AmityTextField {
            return textField.verifyFields(shouldChangeCharactersIn: range, replacementString: string)
        } else if let textView = object as? AmityTextView {
            return textView.verifyFields(shouldChangeCharactersIn: range, replacementString: string)
        } else {
            return false
        }
    }

    func selectCommunityType(_ tag: Int) {
        guard let communityType = AmityCreateCommunityTypes(rawValue: tag) else { return }
        isPublic = communityType == .public
        delegate?.screenViewModel(self, state: .selectedCommunityType(type: communityType))
    }
    
    func updateSelectUser(users: [AmitySelectMemberModel]) {
        storeUsers = users
        delegate?.screenViewModel(self, state: .updateAddMember)
    }
    
    func removeUser(at indexPath: IndexPath) {
        storeUsers.remove(at: indexPath.item)
        delegate?.screenViewModel(self, state: .updateAddMember)
    }
    
    func updateSelectedCategory(categoryId: String?) {
        selectedCategoryId = categoryId
    }
    
    func create() {
        let builder = AmityCommunityCreationDataBuilder()
        builder.setDisplayName(displayName)
        builder.setCommunityDescription(description)
        builder.setIsPublic(isPublic)
        
        if !isPublic {
            let userIds = storeUsers.map { $0.userId }
            builder.setUserIds(userIds)
        }
        
        if let selectedCategoryId = selectedCategoryId {
            builder.setCategoryIds([selectedCategoryId])
        }
        
        if imageAvatar != nil {
            uploadAvatar { [weak self] (image) in
                guard let strongSelf = self else { return }
                guard let image = image else {
                    strongSelf.delegate?.screenViewModel(strongSelf, failure: .unknown)
                    return
                }
                builder.setAvatar(image)
                strongSelf.repository.createCommunity(with: builder, completion: {(community, error) in
                    guard let strongSelf = self else { return }
                    
                    if let error = AmityError(error: error), community == nil {
                        strongSelf.delegate?.screenViewModel(strongSelf, failure: error)
                    } else if let community = community {
                        strongSelf.updateRole(withCommunityId: community.communityId)
                    }
                })
            }
        } else {
            repository.createCommunity(with: builder, completion: { [weak self] (community, error) in
                guard let strongSelf = self else { return }
                
                if let error = AmityError(error: error), community == nil {
                    strongSelf.delegate?.screenViewModel(strongSelf, failure: error)
                } else if let community = community {
                    strongSelf.updateRole(withCommunityId: community.communityId)
                }
            })
        }
    }
    
    func performDismiss() {
        var isValueChanged: Bool = false
        
        if imageAvatar != nil {
            isValueChanged = true
        }
        
        if !displayName.trimmingCharacters(in: .whitespaces).isEmpty {
            isValueChanged = true
        }
        
        if !description.isEmpty {
            isValueChanged = true
        }
        
        if selectedCategoryId != nil {
            isValueChanged = true
        }
         
        if !isPublic || !storeUsers.isEmpty {
            isValueChanged = true
        }
        
        delegate?.screenViewModel(self, state: .onDismiss(isChange: isValueChanged))
    }
    
    func getInfo(communityId: String) {
        self.communityId = communityId
        communityInfoToken = repository.getCommunity(withId: communityId).observe{ [weak self] (community, error) in
            guard let object = community.object else { return }
            let model = AmityCommunityModel(object: object)
            self?.community.value = model
            self?.showProfile(model: model)
            if community.dataStatus == .fresh {
                self?.communityInfoToken?.invalidate()
            }
        }
    }
    
    private func showProfile(model: AmityCommunityModel) {
        updateDisplayName(text: model.displayName)
        updateDescription(text: model.description)
        selectedCategoryId = model.categoryId
        isPublic = model.isPublic
        selectCommunityType(model.isPublic ? 0 : 1)
    }
    
    func update() {
        let builder = AmityCommunityUpdateDataBuilder()
        builder.setDisplayName(displayName)
        builder.setCommunityDescription(description)
        builder.setIsPublic(isPublic)
        if let imageData = imageData {
            builder.setAvatar(imageData)
        }
        if let selectedCategoryId = selectedCategoryId {
            builder.setCategoryIds([selectedCategoryId])
        }
        
        if imageAvatar != nil {
            uploadAvatar { [weak self] (image) in
                guard let strongSelf = self else { return }
                guard let image = image else {
                    strongSelf.delegate?.screenViewModel(strongSelf, failure: .unknown)
                    return
                }
                builder.setAvatar(image)
                strongSelf.repository.updateCommunity(withId: strongSelf.communityId, builder: builder) { (community, error) in
                    if let error = AmityError(error: error) {
                        AmityHUD.hide()
                        strongSelf.delegate?.screenViewModel(strongSelf, failure: error)
                    } else {
                        strongSelf.delegate?.screenViewModel(strongSelf, state: .updateSuccess)
                    }
                }
            }
        } else {
            repository.updateCommunity(withId: communityId, builder: builder) { [weak self] (community, error) in
                guard let strongSelf = self else { return }
                if let error = AmityError(error: error) {
                    AmityHUD.hide()
                    strongSelf.delegate?.screenViewModel(strongSelf, failure: error)
                } else {
                    strongSelf.delegate?.screenViewModel(strongSelf, state: .updateSuccess)
                }
            }
        }
        
    }
    
    func setImage(for image: UIImage) {
        imageAvatar = image
    }
    
    private func uploadAvatar(completion: @escaping (AmityImageData?) -> Void) {
        guard let image = imageAvatar else { return }
        AmityUIKitManagerInternal.shared.fileService.uploadImage(image: image, progressHandler: { _ in
            
        }) { (result) in
            switch result {
            case .success(let _imageData):
                completion(_imageData)
            case .failure:
                completion(nil)
            }
        }
    }
}

private extension AmityCreateCommunityScreenViewModel {
    
    // Force set moderator after create the community success
    private func updateRole(withCommunityId communityId: String) {
        let userId = AmityUIKitManagerInternal.shared.currentUserId
        communityModeration = AmityCommunityModeration(client: AmityUIKitManagerInternal.shared.client, andCommunity: communityId)
        communityModeration?.addRole(AmityCommunityRole.moderator.rawValue, userIds: [userId]) { [weak self] (success, error) in
            guard let strongSelf = self else { return }
            if let _ = error {
                AmityHUD.hide()
                AmityUtilities.showError()
                return
            } else {
                if success {
                    self?.delegate?.screenViewModel(strongSelf, state: .createSuccess(communityId: communityId))
                } else {
                    AmityHUD.hide()
                    AmityUtilities.showError()
                    return
                }
            }
        }
    }
    
}
