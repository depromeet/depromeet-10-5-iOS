import UIKit
import Photos
import Combine

class PosterListViewController: UIViewController {

    private lazy var collectionView: UICollectionView = { createCollectionView() }()
    private lazy var dataSource: DataSource = { createDataSource() }()
    private let refreshControl = UIRefreshControl()
    private lazy var addButton: UIButton = { createAddButton() }()
    private lazy var guideEnglishLabel: UILabel = { createGuideEnglishLabel() }()
    private lazy var guideLabel: UILabel = { createGuideLabel() }()
    private lazy var buttonClickEnglishLabel: UILabel = { createButtonClickEnglishLabel() }()
    private lazy var buttonClickLabel: UILabel = { createButtonClickLabel() }()
    private lazy var mypageButton: UIButton = {
        createMypageButton() }()

    private var subscriptions = Set<AnyCancellable>()
    private let viewModel: PosterListViewModelType
    
    init(viewModel: PosterListViewModelType) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        Log.debug(Self.self, #function)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        style()
        layout()
        bind()
    }

    override func viewWillAppear(_ animated: Bool) {
        HackleTracker.track(key: "posterListView", pageName: .posterList, eventType: .viewWillAppear)
        
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor.black,
            .font: UIFont(name: "PlayfairDisplay-Bold", size: 25) ?? UIFont.boldSystemFont(ofSize: 25)
        ]

        navigationItem.leftBarButtonItems = []
        navigationItem.hidesBackButton = true
        
        viewModel.loadImage()
    }
}

// MARK: - Bind ViewModel
extension PosterListViewController {
    private func bind() {
        viewModel.posters
            .receive(on: DispatchQueue.main)
            .sink { [weak self] posters in
                self?.guideLabel.isHidden = !posters.isEmpty
                self?.guideEnglishLabel.isHidden = !posters.isEmpty
                self?.buttonClickLabel.isHidden = !posters.isEmpty
                self?.buttonClickEnglishLabel.isHidden = !posters.isEmpty
                self?.updateList(with: posters)
            }.store(in: &subscriptions)

        viewModel.guideText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.guideLabel.attributedText = text.toAttributedText(minimumLineHeight: Style.lineHeight,
                                                                        alignment: .center)
            }.store(in: &subscriptions)

        viewModel.guideEnglishText
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] text in
                self?.guideEnglishLabel.attributedText = text.toAttributedText(minimumLineHeight: Style.lineHeight, alignment: .center)
                
            }).store(in: &subscriptions)
        
        viewModel.buttonClickLabel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.buttonClickLabel.attributedText = text.toAttributedText(minimumLineHeight: 14,
                                                                        alignment: .center)
            }.store(in: &subscriptions)

        viewModel.buttonClickEnglishLabel
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] text in
                self?.buttonClickEnglishLabel.attributedText = text.toAttributedText(minimumLineHeight: 25, alignment: .center)
                
            }).store(in: &subscriptions)
        
        viewModel.title
            .receive(on: DispatchQueue.main)
            .sink { [weak self] title in
                self?.navigationItem.title = title
            }.store(in: &subscriptions)

        viewModel.moveToMypage.receive(on: DispatchQueue.main).sink { [weak self] in
            let mypageVC = MyPageViewController(viewModel: MypageViewModel(service: UserService()))
            self?.navigationController?.pushViewController(mypageVC, animated: true)
        }.store(in: &subscriptions)

        viewModel.moveToDetail
            .receive(on: DispatchQueue.main)
            .sink { [weak self] asset in
                let detailVC = PosterDetailViewController(viewModel: PosterDetailViewModel(with: asset, mode: .general))
                self?.navigationController?.pushViewController(detailVC, animated: true)
            }.store(in: &subscriptions)

        viewModel.moveToTemplate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                let templateVM = PosterTemplateListViewModel()
                let templateVC = PosterTemplateListViewController(viewModel: templateVM)
                self?.navigationController?.setNavigationBarHidden(false, animated: false)
                self?.navigationController?.pushViewController(templateVC, animated: true)
            }.store(in: &subscriptions)

        viewModel.showAlert
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msg in
                let alertVC = UIAlertController(title: msg, message: nil, preferredStyle: .alert)
                alertVC.addAction(.init(title: "확인", style: .default, handler: nil))
                self?.present(alertVC, animated: true)
            }.store(in: &subscriptions)

        mypageButton.publisher(for: .touchUpInside).sink { [weak self] _ in
            guard let self = self else { return }
            self.viewModel.mypageBtnTapped.send()
        }.store(in: &subscriptions)

        addButton.publisher(for: .touchUpInside)
            .sink { [weak self] _ in
                guard
                    let self = self
                else { return }
                self.viewModel.addBtnTapped.send(())
            }.store(in: &subscriptions)

        refreshControl.publisher(for: .valueChanged)
            .compactMap { [weak self] _ in
                return self?.viewModel.loadImage()
            }.flatMap { $0 }
            .filter { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshControl.endRefreshing()
                self?.collectionView.reloadData()
            }.store(in: &subscriptions)
    }

    private func updateList(with photos: [PosterPhotoResponseModel], animatingDifferences: Bool = true) {
        var snapshot = SnapShot()
        snapshot.appendSections([.main])
        snapshot.appendItems(photos, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }
}

