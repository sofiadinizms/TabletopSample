/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
An object to respond to player interactions and update gameplay.
*/
import TabletopKit
import RealityKit

struct GameInteraction: TabletopInteraction {
    let game: Game
    
    @MainActor
    mutating func updateCursor(_ proposedDestination: EquipmentIdentifier?, snapshot: TableSnapshot, valid: Bool = false) {
        if let proposedDestination, let tile = game.tabletopGame.equipment(of: ConveyorTile.self, matching: proposedDestination) {
            // Transform the tile position into table space and place the cursor there.
            let boardToTable = game.setup.board.initialState.pose
            let tileToBoard = tile.initialState.pose
            let tileToTable = tileToBoard * boardToTable
            game.renderer.cursorTransform = .init(translation: .init(x: Float(tileToTable.position.x),
                                                                     y: GameMetrics.boardHeight,
                                                                     z: Float(tileToTable.position.y)))
        } else {
            game.renderer.cursorTransform = nil
        }
    }

    mutating func update(context: TabletopInteractionContext, value: TabletopInteractionValue) {
        self.updateCursor(value.proposedDestination.equipmentID, snapshot: context.snapshot)
        
        if value.phase == .started {
            onPhaseStarted(context: context, value: value)
        }
        
        if value.gesturePhase == .ended {
            onGesturePhaseEnded(context: context, value: value)
        }

        if value.phase == .ended {
            // When the interaction is over, turn off the cursor.
            self.updateCursor(nil, snapshot: context.snapshot)
            onPhaseEnded(context: context, value: value)
        }
    }
    
    @MainActor
    func onPhaseStarted(context: TabletopInteractionContext, value: TabletopInteractionValue) {
        if game.tabletopGame.equipment(of: PlayerPawn.self, matching: value.startingEquipmentID) != nil {
            // Only allow pawns to move to conveyor tiles.
            context.allowedDestinations = .restricted(game.tabletopGame.equipment(of: ConveyorTile.self).map(\.id))
        }

        if let card = game.tabletopGame.equipment(of: Card.self, matching: value.startingEquipmentID) {
            // Only allow cards to move to the local player's hand or the deck.
            var allowedDestinations = game.tabletopGame.equipment(of: CardStockGroup.self).map(\.id)
            guard let localSeat = context.snapshot.seat(of: PlayerSeat.self, for: game.tabletopGame.localPlayer) else {
                return
            }
            let cardGroups = game.tabletopGame.equipment(of: CardGroup.self)
            for group in cardGroups where group.owner.id == localSeat.0.id {
                allowedDestinations.append(group.id)
            }
            
            context.allowedDestinations = .restricted(allowedDestinations)
            // Use counter action to signal to all players that someone picked up the card.
            context.addAction(.updateCounter(matching: game.setup.counter.id, value: Int64(card.id.rawValue)))
        }

        if game.tabletopGame.equipment(of: Die.self, matching: value.startingEquipmentID) != nil {
            // Don't let the die land on any other equipment, just the table.
            context.allowedDestinations = .restricted([])
        }
    }
    
    @MainActor
    func onGesturePhaseEnded(context: TabletopInteractionContext, value: TabletopInteractionValue) {
        if let die = game.tabletopGame.equipment(of: Die.self, matching: value.startingEquipmentID) {
            // Play a sound when a player tosses a die.
            if let audioLibraryComponent = die.entity.components[AudioLibraryComponent.self] {
                if let soundResource = audioLibraryComponent.resources["dieSoundShort.mp3"] {
                    die.entity.playAudio(soundResource)
                }
            }
            // Pick a random value for the result of the die toss and toss the die.
            let nextValue = Int.random(in: 1 ... 6)
            context.addAction(.updateEquipment(die, state: .init(value: nextValue, entity: die.entity)))
            context.toss(equipmentID: value.startingEquipmentID, as: die.representation)
            // Move the die back to the starting pose on the table after toss animation finishes.
            context.addAction(.moveEquipment(die, childOf: nil, pose: die.initialState.pose))
        }
    }
    
    @MainActor
    func onPhaseEnded(context: TabletopInteractionContext, value: TabletopInteractionValue) {
        /* If there isn't a proposed destination, there's nothing to do here.
         Objects moving back to their original group animate there smoothly by default. */
        guard let dst = value.proposedDestination.equipmentID else {
            return
        }
        
        if let pawn = game.tabletopGame.equipment(of: PlayerPawn.self, matching: value.startingEquipmentID) {
            // Move the pawn to its new proposed destination with a default pose (centered in new destination).
            context.addAction(.moveEquipment(pawn, childOf: dst, pose: .init()))
        }
        
        if let card = game.tabletopGame.equipment(of: Card.self, matching: value.startingEquipmentID) {
            // If the card moves to the deck, make sure it's face down, and allow any player to pick it up.
            var seatControl: ControllingSeats = .any
            var faceUp = false
            // If the card moves to a player's hand, make sure it's face up, and only allow that player to interact with it.
            if let dstGroup = game.tabletopGame.equipment(of: CardGroup.self, matching: dst) {
                seatControl = .restricted([dstGroup.owner.id])
                faceUp = true
            }
            context.addAction(.updateEquipment(card, faceUp: faceUp, seatControl: seatControl))
            context.addAction(.moveEquipment(card, childOf: dst))
        }
    }
}
