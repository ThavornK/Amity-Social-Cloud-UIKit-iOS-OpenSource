//
//  AmityCommunityDetailBottomViewController.swift
//  AmityUIKit
//
//  Created by Sarawoot Khunsri on 14/9/2563 BE.
//  Copyright © 2563 Amity. All rights reserved.
//

import UIKit

final public class AmityCommunityFeedViewController: AmityProfileBottomViewController {
    
    // MARK: - Properties
    private var timelineVC: AmityFeedViewController?
    private var communityId: String = ""
    var dataDidUpdateHandler: (() -> Void)?
    
    // MARK: - View lifecycle
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupFeed()
        setupEmptyState()
    }
    
    func handleRefreshFeed()  {
        timelineVC?.handleRefreshing()
    }
    
    public static func make(communityId: String) -> AmityCommunityFeedViewController {
        let vc = AmityCommunityFeedViewController()
        vc.communityId = communityId
        vc.timelineVC = AmityFeedViewController.make(feedType: .communityFeed(communityId: communityId))
        vc.timelineVC?.pageTitle = AmityLocalizedStringSet.timelineTitle.localizedString
        vc.timelineVC?.pageIndex = 0
        return vc
    }

    override func viewControllers(for pagerTabStripController: AmityPagerTabViewController) -> [UIViewController] {
        guard let timelineVC = timelineVC else { return [] }
        return [timelineVC]
    }
    
    private func setupFeed() {
        timelineVC?.dataDidUpdateHandler = { [weak self] _ in
            self?.dataDidUpdateHandler?()
        }
    }
    
    private func setupEmptyState() {
        timelineVC?.emptyViewHandler = { emptyView in
            let emptyView = emptyView as? AmityEmptyStateHeaderFooterView
            emptyView?.setLayout(layout: .label(title: AmityLocalizedStringSet.emptyTitleNoPosts.localizedString, subtitle: nil, image: AmityIconSet.emptyNoPosts))
        }
    }
}
