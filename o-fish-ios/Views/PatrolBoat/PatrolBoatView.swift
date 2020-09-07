//
//  PatrolBoatView.swift
//
//  Created on 3/20/20.
//  Copyright © 2020 WildAid. All rights reserved.
//

import SwiftUI

struct PatrolBoatView: View {
//    var isLoggedIn: Binding<Bool>

    @EnvironmentObject var settings: Settings

    @ObservedObject var user = UserViewModel()
    @ObservedObject var onDuty = DutyState.shared

    @State private var location = LocationViewModel(LocationHelper.currentLocation)
    @State private var isActiveRootFromPreboardingView  = false
    @State private var isActiveRootFromSearchView = false
    @State private var isActiveRootFromShowingPatrolSummaryView = false
    @State private var resetLocation = {}

    @State private var dutyReports = [ReportViewModel]()
    @State private var startDuty = DutyChangeViewModel()
    @State private var plannedOffDutyTime = Date()

    @State private var showingAlertItem: AlertItem?
    @State private var profilePicture: PhotoViewModel?

    let photoQueryManager = PhotoQueryManager.shared

    private enum Dimensions {
        static let bottomPadding: CGFloat = 75
        static let topPadding: CGFloat = 14
        static let coordPadding: CGFloat = 58.0
        static let coordTopPadding: CGFloat = 14.0
        static let allCoordPadding: CGFloat = 48.0
        static let trailingPadding: CGFloat = 16.0
        static let trailingCoordPadding: CGFloat = 12.0
    }

    var body: some View {
        VStack {
            SearchBarButton(title: "Find records", action: {
                self.isActiveRootFromSearchView.toggle()
            })
                .padding(.vertical, Dimensions.topPadding)

            NavigationLink(destination: PreboardingView(viewType: .searchRecords,
                                                        onDuty: onDuty,
                                                        rootIsActive: $isActiveRootFromSearchView),
                           isActive: $isActiveRootFromSearchView) {
                            EmptyView()
            }
                .isDetailLink(false)

            ZStack(alignment: .bottom) {
                MapComponentView(location: self.$location,
                    reset: self.$resetLocation,
                    isLocationViewNeeded: false)
                VStack {
                    HStack {
                        CoordsBoxView(location: location)
                            .padding(.trailing, Dimensions.trailingCoordPadding)
                            .padding(.leading, Dimensions.coordPadding)

                        LocationButton(action: resetLocation)
                            .padding(.trailing, Dimensions.coordTopPadding)
                    }
                        .padding(.top, Dimensions.coordTopPadding)
                    Spacer()
                    BoardButtonView {
                        if self.onDuty.onDuty {
                            self.isActiveRootFromPreboardingView.toggle()
                        } else {
                            self.showGoOnDutyAlert()
                        }
                    }
                        .padding(.bottom, Dimensions.bottomPadding)
                        .padding(.horizontal, Dimensions.allCoordPadding)

                    NavigationLink(
                        destination: PreboardingView(viewType: .preboarding,
                                                     onDuty: onDuty,
                                                     rootIsActive: $isActiveRootFromPreboardingView),
                        isActive: self.$isActiveRootFromPreboardingView) {
                            EmptyView()
                    }
                        .isDetailLink(false)
                }

                NavigationLink(destination:
                   PatrolSummaryView(dutyReports: dutyReports,
                       startDuty: startDuty,
                       onDuty: onDuty,
                       plannedOffDutyTime: plannedOffDutyTime,
                       rootIsActive: $isActiveRootFromShowingPatrolSummaryView),
                    isActive: $isActiveRootFromShowingPatrolSummaryView) {
                    EmptyView()
                }
                    .isDetailLink(false)
            }
                .edgesIgnoringSafeArea(.all)
                .navigationBarItems(
                    leading:
                        PatrolBoatUserView(name: user.name.fullName,
                            photo: profilePicture,
                            action: showOptionsModal),

                    trailing:
                        TextToggle(isOn: dutyBinding,
                            titleLabel: "",
                            onLabel: "At Sea",
                            offLabel: "On Land")
                )
                .navigationBarTitle(Text(""), displayMode: .inline)
                .navigationBarBackButtonHidden(true)
        }
            .showingAlert(alertItem: $showingAlertItem)
            .onAppear(perform: onAppear)
    }

    private var dutyBinding: Binding<Bool> {
        Binding<Bool>(
            get: { self.onDuty.onDuty },
            set: {
                if !$0 {
                    self.showOffDutyConfirmation()
                } else {
                    self.onDuty.onDuty = $0
                }
            })
    }

    private func showLogoutAlert() {
        showingAlertItem = AlertItem(title: "You sure you want to logout?",
            message: "You can only log back in once you have cellular service or are connected to WIFI with internet",
            primaryButton: .default(Text("Yes"), action: logoutAlertClicked),
            secondaryButton: .cancel())
    }

    private func showGoOnDutyAlert() {
        showingAlertItem = AlertItem(title: "You're currently on land",
            message: "Change status to \"At Sea\"?",
            primaryButton: .default(Text("Yes"), action: goOnDutyAlertClicked),
            secondaryButton: .cancel())
    }

