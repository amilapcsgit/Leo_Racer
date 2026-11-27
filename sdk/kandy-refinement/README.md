# Kandy refinement generator

These scripts are the 2.8 revision of the Kandy authoring project. Copy them to
the root of the editable Kandy project, alongside its local asset library and
the baseline Kandy 2.7.9 track. Use Godot 4.7.2 to regenerate the scenery:

    godot --headless --path . --script res://build.gd -- baseline ../kandy-bake --generate

Leave out the generate flag to rebake hand-edited placements. Stage the baked
replacement and the other three track folders in build/tracks280 before running
the Windows packaging tools. The Ceylon Blocks source pack and the editable
asset scene are distributed separately for local authoring.
