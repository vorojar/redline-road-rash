"""Adapt Silas6's CC-BY 4.0 motorcycle for REDLINE; run with Blender --background.

The source GLB and attribution live in assets/models/source/silas6. Geometry is
split by connected parts without welding UV seams. Only wheel-local components
rotate; the forks, swingarm and body remain fixed.
"""
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/models/source/silas6/motorcycle.glb"
OUTPUT = ROOT / "assets/models/ratchet.glb"


def components(mesh):
    parents = list(range(len(mesh.vertices)))

    def find(index):
        while parents[index] != index:
            parents[index] = parents[parents[index]]
            index = parents[index]
        return index

    def join(a, b):
        parents[find(a)] = find(b)

    # Coincident seam vertices belong to one physical part, but keep their UVs.
    coordinates = {}
    for vertex in mesh.vertices:
        key = tuple(round(value, 5) for value in vertex.co)
        if key in coordinates:
            join(vertex.index, coordinates[key])
        else:
            coordinates[key] = vertex.index
    for edge in mesh.edges:
        join(*edge.vertices)
    groups = {}
    for vertex in mesh.vertices:
        groups.setdefault(find(vertex.index), []).append(vertex.index)
    return groups.values()


def part_mesh(source, indices, name, pivot, wheel=False):
    selected = set(indices)
    polygons = [p for p in source.polygons if all(i in selected for i in p.vertices)]
    remap = {index: new for new, index in enumerate(indices)}
    mesh = bpy.data.meshes.new(name)
    positions = [source.vertices[i].co - pivot for i in indices]
    if wheel:
        # The body is shortened to fit the existing chassis. Wheels retain a
        # circular YZ cross-section so rolling cannot change their ground height.
        for position in positions:
            position.y *= (.34 / .32847) / (1.58 / 1.67044)
    mesh.from_pydata(positions, [],
                    [[remap[i] for i in p.vertices] for p in polygons])
    mesh.materials.append(source.materials[0])
    uv = mesh.uv_layers.new(name="UVMap")
    normals = []
    for new_polygon, old_polygon in zip(mesh.polygons, polygons):
        new_polygon.use_smooth = old_polygon.use_smooth
        for new_loop, old_loop in zip(new_polygon.loop_indices, old_polygon.loop_indices):
            uv.data[new_loop].uv = source.uv_layers.active.data[old_loop].uv
            normal = source.corner_normals[old_loop].vector.copy()
            if wheel:
                normal.y /= (.34 / .32847) / (1.58 / 1.67044)
            normals.append(normal.normalized())
    mesh.normals_split_custom_set(normals)
    return mesh


bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
originals = [o for o in bpy.context.scene.objects if o.type == "MESH"]
# Measured source wheel centers: Y -0.79709 / +0.87335, Z -0.41496.
# Match existing axle spacing and 0.34 m rolling radius, keeping X symmetry.
transform = Matrix.Diagonal((1.15, 1.58 / 1.67044, .34 / .32847, 1))
transform @= Matrix.Translation(Vector((0, -.03813, .74343)))
for obj in originals:
    obj.data.transform(transform @ obj.matrix_world)
    obj.parent = None
    obj.matrix_world = Matrix.Identity(4)

wheels = {}
for name, forward in [("WheelFront", .79), ("WheelRear", -.79)]:
    wheel = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(wheel)
    wheel.location = (0, forward, .34)
    wheels[name] = wheel

triangle_count = 0
for obj in originals:
    mesh = obj.data
    buckets = {"body": [], "WheelFront": [], "WheelRear": []}
    for indices in components(mesh):
        bucket = "body"
        for name, wheel in wheels.items():
            # Tires, hubs, spokes, rotors and axle ends. Long suspension/frame
            # components extend outside this cylinder and remain on the body.
            if all(abs(mesh.vertices[i].co.x) < .18 and
                   (Vector((mesh.vertices[i].co.y, mesh.vertices[i].co.z)) -
                    Vector((wheel.location.y, wheel.location.z))).length < .345
                   for i in indices):
                bucket = name
                break
        buckets[bucket].extend(indices)
    material_name = obj.active_material.name
    for bucket, indices in buckets.items():
        if not indices:
            continue
        name = "Paint" if material_name == "Main2" else material_name
        pivot = Vector() if bucket == "body" else wheels[bucket].location.copy()
        part = bpy.data.objects.new(name, part_mesh(mesh, indices, name, pivot, bucket != "body"))
        bpy.context.collection.objects.link(part)
        if bucket != "body":
            part.parent = wheels[bucket]
        triangle_count += sum(len(p.vertices) - 2 for p in part.data.polygons)
    bpy.data.objects.remove(obj, do_unlink=True)

for obj in list(bpy.context.scene.objects):
    if obj.type != "MESH" and obj not in wheels.values():
        bpy.data.objects.remove(obj, do_unlink=True)

# This material name selects hue-preserving team tint in damage_visuals.gd.
bpy.data.materials["Main2"].name = "StreetPaint"
texture_work = ROOT / "work/street-bike-textures"
texture_work.mkdir(parents=True, exist_ok=True)
for image in bpy.data.images:
    if image.type != "IMAGE":
        continue
    # glTF images are lazy-loaded; has_data can be false for packed textures.
    _ = image.pixels[0]
    width, height = image.size
    if max(width, height) > 1024:
        factor = 1024 / max(width, height)
        image.scale(round(width * factor), round(height * factor))
    # Give Blender's glTF encoder a real backing file when copying packed images.
    image.filepath_raw = str(texture_work / (image.name + ".png"))
    image.file_format = "PNG"
    image.save()
    image.pack()

assert triangle_count == 69908, f"Splitting lost geometry: {triangle_count} triangles"
assert all(len(wheel.children) == 2 for wheel in wheels.values()), "Missing tire or hub mesh"
bpy.context.view_layer.update()
bpy.ops.export_scene.gltf(filepath=str(OUTPUT), export_format="GLB")
print(f"Street bike exported: {triangle_count} triangles, {OUTPUT.stat().st_size} bytes")
