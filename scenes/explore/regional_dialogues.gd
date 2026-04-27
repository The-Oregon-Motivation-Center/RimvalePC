## regional_dialogues.gd
## Dialogue trees for regional NPCs. Same node shape as TAVERN_DIALOGUES etc.
class_name RegionalDialogues
extends RefCounted

# Helper to keep each tree compact — many NPCs share the same 2-node shape:
# node 0 = intro with (skill choice, leave), node 1 = outcome.
# Reward grammar: gold:N xp:N sp:N ap:N item:X heal:full|half
#                 lose_gold:N rep:FACTION:N intel:TEXT consequence:FLAG

const DIALOGUE_TREES: Dictionary = {

	# ══════════════════ UPPER FORTY (10) ═════════════════════════════════════

	"uf_caelia_default": [
		{"speaker": "Caelia Vex", "text": "Ah, an outsider. Do you know the Duke's mistress hasn't been seen at court in six days? Six. My money says she's either dead or with child — odds even. Which would you bet on?",
			"choices": [
				{"label": "Whisper a rumor back (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "gold:25|intel:Caelia trades rumor-for-rumor", "fail_reward": ""},
				{"label": "Observe her tells (Intuition)", "skill": "Intuition", "dc_offset": -1, "next_pass": 3, "next_fail": 2, "reward": "xp:20|intel:Caelia is afraid — she knows what happened", "fail_reward": ""},
				{"label": "Excuse yourself", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Caelia Vex", "text": "Oh, you ARE useful. Fine — mistress was seen boarding a carriage south. Thornwall Keeps. My informant doesn't lie to me.", "choices": [{"label": "Interesting.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:uf_mistress_south", "fail_reward": ""}]},
		{"speaker": "Caelia Vex", "text": "Hm. You're dull. Move along before you ruin my afternoon.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Caelia Vex", "text": "You see too much for an outsider. Good. The court needs more of that.", "choices": [{"label": "Leave quietly", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "rep:Crown:5", "fail_reward": ""}]},
	],
	"uf_corin_default": [
		{"speaker": "Master Corin", "text": "Examinations are next week and half my students couldn't conjugate a resonance glyph if their lives depended on it. Which — in the field — they absolutely would.",
			"choices": [
				{"label": "Offer to guest-lecture (Learnedness)", "skill": "Learnedness", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "xp:50|rep:Academy:5|intel:Corin owes you a favor", "fail_reward": ""},
				{"label": "Ask what's wrong (Intuition)", "skill": "Intuition", "dc_offset": 1, "next_pass": 3, "next_fail": 2, "reward": "intel:Corin is pressured to pass a Noble Row student", "fail_reward": ""},
				{"label": "Wish luck", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Master Corin", "text": "The students actually listened. Remarkable. Here — a departmental token. Exchange it at the Tower of Knowledge.", "choices": [{"label": "Thank them.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "item:Academy Primer|xp:20", "fail_reward": ""}]},
		{"speaker": "Master Corin", "text": "I'm sure you mean well. I should return to preparation.", "choices": [{"label": "Of course.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Master Corin", "text": "You see it. A Fensley boy. Failing three marks. Noble Row won't take dismissal well. I either bend or I break.", "choices": [{"label": "File it away.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:uf_corin_pressured|xp:20", "fail_reward": ""}]},
	],
	"uf_ardal_default": [
		{"speaker": "Sgt. Ardal Stonewall", "text": "Nothing to report here, traveler. Move along. Unless you've got something to report, in which case I'm all ears and short on good news this week.",
			"choices": [
				{"label": "Volunteer for night patrol (Military)", "skill": "Military", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "gold:60|xp:40|rep:Crown:3", "fail_reward": ""},
				{"label": "Ask what's happening (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 3, "next_fail": 2, "reward": "intel:Three guards vanished near Music District this week", "fail_reward": ""},
				{"label": "Move along", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Sgt. Ardal Stonewall", "text": "Good eye, good instinct, good evening. Here's your stipend. Don't get killed — paperwork's a nightmare.", "choices": [{"label": "Understood.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Sgt. Ardal Stonewall", "text": "Hmph. Move along.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Sgt. Ardal Stonewall", "text": "Three of my people. Gone. Not deserting — I know my squad. Something took them. Keep eyes on the rooftops after dark.", "choices": [{"label": "Noted.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:uf_guards_missing", "fail_reward": ""}]},
	],
	"uf_vixi_default": [
		{"speaker": "Vixi \"Sparks\"", "text": "Wait wait wait — don't move. Don't BREATHE on the blue vial. Step left. GOOD. You have a lovely presence for someone who nearly got us both melted. Shopping?",
			"choices": [
				{"label": "Haggle for a gadget (Speechcraft)", "skill": "Speechcraft", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "item:Smoke Bomb|item:Energy Tonic", "fail_reward": "lose_gold:20"},
				{"label": "Watch her work (Perception)", "skill": "Perception", "dc_offset": 0, "next_pass": 3, "next_fail": 2, "reward": "xp:30|intel:Vixi's gadgets are repurposed Academy prototypes", "fail_reward": ""},
				{"label": "Browse silently", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Vixi \"Sparks\"", "text": "Fine. FINE. Take them. If anyone asks, you took them while I wasn't looking.", "choices": [{"label": "Deal.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Vixi \"Sparks\"", "text": "Hah! No sale. Come back when you can afford my attention.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Vixi \"Sparks\"", "text": "Sharp eye. You saw the seal. Academy throws out failed prototypes. I find new homes. Don't mention this to a certain magister.", "choices": [{"label": "Your secret.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:uf_vixi_contraband", "fail_reward": ""}]},
	],
	"uf_teros_default": [
		{"speaker": "Elder Teros", "text": "Forty years on the Raven Court bench. I sentenced men, and sometimes the wrong men. You look like someone chasing a debt of your own.",
			"choices": [
				{"label": "Ask for case history (Learnedness)", "skill": "Learnedness", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "xp:40|intel:Caelia Vex was a witness at the Vex trials, never a suspect", "fail_reward": ""},
				{"label": "Let him talk (Intuition)", "skill": "Intuition", "dc_offset": -1, "next_pass": 3, "next_fail": 3, "reward": "xp:25", "fail_reward": ""},
				{"label": "Good day", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Elder Teros", "text": "You'd make a fair clerk. The Vex case — I'd look there, if I were chasing court ghosts.", "choices": [{"label": "Thank you.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Elder Teros", "text": "The dead don't care for idle company. Go.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Elder Teros", "text": "The hardest rulings were the ones that felt clean. Clean cases are usually framed. Remember that.", "choices": [{"label": "I will.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"uf_lyra_default": [
		{"speaker": "Lyra Moonshadow", "text": "Information is cheap. Good information is expensive. Verified information? You can't afford it. What are we trading, dear?",
			"choices": [
				{"label": "Offer a rumor (Speechcraft)", "skill": "Speechcraft", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "intel:A midnight cipher at the Grape unlocks the Mint vault tally", "fail_reward": ""},
				{"label": "Read her first (Intuition)", "skill": "Intuition", "dc_offset": 2, "next_pass": 3, "next_fail": 2, "reward": "xp:40|intel:Lyra's strings lead back to Noble Row", "fail_reward": ""},
				{"label": "Pass for now", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Lyra Moonshadow", "text": "Interesting. My ear is yours for the evening. I owe you one.", "choices": [{"label": "Noted.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:uf_lyra_owes_favor", "fail_reward": ""}]},
		{"speaker": "Lyra Moonshadow", "text": "Come back when you have something worth my silence.", "choices": [{"label": "Fair.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Lyra Moonshadow", "text": "Careful. You looked too long. Either you're brave or you're stupid. I have uses for either.", "choices": [{"label": "Keep your uses.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"uf_brendan_default": [
		{"speaker": "Brendan Coppervein", "text": "Thirty tallies, thirty chests, thirty seals. Every morning for eleven years. And SOMEHOW — one has gone missing THIS week.",
			"choices": [
				{"label": "Offer to audit (Learnedness)", "skill": "Learnedness", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "gold:80|xp:30|intel:The missing tally stamped for Noble Row", "fail_reward": ""},
				{"label": "Spot the error (Perception)", "skill": "Perception", "dc_offset": 1, "next_pass": 3, "next_fail": 2, "reward": "xp:40", "fail_reward": ""},
				{"label": "Wish luck", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Brendan Coppervein", "text": "You found it. Entry 14-B, wrong column, wrong seal. Crown thanks you, accounting thanks you more.", "choices": [{"label": "Glad to help.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Brendan Coppervein", "text": "Kind of you. I'll sort it. Eventually. Probably.", "choices": [{"label": "Good luck.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Brendan Coppervein", "text": "Ha! Row 14, column 3, smudged seal. You've a clerk's eye. Drinks on me at the Purple Grape.", "choices": [{"label": "I'll hold you to it.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:uf_brendan_owes_drink", "fail_reward": ""}]},
	],
	"uf_avella_default": [
		{"speaker": "Sister Avella", "text": "Bread for the faithful, bread for the fallen, bread for anyone who needs it. If you're hungry, sit. If you're troubled, also sit. If you're neither — help me.",
			"choices": [
				{"label": "Donate (40g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:40|rep:Church:8|xp:30", "fail_reward": ""},
				{"label": "Ask after orphans (Intuition)", "skill": "Intuition", "dc_offset": 0, "next_pass": 2, "next_fail": 3, "reward": "intel:Three orphans vanished from Raven Court this month", "fail_reward": ""},
				{"label": "Take a loaf", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "item:Field Rations", "fail_reward": ""}]},
		{"speaker": "Sister Avella", "text": "Bless you. The light remembers. Go gently and with full hands.", "choices": [{"label": "Be well.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Sister Avella", "text": "Three of them. Three. The court says they ran; I say they were TAKEN. Please — if anyone listens — they were children.", "choices": [{"label": "I'll keep watch.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:uf_avella_orphans_request", "fail_reward": ""}]},
		{"speaker": "Sister Avella", "text": "Oh, they're managing. Children do. May the light guide your path.", "choices": [{"label": "And yours.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"uf_hollo_default": [
		{"speaker": "Magister Hollo", "text": "Yes yes, what, an adventurer, what do you want, I'm three chapters behind on the resonance journal. Make it fast.",
			"choices": [
				{"label": "Offer to grade (Learnedness)", "skill": "Learnedness", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "xp:50|rep:Academy:3|intel:Hollo suspects a Nimbari is selling Academy prototypes", "fail_reward": ""},
				{"label": "Compliment the journal (Speechcraft)", "skill": "Speechcraft", "dc_offset": 2, "next_pass": 3, "next_fail": 2, "reward": "item:Academy Primer|xp:15", "fail_reward": ""},
				{"label": "Never mind", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Magister Hollo", "text": "You can GRADE? Bless. You. Bring evidence on the Nimbari if you find her.", "choices": [{"label": "Noted.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Magister Hollo", "text": "Mm. Very busy. Come back.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Magister Hollo", "text": "You — you READ the journal? Well. Here, a primer. Go on.", "choices": [{"label": "Thank you.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"uf_pip_default": [
		{"speaker": "Pip the Urchin", "text": "Hey mister/missus/whoever, you got a copper? A half-copper? A CRUST? I'll tell you a SECRET for a crust of bread.",
			"choices": [
				{"label": "Give 5g", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:5|intel:Three kids got into a black carriage near Raven Court last week", "fail_reward": ""},
				{"label": "Win his trust (Creature Handling)", "skill": "Creature Handling", "dc_offset": -1, "next_pass": 2, "next_fail": 3, "reward": "intel:A hidden route runs through the Cradling Depths tunnels", "fail_reward": ""},
				{"label": "Ruffle hair & go", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Pip the Urchin", "text": "*bites coin* It's real! Black carriage. Shiny one. Big K and a bird crest. Ate three kids and drove off.", "choices": [{"label": "Thanks, Pip.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:uf_pip_saw_carriage", "fail_reward": ""}]},
		{"speaker": "Pip the Urchin", "text": "Okay you're not scary. There's a crack behind the smithy, drops into the old tunnels. Don't tell nobody.", "choices": [{"label": "Your secret.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:uf_pip_tunnel_route", "fail_reward": ""}]},
		{"speaker": "Pip the Urchin", "text": "*darts off* Never mind! Forget you saw me!", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],

	# ══════════════════ LOWER FORTY (10) — 2-node compact format ═════════════

	"lf_hax_default": [
		{"speaker": "Foreman Hax", "text": "Shift change in ten. You're blocking the rail line, friend. Unless you can swing a hammer, move.",
			"choices": [
				{"label": "Offer to help (Military)", "skill": "Military", "dc_offset": 0, "next_pass": 1, "next_fail": 1, "reward": "gold:40|xp:30", "fail_reward": "lose_gold:10"},
				{"label": "Ask about the accident (Intuition)", "skill": "Intuition", "dc_offset": 1, "next_pass": 1, "next_fail": 1, "reward": "intel:The foundry 'accident' last week was sabotage — Yonne's inspection is a cover", "fail_reward": ""},
				{"label": "Move aside", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Foreman Hax", "text": "Aye. Go on then.", "choices": [{"label": "Good day.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"lf_vael_default": [
		{"speaker": "Riveted Vael", "text": "Pressure valve's off by a quarter turn and Hax doesn't care. Next rupture's on him, not me.",
			"choices": [
				{"label": "Diagnose it (Learnedness)", "skill": "Learnedness", "dc_offset": 0, "next_pass": 1, "next_fail": 1, "reward": "xp:40|rep:Artisans:2", "fail_reward": ""},
				{"label": "Offer gadgets (Speechcraft)", "skill": "Speechcraft", "dc_offset": 1, "next_pass": 1, "next_fail": 1, "reward": "item:Smoke Bomb", "fail_reward": ""},
				{"label": "Leave", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Riveted Vael", "text": "At least someone gets it. Don't be a stranger.", "choices": [{"label": "Take care.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"lf_jass_default": [
		{"speaker": "\"Smokey\" Jass", "text": "Lungs sound like a kettle. Thirty years down the shaft'll do that. You ever work stone? No? Lucky.",
			"choices": [
				{"label": "Buy him a drink (5g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:5|intel:Old shaft under Steel Works is unsealed — kids use it", "fail_reward": ""},
				{"label": "Ask about tremors (Survival)", "skill": "Survival", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "intel:Tremors under Lower Forty are new — started last moon", "fail_reward": ""},
				{"label": "Leave", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "\"Smokey\" Jass", "text": "Come back anytime. I ain't going nowhere fast.", "choices": [{"label": "Take care.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"lf_yonne_default": [
		{"speaker": "Magister Yonne", "text": "This is a routine inspection. Routine. My ledger says the foundry incident was equipment failure and that is what the ledger will continue to say.",
			"choices": [
				{"label": "Press for truth (Speechcraft)", "skill": "Speechcraft", "dc_offset": 2, "next_pass": 1, "next_fail": 2, "reward": "intel:Yonne was paid to rule the foundry a 'failure' — sabotage confirmed", "fail_reward": ""},
				{"label": "Observe tells (Intuition)", "skill": "Intuition", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "xp:30|consequence:lf_yonne_lying", "fail_reward": ""},
				{"label": "Leave", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Magister Yonne", "text": "...say nothing of this. Please. There's good coin in silence.", "choices": [{"label": "We'll see.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:lf_yonne_bribe_offered", "fail_reward": ""}]},
		{"speaker": "Magister Yonne", "text": "Exactly. Routine. Good day.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"lf_gritta_default": [
		{"speaker": "Gritta Pipe", "text": "Soot in my lungs, soot in my hair, soot in my DREAMS. And the furnace eats coin faster than it eats coal.",
			"choices": [
				{"label": "Offer 10g", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:10|rep:Workers:3", "fail_reward": ""},
				{"label": "Ask about conditions (Perception)", "skill": "Perception", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "intel:Furnace tower emits strange sparks at night — not natural combustion", "fail_reward": ""},
				{"label": "Leave", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Gritta Pipe", "text": "Heart of gold, you. Watch your lungs up here.", "choices": [{"label": "You too.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"lf_mara_default": [
		{"speaker": "Sooty Mara", "text": "Hi. Don't tell the guards. I'm not stealing. I'm FINDING. There's a difference.",
			"choices": [
				{"label": "Win her trust (Creature Handling)", "skill": "Creature Handling", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "intel:The scavenger ring is fencing in West End Gullet — Mara knows the handoff spot", "fail_reward": ""},
				{"label": "Give 2g quietly", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:2|intel:Kid gangs run the north sewers", "fail_reward": ""},
				{"label": "Look away", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Sooty Mara", "text": "You're alright. If you see a tall lady with a scar, that's Mum Wick. Don't cross her.", "choices": [{"label": "Noted.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:lf_mara_trusts", "fail_reward": ""}]},
		{"speaker": "Sooty Mara", "text": "Guard's coming! *bolts*", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"lf_rathe_default": [
		{"speaker": "Captain Rathe", "text": "Undercity guard. Fewer rules, harder nights. The scavenger ring's grown teeth — I can't police them alone.",
			"choices": [
				{"label": "Take the contract (Military)", "skill": "Military", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "gold:80|xp:50", "fail_reward": "lose_gold:15"},
				{"label": "Gather intel (Perception)", "skill": "Perception", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "intel:Mum Wick runs the scavengers from a West End Gullet safehouse", "fail_reward": ""},
				{"label": "Pass", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Captain Rathe", "text": "You're a help. Come back when you've got more.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Captain Rathe", "text": "Keep your purse close walking out.", "choices": [{"label": "Understood.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"lf_whisperer_default": [
		{"speaker": "The Whisperer", "text": "You look for me, or I look for you? Doesn't matter. Whispers flow one direction — out. Pay for the flow or listen to the silence.",
			"choices": [
				{"label": "Buy intel (25g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:25|intel:Noble Row pays the foundry 'inspector' — money trails to Vox Heights", "fail_reward": ""},
				{"label": "Stare them down (Intuition)", "skill": "Intuition", "dc_offset": 2, "next_pass": 2, "next_fail": -1, "reward": "intel:The Whisperer answers to Lyra Moonshadow", "fail_reward": ""},
				{"label": "Walk past", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "The Whisperer", "text": "Pleasure. Fade.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "The Whisperer", "text": "*vanishes into the crowd*", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:lf_whisperer_linked_lyra", "fail_reward": ""}]},
	],
	"lf_bard_default": [
		{"speaker": "Bard of the Anvil", "text": "Song for the smokestacks, song for the soot — ballads of the under-folk, if you've coin for the bowl.",
			"choices": [
				{"label": "Perform alongside (Perform)", "skill": "Perform", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "gold:20|xp:25|rep:Artisans:2", "fail_reward": ""},
				{"label": "Drop a coin (3g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:3|rep:Artisans:1", "fail_reward": ""},
				{"label": "Walk on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Bard of the Anvil", "text": "The crowd LOVED you. My set's yours anytime.", "choices": [{"label": "Cheers.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Bard of the Anvil", "text": "Rough crowd. Mine or yours.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"lf_brall_default": [
		{"speaker": "Sister Brall", "text": "Twenty-six beds and twenty-nine souls tonight. We'll manage. We always do. Unless you can help.",
			"choices": [
				{"label": "Donate 30g", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:30|rep:Church:5|xp:25", "fail_reward": ""},
				{"label": "Medical aid (Medical)", "skill": "Medical", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "xp:40|rep:Church:3", "fail_reward": ""},
				{"label": "Bless them and go", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Sister Brall", "text": "Bless you, child. The light notices such things.", "choices": [{"label": "Be well.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],

	# ══════════════════ ETERNAL LIBRARY (10) ═════════════════════════════════

	"el_vellum_default": [
		{"speaker": "Archivist Vellum", "text": "A manuscript has gone missing. A real one, not a misfiled copy. Quiet catastrophe. Tell no one.",
			"choices": [
				{"label": "Investigate (Learnedness)", "skill": "Learnedness", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "xp:50|intel:The missing manuscript describes pre-Veil cosmology", "fail_reward": ""},
				{"label": "Offer discretion (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "rep:Academy:5|gold:30", "fail_reward": ""},
				{"label": "Decline", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Archivist Vellum", "text": "You'll hear from me when the trail opens.", "choices": [{"label": "Noted.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:el_manuscript_accepted", "fail_reward": ""}]},
		{"speaker": "Archivist Vellum", "text": "Then this conversation didn't happen.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"el_quill_default": [
		{"speaker": "Scribe Quill", "text": "Ink-stained, wrist-cramped, perfectly happy. Do you need a copy of something? I charge by the page.",
			"choices": [
				{"label": "Commission a chart (20g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:20|item:Scroll of Protection", "fail_reward": ""},
				{"label": "Gossip (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "intel:Thorne checks out forbidden volumes nightly — Vellum looks the other way", "fail_reward": ""},
				{"label": "Move on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Scribe Quill", "text": "Back soon?", "choices": [{"label": "Soon.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"el_thorne_default": [
		{"speaker": "Master Thorne", "text": "Forbidden volumes are forbidden for reasons. Most of which are bad. I read them anyway.",
			"choices": [
				{"label": "Discuss lore (Arcane)", "skill": "Arcane", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "sp:4|xp:40|intel:Pre-Veil cosmology describes a 'Before the Stars' state", "fail_reward": ""},
				{"label": "Ask what he reads (Intuition)", "skill": "Intuition", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "intel:Thorne may have taken the missing manuscript — his face went still", "fail_reward": ""},
				{"label": "Leave him to it", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Master Thorne", "text": "Come back. Few can talk these matters.", "choices": [{"label": "I will.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Master Thorne", "text": "If you'll excuse me.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"el_heidi_default": [
		{"speaker": "Young Heidi", "text": "Sorry! Sorry. I dropped a— don't look at me, I— *fumbles scrolls*",
			"choices": [
				{"label": "Help her (Creature Handling)", "skill": "Creature Handling", "dc_offset": -1, "next_pass": 1, "next_fail": 1, "reward": "xp:20|intel:Heidi saw Thorne carry a manuscript out last night", "fail_reward": ""},
				{"label": "Reassure (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 1, "next_fail": 1, "reward": "rep:Academy:2", "fail_reward": ""},
				{"label": "Walk past", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Young Heidi", "text": "Th-thanks. I owe you.", "choices": [{"label": "No trouble.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"el_dross_default": [
		{"speaker": "Librarian Dross", "text": "SILENCE in the stacks. SIL-ENCE. If you cannot maintain it, depart.",
			"choices": [
				{"label": "Apologize (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "rep:Academy:2", "fail_reward": ""},
				{"label": "Match her sternness (Intuition)", "skill": "Intuition", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "intel:Dross knows every borrow record — she keeps a second ledger in her desk", "fail_reward": ""},
				{"label": "Lower your voice", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Librarian Dross", "text": "Acceptable. Carry on quietly.", "choices": [{"label": "Thank you.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Librarian Dross", "text": "OUT.", "choices": [{"label": "*leaves*", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"el_patron_default": [
		{"speaker": "The Hooded Patron", "text": "...",
			"choices": [
				{"label": "Try to read them (Intuition)", "skill": "Intuition", "dc_offset": 2, "next_pass": 1, "next_fail": 2, "reward": "xp:40|intel:The Patron is not human — their shadow moves wrong", "fail_reward": ""},
				{"label": "Offer a book (Learnedness)", "skill": "Learnedness", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "sp:3|rep:Unknown:2", "fail_reward": ""},
				{"label": "Respect the silence", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "The Hooded Patron", "text": "*nods once*", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:el_patron_acknowledged", "fail_reward": ""}]},
		{"speaker": "The Hooded Patron", "text": "*does not look up*", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"el_reis_default": [
		{"speaker": "Cartographer Reis", "text": "Maps lie, traveler. All of them. Mine lie less than most. Need one?",
			"choices": [
				{"label": "Commission (40g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:40|intel:Reis maps the hidden passages under Upper Forty — tunnels connect Lower Forty & West End", "fail_reward": ""},
				{"label": "Discuss geography (Survival)", "skill": "Survival", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "xp:30", "fail_reward": ""},
				{"label": "Not today", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Cartographer Reis", "text": "May your paths stay straight.", "choices": [{"label": "And yours.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"el_bind_default": [
		{"speaker": "Brother Bind", "text": "A good binding outlasts the reader. Most of my work outlasts the Library itself — not bragging. Geometry.",
			"choices": [
				{"label": "Repair a book (15g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:15|item:Scroll of Protection", "fail_reward": ""},
				{"label": "Ask about forgeries (Perception)", "skill": "Perception", "dc_offset": 1, "next_pass": 1, "next_fail": -1, "reward": "intel:The missing manuscript's binding had been re-sewn — someone replaced pages", "fail_reward": ""},
				{"label": "Leave", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Brother Bind", "text": "Peace to your pages.", "choices": [{"label": "And yours.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"el_marcellia_default": [
		{"speaker": "Lady Marcellia", "text": "Philanthropy is easier than politics. I fund the Library because I can, and because books don't disappoint.",
			"choices": [
				{"label": "Compliment her (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "rep:Noble Row:3|xp:20", "fail_reward": ""},
				{"label": "Ask about the missing manuscript (Intuition)", "skill": "Intuition", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "intel:Marcellia has been buying pre-Veil texts privately — she wants the missing one", "fail_reward": ""},
				{"label": "Bow and go", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Lady Marcellia", "text": "Do come by again.", "choices": [{"label": "I shall.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Lady Marcellia", "text": "A fine day to you.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"el_wanderer_default": [
		{"speaker": "The Wanderer", "text": "Every library is the same library. Every library is a different one. You are still early.",
			"choices": [
				{"label": "Ask meaning (Arcane)", "skill": "Arcane", "dc_offset": 2, "next_pass": 1, "next_fail": 2, "reward": "sp:5|intel:The Wanderer walks between libraries across many worlds", "fail_reward": ""},
				{"label": "Offer tea (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "xp:30|rep:Unknown:1", "fail_reward": ""},
				{"label": "Nod and go", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "The Wanderer", "text": "We meet again, in some sense.", "choices": [{"label": "*nods*", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:el_wanderer_met", "fail_reward": ""}]},
		{"speaker": "The Wanderer", "text": "*is already gone when you look back*", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],

	# ══════════════════ WEST END GULLET (10) ═════════════════════════════════

	"weg_echo_default": [
		{"speaker": "Echo Caldera", "text": "The fountain speaks, when it wants. Yesterday it named three people who won't be born for twelve years. Troubling phrasing.",
			"choices": [
				{"label": "Listen with her (Arcane)", "skill": "Arcane", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "sp:4|intel:The mirror curse is tied to the fountain — they share a resonance", "fail_reward": ""},
				{"label": "Calm her (Creature Handling)", "skill": "Creature Handling", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "xp:30|rep:West End:2", "fail_reward": ""},
				{"label": "Back away", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Echo Caldera", "text": "Good. You hear it too. That is a kindness in this district.", "choices": [{"label": "Walk gently.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Echo Caldera", "text": "*whispers at the water's surface*", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"weg_sint_default": [
		{"speaker": "Mirrorwright Sint", "text": "Each mirror here shows who you'd be if one choice had gone differently. Buyer beware — some are correct.",
			"choices": [
				{"label": "Purchase (50g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:50|item:Scroll of Protection|intel:Sint warns: the cursed mirrors were made by the Enclave, not by her", "fail_reward": ""},
				{"label": "Interrogate her (Intuition)", "skill": "Intuition", "dc_offset": 1, "next_pass": 1, "next_fail": -1, "reward": "intel:Sint fears her mirrors are being replaced with cursed ones overnight", "fail_reward": ""},
				{"label": "Just browse", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Mirrorwright Sint", "text": "Tell no one the mirror lied to you. They always lie. That is the point.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"weg_shadow_default": [
		{"speaker": "The Off-Shadow", "text": "You'll want the underground for what's coming. I'm the underground. What are you buying?",
			"choices": [
				{"label": "Bargain for passage (Speechcraft)", "skill": "Speechcraft", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "intel:The sewer route from West End to Upper Forty bypasses all guard posts", "fail_reward": ""},
				{"label": "Pay 30g flat", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:30|intel:The sewer route is clear, for now", "fail_reward": ""},
				{"label": "Not today", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "The Off-Shadow", "text": "*nods once; is already elsewhere*", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "The Off-Shadow", "text": "Come back with sharper questions.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"weg_brix_default": [
		{"speaker": "Wrong-Way Brix", "text": "Left is right and right is left and also sometimes down? I get paid to guide tourists. They never come back. Don't worry about it.",
			"choices": [
				{"label": "Hire him (10g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:10|intel:The district's geometry rearranges nightly — maps expire at midnight", "fail_reward": ""},
				{"label": "Help him get oriented (Survival)", "skill": "Survival", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "xp:20|rep:West End:1", "fail_reward": ""},
				{"label": "Walk away carefully", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Wrong-Way Brix", "text": "Was that... was that helpful? It felt helpful. Okay.", "choices": [{"label": "Go well.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"weg_herald_default": [
		{"speaker": "The Sovereign's Herald", "text": "HEAR YE. HEAR YE. The Shadow Sovereign's sixteenth decree of the quarter. Listen closely; there is no second reading.",
			"choices": [
				{"label": "Listen carefully (Perception)", "skill": "Perception", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "intel:The sixteenth decree authorizes the Sovereign to requisition any mirror within the district", "fail_reward": ""},
				{"label": "Interrupt politely (Speechcraft)", "skill": "Speechcraft", "dc_offset": 2, "next_pass": 1, "next_fail": 2, "reward": "rep:Crown:-1|xp:20", "fail_reward": ""},
				{"label": "Keep walking", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "The Sovereign's Herald", "text": "THUS SPOKE. Move along.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "The Sovereign's Herald", "text": "YOU INTERRUPT THE SOVEREIGN'S WORD. OFF. OFF OFF OFF.", "choices": [{"label": "*leaves*", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"weg_malbena_default": [
		{"speaker": "Aunt Malbena", "text": "House tilts left since Tuesday. I've tilted with it. Tea?",
			"choices": [
				{"label": "Accept tea (Creature Handling)", "skill": "Creature Handling", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "heal:half|rep:West End:2|intel:Malbena's cellar door leads somewhere it shouldn't — occasionally", "fail_reward": ""},
				{"label": "Politely decline (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "xp:15", "fail_reward": ""},
				{"label": "Excuse yourself", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Aunt Malbena", "text": "Mind the step down. And up. And sideways.", "choices": [{"label": "Thank you.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"weg_tom_default": [
		{"speaker": "Silent Tom", "text": "*plays a slow, strange melody on a lute. The notes seem to curl the air.*",
			"choices": [
				{"label": "Sit and listen (Perform)", "skill": "Perform", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "sp:3|xp:30|rep:Artisans:2", "fail_reward": ""},
				{"label": "Tip 5g", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:5|heal:half", "fail_reward": ""},
				{"label": "Move on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Silent Tom", "text": "*bows wordlessly*", "choices": [{"label": "*bows back*", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Silent Tom", "text": "*keeps playing*", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"weg_choir_default": [
		{"speaker": "The Echoing Choir", "text": "We sing to the fountain. The fountain sings back, sometimes. The harmonies are not pleasant but they are accurate.",
			"choices": [
				{"label": "Join the chant (Perform)", "skill": "Perform", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "sp:4|xp:40|intel:The Choir believes the mirror curse feeds on unsung grief", "fail_reward": ""},
				{"label": "Ask about the curse (Arcane)", "skill": "Arcane", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "intel:The curse traces to an Enclave ritual 40 years past", "fail_reward": ""},
				{"label": "Step back", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "The Echoing Choir", "text": "Your voice is welcome here. Rare.", "choices": [{"label": "Thank you.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "The Echoing Choir", "text": "The fountain will forgive.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"weg_gor_default": [
		{"speaker": "Twisted Smith Gor", "text": "The anvil bends where it shouldn't. I work with it. Metal listens if you ask wrong enough.",
			"choices": [
				{"label": "Repair equipment (20g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:20|heal:half", "fail_reward": ""},
				{"label": "Compliment the work (Learnedness)", "skill": "Learnedness", "dc_offset": 1, "next_pass": 1, "next_fail": -1, "reward": "rep:Artisans:2|intel:Gor's twisted iron repels mirror reflections — useful against the curse", "fail_reward": ""},
				{"label": "Walk on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Twisted Smith Gor", "text": "Come back when something's broken. It will be.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"weg_lan_default": [
		{"speaker": "Moth Lan", "text": "Lamps for the district. One candle keeps honest shadows honest. Two keeps them HAPPY. Three — don't.",
			"choices": [
				{"label": "Buy a lamp (15g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:15|item:Smoke Bomb|intel:Lan's lamps slow the nightly geometry-shift", "fail_reward": ""},
				{"label": "Ask about the dark (Perception)", "skill": "Perception", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "intel:Certain streets in West End only exist between 2 AM and 4 AM", "fail_reward": ""},
				{"label": "Browse only", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Moth Lan", "text": "Walk lit, walk twice.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],

	# ══════════════════ CRADLING DEPTHS (10) ═════════════════════════════════

	"cd_seris_default": [
		{"speaker": "High Oracle Seris", "text": "A vision came last night. A wheel of fire rolls toward the valley. Whether it heals or consumes depends on who stands before it.",
			"choices": [
				{"label": "Ask for the full vision (Arcane)", "skill": "Arcane", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "sp:5|intel:Seris's vision names the valley — Vulcan Valley is the wheel", "fail_reward": ""},
				{"label": "Offer prayer (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "rep:Church:5|heal:full", "fail_reward": ""},
				{"label": "Walk on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "High Oracle Seris", "text": "Travel well. The wheel rolls regardless.", "choices": [{"label": "Blessings.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:cd_seris_vision", "fail_reward": ""}]},
		{"speaker": "High Oracle Seris", "text": "The vision is not for you today.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"cd_aelan_default": [
		{"speaker": "Priest Aelan", "text": "Welcome, traveler. The temple is open. Your troubles are smaller here, if you let them be.",
			"choices": [
				{"label": "Confession (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "heal:full|sp:2", "fail_reward": ""},
				{"label": "Donate 30g", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:30|rep:Church:5|xp:25", "fail_reward": ""},
				{"label": "Leave a candle", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Priest Aelan", "text": "The light goes with you.", "choices": [{"label": "And with you.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"cd_bel_default": [
		{"speaker": "Crystalkeeper Bel", "text": "Each crystal here holds a memory — not a prayer. The distinction matters. Don't touch them.",
			"choices": [
				{"label": "Read a crystal (Arcane)", "skill": "Arcane", "dc_offset": 2, "next_pass": 1, "next_fail": 2, "reward": "sp:3|intel:The crystals record a pre-Veil event — the 'Silencing'", "fail_reward": ""},
				{"label": "Offer cleaning supplies (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "xp:25|rep:Church:2", "fail_reward": ""},
				{"label": "Keep your hands in your pockets", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Crystalkeeper Bel", "text": "Respectful. Good. Rare.", "choices": [{"label": "Thank you.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Crystalkeeper Bel", "text": "Mind yourself.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"cd_kira_default": [
		{"speaker": "Ichor-Touched Kira", "text": "The ichor sings through my veins. It is not pain. It is not joy. It is an instruction. I follow it as best I can.",
			"choices": [
				{"label": "Ask what it says (Intuition)", "skill": "Intuition", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "sp:4|intel:The ichor commands Kira to find a 'Vessel' — meaning unclear", "fail_reward": ""},
				{"label": "Offer to help (Medical)", "skill": "Medical", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "xp:35|heal:full", "fail_reward": ""},
				{"label": "Step back", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Ichor-Touched Kira", "text": "The ichor approves of you. This is rare.", "choices": [{"label": "I'll watch for it.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:cd_ichor_marked", "fail_reward": ""}]},
		{"speaker": "Ichor-Touched Kira", "text": "It doesn't know you. Perhaps later.", "choices": [{"label": "Perhaps.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"cd_odam_default": [
		{"speaker": "Lightsmith Odam", "text": "Sacred smithing is normal smithing with prayer in the hammer-strike. Mostly it's the hammer.",
			"choices": [
				{"label": "Buy a blessed edge (60g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:60|item:Iron Shield", "fail_reward": ""},
				{"label": "Discuss craft (Learnedness)", "skill": "Learnedness", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "xp:30|rep:Artisans:2", "fail_reward": ""},
				{"label": "Move on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Lightsmith Odam", "text": "Light strike your blade true.", "choices": [{"label": "Thank you.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"cd_len_default": [
		{"speaker": "Chorister Len", "text": "The cathedral acoustics were built to swallow one note and release another. Try it — hum any pitch.",
			"choices": [
				{"label": "Sing with him (Perform)", "skill": "Perform", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "sp:3|xp:30|rep:Church:3", "fail_reward": ""},
				{"label": "Listen analytically (Arcane)", "skill": "Arcane", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "intel:The cathedral's resonance pattern teaches a Rimvale ritual spell when held correctly", "fail_reward": ""},
				{"label": "Polite nod, leave", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Chorister Len", "text": "The walls remember you now.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Chorister Len", "text": "Try again. The acoustics forgive.", "choices": [{"label": "Maybe soon.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"cd_zara_default": [
		{"speaker": "Pilgrim Zara", "text": "I walked twelve days to see the Oracle. She took one look at me and said 'come back in a month'. I'm three months in.",
			"choices": [
				{"label": "Offer company (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "heal:half|rep:Church:2", "fail_reward": ""},
				{"label": "Buy her a meal (8g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:8|intel:Seris has turned away three pilgrims this month — unusual", "fail_reward": ""},
				{"label": "Wish her luck", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Pilgrim Zara", "text": "Bless you. Twelfth day here I've eaten something warm.", "choices": [{"label": "Safe travels.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"cd_clarity_default": [
		{"speaker": "Sister Clarity", "text": "The sanctuary is open to any who need it. No questions beyond the first: do you come in peace?",
			"choices": [
				{"label": "Rest here (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "heal:full|sp:2|ap:2", "fail_reward": ""},
				{"label": "Donate 20g", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:20|rep:Church:4", "fail_reward": ""},
				{"label": "Light a candle", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Sister Clarity", "text": "Walk in clarity.", "choices": [{"label": "And you.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"cd_brendai_default": [
		{"speaker": "Abbot Brendai", "text": "Seris is my oldest friend, and I am concerned for her. Her visions are becoming sharper. She has aged a decade in a year.",
			"choices": [
				{"label": "Offer aid (Medical)", "skill": "Medical", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "xp:40|intel:Seris's visions come at a physical cost — her body is failing", "fail_reward": ""},
				{"label": "Ask about the order (Learnedness)", "skill": "Learnedness", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "intel:The Depths order has no successor — if Seris falls, the prophecies stop", "fail_reward": ""},
				{"label": "Walk away", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Abbot Brendai", "text": "If you have skill to spare, please come back.", "choices": [{"label": "I will.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:cd_brendai_asked_help", "fail_reward": ""}]},
		{"speaker": "Abbot Brendai", "text": "Peace regardless.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"cd_veiled_default": [
		{"speaker": "The Veiled One", "text": "I was Seris's teacher. I know what she carries. It will kill her, as it nearly killed me.",
			"choices": [
				{"label": "Ask for guidance (Arcane)", "skill": "Arcane", "dc_offset": 2, "next_pass": 1, "next_fail": 2, "reward": "sp:5|intel:The Veiled One can take the visions back — at a cost Seris must consent to", "fail_reward": ""},
				{"label": "Observe (Intuition)", "skill": "Intuition", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "xp:40|consequence:cd_veiled_knows_much", "fail_reward": ""},
				{"label": "Leave them be", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "The Veiled One", "text": "If you love her, bring her to me before the next new moon.", "choices": [{"label": "I'll try.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "The Veiled One", "text": "*the veil shifts slightly*", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],

	# ══════════════════ KINGDOM OF QUNORUM (8) ═══════════════════════════════

	"kq_elwyn_default": [
		{"speaker": "Captain Elwyn", "text": "Border incursions three nights running. Bandits or worse. The Wizard says worse. The Wizard always says worse.",
			"choices": [
				{"label": "Volunteer patrol (Military)", "skill": "Military", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "gold:80|xp:50|rep:Crown:4", "fail_reward": "lose_gold:15"},
				{"label": "Ask the Wizard's case (Intuition)", "skill": "Intuition", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "intel:The 'incursions' left symbols not known to any bandit clan — Meridon is scared", "fail_reward": ""},
				{"label": "Wish him well", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Captain Elwyn", "text": "Aye. Back by dawn, report to the barracks.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Captain Elwyn", "text": "Come back when you've a steadier hand.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"kq_meridon_default": [
		{"speaker": "Royal Wizard Meridon", "text": "The border symbols are cosmological. Pre-Veil astronomy. Someone out there remembers what came before.",
			"choices": [
				{"label": "Discuss cosmology (Arcane)", "skill": "Arcane", "dc_offset": 2, "next_pass": 1, "next_fail": 2, "reward": "sp:5|xp:45|intel:Meridon suspects the missing Eternal Library manuscript has reached enemy hands", "fail_reward": ""},
				{"label": "Offer protection (Military)", "skill": "Military", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "rep:Crown:3|gold:30", "fail_reward": ""},
				{"label": "Withdraw", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Royal Wizard Meridon", "text": "Rare to meet a mind that listens. Return when you have pieces I lack.", "choices": [{"label": "I will.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:kq_meridon_alliance", "fail_reward": ""}]},
		{"speaker": "Royal Wizard Meridon", "text": "Perhaps another day.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"kq_tavis_default": [
		{"speaker": "Knight-Errant Tavis", "text": "Ride to the border, they said. Simple. Glorious. Three horses in, I've met stranger things in the grass than in any dungeon.",
			"choices": [
				{"label": "Ride with him (Creature Handling)", "skill": "Creature Handling", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "gold:40|xp:35", "fail_reward": ""},
				{"label": "Exchange stories (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "intel:Tavis saw tracks at the border that don't match any lineage's boot", "fail_reward": ""},
				{"label": "Farewell", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Knight-Errant Tavis", "text": "Honor to you, traveler.", "choices": [{"label": "And to you.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Knight-Errant Tavis", "text": "Another time, perhaps.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"kq_isolda_default": [
		{"speaker": "Merchant Queen Isolda", "text": "Caravans are ONE third escort, one third cargo, one third paperwork. Guess which pays.",
			"choices": [
				{"label": "Haggle (Speechcraft)", "skill": "Speechcraft", "dc_offset": 1, "next_pass": 1, "next_fail": -1, "reward": "item:Health Potion|item:Field Rations", "fail_reward": ""},
				{"label": "Escort contract (Military)", "skill": "Military", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "gold:100|xp:40", "fail_reward": "lose_gold:20"},
				{"label": "Browse only", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Merchant Queen Isolda", "text": "Pleasure. My caravans remember friendly faces.", "choices": [{"label": "Cheers.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"kq_ailin_default": [
		{"speaker": "High Priestess Ailin", "text": "The prophecy splits in three this season. Three possible kingdoms by year's end. I will not say which one I pray for.",
			"choices": [
				{"label": "Seek blessing (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "heal:full|sp:3|rep:Church:4", "fail_reward": ""},
				{"label": "Ask about the three paths (Arcane)", "skill": "Arcane", "dc_offset": 1, "next_pass": 1, "next_fail": -1, "reward": "intel:One prophecy ends in silence — Ailin fears that is the true one", "fail_reward": ""},
				{"label": "Bow and leave", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "High Priestess Ailin", "text": "Walk in clear purpose.", "choices": [{"label": "Blessings.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"kq_perrin_default": [
		{"speaker": "Squire Perrin", "text": "One day I'll be knighted! One day! Today I'm cleaning saddles and trying not to die of boredom. But ONE DAY.",
			"choices": [
				{"label": "Encourage him (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "rep:Crown:2|xp:20", "fail_reward": ""},
				{"label": "Teach a tip (Military)", "skill": "Military", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "xp:30|rep:Crown:3", "fail_reward": ""},
				{"label": "Nod and go", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Squire Perrin", "text": "I'll remember that! Swear by the Crown!", "choices": [{"label": "Good luck.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"kq_kenneth_default": [
		{"speaker": "Smith Kenneth", "text": "Royal Smith. Means the Crown pays, the standard's high, and I sleep in the forge most nights. Need work?",
			"choices": [
				{"label": "Repair gear (30g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:30|heal:half", "fail_reward": ""},
				{"label": "Discuss metals (Learnedness)", "skill": "Learnedness", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "xp:25|rep:Artisans:2", "fail_reward": ""},
				{"label": "Move on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Smith Kenneth", "text": "Come back anytime. The forge stays lit.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"kq_grayson_default": [
		{"speaker": "Old Grayson", "text": "Been tending this bar since the old king's youth. Seen prophecies come and go. Most don't.",
			"choices": [
				{"label": "Ask his take (Intuition)", "skill": "Intuition", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "intel:Grayson saw the same 'prophecy pattern' thirty years ago — it ended in fire", "fail_reward": ""},
				{"label": "Buy a round (10g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:10|heal:half|intel:Locals whisper about a hooded woman who visits Ailin after dark", "fail_reward": ""},
				{"label": "Leave a tip and go", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Old Grayson", "text": "Drink steady. Watch the corners.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Old Grayson", "text": "Some things I keep for the right ears.", "choices": [{"label": "Fair.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],

	# ══════════════════ WILDS OF ENDERO (6) ══════════════════════════════════

	"we_brushwalker_default": [
		{"speaker": "Chief Brushwalker", "text": "The great beasts are restless this moon. Something drives them from the deeps. We will not be their kindling.",
			"choices": [
				{"label": "Offer scouting (Survival)", "skill": "Survival", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "gold:50|xp:40|intel:A Beast-Lord stirs beneath Endero — older than the Kingdom", "fail_reward": ""},
				{"label": "Speak of kinship (Creature Handling)", "skill": "Creature Handling", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "rep:Tribes:4|xp:30", "fail_reward": ""},
				{"label": "Respect and depart", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Chief Brushwalker", "text": "Walk the trails. The tribes see you now.", "choices": [{"label": "Honor to you.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:we_tribes_acknowledge", "fail_reward": ""}]},
		{"speaker": "Chief Brushwalker", "text": "Return when you've walked more.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"we_oren_default": [
		{"speaker": "Druid Oren", "text": "The circle is losing its song. Trees that should be loud grow quiet. A druid knows silence in the wrong key.",
			"choices": [
				{"label": "Help him listen (Arcane)", "skill": "Arcane", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "sp:4|intel:The silence radiates from the Beast-Lord's lair", "fail_reward": ""},
				{"label": "Heal a sick tree (Medical)", "skill": "Medical", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "xp:35|rep:Tribes:2", "fail_reward": ""},
				{"label": "Walk on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Druid Oren", "text": "You walk in tune. Good.", "choices": [{"label": "Good travels.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Druid Oren", "text": "Listen longer before returning.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"we_rysa_default": [
		{"speaker": "Beast-Talker Rysa", "text": "The big ones aren't angry. They're AFRAID. Something older than fear walks their forests. A beast doesn't know the word 'god'. It knows the shape.",
			"choices": [
				{"label": "Translate for a creature (Creature Handling)", "skill": "Creature Handling", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "xp:40|intel:The Beast-Lord is dormant but waking — three nights at most", "fail_reward": ""},
				{"label": "Offer food (8g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:8|rep:Tribes:2", "fail_reward": ""},
				{"label": "Leave", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Beast-Talker Rysa", "text": "The beasts remember you now. That's worth more than gold here.", "choices": [{"label": "Honor.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Beast-Talker Rysa", "text": "Come back with still hands.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"we_kell_default": [
		{"speaker": "Hunter Kell", "text": "Tracks. Real fresh. Not one beast — a pack, coordinated. Pack predators don't hunt pack predators. Except these did.",
			"choices": [
				{"label": "Track with him (Survival)", "skill": "Survival", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "gold:45|xp:40|intel:Something directed the beasts — the tracks show a single bare footprint in the middle", "fail_reward": "lose_gold:10"},
				{"label": "Ask for an arrow (10g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:10|item:Iron Shield", "fail_reward": ""},
				{"label": "Move on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Hunter Kell", "text": "Steady aim.", "choices": [{"label": "And you.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Hunter Kell", "text": "You lost the trail. Happens.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"we_anise_default": [
		{"speaker": "Ring-Keeper Anise", "text": "The stones turn at dusk. Most nights, gently. Tonight one pointed toward the Kingdom. It has never pointed there.",
			"choices": [
				{"label": "Read the ring (Arcane)", "skill": "Arcane", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "sp:4|intel:The ring answers the Beast-Lord's stirring — it points at the Wizard's Tower", "fail_reward": ""},
				{"label": "Offer ritual (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "rep:Tribes:3|heal:full", "fail_reward": ""},
				{"label": "Step back", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Ring-Keeper Anise", "text": "The ring will speak more, if you return at dusk.", "choices": [{"label": "I will.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Ring-Keeper Anise", "text": "Another dusk, perhaps.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"we_jonn_default": [
		{"speaker": "Wandering Jonn", "text": "Every tavern, every trail, every mead hall. I walk and sing. If you've got a story, I've got a verse.",
			"choices": [
				{"label": "Trade tales (Perform)", "skill": "Perform", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "xp:30|rep:Artisans:2|intel:Three tribes fled the deep forest last week — never in living memory", "fail_reward": ""},
				{"label": "Tip 5g for a song", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:5|sp:2", "fail_reward": ""},
				{"label": "Walk on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Wandering Jonn", "text": "May your road sing back.", "choices": [{"label": "And yours.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],

	# ══════════════════ FOREST OF SUBEDEN (6) ════════════════════════════════

	"fs_lyna_default": [
		{"speaker": "Moonspeaker Lyna", "text": "The moonwells darken. Silver waters turn black, then still. The elves fear, though elves rarely speak fear aloud.",
			"choices": [
				{"label": "Test the water (Arcane)", "skill": "Arcane", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "sp:4|intel:The moonwell taint is from beneath — a rot seeps up from SubEden's roots", "fail_reward": ""},
				{"label": "Sing the old rites (Perform)", "skill": "Perform", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "rep:Elves:4|xp:35", "fail_reward": ""},
				{"label": "Leave the glade", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Moonspeaker Lyna", "text": "The forest notes you. Return when the moon is fuller.", "choices": [{"label": "*bows*", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:fs_lyna_marks_you", "fail_reward": ""}]},
		{"speaker": "Moonspeaker Lyna", "text": "Come back when the moon is kinder.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"fs_thistledown_default": [
		{"speaker": "Queen Thistledown", "text": "A bargain, mortal? The fey bargain always. Speak carefully — words bind where coin does not.",
			"choices": [
				{"label": "Phrase it exactly (Speechcraft)", "skill": "Speechcraft", "dc_offset": 2, "next_pass": 1, "next_fail": 2, "reward": "sp:5|item:Scroll of Protection", "fail_reward": "lose_gold:30"},
				{"label": "Refuse the bargain", "skill": "", "dc_offset": 0, "next_pass": 3, "next_fail": -1, "reward": "rep:Fey:2", "fail_reward": ""},
				{"label": "Step away", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Queen Thistledown", "text": "Precise tongue. Rare in mortals. The bargain holds.", "choices": [{"label": "Sealed.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:fs_fey_bargain", "fail_reward": ""}]},
		{"speaker": "Queen Thistledown", "text": "Oh, sloppy. We'll see what the bargain becomes.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Queen Thistledown", "text": "Refusal. A kind of wisdom. Go — unbound.", "choices": [{"label": "My thanks.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"fs_yew_default": [
		{"speaker": "The Ancient Yew", "text": "...you speak? Few speak the slow tongue. Let me remember how to ANSWER.",
			"choices": [
				{"label": "Wait patiently (Intuition)", "skill": "Intuition", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "sp:5|xp:40|intel:The Yew has seen SubEden's rot grow ring by ring — it began three winters ago", "fail_reward": ""},
				{"label": "Leave an offering (15g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:15|rep:Fey:3|sp:3", "fail_reward": ""},
				{"label": "Move quietly past", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "The Ancient Yew", "text": "...you listened. That is the rare part. Return at any century.", "choices": [{"label": "I will.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "The Ancient Yew", "text": "...too fast... come slower next time...", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"fs_sylvios_default": [
		{"speaker": "Enchanter Sylvios", "text": "Enchantment is permission. The object must consent. Most objects are flattered, a few refuse. My desk refused twice.",
			"choices": [
				{"label": "Commission (50g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:50|item:Scroll of Protection", "fail_reward": ""},
				{"label": "Discuss theory (Arcane)", "skill": "Arcane", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "sp:3|xp:30", "fail_reward": ""},
				{"label": "Walk on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Enchanter Sylvios", "text": "My work serves well. Return anytime.", "choices": [{"label": "Thanks.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"fs_eluin_default": [
		{"speaker": "Whisper Eluin", "text": "*appears at your elbow silently* ...the forest is not safe today. I will walk a turn with you if you wish.",
			"choices": [
				{"label": "Accept escort (Creature Handling)", "skill": "Creature Handling", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "xp:30|heal:half", "fail_reward": ""},
				{"label": "Ask what's wrong (Perception)", "skill": "Perception", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "intel:Eluin saw a figure in dark robes standing at the moonwell at dawn", "fail_reward": ""},
				{"label": "Decline", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Whisper Eluin", "text": "The forest walks with you for a time. Good.", "choices": [{"label": "Thank you.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Whisper Eluin", "text": "*fades back into the bracken*", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"fs_rose_default": [
		{"speaker": "Spirit-Touched Rose", "text": "The spirits press against me today. Too many. Too loud. I'll tell you the clearest one, if you'll listen.",
			"choices": [
				{"label": "Listen (Intuition)", "skill": "Intuition", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "sp:3|intel:Rose hears a voice calling itself 'Before' — the pre-Veil entity stirs", "fail_reward": ""},
				{"label": "Share tea (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "heal:full|rep:Fey:2", "fail_reward": ""},
				{"label": "Let her rest", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Spirit-Touched Rose", "text": "The spirits quieted. Briefly. Thank you.", "choices": [{"label": "Peace to you.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Spirit-Touched Rose", "text": "Too many voices. Later. Please later.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],

	# ══════════════════ MORTAL ARENA (8) ═════════════════════════════════════

	"ma_marcus_default": [
		{"speaker": "Champion Marcus", "text": "Undefeated in forty bouts. They call me Champion. They also call this place Mortal, and few remember why. Stay or fight or leave.",
			"choices": [
				{"label": "Challenge him (Military)", "skill": "Military", "dc_offset": 2, "next_pass": 1, "next_fail": 2, "reward": "gold:150|xp:80|rep:Arena:5", "fail_reward": "lose_gold:30"},
				{"label": "Ask about rigged bouts (Intuition)", "skill": "Intuition", "dc_offset": 1, "next_pass": 3, "next_fail": 2, "reward": "intel:Marcus's last five wins were paid — Varek arranged them, but now demands a loss", "fail_reward": ""},
				{"label": "Salute and move on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Champion Marcus", "text": "Good fight. Very good. The sand knows you now.", "choices": [{"label": "Honor.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Champion Marcus", "text": "Come back when you're sharper.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Champion Marcus", "text": "You SEE it. Good. Keep your mouth shut and your eyes on the stands. Varek wants me dead on the sand this month.", "choices": [{"label": "Noted.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:ma_marcus_confides", "fail_reward": ""}]},
	],
	"ma_grool_default": [
		{"speaker": "Pit Master Grool", "text": "Six forms, ten weapons, every dirty trick worth knowing. Twenty silver for an hour. Thirty if you want the truth about the arena.",
			"choices": [
				{"label": "Train (Military, 20g)", "skill": "Military", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:20|xp:50|rep:Arena:2", "fail_reward": ""},
				{"label": "Pay for the truth (30g)", "skill": "", "dc_offset": 0, "next_pass": 2, "next_fail": -1, "reward": "lose_gold:30|intel:Varek owes 3000g to Noble Row bettors — next bout must collapse dramatically", "fail_reward": ""},
				{"label": "Leave", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Pit Master Grool", "text": "You stand different already. Come back.", "choices": [{"label": "I will.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Pit Master Grool", "text": "Now you know. What you do with it's your problem.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"ma_varek_default": [
		{"speaker": "Betmaster Varek", "text": "Odds! Stakes! Futures! You look like someone who trusts their gut. Good — gut pays better than brain in my line.",
			"choices": [
				{"label": "Place a bet (20g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "lose_gold:20|gold:50", "fail_reward": "lose_gold:20"},
				{"label": "Read his tells (Intuition)", "skill": "Intuition", "dc_offset": 1, "next_pass": 3, "next_fail": -1, "reward": "intel:Varek is rigging — Marcus dies next week unless the title changes hands clean", "fail_reward": ""},
				{"label": "Pass", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Betmaster Varek", "text": "PAYOUT! Told you gut pays.", "choices": [{"label": "Ha.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Betmaster Varek", "text": "Lost this round! Come back with cleaner luck.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Betmaster Varek", "text": "Nnnnope. Move along. No bet today.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:ma_varek_suspects_you", "fail_reward": ""}]},
	],
	"ma_axel_default": [
		{"speaker": "Trainer Axel", "text": "Grool runs pits; I run forms. The crowd wants spectacle; I want survival. Which will keep you alive?",
			"choices": [
				{"label": "Spar (Military)", "skill": "Military", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "xp:40|rep:Arena:2", "fail_reward": ""},
				{"label": "Discuss philosophy (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "intel:Axel refuses Varek's students — he teaches honest forms only", "fail_reward": ""},
				{"label": "Nod and leave", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Trainer Axel", "text": "Steady grip. Return anytime.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Trainer Axel", "text": "More work needed. Dismissed.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"ma_vona_default": [
		{"speaker": "Priestess Vona", "text": "Every gladiator prays. Some to their god, some to the sand, some to the crowd. I keep track. The crowd wins most bouts.",
			"choices": [
				{"label": "Accept blessing (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "heal:full|sp:2", "fail_reward": ""},
				{"label": "Donate 20g", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:20|rep:Arena:3|rep:Church:2", "fail_reward": ""},
				{"label": "Bow and go", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Priestess Vona", "text": "Walk in shaped courage.", "choices": [{"label": "Blessings.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"ma_reto_default": [
		{"speaker": "Wounded Reto", "text": "Eighteen bouts. Sixteen wins. Two losses. The first cost me the arm. The second would've cost me more. Every night I'm grateful.",
			"choices": [
				{"label": "Share a drink (5g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:5|intel:Reto's last opponent was paid to lose — Reto is alive because someone cheated for him", "fail_reward": ""},
				{"label": "Ask about retirement (Medical)", "skill": "Medical", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "xp:25|rep:Arena:1", "fail_reward": ""},
				{"label": "Leave him to his ale", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Wounded Reto", "text": "Decent of you. Most don't sit with the broken.", "choices": [{"label": "Take care.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"ma_madam_default": [
		{"speaker": "The Crimson Madam", "text": "The Arena bleeds its men; I bandage them. Not always the wounds you think. What brings you to my door?",
			"choices": [
				{"label": "Inquire after intel (Speechcraft)", "skill": "Speechcraft", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "intel:Varek visits thrice weekly — pays for silence about his debts", "fail_reward": ""},
				{"label": "Buy a round for the house (40g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:40|rep:Arena:3|heal:full", "fail_reward": ""},
				{"label": "Decline politely", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "The Crimson Madam", "text": "Pleasure doing business. My door stays open.", "choices": [{"label": "Madam.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "The Crimson Madam", "text": "My silence costs more than you offered. Another time.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"ma_felora_default": [
		{"speaker": "Master Smith Felora", "text": "Gladiator steel has to flex, not just cut. Decorative smiths make statues. I make survivors.",
			"choices": [
				{"label": "Commission a blade (80g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:80|item:Iron Shield", "fail_reward": ""},
				{"label": "Discuss craft (Learnedness)", "skill": "Learnedness", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "xp:30|rep:Artisans:3", "fail_reward": ""},
				{"label": "Move on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Master Smith Felora", "text": "May your steel outlast you.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],

	# ══════════════════ PHARAOH'S DEN (5) ════════════════════════════════════

	"pd_anubis_default": [
		{"speaker": "High Mummifier Anubis", "text": "The dead speak loudly here. One grows used to it. Or one leaves quickly. Which will it be?",
			"choices": [
				{"label": "Discuss the dead (Arcane)", "skill": "Arcane", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "sp:4|intel:A tomb in the lower pyramid was opened two weeks ago — from the inside", "fail_reward": ""},
				{"label": "Bring offering (20g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:20|rep:Tomb:3|heal:half", "fail_reward": ""},
				{"label": "Leave quickly", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "High Mummifier Anubis", "text": "The dead mark you as respectful. They remember such things.", "choices": [{"label": "Honor.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "High Mummifier Anubis", "text": "Return with cleaner thoughts.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"pd_senet_default": [
		{"speaker": "Tomb Reader Senet", "text": "The glyphs on the cursed tomb misbehave. They read different sentences each time. Usually glyphs are more committed.",
			"choices": [
				{"label": "Cross-reference (Learnedness)", "skill": "Learnedness", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "xp:40|intel:The shifting glyphs spell one word consistently across all readings: 'WOKE'", "fail_reward": ""},
				{"label": "Share tea (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "rep:Tomb:2|heal:half", "fail_reward": ""},
				{"label": "Nod and leave", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Tomb Reader Senet", "text": "Sharper eye than most. Return when you have more glyphs.", "choices": [{"label": "I will.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Tomb Reader Senet", "text": "Come back with cooler head.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"pd_khetra_default": [
		{"speaker": "Sand-Walker Khetra", "text": "Sun up, sand shifts. Sun down, sand shifts. Sometimes something else shifts. Today is a something-else day.",
			"choices": [
				{"label": "Follow the trail (Survival)", "skill": "Survival", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "gold:45|xp:40|intel:A trail of sand-slow footprints leads from the cursed tomb into the deep dunes", "fail_reward": "lose_gold:10"},
				{"label": "Buy a water-skin (15g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:15|item:Field Rations", "fail_reward": ""},
				{"label": "Stay in town", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Sand-Walker Khetra", "text": "Keep your eyes low, your feet light.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Sand-Walker Khetra", "text": "Sand took the trail. Come back sharper.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"pd_maat_default": [
		{"speaker": "Priest Ma'at", "text": "The curse came with the tomb opening. I carry part of it. Don't worry — it's not contagious. Usually.",
			"choices": [
				{"label": "Offer healing (Medical)", "skill": "Medical", "dc_offset": 2, "next_pass": 1, "next_fail": 2, "reward": "xp:50|rep:Tomb:4|intel:Ma'at saw the tomb-walker — it wore priestly vestments from 400 years past", "fail_reward": "heal:half"},
				{"label": "Study the curse (Arcane)", "skill": "Arcane", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "sp:4|consequence:pd_curse_studied", "fail_reward": ""},
				{"label": "Back away slowly", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Priest Ma'at", "text": "Rare kindness. The curse eases, slightly, in your presence.", "choices": [{"label": "Peace.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Priest Ma'at", "text": "The curse does not bend today. Return another.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"pd_rashid_default": [
		{"speaker": "Golden Merchant Rashid", "text": "Antiquities! All legitimate! The tomb authorities have approved every piece on this table. Approved. Officially. Please stop looking at me like that.",
			"choices": [
				{"label": "Haggle (Speechcraft)", "skill": "Speechcraft", "dc_offset": 1, "next_pass": 1, "next_fail": -1, "reward": "item:Scroll of Protection|xp:25", "fail_reward": ""},
				{"label": "Check authenticity (Perception)", "skill": "Perception", "dc_offset": 0, "next_pass": 2, "next_fail": -1, "reward": "intel:Half of Rashid's 'antiquities' are fresh forgeries — the other half are CURSED originals", "fail_reward": ""},
				{"label": "Browse only", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Golden Merchant Rashid", "text": "Pleasure. Come back, come back! Tell NO authorities!", "choices": [{"label": "Ha.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Golden Merchant Rashid", "text": "*nervously sweating* ...may I interest you in a definitely-not-cursed scarab?", "choices": [{"label": "Pass.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:pd_rashid_rumbled", "fail_reward": ""}]},
	],

	# ══════════════════ THE DARKNESS (5) ═════════════════════════════════════

	"td_hollowell_default": [
		{"speaker": "Mayor Hollowell", "text": "Evening. Or — whatever time it is. Hard to tell these days. The lanterns only last so long. I only last so long.",
			"choices": [
				{"label": "Offer aid (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "rep:Dark:3|intel:Hollowell knows the Thing in the Dark took his wife three years ago", "fail_reward": ""},
				{"label": "Read his state (Intuition)", "skill": "Intuition", "dc_offset": 1, "next_pass": 3, "next_fail": 2, "reward": "xp:35|consequence:td_hollowell_haunted", "fail_reward": ""},
				{"label": "Let him be", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Mayor Hollowell", "text": "Kindness. There's little of it left here. Thank you.", "choices": [{"label": "Stay lit.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Mayor Hollowell", "text": "Go. The town doesn't need more visitors.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Mayor Hollowell", "text": "...she's still here, you know. Not alive. Not gone. In between. The Thing keeps her like that.", "choices": [{"label": "I'm sorry.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"td_mott_default": [
		{"speaker": "Lantern-Keeper Mott", "text": "Oil's low. Flame's lower. If I go dark, the town goes dark. If the town goes dark, the town goes gone. No pressure.",
			"choices": [
				{"label": "Donate oil (15g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:15|rep:Dark:4|intel:The lanterns here burn blessed oil — the Thing cannot cross flame", "fail_reward": ""},
				{"label": "Help refill (Survival)", "skill": "Survival", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "xp:30|rep:Dark:2", "fail_reward": ""},
				{"label": "Move on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Lantern-Keeper Mott", "text": "Bless you. Lanterns keep, tonight.", "choices": [{"label": "Safe.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Lantern-Keeper Mott", "text": "Kindness noted. Go cautious.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"td_black_default": [
		{"speaker": "Widow Black", "text": "Seven years a widow. Longer than the marriage, by now. The Thing took him. Took the neighbors too. I stay out of spite.",
			"choices": [
				{"label": "Listen (Intuition)", "skill": "Intuition", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "xp:35|intel:Widow Black knows where the Thing sleeps — but she won't say until someone brings her husband's pocket watch", "fail_reward": ""},
				{"label": "Bring flowers (10g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:10|rep:Dark:3", "fail_reward": ""},
				{"label": "Leave her in peace", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Widow Black", "text": "You listen. No one listens. Come back.", "choices": [{"label": "I will.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Widow Black", "text": "Go on. I've wept enough for strangers this year.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"td_shop_default": [
		{"speaker": "The Shopkeeper", "text": "...\n\n...you want something. I have something. Name it. No questions. I charge double for questions.",
			"choices": [
				{"label": "Buy a charm (30g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:30|item:Smoke Bomb|intel:The charm hums faintly near the Thing's old tracks", "fail_reward": ""},
				{"label": "Observe them (Perception)", "skill": "Perception", "dc_offset": 2, "next_pass": 2, "next_fail": -1, "reward": "intel:The Shopkeeper has no reflection in the shop's mirror", "fail_reward": ""},
				{"label": "Browse", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "The Shopkeeper", "text": "...pleasure. Go.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "The Shopkeeper", "text": "...don't come back with that look.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:td_shopkeeper_suspect", "fail_reward": ""}]},
	],
	"td_blight_default": [
		{"speaker": "Preacher Blight", "text": "THE END COMES. It has been coming since I was a boy. It is STILL coming. I refuse to be surprised when it arrives.",
			"choices": [
				{"label": "Argue gently (Speechcraft)", "skill": "Speechcraft", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "xp:30|rep:Church:1", "fail_reward": ""},
				{"label": "Donate (10g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:10|intel:Blight's sermons reference the same pre-Veil cosmology Meridon is worried about", "fail_reward": ""},
				{"label": "Walk past", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Preacher Blight", "text": "YOU LISTEN. Few listen. The end thanks you.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Preacher Blight", "text": "THEN BE DAMNED WITH THE REST.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],

	# ══════════════════ HOUSE OF ARACHANA (5) ════════════════════════════════

	"ha_matriarch_default": [
		{"speaker": "Web-Weaver Matriarch", "text": "Ssssso. A visitor. Outsiders pay the silk tax — one coin, one lie, or one story. Your choice.",
			"choices": [
				{"label": "Tell a true lie (Speechcraft)", "skill": "Speechcraft", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "rep:Spider:4|xp:30", "fail_reward": ""},
				{"label": "Pay silk tax (15g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:15|item:Scroll of Protection", "fail_reward": ""},
				{"label": "Leave the hall", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Web-Weaver Matriarch", "text": "Accepted. The webs remember your visit now.", "choices": [{"label": "Honor.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:ha_matriarch_marks_you", "fail_reward": ""}]},
		{"speaker": "Web-Weaver Matriarch", "text": "A poor lie. The webs disapprove. Pay next time.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"ha_kess_default": [
		{"speaker": "Silk Merchant Kess", "text": "Finest silk outside the Metropolitan. Threads you can stop a blade with — tested, obviously. Would you like to test?",
			"choices": [
				{"label": "Buy a silk cloak (50g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:50|item:Iron Shield", "fail_reward": ""},
				{"label": "Haggle (Speechcraft)", "skill": "Speechcraft", "dc_offset": 1, "next_pass": 1, "next_fail": -1, "reward": "item:Health Potion|xp:25", "fail_reward": ""},
				{"label": "Browse only", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Silk Merchant Kess", "text": "Pleasure! The silk remembers its buyer.", "choices": [{"label": "Cheers.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"ha_orin_default": [
		{"speaker": "Venom-Brewer Orin", "text": "Proper venom is delicate. One drop heals, two drop paralyzes, three drop — well, you won't have to worry about that.",
			"choices": [
				{"label": "Study brewing (Learnedness)", "skill": "Learnedness", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "xp:35|item:Antitoxin", "fail_reward": ""},
				{"label": "Buy a remedy (20g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:20|item:Health Potion", "fail_reward": ""},
				{"label": "Leave", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Venom-Brewer Orin", "text": "A steady hand. Rare. Come back.", "choices": [{"label": "I will.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Venom-Brewer Orin", "text": "Shaky. Steady first. Then return.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"ha_priestess_default": [
		{"speaker": "Spider Priestess", "text": "The Great Weaver spins all fates. Most threads are short. A few are long. Very few see the whole tapestry.",
			"choices": [
				{"label": "Seek a glimpse (Arcane)", "skill": "Arcane", "dc_offset": 2, "next_pass": 1, "next_fail": 2, "reward": "sp:4|intel:The Priestess sees many threads ending in fire — a regional convergence is near", "fail_reward": ""},
				{"label": "Offer to the Weaver (30g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:30|rep:Spider:5|heal:full", "fail_reward": ""},
				{"label": "Leave", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Spider Priestess", "text": "Your thread lengthens. Watch where it leads.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Spider Priestess", "text": "The thread knots. Return patient.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"ha_trask_default": [
		{"speaker": "Brood-Tender Trask", "text": "Brood's hungry. Brood's always hungry. You look well-fed. No, no — joking! Mostly.",
			"choices": [
				{"label": "Feed the brood (5g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:5|rep:Spider:2|intel:The brood grows restless — they've tripled in size this season", "fail_reward": ""},
				{"label": "Calm a spiderling (Creature Handling)", "skill": "Creature Handling", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "xp:35|rep:Spider:3", "fail_reward": ""},
				{"label": "Back away", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Brood-Tender Trask", "text": "They liked you! Rare! Visit again!", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Brood-Tender Trask", "text": "Nip! Ow. Try again sometime.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],

	# ══════════════════ CRYPT AT END OF VALLEY (5) ═══════════════════════════

	"ce_mortis_default": [
		{"speaker": "Gravekeeper Mortis", "text": "Forty thousand interred in these slopes. I know most of them by name. They are quieter than living companions, mostly.",
			"choices": [
				{"label": "Offer help (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "xp:30|rep:Crypt:3", "fail_reward": ""},
				{"label": "Ask about the stolen urn (Perception)", "skill": "Perception", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "intel:The urn was taken by someone with a key — only four people have keys", "fail_reward": ""},
				{"label": "Leave him to his work", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Gravekeeper Mortis", "text": "Thank you. The dead appreciate witnesses.", "choices": [{"label": "Peace.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Gravekeeper Mortis", "text": "Another time, perhaps.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"ce_lara_default": [
		{"speaker": "Priestess Lara", "text": "The mourning rites are every dawn. Attendance has been thin. Grief wears thinner still.",
			"choices": [
				{"label": "Join the rite (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "rep:Church:4|heal:full|sp:2", "fail_reward": ""},
				{"label": "Ask about losses (Intuition)", "skill": "Intuition", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "intel:Three mourners went missing after rites this month — last seen near the Grand Mausoleum", "fail_reward": ""},
				{"label": "Bow and leave", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Priestess Lara", "text": "The dead thank your voice.", "choices": [{"label": "Peace.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"ce_tark_default": [
		{"speaker": "Sepulcher Guard Tark", "text": "Quiet duty, mostly. Stops being quiet when the stolen urn business started. Suspect list is short and I'm on it.",
			"choices": [
				{"label": "Clear his name (Intuition)", "skill": "Intuition", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "xp:40|rep:Crypt:3|intel:Tark is clean — his shift log has been tampered with to frame him", "fail_reward": ""},
				{"label": "Volunteer watch (Military)", "skill": "Military", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "gold:50|xp:30", "fail_reward": "lose_gold:10"},
				{"label": "Move on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Sepulcher Guard Tark", "text": "Owe you for this. Bring me whatever you find, we'll sort it.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Sepulcher Guard Tark", "text": "Might be nothing. Might be me. Hope you're wrong.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"ce_oswin_default": [
		{"speaker": "Bone-Carver Oswin", "text": "Every memorial I carve remembers a life. Most are plain. A few — a FEW — the families pay extra for, uh, specific phrasings.",
			"choices": [
				{"label": "Commission (40g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:40|item:Scroll of Protection", "fail_reward": ""},
				{"label": "Ask about recent work (Perception)", "skill": "Perception", "dc_offset": 1, "next_pass": 1, "next_fail": -1, "reward": "intel:Oswin was paid double to carve an 'anonymous' memorial two weeks ago — near the stolen-urn plot", "fail_reward": ""},
				{"label": "Browse", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Bone-Carver Oswin", "text": "May the stone keep the name.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"ce_silas_default": [
		{"speaker": "Vigil Monk Silas", "text": "I keep vigil. That is all I do. If you need prayer, sit. If you need counsel, sit longer.",
			"choices": [
				{"label": "Sit with him (Intuition)", "skill": "Intuition", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "sp:3|xp:30|intel:Silas hears every whisper in the valley — he knows the urn thief crossed east at midnight", "fail_reward": ""},
				{"label": "Donate (20g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:20|rep:Church:3|heal:full", "fail_reward": ""},
				{"label": "Leave in silence", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Vigil Monk Silas", "text": "Walk in balance.", "choices": [{"label": "Peace.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],

	# ══════════════════ SPINDLE YORK'S SCHISM (5) ════════════════════════════

	"sy_tess_default": [
		{"speaker": "Canyon Guide Tess", "text": "Ledges shift. Ropes fray. I've guided fifteen climbers into the schism and fourteen back. That one bothers me.",
			"choices": [
				{"label": "Hire for descent (25g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:25|intel:Four climbers have gone missing this season — Tess swears she lost only one herself", "fail_reward": ""},
				{"label": "Offer climbing skill (Survival)", "skill": "Survival", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "gold:40|xp:35", "fail_reward": "lose_gold:10"},
				{"label": "Stay topside", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Canyon Guide Tess", "text": "Good rope-sense. You want the deep descent, come dawn.", "choices": [{"label": "Dawn.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Canyon Guide Tess", "text": "Rope slipped. Try another day.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"sy_hermit_default": [
		{"speaker": "The Void-Touched Hermit", "text": "The void whispers clearest at the schism's edge. Most can't hear it. I hear nothing ELSE. Be glad of your deafness.",
			"choices": [
				{"label": "Listen with him (Arcane)", "skill": "Arcane", "dc_offset": 2, "next_pass": 1, "next_fail": 2, "reward": "sp:5|intel:The void beneath Spindle pulses — it is AWARE, and it is growing curious", "fail_reward": ""},
				{"label": "Offer food (10g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:10|heal:half|xp:20", "fail_reward": ""},
				{"label": "Retreat", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "The Void-Touched Hermit", "text": "You heard. Few do. Watch where the shadow falls from now.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:sy_hermit_bond", "fail_reward": ""}]},
		{"speaker": "The Void-Touched Hermit", "text": "Too loud still. Return quieter.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"sy_vashnar_default": [
		{"speaker": "Cult Priest Vashnar", "text": "Do you feel it? The pulse beneath your feet? That is the Truth. Join us and you will hear clearly. Refuse and you will hear eventually, anyway.",
			"choices": [
				{"label": "Refuse firmly (Speechcraft)", "skill": "Speechcraft", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "xp:30|rep:Cult:-5", "fail_reward": ""},
				{"label": "Feign interest (Intuition)", "skill": "Intuition", "dc_offset": 1, "next_pass": 3, "next_fail": 2, "reward": "intel:The cult plans a ritual at the schism's edge in three nights — to 'wake' the void", "fail_reward": ""},
				{"label": "Walk away", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Cult Priest Vashnar", "text": "Fool. The void hears your refusal and remembers it.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Cult Priest Vashnar", "text": "The pulse claims all eventually.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:sy_marked_by_cult", "fail_reward": ""}]},
		{"speaker": "Cult Priest Vashnar", "text": "A convert! Or a spy. Doesn't matter — either serves. We meet at the ledge at midnight the third night from now.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"sy_orik_default": [
		{"speaker": "Abyss Miner Orik", "text": "Dig deep enough and the ground starts dreaming. I quit when my pick struck a CHORD. Literally. The rock sang.",
			"choices": [
				{"label": "Buy ore (25g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:25|item:Iron Shield|intel:The deep ore resonates with arcane tools — Meridon would pay for this", "fail_reward": ""},
				{"label": "Hear him out (Intuition)", "skill": "Intuition", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "xp:25|intel:The chord Orik heard matches the pre-Veil cosmological frequencies", "fail_reward": ""},
				{"label": "Move on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Abyss Miner Orik", "text": "Don't dig deep. That's my advice. Sell for me. Dig not.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"sy_yulia_default": [
		{"speaker": "Schism Watcher Yulia", "text": "My job is to notice when the schism widens. Last month: a hand's breadth. This week: a forearm. Something is stretching.",
			"choices": [
				{"label": "Measure with her (Learnedness)", "skill": "Learnedness", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "xp:35|intel:The schism widens in regular intervals — approximately every seven nights, always at midnight", "fail_reward": ""},
				{"label": "Offer a telescope (15g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:15|rep:Academy:2", "fail_reward": ""},
				{"label": "Walk on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Schism Watcher Yulia", "text": "Good numbers. Come back in seven nights.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Schism Watcher Yulia", "text": "Measurements are off today. Mine or yours.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],

	# ══════════════════ ARGENT HALL (5) ══════════════════════════════════════

	"ah_ander_default": [
		{"speaker": "Glacier-Carver Ander", "text": "I found a body in the ice. Clothing's wrong for this century. Face is wrong for any century.",
			"choices": [
				{"label": "Examine the body (Medical)", "skill": "Medical", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "xp:40|intel:The frozen stranger wears pre-Veil vestments — possibly the first one we've ever found preserved", "fail_reward": ""},
				{"label": "Offer discretion (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "rep:Frost:3|gold:30", "fail_reward": ""},
				{"label": "Walk on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Glacier-Carver Ander", "text": "Glad someone looks at this seriously. Come back if you know people who care.", "choices": [{"label": "I will.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:ah_frozen_stranger_examined", "fail_reward": ""}]},
		{"speaker": "Glacier-Carver Ander", "text": "Hm. Another time.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"ah_tova_default": [
		{"speaker": "Frost-Priest Tova", "text": "The frost speaks in crystals. It is speaking of an intruder under the ice. Old. Patient. Cold.",
			"choices": [
				{"label": "Translate (Arcane)", "skill": "Arcane", "dc_offset": 1, "next_pass": 1, "next_fail": -1, "reward": "sp:4|intel:The ice entity is not the body Ander found — it is something else beneath, older, waiting", "fail_reward": ""},
				{"label": "Offer prayer (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "heal:full|rep:Frost:4", "fail_reward": ""},
				{"label": "Bow and go", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Frost-Priest Tova", "text": "The frost notes your reverence.", "choices": [{"label": "Honor.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"ah_voss_default": [
		{"speaker": "Crystal Master Voss", "text": "Frostglass is trickier than steel. Won't take a proper edge but will shatter a boulder. Trade-off, as always.",
			"choices": [
				{"label": "Buy frostglass tool (40g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:40|item:Iron Shield", "fail_reward": ""},
				{"label": "Learn technique (Learnedness)", "skill": "Learnedness", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "xp:30|rep:Artisans:2", "fail_reward": ""},
				{"label": "Move on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Crystal Master Voss", "text": "Aye. Stay warm out there.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"ah_hark_default": [
		{"speaker": "Tundra Scout Hark", "text": "Pattern of tracks makes no sense. Something walked out of the deep ice last week. Footprints start mid-field. Nothing leads to them.",
			"choices": [
				{"label": "Investigate (Survival)", "skill": "Survival", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "gold:50|xp:40|intel:The tracks vanish at the ice body's location — the stranger walked out, not in", "fail_reward": ""},
				{"label": "Share provisions (10g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:10|rep:Frost:2", "fail_reward": ""},
				{"label": "Walk on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Tundra Scout Hark", "text": "Sharp eye. Bring more as you find it.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Tundra Scout Hark", "text": "Another scout can look. Come back when you've walked more ice.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"ah_edda_default": [
		{"speaker": "Icecrafter Edda", "text": "Winter has teeth, traveler. Everything I make fights winter. Except this — *holds up an ice flower* — this just keeps winter company.",
			"choices": [
				{"label": "Buy a warming charm (20g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:20|item:Field Rations|heal:half", "fail_reward": ""},
				{"label": "Compliment the artistry (Perform)", "skill": "Perform", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "xp:20|rep:Artisans:1", "fail_reward": ""},
				{"label": "Move on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Icecrafter Edda", "text": "Go warm. Come back.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],

	# ══════════════════ SACRAL SEPARATION (5) ════════════════════════════════

	"ss_keen_default": [
		{"speaker": "Monk Keen", "text": "The order has taken a vow of silence. I am the only one permitted to speak, and only to warn outsiders: do not enter the meditation center after midnight.",
			"choices": [
				{"label": "Ask why (Intuition)", "skill": "Intuition", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "xp:35|intel:Something enters the meditation hall at midnight — the monks meditate through it", "fail_reward": ""},
				{"label": "Accept the warning (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "rep:Church:3|sp:2", "fail_reward": ""},
				{"label": "Bow and leave", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Monk Keen", "text": "Walk softly. The sands listen.", "choices": [{"label": "Peace.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Monk Keen", "text": "Silence speaks enough. Go.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"ss_saber_default": [
		{"speaker": "Desert Guide Saber", "text": "Three days to the Sacral Nexus if you know the route. Thirteen if you don't. Most don't know.",
			"choices": [
				{"label": "Hire (30g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:30|intel:Saber knows of an unmapped well between the outposts — lifesaving in emergencies", "fail_reward": ""},
				{"label": "Ask about the sands (Survival)", "skill": "Survival", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "xp:30|intel:The sand in Sacral Separation shifts against natural wind patterns at night — unnatural", "fail_reward": ""},
				{"label": "Travel alone", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Desert Guide Saber", "text": "Stay hydrated. Stay oriented.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"ss_vassal_default": [
		{"speaker": "Pilgrim Vassal", "text": "Twenty years a pilgrim. Every year I walk a little slower. I'll die on this road and that is acceptable. I've been happy.",
			"choices": [
				{"label": "Walk with him (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "heal:full|rep:Church:3|xp:25", "fail_reward": ""},
				{"label": "Donate to his journey (5g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:5|intel:Vassal carries a relic he must deliver before he dies — but won't name the recipient", "fail_reward": ""},
				{"label": "Wish him well", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Pilgrim Vassal", "text": "Your company warmed a mile. Thank you.", "choices": [{"label": "Safe travels.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"ss_ellar_default": [
		{"speaker": "Obelisk Watcher Ellar", "text": "The obelisks hum. Always have. Recently, they hum a SECOND frequency beneath the first. Something else is using them as a carrier wave.",
			"choices": [
				{"label": "Analyze the frequency (Arcane)", "skill": "Arcane", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "sp:5|intel:The second frequency matches Meridon's pre-Veil cosmological signatures — a broadcast is ongoing", "fail_reward": ""},
				{"label": "Offer measurement tools (20g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:20|rep:Academy:3", "fail_reward": ""},
				{"label": "Walk on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Obelisk Watcher Ellar", "text": "Good ear. Come back in three nights.", "choices": [{"label": "I will.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Obelisk Watcher Ellar", "text": "Another sharp mind is needed. Perhaps another time.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"ss_thada_default": [
		{"speaker": "Holy Forger Thada", "text": "I forge only what the order approves. The order approves little. My days are mostly hammering things back into specification.",
			"choices": [
				{"label": "Commission (60g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:60|item:Iron Shield", "fail_reward": ""},
				{"label": "Discuss craft (Learnedness)", "skill": "Learnedness", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "xp:30|rep:Artisans:2", "fail_reward": ""},
				{"label": "Move on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Holy Forger Thada", "text": "Hammer true.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],

	# ══════════════════ DEPTHS OF DENORIM (6) ════════════════════════════════

	"dd_mirelle_default": [
		{"speaker": "Sea Prince Mirelle", "text": "A kraken has been sighted at the edge of the kingdom. My father refuses to believe. Krakens are old enemies; we have no answer prepared.",
			"choices": [
				{"label": "Offer help (Military)", "skill": "Military", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "gold:80|xp:50|rep:Coral Crown:5", "fail_reward": "lose_gold:15"},
				{"label": "Counsel the prince (Speechcraft)", "skill": "Speechcraft", "dc_offset": 1, "next_pass": 3, "next_fail": 2, "reward": "intel:Mirelle plans a counter-expedition — his father does not know", "fail_reward": ""},
				{"label": "Bow and withdraw", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Sea Prince Mirelle", "text": "Your name is marked at court. Return with results.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Sea Prince Mirelle", "text": "Another time.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Sea Prince Mirelle", "text": "You see it. Good. Meet me at the tide hall at dusk — we plan quietly.", "choices": [{"label": "Dusk.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:dd_mirelle_conspiracy", "fail_reward": ""}]},
	],
	"dd_nept_default": [
		{"speaker": "Coral Master Nept", "text": "Coral grows where the water allows. The palace grows where I allow. It is a good partnership.",
			"choices": [
				{"label": "Commission ornament (50g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:50|item:Scroll of Protection", "fail_reward": ""},
				{"label": "Learn coral craft (Learnedness)", "skill": "Learnedness", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "xp:30|rep:Artisans:2", "fail_reward": ""},
				{"label": "Admire and go", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Coral Master Nept", "text": "May your path grow straight.", "choices": [{"label": "Thank you.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"dd_dorsal_default": [
		{"speaker": "Kelp-Farmer Dorsal", "text": "Kelp's slow but honest. Weather's been strange — kelp grows sideways instead of up. Sea's telling us something. Nobody listens.",
			"choices": [
				{"label": "Listen with him (Survival)", "skill": "Survival", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "xp:35|intel:The currents shifted three days ago — same day the kraken sighting was reported", "fail_reward": ""},
				{"label": "Buy fresh kelp (8g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:8|item:Field Rations|heal:half", "fail_reward": ""},
				{"label": "Walk on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Kelp-Farmer Dorsal", "text": "Good ear. Come back when kelp has more to say.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Kelp-Farmer Dorsal", "text": "Ah well. Kelp's patient.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"dd_urvay_default": [
		{"speaker": "Brine-Trader Urvay", "text": "Salt, preservatives, anything that keeps a thing longer than a thing wants to keep. Brisk business at the fortifications lately.",
			"choices": [
				{"label": "Haggle (Speechcraft)", "skill": "Speechcraft", "dc_offset": 1, "next_pass": 1, "next_fail": -1, "reward": "item:Field Rations|item:Antitoxin", "fail_reward": ""},
				{"label": "Ask about fortifications (Perception)", "skill": "Perception", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "intel:The palace has quietly begun stockpiling brine-preserved war rations — they expect a siege", "fail_reward": ""},
				{"label": "Browse", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Brine-Trader Urvay", "text": "Keep your goods preserved.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"dd_alleria_default": [
		{"speaker": "Tide-Singer Alleria", "text": "The tides remember every drowned sailor. When I sing, some of them sing back. Lately the choir is too LARGE. Something sinks ships we haven't heard report of yet.",
			"choices": [
				{"label": "Listen with her (Arcane)", "skill": "Arcane", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "sp:4|intel:Alleria counts six ships sunk silently — the kraken is already feeding", "fail_reward": ""},
				{"label": "Sing with her (Perform)", "skill": "Perform", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "rep:Coral Crown:3|heal:full", "fail_reward": ""},
				{"label": "Step back", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Tide-Singer Alleria", "text": "The tide notes your voice. Come back at ebb.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Tide-Singer Alleria", "text": "Another tide.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"dd_calvus_default": [
		{"speaker": "Sunken Guard Calvus", "text": "Palace guard. Dry duty — on the surface. Lately we're reinforced; more patrols in the lower corridors. Something's coming.",
			"choices": [
				{"label": "Volunteer (Military)", "skill": "Military", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "gold:60|xp:40|rep:Coral Crown:3", "fail_reward": "lose_gold:10"},
				{"label": "Ask about orders (Intuition)", "skill": "Intuition", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "intel:New orders came from the Prince, not the King — the succession may be accelerating", "fail_reward": ""},
				{"label": "Move on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Sunken Guard Calvus", "text": "Glad of help. Back to your post.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Sunken Guard Calvus", "text": "Not today. Move along.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],

	# ══════════════════ CORRUPTED MARSHES (6) ════════════════════════════════

	"cm_vortimer_default": [
		{"speaker": "Lich-Lord Vortimer", "text": "Ah. A LIVING. How novel. Most visitors have the good sense to be dead already. Speak, or leave — preferably the latter.",
			"choices": [
				{"label": "Negotiate (Speechcraft)", "skill": "Speechcraft", "dc_offset": 2, "next_pass": 1, "next_fail": 2, "reward": "intel:Vortimer seeks the pre-Veil manuscript — offering payment in corpse-lore secrets", "fail_reward": ""},
				{"label": "Assess him (Arcane)", "skill": "Arcane", "dc_offset": 2, "next_pass": 3, "next_fail": 2, "reward": "xp:50|consequence:cm_vortimer_assessed", "fail_reward": ""},
				{"label": "Leave immediately", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Lich-Lord Vortimer", "text": "A TRADE, then. Bring me the manuscript; I shall teach you the reversal rite. Betray and you shall rot while still able to feel it.", "choices": [{"label": "Understood.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:cm_vortimer_bargain", "fail_reward": ""}]},
		{"speaker": "Lich-Lord Vortimer", "text": "INSUFFICIENT. Return when you have more leverage — or a convincing corpse.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Lich-Lord Vortimer", "text": "You see more than most. Good. I may use you. Or not. We shall see.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"cm_grellith_default": [
		{"speaker": "Swamp Witch Grellith", "text": "The marsh offers cures, curses, and commentary. Which are you buying? First one's discounted. Commentary is free, and free is what it's worth.",
			"choices": [
				{"label": "Buy a remedy (25g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:25|item:Health Potion|item:Antitoxin", "fail_reward": ""},
				{"label": "Request a curse (Arcane)", "skill": "Arcane", "dc_offset": 2, "next_pass": 2, "next_fail": -1, "reward": "sp:3|consequence:cm_grellith_owes_curse", "fail_reward": ""},
				{"label": "Walk on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Swamp Witch Grellith", "text": "Mind the tea — it's an acquired taste.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Swamp Witch Grellith", "text": "Noted. I owe you one curse. Redeemable anytime.", "choices": [{"label": "Fair.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"cm_karsk_default": [
		{"speaker": "Bone Priest Karsk", "text": "The marsh keeps the bones of sixteen generations. Each one speaks, if you know which bone to ask.",
			"choices": [
				{"label": "Consult a bone (Arcane)", "skill": "Arcane", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "sp:4|intel:The eldest bones speak of 'The One Beneath' — a pre-Veil entity now stirring", "fail_reward": ""},
				{"label": "Offer bones (20g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:20|rep:Marsh:3", "fail_reward": ""},
				{"label": "Withdraw", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Bone Priest Karsk", "text": "The bones approve. Rare.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Bone Priest Karsk", "text": "The bones ignored you. Try softer questions.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"cm_rotvel_default": [
		{"speaker": "Marsh Merchant Rotvel", "text": "Carrion-honey, swamp-silk, bog-resin. Odd wares for odd buyers. You look like an odd buyer. Shop.",
			"choices": [
				{"label": "Buy curiosity (30g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:30|item:Scroll of Protection|xp:15", "fail_reward": ""},
				{"label": "Haggle (Speechcraft)", "skill": "Speechcraft", "dc_offset": 1, "next_pass": 1, "next_fail": -1, "reward": "item:Antitoxin", "fail_reward": ""},
				{"label": "Leave", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Marsh Merchant Rotvel", "text": "Return when mud dries. Won't be soon.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"cm_moll_default": [
		{"speaker": "Keeper of Graves Moll", "text": "I keep the graves of those the marsh refuses to take back. Stubborn dead. Some you might know.",
			"choices": [
				{"label": "Ask about recent dead (Intuition)", "skill": "Intuition", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "intel:Three fresh graves this month — all outlanders who vanished from the upriver regions", "fail_reward": ""},
				{"label": "Help her tend (Medical)", "skill": "Medical", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "xp:30|rep:Marsh:2|sp:2", "fail_reward": ""},
				{"label": "Leave her to her work", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Keeper of Graves Moll", "text": "The graves noticed you. That is a warmth.", "choices": [{"label": "Peace.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Keeper of Graves Moll", "text": "The graves keep their silence with you today.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"cm_brem_default": [
		{"speaker": "Cursed Hunter Brem", "text": "I hunt the marsh that hunts me back. We're even, most nights. Some nights the marsh cheats.",
			"choices": [
				{"label": "Hunt with him (Survival)", "skill": "Survival", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "gold:50|xp:40|intel:Brem traps something inhuman each week in the same spot — it keeps returning alive", "fail_reward": "lose_gold:10"},
				{"label": "Share rations (10g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:10|heal:half|rep:Marsh:2", "fail_reward": ""},
				{"label": "Move on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Cursed Hunter Brem", "text": "Steady hand. Hunt well.", "choices": [{"label": "And you.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Cursed Hunter Brem", "text": "Not your night. Try again.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],

	# ══════════════════ GLOAMFEN HOLLOW (6) ══════════════════════════════════

	"gh_viscer_default": [
		{"speaker": "Cathedral Keeper Viscer", "text": "The cathedral breathes, you understand. Its ribs are ribs. Please do not alarm it. Alarmed cathedrals behave poorly.",
			"choices": [
				{"label": "Listen to the cathedral (Intuition)", "skill": "Intuition", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "sp:4|intel:The cathedral is a living creature kept asleep — it has been asleep for 800 years", "fail_reward": ""},
				{"label": "Offer tribute (20g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:20|rep:Hollow:3", "fail_reward": ""},
				{"label": "Back away quietly", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Cathedral Keeper Viscer", "text": "It noticed you, but accepts. Rare.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Cathedral Keeper Viscer", "text": "Quieter, please. It stirs.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"gh_pith_default": [
		{"speaker": "Organ-Tender Pith", "text": "The organs need tending. Literally and musically. The pipes here are made of — well. I tend them. That's my job.",
			"choices": [
				{"label": "Play a note (Perform)", "skill": "Perform", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "sp:3|xp:30|intel:A specific chord on the organ 'calms' the cathedral — Pith will teach you the notes", "fail_reward": ""},
				{"label": "Help tune (Medical)", "skill": "Medical", "dc_offset": 1, "next_pass": 1, "next_fail": -1, "reward": "rep:Hollow:3|xp:25", "fail_reward": ""},
				{"label": "Walk on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Organ-Tender Pith", "text": "The pipes accept you. Return to learn more notes.", "choices": [{"label": "I will.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Organ-Tender Pith", "text": "A sour note. The pipes will remember.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"gh_maros_default": [
		{"speaker": "Bile Brewer Maros", "text": "Bile's complicated. The cathedral's is sacred; the marsh's is medicinal; the wrong kind kills. Guess which one I sell?",
			"choices": [
				{"label": "Buy remedy (25g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:25|item:Antitoxin|item:Health Potion", "fail_reward": ""},
				{"label": "Learn brewing (Learnedness)", "skill": "Learnedness", "dc_offset": 1, "next_pass": 1, "next_fail": -1, "reward": "xp:35|rep:Artisans:2", "fail_reward": ""},
				{"label": "Leave", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Bile Brewer Maros", "text": "Safe drinking.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"gh_kish_default": [
		{"speaker": "Decay Priest Kish", "text": "Decay is rebirth in slow motion. The cathedral teaches this. The cathedral is TIRED of teaching this. Please hurry.",
			"choices": [
				{"label": "Study the philosophy (Arcane)", "skill": "Arcane", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "sp:4|intel:The cathedral's 'sleep' is slowly failing — rebirth into what it was before is imminent", "fail_reward": ""},
				{"label": "Offer prayer (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "rep:Hollow:3|sp:2", "fail_reward": ""},
				{"label": "Bow and leave", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Decay Priest Kish", "text": "Walk in the slow rebirth.", "choices": [{"label": "Peace.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Decay Priest Kish", "text": "Study longer. Return patient.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"gh_thul_default": [
		{"speaker": "Bone-Merchant Thul", "text": "Hollow bone sells better than solid. People think it's rarer. It's really just calcified slowly. Still — market speaks.",
			"choices": [
				{"label": "Buy a talisman (20g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:20|item:Scroll of Protection", "fail_reward": ""},
				{"label": "Appraise wares (Perception)", "skill": "Perception", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "intel:Some of Thul's 'bones' are fresh carvings — from the cathedral itself", "fail_reward": ""},
				{"label": "Browse", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Bone-Merchant Thul", "text": "Come back! Prices decay, too.", "choices": [{"label": "Ha.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"gh_ylba_default": [
		{"speaker": "Flesh-Weaver Ylba", "text": "I mend. I repair. Some call it grotesque. The mended call it miracle. Perspective is everything.",
			"choices": [
				{"label": "Commission healing (40g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:40|heal:full|sp:2", "fail_reward": ""},
				{"label": "Study technique (Medical)", "skill": "Medical", "dc_offset": 1, "next_pass": 1, "next_fail": -1, "reward": "xp:40|rep:Hollow:2", "fail_reward": ""},
				{"label": "Move on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Flesh-Weaver Ylba", "text": "Mend true.", "choices": [{"label": "Thank you.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],

	# ══════════════════ MOROBOROS (6) ════════════════════════════════════════

	"mb_paradox_default": [
		{"speaker": "Timekeeper Paradox", "text": "Your next question — yes. Your question before that — also yes. The question you haven't formed yet — no.",
			"choices": [
				{"label": "Ask anyway (Arcane)", "skill": "Arcane", "dc_offset": 2, "next_pass": 1, "next_fail": 2, "reward": "sp:5|intel:Moroboros has an 'hour that shouldn't exist' between 2:13 and 2:14 AM — it is spreading", "fail_reward": ""},
				{"label": "Trust their warning (Intuition)", "skill": "Intuition", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "xp:35|consequence:mb_paradox_acknowledged", "fail_reward": ""},
				{"label": "Leave", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Timekeeper Paradox", "text": "You always return. You returned yesterday. Tomorrow also.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Timekeeper Paradox", "text": "Not yet. Later, when you have already asked.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"mb_null_default": [
		{"speaker": "Dream Shepherd Null", "text": "Dreams leak in this district. Mostly other people's. If you recognize a memory that isn't yours, that's normal here. Keep moving.",
			"choices": [
				{"label": "Seek a lost dream (Arcane)", "skill": "Arcane", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "sp:3|intel:Null can return stolen dreams — for a price", "fail_reward": ""},
				{"label": "Share a dream (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "xp:25|rep:Dreams:2", "fail_reward": ""},
				{"label": "Walk on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Dream Shepherd Null", "text": "Sleep well. And when you don't, remember me.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Dream Shepherd Null", "text": "Try dreaming first. Return after.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"mb_six_default": [
		{"speaker": "Reality Weaver Six", "text": "I weave small patches over tears in local reality. The tears are FASTER than I am, lately. I am considering retirement.",
			"choices": [
				{"label": "Help weave (Arcane)", "skill": "Arcane", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "sp:5|xp:40|rep:Moroboros:4", "fail_reward": ""},
				{"label": "Offer materials (25g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:25|item:Scroll of Protection", "fail_reward": ""},
				{"label": "Move on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Reality Weaver Six", "text": "Another hand helps. Return when you can.", "choices": [{"label": "I will.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Reality Weaver Six", "text": "Subtler work needed. Come back steadier.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"mb_smith_default": [
		{"speaker": "The Impossible Smith", "text": "Steel behaves differently here. I've made a knife that cuts only mornings. Useless most of the time. Rented well, occasionally.",
			"choices": [
				{"label": "Commission (70g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:70|item:Iron Shield", "fail_reward": ""},
				{"label": "Discuss weird steel (Learnedness)", "skill": "Learnedness", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "xp:30|rep:Artisans:2", "fail_reward": ""},
				{"label": "Move on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "The Impossible Smith", "text": "Cut only what you mean to.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"mb_surreal_default": [
		{"speaker": "The Surreal One", "text": "Hello. Also: goodbye. Also: maybe. The order is yours to pick.",
			"choices": [
				{"label": "Bargain for impossibility (Speechcraft)", "skill": "Speechcraft", "dc_offset": 2, "next_pass": 1, "next_fail": -1, "reward": "item:Scroll of Protection|sp:3|intel:The 'hour that shouldn't exist' can be entered — if you know the right street", "fail_reward": ""},
				{"label": "Just nod", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "xp:15", "fail_reward": ""},
				{"label": "Back away smoothly", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "The Surreal One", "text": "Farewell. Also, hello. Good day, in both directions.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"mb_zera_default": [
		{"speaker": "Future-Echo Zera", "text": "I am the echo of someone who will become me. Every moment I lag a little less. When I catch up I will be real.",
			"choices": [
				{"label": "Measure the lag (Perception)", "skill": "Perception", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "xp:40|intel:Zera catches up to herself on the night of a regional convergence — six days out", "fail_reward": ""},
				{"label": "Keep her company (Creature Handling)", "skill": "Creature Handling", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "rep:Moroboros:3|sp:2", "fail_reward": ""},
				{"label": "Leave", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Future-Echo Zera", "text": "Thank you for noticing me. Most don't. Some of me will remember.", "choices": [{"label": "Take care.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Future-Echo Zera", "text": "Another echo ahead. Come back when I have.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],

	# ══════════════════ VULCAN VALLEY (6) ════════════════════════════════════

	"vv_pyrus_default": [
		{"speaker": "Forgemaster Pyrus", "text": "I hammer meteor steel. Most smiths have never SEEN it. I get it by the cartload because things fall from the sky here.",
			"choices": [
				{"label": "Buy meteor blade (100g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:100|item:Iron Shield", "fail_reward": ""},
				{"label": "Ask about the Heart (Intuition)", "skill": "Intuition", "dc_offset": 1, "next_pass": 2, "next_fail": -1, "reward": "intel:The titan heart beneath the valley BEATS — Pyrus times his hammer to it", "fail_reward": ""},
				{"label": "Browse", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Forgemaster Pyrus", "text": "Burn true.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Forgemaster Pyrus", "text": "The heart is ancient. Older than the valley. When it stops — the valley stops. Keep watch.", "choices": [{"label": "Noted.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:vv_heart_warning", "fail_reward": ""}]},
	],
	"vv_mira_default": [
		{"speaker": "Lava-Wraith Mira", "text": "I used to be alive. Now I am mostly heat and memory. The molten pool is kinder than most people were.",
			"choices": [
				{"label": "Listen (Intuition)", "skill": "Intuition", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "xp:35|intel:Mira was the previous Lightsmith of the valley — the titan heart burned her to this state", "fail_reward": ""},
				{"label": "Offer passage (Speechcraft)", "skill": "Speechcraft", "dc_offset": 1, "next_pass": 1, "next_fail": -1, "reward": "rep:Valley:3|sp:2", "fail_reward": ""},
				{"label": "Step back", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Lava-Wraith Mira", "text": "Kindness warms even me. Return sometime.", "choices": [{"label": "I will.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"vv_rhael_default": [
		{"speaker": "Ember Scout Rhael", "text": "Ember lines shift daily. Mapped them yesterday; have to remap today. Tomorrow the lava is probably where my feet currently are.",
			"choices": [
				{"label": "Scout with him (Survival)", "skill": "Survival", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "gold:50|xp:40|intel:Ember lines trace a pattern — a second heart beats beneath the first, slightly offset", "fail_reward": "lose_gold:10"},
				{"label": "Share supplies (10g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:10|rep:Valley:2", "fail_reward": ""},
				{"label": "Stay in town", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Ember Scout Rhael", "text": "Steady boots. Good scouting.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Ember Scout Rhael", "text": "Lava moved faster than you. Come back sharper.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"vv_solne_default": [
		{"speaker": "Ember Trader Solne", "text": "Glass beads from ember falls. Obsidian from cooled crusts. Solne has the finest stock in any valley. Questionable but finest.",
			"choices": [
				{"label": "Buy bead set (30g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:30|item:Scroll of Protection", "fail_reward": ""},
				{"label": "Haggle (Speechcraft)", "skill": "Speechcraft", "dc_offset": 1, "next_pass": 1, "next_fail": -1, "reward": "item:Health Potion", "fail_reward": ""},
				{"label": "Browse", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Ember Trader Solne", "text": "Return! Embers are constantly in stock.", "choices": [{"label": "Ha.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"vv_ignus_default": [
		{"speaker": "Priest Ignus", "text": "The volcano IS the shrine. We do not build on it; we ask permission to stand near it. Most of the time, it permits.",
			"choices": [
				{"label": "Pray (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "heal:full|rep:Church:3", "fail_reward": ""},
				{"label": "Study the rites (Arcane)", "skill": "Arcane", "dc_offset": 1, "next_pass": 1, "next_fail": -1, "reward": "sp:4|intel:The heart beats faster before eruptions — Ignus has been counting, and it has not slowed in months", "fail_reward": ""},
				{"label": "Bow and leave", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Priest Ignus", "text": "Walk in the fire's favor.", "choices": [{"label": "Blessings.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"vv_vulk_default": [
		{"speaker": "Firesmith Vulk", "text": "Apprenticed to Pyrus. Ten years in. Allowed to hit iron. Not yet allowed to LOOK AT meteor steel. Soon. Maybe.",
			"choices": [
				{"label": "Encourage him (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "rep:Artisans:2|xp:20", "fail_reward": ""},
				{"label": "Teach him a trick (Learnedness)", "skill": "Learnedness", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "xp:30|rep:Valley:2", "fail_reward": ""},
				{"label": "Move on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Firesmith Vulk", "text": "Remembered! Always welcome at the anvil!", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],

	# ══════════════════ INFERNAL MACHINE (6) ═════════════════════════════════

	"im_damn_default": [
		{"speaker": "Overseer Damn", "text": "Welcome to the Works. Every soul processed here signed a contract. Even those who say they didn't — they did. Paperwork is final.",
			"choices": [
				{"label": "Review contracts (Learnedness)", "skill": "Learnedness", "dc_offset": 2, "next_pass": 1, "next_fail": 2, "reward": "xp:50|intel:Several contracts have a clause the Overseer hopes no one reads — an escape route", "fail_reward": ""},
				{"label": "Barter (Speechcraft)", "skill": "Speechcraft", "dc_offset": 2, "next_pass": 1, "next_fail": 2, "reward": "gold:60|consequence:im_damn_bargain", "fail_reward": ""},
				{"label": "Leave before committing", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Overseer Damn", "text": "PLEASE stop reading. Please. The Works function better when people stop reading.", "choices": [{"label": "Noted.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:im_found_loophole", "fail_reward": ""}]},
		{"speaker": "Overseer Damn", "text": "Your paperwork has been received. It will be processed in seventy to seven-hundred years.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"im_riva_default": [
		{"speaker": "Soul-Collector Riva", "text": "Contract work. Doors-to-souls, mostly. The commission is generous; the retirement plan is non-existent.",
			"choices": [
				{"label": "Read the fine print (Perception)", "skill": "Perception", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "intel:Riva's own contract has a flaw — she can be released if someone speaks her true name aloud in the Works", "fail_reward": ""},
				{"label": "Buy a contract-break (60g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:60|item:Scroll of Protection", "fail_reward": ""},
				{"label": "Decline", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Soul-Collector Riva", "text": "Very sharp of you. Don't share my secret lightly.", "choices": [{"label": "Your secret.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:im_riva_knows_true_name", "fail_reward": ""}]},
		{"speaker": "Soul-Collector Riva", "text": "Try again with cleaner eyes.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"im_kolk_default": [
		{"speaker": "Brass-Warden Kolk", "text": "Brass doors, brass locks, brass keys. I maintain the Works. Brass is easier than living tenants. They complain less.",
			"choices": [
				{"label": "Study the locks (Learnedness)", "skill": "Learnedness", "dc_offset": 1, "next_pass": 1, "next_fail": -1, "reward": "xp:35|intel:Kolk knows three doors in the Works that lead OUT — but he's forbidden to open them", "fail_reward": ""},
				{"label": "Offer polish (15g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:15|rep:Works:3", "fail_reward": ""},
				{"label": "Walk on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Brass-Warden Kolk", "text": "Shine true.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"im_ven_default": [
		{"speaker": "Damnation Warden Ven", "text": "I am the first face contract-breakers see. I am largely paperwork with a whip. The whip is decorative. The paperwork is the worst of it.",
			"choices": [
				{"label": "Flatter (Speechcraft)", "skill": "Speechcraft", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "rep:Works:3|xp:25", "fail_reward": ""},
				{"label": "Bribe (30g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:30|intel:Ven will overlook one contract-break per bribe — per season, not more", "fail_reward": ""},
				{"label": "Keep walking", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Damnation Warden Ven", "text": "My paperwork thanks you.", "choices": [{"label": "Ha.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Damnation Warden Ven", "text": "Too clumsy. Try later.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"im_oleaf_default": [
		{"speaker": "Sulfur Brewer Oleaf", "text": "Sulfur tea. Don't wrinkle your nose. It cures seven kinds of curse. One of them's the curse of wrinkling your nose at sulfur tea.",
			"choices": [
				{"label": "Drink some (20g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:20|heal:full|item:Antitoxin", "fail_reward": ""},
				{"label": "Study recipes (Learnedness)", "skill": "Learnedness", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "xp:30|rep:Artisans:2", "fail_reward": ""},
				{"label": "Decline", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Sulfur Brewer Oleaf", "text": "The tea notes your patronage.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"im_marrok_default": [
		{"speaker": "Infernal Smith Marrok", "text": "Brass won't cut, iron won't burn, meteor steel won't settle. I work a fourth alloy, and no — you can't know what's in it.",
			"choices": [
				{"label": "Commission blade (80g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:80|item:Iron Shield", "fail_reward": ""},
				{"label": "Inspect the alloy (Perception)", "skill": "Perception", "dc_offset": 2, "next_pass": 1, "next_fail": -1, "reward": "intel:Marrok's fourth alloy is bound-soul metal — each blade contains a willing contract-breaker", "fail_reward": ""},
				{"label": "Walk on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Infernal Smith Marrok", "text": "Cut deep.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],

	# ══════════════════ ARCANE COLLAPSE (5) ══════════════════════════════════

	"ac_vess_default": [
		{"speaker": "Reality Surgeon Vess", "text": "Yes, reality has tears. Yes, I stitch them. No, you cannot watch — the technique involves YOUR reality as well.",
			"choices": [
				{"label": "Offer to assist (Arcane)", "skill": "Arcane", "dc_offset": 2, "next_pass": 1, "next_fail": 2, "reward": "sp:5|xp:50|intel:The Collapse is widening — three tears have merged this week", "fail_reward": ""},
				{"label": "Study technique (Learnedness)", "skill": "Learnedness", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "xp:35|sp:2", "fail_reward": ""},
				{"label": "Leave", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Reality Surgeon Vess", "text": "Steady hand. Come back when reality's tears are fresh.", "choices": [{"label": "I will.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Reality Surgeon Vess", "text": "Too rough. Try not to SHAKE reality while handling it.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"ac_telm_default": [
		{"speaker": "Mana-Mad Priest Telm", "text": "MANA THINGS MANA THINGS MANA! — ah, sorry. Centering now. Yes. Hello.",
			"choices": [
				{"label": "Steady him (Medical)", "skill": "Medical", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "xp:30|intel:Telm glimpses futures when stable — he has seen the Collapse consume the Kingdom", "fail_reward": ""},
				{"label": "Meditate together (Speechcraft)", "skill": "Speechcraft", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "sp:3|rep:Church:2", "fail_reward": ""},
				{"label": "Step away carefully", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Mana-Mad Priest Telm", "text": "...thank you. Brief clarity. Rare. Please return when mana's quiet.", "choices": [{"label": "Peace.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Mana-Mad Priest Telm", "text": "MANA! — no wait — hello? Yes? No?", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"ac_aeol_default": [
		{"speaker": "Tower Keeper Aeol", "text": "The fractured tower sways. Always has. Tonight it sways in a new direction. That is — concerning.",
			"choices": [
				{"label": "Investigate (Perception)", "skill": "Perception", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "xp:40|intel:The tower leans toward the exact location where the missing Library manuscript has ended up", "fail_reward": ""},
				{"label": "Offer support beams (30g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:30|rep:Tower:3", "fail_reward": ""},
				{"label": "Back away from the tower", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Tower Keeper Aeol", "text": "Your sight is helpful. Return when the tower sways again.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Tower Keeper Aeol", "text": "Another sway, another time.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"ac_elyth_default": [
		{"speaker": "Spell-Trader Elyth", "text": "Spells by the ounce. Cantrips by the dozen. Rituals by appointment only. What's in your pack already?",
			"choices": [
				{"label": "Browse rituals (Arcane)", "skill": "Arcane", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "sp:4|xp:30|intel:Elyth knows pre-Veil spellforms — she teaches one freely to anyone who impresses her", "fail_reward": ""},
				{"label": "Buy a cantrip (40g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:40|sp:3|item:Scroll of Protection", "fail_reward": ""},
				{"label": "Just window-shop", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Spell-Trader Elyth", "text": "Good choice. Cast well.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"ac_orvan_default": [
		{"speaker": "Ethereal Smith Orvan", "text": "Metal goes ETHEREAL here if you hammer it long enough. Useful, sometimes. Lethal, other times. I charge accordingly.",
			"choices": [
				{"label": "Commission ethereal blade (90g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:90|item:Iron Shield", "fail_reward": ""},
				{"label": "Study technique (Learnedness)", "skill": "Learnedness", "dc_offset": 1, "next_pass": 1, "next_fail": -1, "reward": "xp:40|rep:Artisans:3", "fail_reward": ""},
				{"label": "Move on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Ethereal Smith Orvan", "text": "Strike between realities.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],

	# ══════════════════ L.I.T.O. (5) ═════════════════════════════════════════

	"lito_thought_default": [
		{"speaker": "Council Elder Thought", "text": "We council-mind. Many speak as one; one speaks as many. A mind has gone missing. We feel the absence like a dropped stitch.",
			"choices": [
				{"label": "Search with them (Intuition)", "skill": "Intuition", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "xp:50|sp:3|intel:The missing mind is Mind-Walker Zetha's — she has unwoven herself on purpose", "fail_reward": ""},
				{"label": "Offer counsel (Learnedness)", "skill": "Learnedness", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "rep:Council:4|sp:2", "fail_reward": ""},
				{"label": "Bow and leave", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Council Elder Thought", "text": "The Council thanks you. The missing mind is nearly found.", "choices": [{"label": "Honor.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Council Elder Thought", "text": "Another mind is needed. Another time.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"lito_zetha_default": [
		{"speaker": "Mind-Walker Zetha", "text": "*distantly* Hello. I have unwoven. It is quieter. Do not report me to the Council. I left the threads neat.",
			"choices": [
				{"label": "Persuade return (Speechcraft)", "skill": "Speechcraft", "dc_offset": 2, "next_pass": 1, "next_fail": 2, "reward": "intel:Zetha learned something unraveling — she will share if allowed to stay unwoven", "fail_reward": ""},
				{"label": "Respect her choice (Intuition)", "skill": "Intuition", "dc_offset": 0, "next_pass": 3, "next_fail": -1, "reward": "xp:40|rep:Lito:2", "fail_reward": ""},
				{"label": "Step back", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Mind-Walker Zetha", "text": "Fine. I'll speak. The Council is one thread short of unraveling itself. I left BEFORE it happened.", "choices": [{"label": "Noted.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:lito_council_unraveling", "fail_reward": ""}]},
		{"speaker": "Mind-Walker Zetha", "text": "*fades*", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Mind-Walker Zetha", "text": "You are kind. I will remember, even unwoven.", "choices": [{"label": "Peace.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"lito_astral_default": [
		{"speaker": "Dream Shepherd Astral", "text": "The astral bridges connect all sleeping minds. Someone has been crossing them awake. That is TECHNICALLY illegal.",
			"choices": [
				{"label": "Offer patrol (Perception)", "skill": "Perception", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "gold:60|xp:40", "fail_reward": "lose_gold:15"},
				{"label": "Ask who's crossing (Intuition)", "skill": "Intuition", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "intel:The unauthorized crosser is from Moroboros — an echo of someone not yet real", "fail_reward": ""},
				{"label": "Walk on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Dream Shepherd Astral", "text": "Clean work. Return any night.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Dream Shepherd Astral", "text": "Sleep first, patrol later.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"lito_smith_default": [
		{"speaker": "Mindsmith Iron-Thought", "text": "I forge instruments that think — little brass tools with preferences. They prefer NOT to be dropped. Reasonable of them.",
			"choices": [
				{"label": "Commission a thinking tool (70g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:70|item:Scroll of Protection", "fail_reward": ""},
				{"label": "Study the craft (Learnedness)", "skill": "Learnedness", "dc_offset": 1, "next_pass": 1, "next_fail": -1, "reward": "xp:35|rep:Artisans:3", "fail_reward": ""},
				{"label": "Move on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Mindsmith Iron-Thought", "text": "May your tools consent.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"lito_voi_default": [
		{"speaker": "Consciousness Trader Voi", "text": "Trade a memory, receive a skill. Trade a dream, receive a truth. Trade a name, receive — well. Don't trade a name.",
			"choices": [
				{"label": "Trade a minor memory (Speechcraft)", "skill": "Speechcraft", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "xp:40|sp:3|intel:Voi trades with the Council elders — she knows what they've hidden from each other", "fail_reward": ""},
				{"label": "Buy with coin (60g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:60|item:Scroll of Protection", "fail_reward": ""},
				{"label": "Decline trade", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Consciousness Trader Voi", "text": "Pleasure. Your memory is safe with me. Mostly.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Consciousness Trader Voi", "text": "A poor offering. Come back with deeper memories.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],

	# ══════════════════ LAND OF TOMORROW (5) ═════════════════════════════════

	"lot_orbit_default": [
		{"speaker": "Commander Orbit", "text": "Station's nominal. Mostly. We had an airlock incident three days back. Someone stepped OUT. Nobody stepped in to replace them.",
			"choices": [
				{"label": "Investigate (Perception)", "skill": "Perception", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "xp:45|intel:The airlock logs were tampered with — the missing crew member WALKED OUT willingly", "fail_reward": ""},
				{"label": "Volunteer for patrol (Military)", "skill": "Military", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "gold:70|xp:40", "fail_reward": "lose_gold:15"},
				{"label": "Wish him luck", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Commander Orbit", "text": "Appreciate the sharp eye. Don't tell the crew yet.", "choices": [{"label": "Understood.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:lot_orbit_confides", "fail_reward": ""}]},
		{"speaker": "Commander Orbit", "text": "Another round, perhaps.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"lot_freya_default": [
		{"speaker": "Cryo-Tech Freya", "text": "Cryo pods are stable. All forty-two of them. We had forty-THREE last month. I have no memory of forty-three. My logs do.",
			"choices": [
				{"label": "Review logs (Learnedness)", "skill": "Learnedness", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "xp:40|intel:The missing pod contained someone labeled 'Pilot Zero' — Freya was the one who erased them", "fail_reward": ""},
				{"label": "Calm her (Medical)", "skill": "Medical", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "rep:Station:2|heal:full", "fail_reward": ""},
				{"label": "Walk on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Cryo-Tech Freya", "text": "Thank you. The gap is easier to bear with a witness.", "choices": [{"label": "Peace.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Cryo-Tech Freya", "text": "...I'll check later. Later.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"lot_peel_default": [
		{"speaker": "Stellar Chef Peel", "text": "Dehydrated everything! It rehydrates into roast beef, roast duck, roast ANYTHING. I forget which is which. You pick.",
			"choices": [
				{"label": "Buy a meal (12g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:12|item:Field Rations|heal:full", "fail_reward": ""},
				{"label": "Share station gossip (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "intel:Peel overheard Orbit mention 'Pilot Zero' last week — nobody on station has that name", "fail_reward": ""},
				{"label": "Walk on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Stellar Chef Peel", "text": "Rehydrate safely!", "choices": [{"label": "Ha.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"lot_vrix_default": [
		{"speaker": "Plasma Engineer Vrix", "text": "Reactor's purring. Purring WRONG, but purring. Frequency shift, never seen it. I'm TRYING not to be alarmed.",
			"choices": [
				{"label": "Diagnose (Learnedness)", "skill": "Learnedness", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "xp:40|intel:The reactor frequency matches the pre-Veil broadcast Ellar detected at the Obelisks", "fail_reward": ""},
				{"label": "Assist repair (25g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:25|rep:Station:3", "fail_reward": ""},
				{"label": "Leave quickly", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Plasma Engineer Vrix", "text": "Good data. Don't tell anyone yet.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Plasma Engineer Vrix", "text": "Subtler eye needed. Perhaps another shift.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"lot_kelvyn_default": [
		{"speaker": "Airlock Officer Kelvyn", "text": "Every airlock cycle is logged. The one from three days ago is logged but not RECORDED. That shouldn't be possible. The logs say it's possible.",
			"choices": [
				{"label": "Inspect the airlock (Perception)", "skill": "Perception", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "xp:45|intel:Hand-print on the outer door matches no crew member — but matches the pre-Veil symbols on the Obelisks", "fail_reward": ""},
				{"label": "Offer a shift of rest (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "rep:Station:3|heal:full", "fail_reward": ""},
				{"label": "Move on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Airlock Officer Kelvyn", "text": "Your sharpness is appreciated. Come back at shift change.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Airlock Officer Kelvyn", "text": "Another look later.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],

	# ══════════════════ CITY OF ETERNAL LIGHT (8) ════════════════════════════

	"cel_herald_default": [
		{"speaker": "The Sun Sovereign's Herald", "text": "HEAR, seekers. The Sun Sovereign grants audience to the worthy. The worthy are distressingly few.",
			"choices": [
				{"label": "Petition for audience (Speechcraft)", "skill": "Speechcraft", "dc_offset": 2, "next_pass": 1, "next_fail": 2, "reward": "rep:Sun:5|intel:The Sovereign has barred angelic advisors from court — no one knows why", "fail_reward": ""},
				{"label": "Observe the Herald (Intuition)", "skill": "Intuition", "dc_offset": 1, "next_pass": 3, "next_fail": 2, "reward": "xp:40|consequence:cel_herald_suspicion", "fail_reward": ""},
				{"label": "Bow and leave", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "The Sun Sovereign's Herald", "text": "Your petition is noted. Return at dawn with offering.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "The Sun Sovereign's Herald", "text": "Unworthy. Depart.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "The Sun Sovereign's Herald", "text": "You see what others do not. The Herald is new — the old one vanished seven days ago.", "choices": [{"label": "Noted.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"cel_uri_default": [
		{"speaker": "Angel-Speaker Uri", "text": "The angels have grown quiet. I spoke daily with them once. Now — nothing. Either they have left us, or they have been silenced.",
			"choices": [
				{"label": "Seek a whisper (Arcane)", "skill": "Arcane", "dc_offset": 2, "next_pass": 1, "next_fail": 2, "reward": "sp:5|intel:The angels were banished from court by the new Herald — Uri suspects he is not what he claims", "fail_reward": ""},
				{"label": "Offer prayer (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 1, "next_fail": 2, "reward": "rep:Sun:4|heal:full|sp:2", "fail_reward": ""},
				{"label": "Bow and leave", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Angel-Speaker Uri", "text": "A whisper! I'll trust you with it when more comes. Return soon.", "choices": [{"label": "I will.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:cel_uri_ally", "fail_reward": ""}]},
		{"speaker": "Angel-Speaker Uri", "text": "The silence answers no one today.", "choices": [{"label": "Peace.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"cel_vena_default": [
		{"speaker": "Lightforge Master Vena", "text": "Light-metal. Hardest craft in the realms. My hammer shines when struck. I blink a lot.",
			"choices": [
				{"label": "Commission lightblade (120g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:120|item:Iron Shield", "fail_reward": ""},
				{"label": "Discuss metallurgy (Learnedness)", "skill": "Learnedness", "dc_offset": 1, "next_pass": 1, "next_fail": -1, "reward": "xp:40|rep:Artisans:3", "fail_reward": ""},
				{"label": "Move on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Lightforge Master Vena", "text": "Strike bright.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"cel_sess_default": [
		{"speaker": "Divine Merchant Sess", "text": "Relics! Artifacts! Possibly fake but OFTEN real! The Church approves my sales... mostly. Legal enough. Look around.",
			"choices": [
				{"label": "Buy relic (80g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:80|item:Scroll of Protection", "fail_reward": ""},
				{"label": "Appraise stock (Perception)", "skill": "Perception", "dc_offset": 1, "next_pass": 1, "next_fail": -1, "reward": "intel:One relic on Sess's shelf IS authentic — it predates the Veil — he doesn't know what he has", "fail_reward": ""},
				{"label": "Browse", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Divine Merchant Sess", "text": "Come back! The Church won't mind!", "choices": [{"label": "Ha.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"cel_phin_default": [
		{"speaker": "Celestial Barkeep Phin", "text": "Ale of the Eternal Light. Doesn't make you drunker; makes you NICER. Unless you're already nice, in which case it makes you honest.",
			"choices": [
				{"label": "Pour a round (15g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:15|heal:full|sp:2|intel:Phin heard a pilgrim claim the Sovereign has not been seen in person for three weeks", "fail_reward": ""},
				{"label": "Listen to the room (Perception)", "skill": "Perception", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "intel:Court rumors confirm — the Sovereign's public appearances are all through the Herald's voice", "fail_reward": ""},
				{"label": "Walk out", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Celestial Barkeep Phin", "text": "Back anytime. Honest drinkers welcome.", "choices": [{"label": "Cheers.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"cel_caen_default": [
		{"speaker": "Lightbringer Caen", "text": "Light-magic is the second-rarest. Only Void-magic is rarer. I practice both, privately. The Church would not approve.",
			"choices": [
				{"label": "Discuss magic (Arcane)", "skill": "Arcane", "dc_offset": 2, "next_pass": 1, "next_fail": 2, "reward": "sp:5|xp:40|intel:Caen detects imbalance in the city's light — something absorbs it near the palace", "fail_reward": ""},
				{"label": "Trade a charm (50g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:50|item:Scroll of Protection|sp:2", "fail_reward": ""},
				{"label": "Move on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Lightbringer Caen", "text": "Your instincts are sharp. Return when you have more to compare.", "choices": [{"label": "I will.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Lightbringer Caen", "text": "Subtler, next time.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"cel_mira_default": [
		{"speaker": "Ascension Guide Mira", "text": "The path to ascension requires three trials. Many begin. Few finish. The ones who finish — most go missing within a year.",
			"choices": [
				{"label": "Ask about the missing (Intuition)", "skill": "Intuition", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "intel:The 'ascended' are being collected by the Herald — Mira has traced every disappearance to one event: a royal audience", "fail_reward": ""},
				{"label": "Begin a trial (25g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:25|rep:Sun:3|xp:30", "fail_reward": ""},
				{"label": "Wish her well", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Ascension Guide Mira", "text": "You ask the right questions. We need more of that.", "choices": [{"label": "Honor.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:cel_mira_alliance", "fail_reward": ""}]},
		{"speaker": "Ascension Guide Mira", "text": "Walk further, ask later.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"cel_kel_default": [
		{"speaker": "Warden of Radiance Kel", "text": "I guard the Palace perimeter. Recently reassigned from inner watch. No reason given. I was the last inner guard to have seen the Sovereign in person.",
			"choices": [
				{"label": "Press for detail (Intuition)", "skill": "Intuition", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "xp:45|intel:Kel saw the Sovereign collapsed in his quarters three weeks ago — was told to tell no one, then reassigned", "fail_reward": ""},
				{"label": "Offer camaraderie (Military)", "skill": "Military", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "gold:40|rep:Sun:3", "fail_reward": ""},
				{"label": "Walk on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Warden of Radiance Kel", "text": "...right. I needed to tell someone. If I turn up dead, start with the Herald.", "choices": [{"label": "Understood.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:cel_kel_last_witness", "fail_reward": ""}]},
		{"speaker": "Warden of Radiance Kel", "text": "Another day, perhaps.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],

	# ══════════════════ HALLOWED SACRAMENT (7) ═══════════════════════════════

	"hs_cassian_default": [
		{"speaker": "High Ascendant Cassian", "text": "The Sacrament stands ready to elevate the worthy. It has stood ready for four years. No worthy have come. I have begun to wonder if the test is too high — or the world too low.",
			"choices": [
				{"label": "Offer yourself as candidate (Learnedness)", "skill": "Learnedness", "dc_offset": 2, "next_pass": 1, "next_fail": 2, "reward": "xp:60|rep:Sacrament:5|intel:The test requires three moral trials — Cassian will reveal them only to accepted candidates", "fail_reward": ""},
				{"label": "Discuss the stagnation (Intuition)", "skill": "Intuition", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "intel:Cassian suspects the Light itself has shifted — the Sacrament tests against a standard that no longer matches the world", "fail_reward": ""},
				{"label": "Bow and leave", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "High Ascendant Cassian", "text": "Come back prepared. The Sacrament waits.", "choices": [{"label": "I will.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "High Ascendant Cassian", "text": "Unworthy today. Return when ready.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"hs_bevin_default": [
		{"speaker": "Trial Master Bevin", "text": "My job is to make the Sacrament hard. I am very good at my job. Nobody passes. I'm told this is a PROBLEM.",
			"choices": [
				{"label": "Ask for one trial (Military)", "skill": "Military", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "gold:60|xp:45|rep:Sacrament:3", "fail_reward": "lose_gold:20"},
				{"label": "Negotiate difficulty (Speechcraft)", "skill": "Speechcraft", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "intel:Bevin will grant a trial at reduced difficulty for genuine seekers — but only once", "fail_reward": ""},
				{"label": "Walk on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Trial Master Bevin", "text": "Passed. Barely. That's how it should feel.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Trial Master Bevin", "text": "Failed. Expected. Come back.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"hs_irwyn_default": [
		{"speaker": "Meditation Master Irwyn", "text": "Sit, if you wish. The floor is cold but the silence is honest. Most find one or the other unbearable.",
			"choices": [
				{"label": "Meditate with him (Arcane)", "skill": "Arcane", "dc_offset": 1, "next_pass": 1, "next_fail": -1, "reward": "sp:5|xp:40|heal:full", "fail_reward": ""},
				{"label": "Ask about the Light's shift (Intuition)", "skill": "Intuition", "dc_offset": 1, "next_pass": 1, "next_fail": -1, "reward": "intel:Irwyn has felt the Light 'tilt' in recent months — toward the Crimson Throne, of all places", "fail_reward": ""},
				{"label": "Walk past", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Meditation Master Irwyn", "text": "Silence is yours now. Keep a piece of it.", "choices": [{"label": "Peace.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"hs_odris_default": [
		{"speaker": "Pilgrim-Priest Odris", "text": "Pilgrimage this year has been THIN. Faith is thin. Everywhere I walk, the temples stand tall and the pews stay empty.",
			"choices": [
				{"label": "Offer fellowship (Speechcraft)", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "rep:Sacrament:3|heal:full|xp:25", "fail_reward": ""},
				{"label": "Donate (20g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:20|rep:Church:4", "fail_reward": ""},
				{"label": "Wish him well", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Pilgrim-Priest Odris", "text": "Walk with light in your eyes.", "choices": [{"label": "Blessings.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"hs_evra_default": [
		{"speaker": "Sacred Forger Evra", "text": "I forge only blessed steel. The blessings come from the Sacrament; they grow weaker every year. I may soon be forging mere expensive steel.",
			"choices": [
				{"label": "Commission blessed gear (100g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:100|item:Iron Shield", "fail_reward": ""},
				{"label": "Discuss the weakening (Learnedness)", "skill": "Learnedness", "dc_offset": 1, "next_pass": 1, "next_fail": -1, "reward": "xp:35|intel:The blessings fade in step with the Light's 'tilt' — both point back to the Crimson Throne", "fail_reward": ""},
				{"label": "Move on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Sacred Forger Evra", "text": "Hammer true, bless truer.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"hs_sessa_default": [
		{"speaker": "Vault Keeper Sessa", "text": "The Vault holds three sacred items. One is now MISSING. I alone have the key. I am suspect number one. I would also be suspect number one.",
			"choices": [
				{"label": "Clear her (Perception)", "skill": "Perception", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "xp:45|rep:Sacrament:4|intel:The vault was entered by a second key — someone copied Sessa's key in the last month", "fail_reward": ""},
				{"label": "Help search (Survival)", "skill": "Survival", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "gold:40|rep:Sacrament:2", "fail_reward": ""},
				{"label": "Walk on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Vault Keeper Sessa", "text": "Thank you. I thought I was losing my mind.", "choices": [{"label": "Peace.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:hs_sessa_cleared", "fail_reward": ""}]},
		{"speaker": "Vault Keeper Sessa", "text": "I need harder evidence. Come back with more.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"hs_marmot_default": [
		{"speaker": "Garden Tender Marmot", "text": "Sacred gardens. Sacred pests, technically. I'm not supposed to pick them, but they'll devour everything if I don't. Theological dilemma.",
			"choices": [
				{"label": "Help with pests (Creature Handling)", "skill": "Creature Handling", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "xp:30|rep:Sacrament:2|item:Field Rations", "fail_reward": ""},
				{"label": "Bring sacred water (15g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:15|heal:full|sp:2", "fail_reward": ""},
				{"label": "Leave her to it", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Garden Tender Marmot", "text": "Garden thanks you. The pests don't, but they don't count.", "choices": [{"label": "Ha.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],

	# ══════════════════ BEATING HEART OF THE VOID (5) ════════════════════════

	"bhv_venn_default": [
		{"speaker": "Heart-Keeper Venn", "text": "The Heart beats. It has always beat. Recently it has been beating — differently. Not faster. Different RHYTHM. I fear rhythm changes.",
			"choices": [
				{"label": "Listen with him (Medical)", "skill": "Medical", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "xp:50|intel:The Heart now beats in a cadence matching pre-Veil cosmological frequencies — it is waking", "fail_reward": ""},
				{"label": "Offer to soothe (Arcane)", "skill": "Arcane", "dc_offset": 2, "next_pass": 1, "next_fail": 2, "reward": "sp:5|rep:Heart:4", "fail_reward": ""},
				{"label": "Back away", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Heart-Keeper Venn", "text": "Your ear is true. The Heart does not reject you. Rare.", "choices": [{"label": "Honor.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "consequence:bhv_heart_acknowledges", "fail_reward": ""}]},
		{"speaker": "Heart-Keeper Venn", "text": "The Heart does not know you yet. Return.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"bhv_slix_default": [
		{"speaker": "Mutation Merchant Slix", "text": "Mutation by the dose! Minor enhancements. Tiny horns, mostly. Prehensile tongue available. Customer discretion advised, because customers rarely discretize.",
			"choices": [
				{"label": "Buy a mutation (50g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:50|sp:3|item:Health Potion|consequence:bhv_minor_mutation", "fail_reward": ""},
				{"label": "Inspect safety (Medical)", "skill": "Medical", "dc_offset": 1, "next_pass": 1, "next_fail": -1, "reward": "xp:35|intel:Slix's mutations are side effects of the Heart's awakening — she doesn't know she's been harvesting the byproduct", "fail_reward": ""},
				{"label": "Browse", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Mutation Merchant Slix", "text": "Enjoy your new feature! Results are final!", "choices": [{"label": "Ha.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"bhv_oorma_default": [
		{"speaker": "Flesh-Priest Oorma", "text": "Flesh is the Void's garment. When the Heart wakes, it will need new garments. I — hm. I should stop talking. You look squeamish.",
			"choices": [
				{"label": "Press the priest (Intuition)", "skill": "Intuition", "dc_offset": 2, "next_pass": 1, "next_fail": 2, "reward": "xp:50|intel:Oorma's order harvests volunteers — the 'new flesh' is not metaphor", "fail_reward": ""},
				{"label": "Offer prayer (Speechcraft)", "skill": "Speechcraft", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "rep:Heart:2|sp:3", "fail_reward": ""},
				{"label": "Leave this conversation", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Flesh-Priest Oorma", "text": "Few ask. Fewer persist. You may be useful. Or useful DIFFERENTLY.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Flesh-Priest Oorma", "text": "Another day. The flesh is patient.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"bhv_coccoon_default": [
		{"speaker": "The Coccoon Guardian", "text": "Shhh. The chrysalis sleeps. Inside: someone. Outside: me. Between us, the waking. Wait patiently or LEAVE.",
			"choices": [
				{"label": "Observe silently (Perception)", "skill": "Perception", "dc_offset": 1, "next_pass": 1, "next_fail": 2, "reward": "xp:40|intel:The chrysalis contains a mind-shaped humanoid — it matches the description of Pilot Zero from the Land of Tomorrow", "fail_reward": ""},
				{"label": "Offer incense (15g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:15|sp:2|rep:Heart:2", "fail_reward": ""},
				{"label": "Back away", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "The Coccoon Guardian", "text": "Quiet kindness. The chrysalis felt it.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "The Coccoon Guardian", "text": "Too loud. Go.", "choices": [{"label": "…", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
	"bhv_karix_default": [
		{"speaker": "Chitin Forger Karix", "text": "Chitin armor is lighter than steel, stronger than bronze, and hums when the Heart beats. Disorienting. I charge extra for the hum.",
			"choices": [
				{"label": "Commission chitin gear (110g)", "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1, "reward": "lose_gold:110|item:Iron Shield", "fail_reward": ""},
				{"label": "Study the material (Learnedness)", "skill": "Learnedness", "dc_offset": 1, "next_pass": 1, "next_fail": -1, "reward": "xp:40|intel:Karix's chitin comes from shed skin of the Heart itself — the Heart sheds when it breathes harder", "fail_reward": ""},
				{"label": "Move on", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
		{"speaker": "Chitin Forger Karix", "text": "Wear it loud.", "choices": [{"label": "Aye.", "skill": "", "dc_offset": 0, "next_pass": -1, "next_fail": -1, "reward": "", "fail_reward": ""}]},
	],
}

static func get_tree(tree_id: String) -> Array:
	return DIALOGUE_TREES.get(tree_id, [])

static func has_tree(tree_id: String) -> bool:
	return DIALOGUE_TREES.has(tree_id)
