# ChantLibraryData.gd
# The active authored chant registry for the current combat prototype.
extends Resource
class_name ChantLibraryData


@export var active_recipes: Array[SpellRecipeData] = []
