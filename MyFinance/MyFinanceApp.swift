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
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .modelContainer(ModelContainerService.shared.container)
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
