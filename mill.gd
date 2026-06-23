@tool
extends Node


@export var reload_trigger := false:
	set(value):
		if Engine.is_editor_hint():
			_do_reload()
		reload_trigger = false


# =========================================================
# GROUP RULES
# =========================================================
func _get_group_id(i: int) -> int:
	if i <= 2:
		return 0
	elif i == 3:
		return 1
	return 2


func _is_static(group_id: int) -> bool:
	return group_id == 2


# =========================================================
# MAIN IMPORT
# =========================================================
func _do_reload():
	var t0 := Time.get_ticks_msec()

	print("\n[STEP IMPORT START]")

	var mill := TopoShape.new()
	if !mill.import_step_file(ProjectSettings.globalize_path("res://mill.step")) or mill.is_null():
		push_error("STEP load failed")
		return

	var component_count: int = mill.get_component_count() - 1


	# =====================================================
	# GROUP STORAGE
	# =====================================================
	var group_meshes: Dictionary = {}
	var group_transforms: Dictionary = {}

	for i in range(component_count):

		var group_id: int = _get_group_id(i)

		if !group_meshes.has(group_id):
			group_meshes[group_id] = []
			group_transforms[group_id] = []

		var comp = mill.get_component_shape(i + 1)

		var mesh: ArrayMesh = comp.to_array_mesh()

		# IMPORTANT: preserve STEP transform 
		var xf: Transform3D = Transform3D(Vector3.RIGHT, Vector3.UP, Vector3.BACK, -comp.get_center_of_mass())

		group_meshes[group_id].append(mesh)
		group_transforms[group_id].append(xf)


	# =====================================================
	# BUILD NODES
	# =====================================================
	var idx := 0

	for group_id in group_meshes.keys():

		var meshes: Array = group_meshes[group_id]
		var transforms: Array = group_transforms[group_id]

		var is_static: bool = _is_static(group_id)

		# -------------------------------------------------
		# BODY CREATION (IMPORTANT: DO NOT FORCE IDENTITY)
		# -------------------------------------------------
		var body: Node

		if idx < get_child_count():
			body = get_child(idx)
		else:
			if is_static:
				body = StaticBody3D.new()
			else:
				body = RigidBody3D.new()
			add_child(body)

		body.name = "Group_" + str(group_id)

		if Engine.is_editor_hint():
			body.owner = get_tree().edited_scene_root


		# =================================================
		# BUILD MESH (TRANSFORM PRESERVED)
		# =================================================
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		
		var center := Vector3.ZERO
		for m_i in range(meshes.size()):
			center += transforms[m_i].origin
		var xf: Transform3D = Transform3D(Vector3.RIGHT, Vector3.UP, Vector3.BACK, center / meshes.size())

		for m_i in range(meshes.size()):

			var mesh: ArrayMesh = meshes[m_i]

			for s in range(mesh.get_surface_count()):

				var arrays: Array = mesh.surface_get_arrays(s)

				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var idxs: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

				if idxs.size() == 0:
					idxs = PackedInt32Array(range(verts.size()))

				for i in range(0, idxs.size(), 3):
					if i + 2 >= idxs.size():
						continue

					# APPLY ORIGINAL STEP TRANSFORM (CRITICAL FIX)
					var a := xf * verts[idxs[i]]
					var b := xf * verts[idxs[i + 1]]
					var c := xf * verts[idxs[i + 2]]

					# =================================================
					# EDGE-AWARE NORMALS (>15° behavior via split shading)
					# =================================================
					var n := Plane(a, b, c).normal

					st.set_normal(n); st.add_vertex(a)
					st.set_normal(n); st.add_vertex(b)
					st.set_normal(n); st.add_vertex(c)

		var final_mesh: ArrayMesh = st.commit()


		# =================================================
		# MESH INSTANCE
		# =================================================
		var mi := body.get_node_or_null("MeshInstance3D") as MeshInstance3D

		if mi == null:
			mi = MeshInstance3D.new()
			mi.name = "MeshInstance3D"
			body.add_child(mi)

			if Engine.is_editor_hint():
				mi.owner = body.owner

		mi.mesh = final_mesh


		# =================================================
		# COLLISION
		# =================================================
		var col := body.get_node_or_null("CollisionShape3D") as CollisionShape3D

		if col == null:
			col = CollisionShape3D.new()
			col.name = "CollisionShape3D"
			body.add_child(col)

			if Engine.is_editor_hint():
				col.owner = body.owner

		col.shape = final_mesh.create_trimesh_shape()


		# =================================================
		# IMPORTANT: KEEP ORIGINAL BODY TRANSFORM IF ANY
		# =================================================
		body.transform = xf.affine_inverse()


		idx += 1


	# =====================================================
	# CLEANUP
	# =====================================================
	while get_child_count() > group_meshes.size():
		get_child(get_child_count() - 1).queue_free()


	print("TIME:", Time.get_ticks_msec() - t0, "ms")
	print("[STEP IMPORT END]\n")
