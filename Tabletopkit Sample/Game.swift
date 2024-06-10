/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A parent container to organize classes for the game.
*/
@preconcurrency import TabletopKit
import RealityKit
import SwiftUI
import TabletopGameSampleContent

@MainActor
@Observable
class Game {
    let tabletopGame: TabletopGame
    let renderer: GameRenderer
    let observer: GameObserver
    let setup: GameSetup

    init() async {
        renderer = GameRenderer()
        setup = GameSetup(root: renderer.root)
        
        tabletopGame = TabletopGame(tableSetup: setup.setup)
        
        observer = GameObserver(tabletop: tabletopGame, renderer: renderer)
        tabletopGame.addObserver(observer)
        
        tabletopGame.addRenderDelegate(renderer)
        renderer.game = self

        // Claim any seat when launching in single-player mode; a player must be seated to interact with the game.
        tabletopGame.claimAnySeat()

        // Shuffles the card deck.
        self.resetGame()
    }
    
    deinit {
        Task {
            await tabletopGame.removeObserver(observer)
            await tabletopGame.removeRenderDelegate(renderer)
        }
    }
}
