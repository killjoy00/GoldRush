import GoldRushEngine

/// A strategy that plays Gold Rush.
///
/// Agents are handed a `PlayerView`, never a `GameState`. The type system is
/// what guarantees an agent cannot consult hidden information: there is no
/// accessor on the view that would reveal a card the player has not observed.
public protocol GameAgent: Sendable {
    var name: String { get }
}
