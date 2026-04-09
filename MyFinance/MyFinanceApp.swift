//
//  MyFinanceApp.swift
//  MyFinance
//
//  Created by Rahmandhika Putra Purwadi Wicaksono on 08/04/26.
//

import SwiftUI
import SwiftData

@main
struct MyFinanceApp: App {
    @State private var auth = AuthenticationService()

    var body: some Scene {
        WindowGroup {
            if auth.isLocked {
                LockView()
                    .environment(auth)
            } else {
                MainTabView()
                    .modelContainer(ModelContainerService.shared.container)
                    .environment(auth)
                    .onAppear {
                        ModelContainerService.shared.seedDefaultCategoriesIfNeeded()
                        Task {
                            await NotificationService.shared.requestPermission()
                            let ctx = ModelContainerService.shared.container.mainContext
                            await ExchangeRateService.shared.refresh(context: ctx)
                        }
                    }
            }
        }
    }
}
