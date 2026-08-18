import Foundation

let usage = """
GoldRushSim -- headless Monte Carlo for Gold Rush

USAGE
  GoldRushSim <subcommand> [options]

SUBCOMMANDS
  balance   per-card EV, SD and win rate when held; flags cards >1.5 SD from
            their family mean
  seat      win rate by seat, isolating the structural advantage of choosing
            in the final round
  hidden    hidden-card counts 0/1/2 against persistentHiddenCards on and off
  reveal    whether WHICH three cards a player reveals affects winning
  deck      how much residual-card uncertainty matters, holding cards drawn fixed
  toggles   win rate and score spread across every rules variant

COMMON OPTIONS
  --games N          games per configuration
  --seed N           base seed; results are reproducible from it
  --threads N        worker threads (default: core count)
  --agent NAME       agent for `balance` (default: greedy)
  --deck-size N|LIST deck size, or a comma list for `deck`

RULES TOGGLES
  --scoring-draft          snake draft instead of a blind deal
  --progressive-reveal     reveal 2 at setup, a 3rd after round 4
  --no-persistent-hidden   face-down cards reveal to both players on claim
  --no-motherlode          all 8 rounds draw 7
  --hidden-cards N         fixed face-down count per round

Output is CSV on stdout; comment lines begin with '#'.
"""

guard let args = Args(CommandLine.arguments) else {
    print(usage)
    exit(1)
}

switch args.subcommand {
case "balance": Sim.balance(args)
case "seat": Sim.seat(args)
case "hidden": Sim.hidden(args)
case "reveal": Sim.reveal(args)
case "deck": Sim.deck(args)
case "toggles": Sim.toggles(args)
case "help", "--help", "-h": print(usage)
default:
    FileHandle.standardError.write("unknown subcommand: \(args.subcommand)\n\n".data(using: .utf8)!)
    print(usage)
    exit(1)
}