// MARK: - Configure UI
extension PosterListViewController {
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }

    private func style() {
        view.backgroundColor = .white

        navigationController?.interactivePopGestureRecognizer?.delegate = self
        navigationController?.view.backgroundColor = .white
        navigationController?.navigationBar.backgroundColor = .clear
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.shadowImage = UIImage()
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor.black,
            .font: UIFont(name: "PlayfairDisplay-Bold", size: 25) ?? UIFont.boldSystemFont(ofSize: 25)
        ]

        let rightBarButton = UIBarButtonItem(customView: mypageButton)
        navigationItem.rightBarButtonItem = rightBarButton
        navigationItem.rightBarButtonItem?.tintColor = .gray
    }

    private func layout() {
        setGuideLabelLayout()
        setPosterListViewLayout()
        setAddButtonLayout()
    }

    // MARK: Create Views
    private func createMypageButton() -> UIButton {
        let view = UIButton(type: .custom)
        if let image = UIImage(named: "person") {
            view.setImage(image, for: .normal)
        }
        view.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
        return view
    }

    private func createAddButton() -> UIButton {
        let view = UIButton()
        view.backgroundColor = #colorLiteral(red: 0.1098039216, green: 0.1098039216, blue: 0.1098039216, alpha: 1)
        let icon = UIImage(systemName: "plus.circle")?.withTintColor(#colorLiteral(red: 1, green: 1, blue: 1, alpha: 1), renderingMode: .alwaysOriginal)
        view.setImage(icon, for: .normal)
        view.imageView?.contentMode = .scaleAspectFit

        let conerRadius = Layout.btnHeight / 2
        let rect = CGRect(origin: .zero, size: .init(width: Layout.btnHeight, height: Layout.btnHeight))
        view.layer.cornerRadius = conerRadius
        view.layer.shadowColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1).cgColor
        view.layer.shadowPath = UIBezierPath(roundedRect: rect, cornerRadius: conerRadius).cgPath
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowOpacity = 0.3
        view.layer.shadowRadius = 8

        view.imageEdgeInsets = .init(top: Layout.btnContentInset,
                                     left: Layout.btnContentInset,
                                     bottom: Layout.btnContentInset,
                                     right: Layout.btnContentInset)
        view.translatesAutoresizingMaskIntoConstraints = false
        self.view.insertSubview(view, aboveSubview: collectionView)
        self.view.addSubview(view)
        return view
    }

    private func createGuideEnglishLabel() -> UILabel {
        let view = UILabel()
        view.numberOfLines = 0
        view.font = UIFont.systemFont(ofSize: 18)
        view.textColor = #colorLiteral(red: 0.6666666667, green: 0.6666666667, blue: 0.6666666667, alpha: 1)
        view.font = UIFont(name: "PlayfairDisplay-Bold", size: 18)
        view.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(view)
        return view
    }
    
    private func createGuideLabel() -> UILabel {
        let view = UILabel()
        view.numberOfLines = 0
        view.font = UIFont.systemFont(ofSize: 18)
        view.textColor = #colorLiteral(red: 0.6666666667, green: 0.6666666667, blue: 0.6666666667, alpha: 1)
        view.font = UIFont(name: "Pretendard-Bold", size: 12)
        view.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(view)
        return view
    }
    
    private func createButtonClickEnglishLabel() -> UILabel {
        let view = UILabel()
        view.numberOfLines = 0
        view.font = UIFont.systemFont(ofSize: 18)
        view.textColor = .black
        view.font = UIFont(name: "PlayfairDisplay-Bold", size: 18)
        view.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(view)
        return view
    }
    
    private func createButtonClickLabel() -> UILabel {
        let view = UILabel()
        view.numberOfLines = 0
        view.font = UIFont.systemFont(ofSize: 18)
        view.textColor = .black
        view.font = UIFont(name: "Pretendard-Bold", size: 12)
        view.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(view)
        return view
    }

    private func createCollectionView() -> UICollectionView {
        let view = UICollectionView(frame: .zero, collectionViewLayout: collectionViewLayout)
        view.backgroundColor = .clear
        view.refreshControl = refreshControl
        view.delegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(view)
        return view
    }

    private func createDataSource() -> DataSource {
        let registration = CellRegistration { cell, _, item in
            cell.update(with: item)
        }

        return DataSource(collectionView: collectionView) { collectionView, indexPath, item -> UICollectionViewCell? in
            collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: item)
        }
    }

    private var collectionViewLayout: UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { [weak self] _, env in
            let width = env.container.contentSize.width - Layout.horizontalInset * 2
            let numOfItemsPerRow = CGFloat(self?.viewModel.numOfItemsPerRow ?? 1)

            let itemWidth = (width - Layout.horizontalSpacing * (numOfItemsPerRow - 1)) / numOfItemsPerRow
            let posterSize = PosterModel.defaultSize
            let itemHeight = itemWidth / posterSize.width * posterSize.height

            let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(itemWidth),
                                                  heightDimension: .absolute(itemHeight))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                   heightDimension: .absolute(itemHeight))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize,
                                                           subitems: [item])
            group.interItemSpacing = .fixed(Layout.horizontalSpacing)

            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = Layout.verticalSpacing
            section.contentInsets = .init(top: Layout.listViewTopInset,
                                          leading: Layout.horizontalInset,
                                          bottom: Layout.listViewBottomInset,
                                          trailing: Layout.horizontalInset)
            return section
        }
        return layout
    }

    // MARK: Set Layouts
    private func setGuideLabelLayout() {
        NSLayoutConstraint.activate([
            guideLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor,
                                                constant: Layout.horizontalInset),
            guideLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor,
                                                 constant: -Layout.horizontalInset),
            guideLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        NSLayoutConstraint.activate([
            guideEnglishLabel.bottomAnchor.constraint(equalTo: guideLabel.bottomAnchor, constant: -26),
            guideEnglishLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor,
                                                constant: Layout.horizontalInset),
            guideEnglishLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor,
                                                 constant: -Layout.horizontalInset)
        ])
        
        NSLayoutConstraint.activate([
            buttonClickLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor,
                                                constant: Layout.horizontalInset),
            buttonClickLabel.bottomAnchor.constraint(equalTo: addButton.topAnchor, constant: -36),
            buttonClickLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor,
                                                 constant: -Layout.horizontalInset)
        ])
        
        NSLayoutConstraint.activate([
            buttonClickEnglishLabel.bottomAnchor.constraint(equalTo: buttonClickLabel.topAnchor, constant: -10),
            buttonClickEnglishLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor,
                                                constant: Layout.horizontalInset),
            buttonClickEnglishLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor,
                                                 constant: -Layout.horizontalInset)
        ])
        
    }

    private func setPosterListViewLayout() {
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setAddButtonLayout() {
        NSLayoutConstraint.activate([
            addButton.widthAnchor.constraint(equalToConstant: Layout.btnHeight),
            addButton.heightAnchor.constraint(equalToConstant: Layout.btnHeight),
            addButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            addButton.bottomAnchor.constraint(equalTo: view.bottomAnchor,
                                              constant: -Layout.btnBottomInset)
        ])
    }
}

