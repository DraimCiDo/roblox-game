--!strict
-- Runtime state shared by the gameplay modules. One entry per player where keyed by Player;
-- Plots.release clears them when the player leaves.

local World = require(script.Parent.Parent.World.World)

local State = {}

export type Session = {
	Plot: World.Plot,
	ReadyAt: number,
	RemoteAt: number,
	PhysicalAt: { [string]: number },
	Initialized: boolean,
	ReleaseAt: number?,
	Use: World.Use,
}

State.sessions = {} :: { [Player]: Session }
State.occupants = {} :: { [number]: Player }
State.dialStages = {} :: { [Player]: number }
State.stats = {} :: { [Player]: { Coins: IntValue, Opened: IntValue } }
State.guides = {} :: { [Player]: { Id: string, Target: Instance? } }
State.galleryAt = {} :: { [Player]: number }
State.lastProfileQuery = {} :: { [Player]: number }
State.plots = {} :: { World.Plot }

-- Set by SimulatorService before any player is handled.
State.changed = nil :: any
State.interface = nil :: any

function State.tell(player: Player, text: string): ()
	State.interface:FireClient(player, "notice", text)
end

-- A notice shown as a problem: red, with the error sound.
function State.warn(player: Player, text: string): ()
	State.interface:FireClient(player, "notice", text, "warning")
end

return State
