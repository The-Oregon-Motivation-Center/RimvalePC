## story_briefings.gd
## Per-mission cutscene dialogue. Each entry is a list of dialogue beats spoken
## by the regional ACF contact, written in their voice/personality.
##
## Voice guides:
##   Lyra (Plains)        - warm, blunt, farmer-friendly
##   Seris (Shadows)      - quiet, deliberate, low-talker
##   Gronk (Astral)       - terse, military, transmits fast
##   Unit 4 (Terminus)    - clinical, watchling synthetic
##   Arvane (Glass)       - paranoid, sharp, distrusts everything
##   Loxy (Isles)         - cheerful, mischievous, wave-rider
##   Calder (Metro)       - calculating, three-steps-ahead
##   Veyraen (Titans)     - solemn, ancient, careful with words
##   Edda (Peaks)         - scholarly, cross-referencing everything
##   Director Sorn (Sub.) - commander, precise, weight-of-the-world
##
## Each value is a Dictionary:
##   {
##     "lines": [...],          # 3–5 dialogue beats
##     "team_intro": "...",     # one-line scene-setter for the team panel
##   }

extends Node

const BRIEFINGS: Dictionary = {

	# ── Training missions ───────────────────────────────────────────────────
	"t1": {
		"team_intro": "Your team forms up at the Qunorum waystation. Buckles tightening, packs settling.",
		"lines": [
			"Lyra: \"Welcome to the field. I'm not going to sugar this — a village well went bad and people are getting sick.\"",
			"Lyra: \"It's not natural. Someone laced something into the cistern, and they took their time doing it.\"",
			"Lyra: \"Find the underground source, clear whoever's down there, and purify what's left. Bring back any markings you find — patterns matter.\"",
			"Lyra: \"It's a small job by the numbers, but a kid in that village hasn't kept water down in three days. Move quick.\"",
		],
	},
	"t2": {
		"team_intro": "The team checks rope-and-hook gear at the Arachana approach. Web silk on every tunnel mouth.",
		"lines": [
			"Lyra: \"Same hand that fouled Qunorum's water has been busy in Arachana. The web-keepers won't go near the deep grottos.\"",
			"Lyra: \"Corrupted ichor — black, pulses when the lights catch it right. The spiders are acting wrong, and that's saying something for spiders.\"",
			"Lyra: \"The same sigils your team logged at the well are scratched into the cavern walls. So this is a pattern, not a one-off.\"",
			"Lyra: \"Get in, scrub it clean, and figure out who's drawing the symbols. We need a face for this thing.\"",
		],
	},
	"t3": {
		"team_intro": "The team stands at the SubEden treeline. Birds have stopped singing for half a mile around.",
		"lines": [
			"Lyra: \"The fae have left SubEden. That doesn't happen. Not for any reason I've ever heard.\"",
			"Lyra: \"A spring they consider sacred has gone black. The forest around it is dying in concentric rings — that's deliberate geometry.\"",
			"Lyra: \"If you can commune with anything still down there, do it. The fae have witnessed our enemy at work and they know things we don't.\"",
			"Lyra: \"And try not to set anything on fire. The fae are fragile right now and they hold grudges for centuries.\"",
		],
	},
	"t4": {
		"team_intro": "The Endero Heart-Tree is visible from the camp, leaves curling brown despite the season.",
		"lines": [
			"Lyra: \"This is the fourth site. The Heart-Tree of Endero. Tetrasimian and Cervin lineages have tended it for generations.\"",
			"Lyra: \"Roots have been deliberately poisoned. There are ritual implements left in plain sight — like they wanted us to find them.\"",
			"Lyra: \"Purify the tree, destroy the anchors, and recover anything they left behind. The agent is sloppy now or arrogant; either way it's our window.\"",
			"Lyra: \"Pattern's getting clearer with every site. One more and we'll know who we're hunting.\"",
		],
	},
	"t5": {
		"team_intro": "Back at the Qunorum well, but everything's wrong now. The pattern leads here.",
		"lines": [
			"Lyra: \"Velmara Dusk. Corrupted scholar, formerly of the Eternal Library. That's our agent.\"",
			"Lyra: \"Each site you cleared was a node — she was anchoring a working that destabilizes the natural order to power her own ascension.\"",
			"Lyra: \"And the convergence point traces back to Qunorum. Where it all started. She came back to finish the rite where she began it.\"",
			"Lyra: \"Stop her before the final phase locks in. This is the test, agents — let's see what training got you.\"",
		],
	},

	# ── PLAINS — Seraphina Windwalker ───────────────────────────────────────
	"plains-1": {
		"team_intro": "The team rides out across the Plains. Wheat fields look healthy from a distance — until you get close.",
		"lines": [
			"Lyra: \"Glad you came. Half the farmsteads in a day's ride have gone wrong this week.\"",
			"Lyra: \"Old man Hadric forgot his wife's name. His wife. Twenty-three years married. Gone like morning fog.\"",
			"Lyra: \"There's a tracker walking the rows at night. Fae-touched. She whispers to the plants, and the plants drink it in.\"",
			"Lyra: \"Find what she's growing. Burn it if you have to. The Plains can't take another harvest like this one.\"",
		],
	},
	"plains-2": {
		"team_intro": "Down through a sinkhole into the root network. The earth itself is warm.",
		"lines": [
			"Lyra: \"It's worse than fae mischief. There's a vast root network under the Plains and it's woven into a memory-harvest grid.\"",
			"Lyra: \"Every farmer who's lost a name fed it down here. Every story that vanished from a fireside table — gone into this.\"",
			"Lyra: \"Enclave geometry. Unmistakable. They're routing it all to Sublimini Dominus.\"",
			"Lyra: \"Find every anchor. Break every one. Every minute you delay, another farmer wakes up a stranger to themselves.\"",
		],
	},
	"plains-boss": {
		"team_intro": "Wheat parts as the team approaches. Seraphina stands at the convergence, eyes closed, listening.",
		"lines": [
			"Lyra: \"Seraphina Windwalker. She's at the heart node, finishing the first phase of the Final Rite.\"",
			"Lyra: \"She talks to the roots like family. Doesn't think she's doing anything wrong — thinks she's tending them.\"",
			"Lyra: \"The roots whisper back. That's not a metaphor. They've started moving on their own.\"",
			"Lyra: \"If you can talk her down, try. If you can't — and I don't think you can — end her ritual here. The Plains are owed that much.\"",
		],
	},

	# ── SHADOWS BENEATH — Thalia Darksong ───────────────────────────────────
	"shadows-1": {
		"team_intro": "Lantern oil checked, footsteps muffled. The deep tunnels swallow even whispers.",
		"lines": [
			"Seris: \"Quiet down here. That's the first thing.\"",
			"Seris: \"Settlements have been losing names. Not killed — emptied. Witnesses describe shadows that move against the light. A woman's laughter where there is no woman.\"",
			"Seris: \"Three of our agents went after this. None reported back.\"",
			"Seris: \"The geometry on the tunnel walls is the same shape we saw in Plains. Follow the sigils. Listen more than you look. Sight fails first in the deep.\"",
		],
	},
	"shadows-2": {
		"team_intro": "The team descends deeper. The walls are warmer. The patterns are older.",
		"lines": [
			"Seris: \"The whole tunnel network is a circuit. Every junction is a node. Every dead-end is a capacitor.\"",
			"Seris: \"They're charging it. When it discharges, every name in the undercity goes out. Hundreds of people. At once.\"",
			"Seris: \"Disable nodes from the deepest first. Start with the deepest because that's where the cycle resets.\"",
			"Seris: \"Whoever built this — they're patient. Don't be loud. They notice loud.\"",
		],
	},
	"shadows-boss": {
		"team_intro": "The torches go out one by one in front of the team. She is already there. She has been there.",
		"lines": [
			"Seris: \"Thalia Darksong. The Shadowblade.\"",
			"Seris: \"She doesn't speak. She moves through shadow, takes a name, and the silence she leaves is bigger than anything I can describe.\"",
			"Seris: \"She has the names of the three agents who came before you. She wears their silence like armor.\"",
			"Seris: \"Don't give her yours. If she takes one of you, the rest leave. That's the order. That's not negotiable.\"",
		],
	},

	# ── ASTRAL TEAR — Nirael of the Glass Veil ──────────────────────────────
	"astral-1": {
		"team_intro": "The team steps onto the planar bridge. Reality flexes underfoot.",
		"lines": [
			"Gronk: \"Astral Tear. Already unstable. Now weaponized.\"",
			"Gronk: \"Travelers come out hollow. No name. No past. Membrane has anchors driven into it.\"",
			"Gronk: \"Static cuts every fourth word out of my comms. Watch each other's mouths if I drop.\"",
			"Gronk: \"Find the anchors. Pull them. Don't look at the Tear too long.\"",
		],
	},
	"astral-2": {
		"team_intro": "The seam-nodes glow at the edge of perception. The team picks a path between dimensions.",
		"lines": [
			"Gronk: \"Three nodes deeper in. Void energy bleeds through each one. Network's almost done.\"",
			"Gronk: \"If they finish, the Tear becomes a one-way door. We lose the corridor permanently.\"",
			"Gronk: \"They placed the nodes inside the metaphysical layer itself. Not on terrain. In the layer.\"",
			"Gronk: \"Move fast. Stay close. If you blink wrong here, you might not be the same person on the other side.\"",
		],
	},
	"astral-boss": {
		"team_intro": "Nirael waits, blindfolded with glass. She has been here in every version of this moment.",
		"lines": [
			"Gronk: \"Oracle. Nirael. She watches fractures of timelines. Says the Tear opens in every one.\"",
			"Gronk: \"She'll answer questions before you ask. Don't engage. Don't follow her thread.\"",
			"Gronk: \"She's not predicting — she's choosing which timeline to manifest. Different problem entirely.\"",
			"Gronk: \"Prove her wrong. Take the option she doesn't see. Good hunting.\"",
		],
	},

	# ── TERMINUS VOLARUS — Rurik Stormbringer ───────────────────────────────
	"terminus-1": {
		"team_intro": "The team straps in to a sky-skiff. Lightning sketches geometric patterns over the relay towers.",
		"lines": [
			"Unit 4: \"Terminus relays — offline. Sky routes — interrupted. Communication — fragmented.\"",
			"Unit 4: \"Storm patterns: geometric. Confidence: high. Probability of natural origin: under three percent.\"",
			"Unit 4: \"Someone is conducting them. Towers form lattice. Lattice forms ritual.\"",
			"Unit 4: \"Disable the towers. Start at the western link. I will keep the channel open as long as I can. Signal acknowledged. Good luck, agent.\"",
		],
	},
	"terminus-2": {
		"team_intro": "Wind howls between the towers. Each one hums a slightly different note.",
		"lines": [
			"Unit 4: \"Each tower a node. Network converts storm energy directly to SP. Funnel to Sublimini Dominus.\"",
			"Unit 4: \"The Stormclad who built the network — fully aware. He will not stand down.\"",
			"Unit 4: \"He performs combat as theater. Document if possible. We will study after.\"",
			"Unit 4: \"Recommend dismantling network from the outside in. End his performance.\"",
		],
	},
	"terminus-boss": {
		"team_intro": "Rurik stands atop the central tower, arms raised, lightning answering.",
		"lines": [
			"Unit 4: \"Rurik Stormbringer. Elemental mage. Considers his work art.\"",
			"Unit 4: \"He will narrate every bolt. He will pose between strikes. Do not let it distract you.\"",
			"Unit 4: \"He has been preparing this performance for months.\"",
			"Unit 4: \"End the show. Quickly. The Terminus needs its sky back.\"",
		],
	},

	# ── GLASS PASSAGE — Vorath Twins ────────────────────────────────────────
	"glass-1": {
		"team_intro": "The team enters the Passage. Every reflection moves a half-second late.",
		"lines": [
			"Arvane: \"The Glass Passage was always strange. Now it's hostile.\"",
			"Arvane: \"Reflections are too perfect. They know things they shouldn't. They lead travelers into traps and walk out wearing their faces.\"",
			"Arvane: \"Don't trust anything you see in mirrored surfaces. Don't trust anything you see, period.\"",
			"Arvane: \"Look for the layered illusions. Cut them at the source.\"",
		],
	},
	"glass-2": {
		"team_intro": "The geography no longer matches the maps. The sky is below. The ground is wrong.",
		"lines": [
			"Arvane: \"The Vorath Twins have rebuilt the Passage in their own image.\"",
			"Arvane: \"Three mirror-nodes hold the false reality together. Disable all three to see the true terrain.\"",
			"Arvane: \"They will use your own reflections against you. They wear faces of people you trust.\"",
			"Arvane: \"Strike true. The Passage owes you nothing back.\"",
		],
	},
	"glass-boss": {
		"team_intro": "Two figures, mirroring each other perfectly. Or maybe four. Or maybe one.",
		"lines": [
			"Arvane: \"Ilyra and Kael Vorath. They finish each other's sentences. Each other's spells. Each other's attacks.\"",
			"Arvane: \"When one moves, the other mirrors. Their illusions stack — false realities inside false realities.\"",
			"Arvane: \"You cannot kill one without the other. Coordinate. Strike together.\"",
			"Arvane: \"And do not — under any circumstances — let either of them touch a mirror once they are bleeding.\"",
		],
	},

	# ── ISLES — Gorrim Ironfist ─────────────────────────────────────────────
	"isles-1": {
		"team_intro": "Salt spray, wet boots, the team boards the launch. Loxy waves from the wheel.",
		"lines": [
			"Loxy: \"Hi! Yes, I'm the one with the boat. Try not to put any holes in it!\"",
			"Loxy: \"So — fishermen are pulling up machine parts instead of fish. Our divers say there's a metal scaffold the size of a city below the surface.\"",
			"Loxy: \"Enclave sigils on every strut. Whatever they're building, they don't want anyone to see it.\"",
			"Loxy: \"Get down there. Tell me what they're doing. Try not to drown! Wind at your backs!\"",
		],
	},
	"isles-2": {
		"team_intro": "The team dives. Bioluminescent algae outline the engine. It hums a low, wrong note.",
		"lines": [
			"Loxy: \"Ohh, this is bad. It's a giant SP harvester. Tinkering type.\"",
			"Loxy: \"Built into a cavern. Siphons the ocean's natural currents and converts them to raw SP straight to Sublimini.\"",
			"Loxy: \"Engineer's name is Gorrim Ironfist. He's been at it for months. Months!\"",
			"Loxy: \"Disable it before he completes the transfer. He'll be cranky. He's allowed to be cranky after we kick him out.\"",
		],
	},
	"isles-boss": {
		"team_intro": "Gorrim stands knee-deep in seawater, six tools in his hands, looking annoyed.",
		"lines": [
			"Loxy: \"Heads up — Gorrim is REALLY mad you interrupted him.\"",
			"Loxy: \"Seventeen gadgets half-assembled. He'll throw them at you. Mostly the half-finished ones.\"",
			"Loxy: \"He's dwarven-stubborn and he'll fight to the last bolt.\"",
			"Loxy: \"You've got this! End the engine. End the rite. Wind at your backs, friends!\"",
		],
	},

	# ── METROPOLITAN — Zorin Blackscale ─────────────────────────────────────
	"metro-1": {
		"team_intro": "The team enters the Academy by the south gate. Students give nothing — no glance, no greeting.",
		"lines": [
			"Calder: \"The Lyceum. Most respected arcane academy in the Metropolitan. And they have students nobody hired.\"",
			"Calder: \"Enrollment doubled in two months. SP reserves tripled. Dean swears she didn't approve any of it.\"",
			"Calder: \"They're using the Academy infrastructure to train ritual conduits. Production line for the Final Rite.\"",
			"Calder: \"Find the recruiter. Get me a name. We unwind this thread by thread.\"",
		],
	},
	"metro-2": {
		"team_intro": "The Records office. Half the ledgers read in handwriting nobody employed wrote.",
		"lines": [
			"Calder: \"It's not just the Academy. It's the city.\"",
			"Calder: \"Civic records have been quietly rewritten. Hundreds of people report memory gaps that line up with administrative blackouts.\"",
			"Calder: \"They're prepping the entire population for the Rite of Hollow Identity. Erase the city's sense of itself, then erase the people.\"",
			"Calder: \"Disrupt the administrative core. Find their command node. Keep your faces away from cameras until I clear them.\"",
		],
	},
	"metro-boss": {
		"team_intro": "The ley-line grid in the Academy's belly hums to wakefulness. Wards spike. Zorin walks out smiling.",
		"lines": [
			"Calder: \"Zorin Blackscale. Arcane Strategist. He's turned the Academy's ley-line grid into his fortress.\"",
			"Calder: \"He'll quote arcane texts at you while ward arrays cycle through countermeasures. Annoying. Effective.\"",
			"Calder: \"And then — and this is the part nobody warned us about — he transforms.\"",
			"Calder: \"Draconic form. Full scale. End him before the ley grid finishes a third revolution. Watch the rooftops on the way out.\"",
		],
	},

	# ── TITAN'S LAMENT — Morthis the Binder ─────────────────────────────────
	"titans-1": {
		"team_intro": "The wind through the ruins is a low chord. Veyraen has not blinked since the team arrived.",
		"lines": [
			"Veyraen: \"The Titan's Lament has always been a place of mourning.\"",
			"Veyraen: \"The mourning has changed shape. Iron chains run between the ruins. The silence is no longer silence — it is bound SP, humming.\"",
			"Veyraen: \"Someone is harvesting the grief of an age. Someone is crude enough to weigh it, and small enough to spend it.\"",
			"Veyraen: \"Walk gently. The Titans are watching. Do not fail them.\"",
		],
	},
	"titans-2": {
		"team_intro": "Echo-spirits drift between the team like cold mist. Each one is bound to a chain.",
		"lines": [
			"Veyraen: \"He has chained the echo-spirits of the Titans themselves. Each soul a battery for the Final Rite.\"",
			"Veyraen: \"Break the chains from the inside. The ruins do not look kindly on visitors who survive them.\"",
			"Veyraen: \"You will hear voices. Old voices. Names of mountains that no longer exist. Do not answer.\"",
			"Veyraen: \"May the Titans bear witness. Free them.\"",
		],
	},
	"titans-boss": {
		"team_intro": "Morthis at the center of the chain-array, muttering names. He has not slept in weeks.",
		"lines": [
			"Veyraen: \"Morthis the Binder. He knows each soul he has chained by name. He calls this respectful.\"",
			"Veyraen: \"He will add your names to his list. He will say it gently as he does it.\"",
			"Veyraen: \"His chains reach thirty feet. He has not slept since the binding began. He is, at this point, more chain than man.\"",
			"Veyraen: \"End the binding. The Titans will sleep again, or they will not — but either way, end it.\"",
		],
	},

	# ── PEAKS OF ISOLATION — Kaelen the Hollow ──────────────────────────────
	"peaks-1": {
		"team_intro": "The team climbs. The hermits descend. None of them look up.",
		"lines": [
			"Edda: \"The mountain shrines are emptying. Hermits walking down in silence.\"",
			"Edda: \"They respond to nothing. Their faces are wrong — borrowed expressions, postures that don't fit their frames.\"",
			"Edda: \"I've cross-referenced the shrine rosters with the descents. The pattern is undeniable.\"",
			"Edda: \"Find what's drawing them down. Find what's emptying them. Knowledge is armor — record everything.\"",
		],
	},
	"peaks-2": {
		"team_intro": "Bone masks at the altar of every shrine. Stacked. Sorted by size.",
		"lines": [
			"Edda: \"The Rite of Hollow Identity has been performed at multiple shrines.\"",
			"Edda: \"Bone-masks carved from faces. Willing and unwilling alike. Sorted with care, which is the part that bothers me.\"",
			"Edda: \"This isn't memory theft. It's collection. Someone is wearing the faces of the forgotten.\"",
			"Edda: \"Document, don't disturb the altar arrangements. We need the geometry intact for the ritual reversal.\"",
		],
	},
	"peaks-boss": {
		"team_intro": "Kaelen stands on the high shrine, wearing one face — then another — then another.",
		"lines": [
			"Edda: \"Kaelen the Hollow. The face collector. Wears a different stolen face every time you look at him.\"",
			"Edda: \"He'll speak in voices you recognize. Loved ones. Dead friends. Children. Don't engage.\"",
			"Edda: \"His masks are fragments of the unmade. Cracking them releases what's left of those people.\"",
			"Edda: \"Stay sharp. Stay yourselves. Knowledge is armor. Good luck, agents.\"",
		],
	},

	# ── SUBLIMINI DOMINUS — endgame ─────────────────────────────────────────
	"sub-1": {
		"team_intro": "The team stands at the resonance gate. Director Sorn watches from the observation pad.",
		"lines": [
			"Director Sorn: \"All nine regional nodes. Dismantled. Every one.\"",
			"Director Sorn: \"What's left is the Architect, the Heart, and what's between. This is the endgame.\"",
			"Director Sorn: \"Sublimini Dominus is reached through metaphysical resonance. The geometry is wrong. Everything will feel like a dream.\"",
			"Director Sorn: \"Move carefully. The Final Rite is already underway. Don't make me write the after-action report myself. Good hunting.\"",
		],
	},
	"sub-2": {
		"team_intro": "The Culled wait in formation. Eighty silent figures, breathing in unison.",
		"lines": [
			"Director Sorn: \"The Culled. Eighty minds erased into one. They patrol in silence.\"",
			"Director Sorn: \"Their chant disrupts focus. Ranged combat is unreliable. Close the distance.\"",
			"Director Sorn: \"They will not surrender. They cannot. There is no individual left to surrender.\"",
			"Director Sorn: \"Break through. All of them. There is no other path.\"",
		],
	},
	"sub-3": {
		"team_intro": "Korrin's flame answers Veyra's pulse. Two guardians, one approach. The Heart pulses below.",
		"lines": [
			"Director Sorn: \"Korrin of the Forgotten Flame and Veyra's Echo. Last guardians before the Heart.\"",
			"Director Sorn: \"Korrin converts everything he touches into entropy. Veyra has no face — she reads the Heart's pulses as scripture.\"",
			"Director Sorn: \"They believe what they're doing is mercy. Don't waste breath arguing.\"",
			"Director Sorn: \"End them and move on. The Architect is past the next door.\"",
		],
	},
	"sub-final": {
		"team_intro": "High Null Sereth conducts the Rite. The Beating Heart pulses in time. Reality lists toward him.",
		"lines": [
			"Director Sorn: \"High Null Sereth. The Architect. Burned his own name from the Eternal Library to do this.\"",
			"Director Sorn: \"He has no name. No past. Only the Rite. Over a hundred thousand SP channeling into the vessel.\"",
			"Director Sorn: \"Stop the Rite. Stop the Architect. Stop the Heart. Each one matters.\"",
			"Director Sorn: \"This is the end of what the Choir began. It ends with you. Make it count, agents.\"",
		],
	},
}


## Returns the briefing data for a mission, or null if none defined.
func get_briefing(mission_id: String):
	if BRIEFINGS.has(mission_id):
		return BRIEFINGS[mission_id]
	return null