// MARK: - UICollectionViewDelegate
extension PosterListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        viewModel.posterSelected.send(indexPath.item)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let value = scrollView.panGestureRecognizer.translation(in: scrollView).y
        navigationController?.setNavigationBarHidden(value < 0, animated: true)
    }
}

// MARK: UIGestureRecognizerDelegate
extension PosterListViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return !self.isEqual(navigationController?.topViewController)
    }
}

// MARK: - Definitions
extension PosterListViewController {
    typealias DataSource = UICollectionViewDiffableDataSource<Section, PosterPhotoResponseModel>
    typealias SnapShot = NSDiffableDataSourceSnapshot<Section, PosterPhotoResponseModel>
    typealias CellRegistration = UICollectionView.CellRegistration<PosterCell, PosterPhotoResponseModel>

    enum Section {
        case main
    }

    enum Layout {
        static let horizontalInset = CommonLayout.horizontalInset
        static let listViewTopInset: CGFloat = 24
        static let listViewBottomInset: CGFloat = 0
        static let horizontalSpacing: CGFloat = 15
        static let verticalSpacing: CGFloat = 24

        static let btnBottomInset: CGFloat = 28
        static let btnHeight: CGFloat = 56
        static let btnContentInset: CGFloat = 16
    }

    enum Style {
        static let lineHeight: CGFloat = 24
    }
}