    private func showOptionsModal() {
        guard let user = settings.realmUser else {
//            self.isLoggedIn.wrappedValue = false
            print("realmUser not set")
            return
        }

        // TODO: review when viewModifier actions will be available
        let popoverId = UUID().uuidString
        let hidePopover = {
            PopoverManager.shared.hidePopover(id: popoverId)
        }

        var buttons = [
            ModalViewButton(title: NSLocalizedString("Log Out", comment: ""), action: {
                hidePopover()
                self.showLogoutAlert()
            })
        ]

        if user.profilePictureDocumentId != nil {
            buttons.insert(
                ModalViewButton(title: NSLocalizedString("Change profile picture", comment: ""), action: {
                    hidePopover()
                    self.showPhotoPickerTypeModal()
                }),
                at: 0
            )
        } else {
            print("Error, no placeholder image, so not showing edit profile picture option")
        }

        PopoverManager.shared.showPopover(id: popoverId, withButton: false) {
            ModalView(buttons: buttons, cancel: hidePopover)
        }
    }

    private func showPhotoPickerTypeModal() {
        // TODO: for some reason this works only from action and not from viewModifier
        // TODO: review when viewModifier actions will be available

        let popoverId = UUID().uuidString
        let hidePopover = {
            PopoverManager.shared.hidePopover(id: popoverId)
        }
        PopoverManager.shared.showPopover(id: popoverId, withButton: false) {
            ModalView(buttons: [
                ModalViewButton(title: NSLocalizedString("Camera", comment: ""), action: {
                    hidePopover()
                    self.showPhotoTaker(source: .camera)
                }),

                ModalViewButton(title: NSLocalizedString("Photo Library", comment: ""), action: {
                    hidePopover()
                    self.showPhotoTaker(source: .photoLibrary)
                })
            ],
                cancel: hidePopover)
        }
    }

    private func showPhotoTaker(source: UIImagePickerController.SourceType) {
        guard let photo = profilePicture else {
            print("Error, no placeholder image, so cannot edit picture")
            return
        }

        PhotoCaptureController.show(reportID: "", source: source, photoToEdit: photo) { controller, pictureId in

            self.profilePicture = self.getPicture(documentId: pictureId)
            controller.hide()
        }
    }

    /// Actions

    private func onAppear() {
        guard let user = settings.realmUser else {
//            self.isLoggedIn.wrappedValue = false
            print("realmUser not set")
            return
        }
        self.user.email = user.emailAddress
        self.user.name.first = user.firstName
        self.user.name.last = user.lastName
        onDuty.user = self.user

        profilePicture = getPicture(documentId: user.profilePictureDocumentId)
        location = LocationViewModel(LocationHelper.currentLocation)
    }

    private func goOnDutyAlertClicked() {
        self.onDuty.onDuty = true
        self.isActiveRootFromPreboardingView.toggle()
    }

    private func logoutAlertClicked() {
        guard let user = settings.realmUser else {
            print("Attempting to logout when no user logged in")
            return
        }

        user.logOut { _ in
            DispatchQueue.main.async {
                self.settings.realmUser = nil
            }
//            self.isLoggedIn.wrappedValue = false
            NotificationManager.shared.removeAllNotification()
        }
    }

    private func showOffDutyConfirmation() {
        let endDutyTime = Date()
        guard let startDuty = getDutyStartForCurrentUser(),
              startDuty.status == .onDuty else { return }

        self.startDuty = startDuty
        self.plannedOffDutyTime = endDutyTime
        dutyReports = dutyReportsForCurrentUser(startDutyTime: startDuty.date, endDutyTime: endDutyTime)
        isActiveRootFromShowingPatrolSummaryView = true
    }

    /// Logic

    private func getPicture(documentId: String?) -> PhotoViewModel? {
        guard let documentId = documentId else { return nil }
        let photos = photoQueryManager.photoViewModels(imagesId: [documentId])
        return photos.first
    }

    private func getDutyStartForCurrentUser() -> DutyChangeViewModel? {
        guard let user = settings.realmUser else {
            print("Bad state")
            return nil
        }
        let userEmail = user.emailAddress
        let predicate = NSPredicate(format: "user.email = %@", userEmail)

        let realmDutyChanges = settings.realmUser?
            .agencyRealm()?
            .objects(DutyChange.self)
            .filter(predicate)
            .sorted(byKeyPath: "date", ascending: false) ?? nil

        guard let dutyChanges = realmDutyChanges,
              let dutyChange = dutyChanges.first else { return nil }

        return DutyChangeViewModel(dutyChange: dutyChange)
    }

    private func dutyReportsForCurrentUser(startDutyTime: Date, endDutyTime: Date) -> [ReportViewModel] {
        guard let user = settings.realmUser else {
            print("Bad state")
            return []
        }
        let userEmail = user.emailAddress

        let predicate = NSPredicate(format: "timestamp > %@ AND timestamp < %@ AND reportingOfficer.email = %@",
            startDutyTime as NSDate, endDutyTime as NSDate, userEmail)

        let realmReports = settings.realmUser?
            .agencyRealm()?
            .objects(Report.self)
            .filter(predicate)
            .sorted(byKeyPath: "timestamp", ascending: false) ?? nil

        guard let reports = realmReports else { return [] }

        var dutyReports = [ReportViewModel]()
        for report in reports {
            dutyReports.append(ReportViewModel(report))
        }
        return dutyReports
    }
}

struct PatrolBoatView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PatrolBoatView()
                .environmentObject(Settings.shared)
        }
    }
}
