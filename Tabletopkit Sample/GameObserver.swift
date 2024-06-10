/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Respond to asynchronous callbacks throughout gameplay.
*/
import TabletopKit
import RealityKit

@MainActor
class GameObserver: TabletopGame.Observer {
    let tabletop: TabletopGame
    let renderer: GameRenderer

    init(tabletop: TabletopGame, renderer: GameRenderer) {
        self.tabletop = tabletop
        self.renderer = renderer
    }

    nonisolated func actionIsPending(_ action: some TabletopAction, oldSnapshot: TableSnapshot, newSnapshot: TableSnapshot) {
        if let action = action as? MoveEquipmentAction,
           action.equipmentIDs.count == 1,
           let (die, _) = newSnapshot.equipment(of: Die.self, matching: action.equipmentIDs[0]) {
            Task { @MainActor in
                die.playTossSound()
            }
            return
        }

        if let action = action as? UpdateCounterAction,
           let (card, _) = newSnapshot.equipment(of: Card.self, matching: .init(Int(action.newValue))) {
            Task { @MainActor in
                card.playPickupSound()
            }
            return
        }
    }

    nonisolated func actionWasCommitted(_ action: some TabletopAction, oldSnapshot: TableSnapshot, newSnapshot: TableSnapshot) {
        guard let action = action as? MoveEquipmentAction,
              let parentID = action.parentID,
              let destination = newSnapshot.equipment(of: ConveyorTile.self, matching: parentID),
              action.equipmentIDs.count == 1,
              let pawn = newSnapshot.equipment(of: PlayerPawn.self, matching: action.equipmentIDs[0]) else {
            return
        }

        let category = destination.0.category
        let color = pawn.0.cuteBotColor
        let renderer = self.renderer
        Task.detached { @MainActor in
            renderer.playAnimationForTile(category: category, cuteBotColor: color)
        }
    }

    @MainActor
    func playAnimationForTile(category: ConveyorTile.Category, cuteBotColor: PlayerPawn.CuteBotColor) {
        let cuteBotEntity = renderer.cuteBotEntity(for: cuteBotColor)
        switch category {
            case .green:
                if let celebrate = renderer.getAnimation(entity: cuteBotEntity, animation: .jumpJoy),
                   let idle = renderer.getAnimation(entity: cuteBotEntity, animation: .idleA) {
                    renderer.playAnimation(entity: cuteBotEntity, animation: try! .sequence(with: [celebrate, idle.repeat()]))
                }
            case .grey:
                // Just keep idling.
                break
            case .red:
                if let sad = renderer.getAnimation(entity: cuteBotEntity, animation: .sad),
                   let idle = renderer.getAnimation(entity: cuteBotEntity, animation: .idleA) {
                    renderer.playAnimation(entity: cuteBotEntity, animation: try! .sequence(with: [sad, idle.repeat()]))
                }
        }
    }
}
