## engine_test.gd
## Phase 1 verification — runs on startup and prints pass/fail to the Godot console.
## Open Output panel (bottom of editor) to see results.

extends Node

func _ready() -> void:
	print("=== Phase 1 GDExtension Test ===")
	var e = RimvaleAPI.engine

	# 1. Lineages
	var lineages = e.get_all_lineages()
	assert(lineages.size() > 0, "No lineages returned")
	print("PASS  get_all_lineages()  ->  %d lineages, first = '%s'" % [lineages.size(), lineages[0]])

	# 2. Feat categories
	var cats = e.get_all_feat_categories()
	assert(cats.size() == 10, "Expected 10 feat categories, got %d" % cats.size())
	print("PASS  get_all_feat_categories()  ->  %d categories" % cats.size())

	# 3. Tier-1 feats
	var t1 = e.get_feats_by_tier(1)
	assert(t1.size() > 0, "No tier-1 feats returned")
	print("PASS  get_feats_by_tier(1)  ->  %d feats" % t1.size())

	# 4. Create a character
	var handle: int = e.create_character("Vargas", "Regal Human", 20)
	assert(handle != 0, "create_character returned null handle")
	print("PASS  create_character()  ->  handle = %d" % handle)

	# 5. Basic character getters
	assert(e.get_character_name(handle) == "Vargas",  "Name mismatch")
	assert(e.get_character_level(handle) == 1,        "Level should be 1")
	assert(e.get_character_lineage_name(handle) == "Regal Human", "Lineage mismatch")
	print("PASS  character getters  (name / level / lineage)")

	# 6. Spend a feat point
	var feat_ok = e.spend_feat_point(handle, "Unity Scholar Initiate", 1)
	assert(feat_ok, "spend_feat_point failed for Unity Scholar Initiate")
	assert(e.get_character_feat_tier(handle, "Unity Scholar Initiate") == 1, "Feat tier should be 1")
	print("PASS  spend_feat_point()  /  get_character_feat_tier()")

	# 7. Domain feat
	var domain_ok = e.spend_feat_point(handle, "Ember Manipulator", 1)
	assert(domain_ok, "spend_feat_point failed for Ember Manipulator")
	print("PASS  domain feat assignment (Ember Manipulator)")

	# 8. Serialise / deserialise
	var blob: String = e.serialize_character(handle)
	assert(blob.length() > 0, "serialize_character returned empty string")
	var handle2: int = e.deserialize_character(blob)
	assert(handle2 != 0, "deserialize_character returned null handle")
	assert(e.get_character_name(handle2) == "Vargas", "Deserialised name mismatch")
	print("PASS  serialize / deserialize")

	# 9. Spells
	var spells = e.get_all_spells()
	assert(spells.size() > 0, "No spells returned")
	print("PASS  get_all_spells()  ->  %d spells" % spells.size())

	# 10. Regions
	var regions = e.get_all_regions()
	assert(regions.size() > 0, "No regions returned")
	print("PASS  get_all_regions()  ->  %d regions" % regions.size())

	# Cleanup
	e.destroy_character(handle)
	e.destroy_character(handle2)

	print("=== ALL TESTS PASSED — Phase 1 complete ===")
