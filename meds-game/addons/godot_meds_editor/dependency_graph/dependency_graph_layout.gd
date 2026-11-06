@tool
extends RefCounted
## Layered ("Sugiyama") layout for the MEDS dependency graph, with link routing.
##
## 1. Break cycles: reverse the back edges found by a depth-first search started from the
##    causes (boxes nothing flows into).
## 2. Columns: start from the longest path, then move each box to the column that keeps its
##    links shortest (weighted median). Reads, and links of hubs that touch almost everything
##    (e.g. a debug overlay), weigh less so they don't drag the rest of the graph around.
## 3. Order: split links that skip columns into one lane point per column, then reorder each
##    column with barycentre sweeps, keeping the order with the fewest crossings.
## 4. Vertical placement: put each box where its links are straightest (weighted least squares
##    per column, solved with pool-adjacent-violators so boxes and lanes never overlap).
## 5. Routing: each link follows its lanes with horizontal Bezier curves. Backward links
##    (cycles) make a U-turn around their columns instead of cutting through boxes.
## Disconnected parts of the graph are laid out separately and stacked.
##
## Input:  nodes = {id: {"size": Vector2, "in": {kind: port Vector2}, "out": {kind: port Vector2}}}
##         edges = [{"from", "to", "kind", "weak": bool}]
## Output: {"positions": {id: top-left Vector2}, "routes": [PackedVector2Array per edge],
##          "reversed": number of links drawn backwards}

const LAYER_GAP := 170.0
const NODE_GAP := 28.0
const LANE_GAP := 12.0
const COMPONENT_GAP := 140.0
const ORDER_SWEEPS := 16
const PLACE_SWEEPS := 20
const SEGMENT_SAMPLES := 16
const WEAK_WEIGHT := 0.6
const HUB_WEIGHT := 0.1
## Weak pull of every box toward a shared centre line, so columns don't drift into a staircase.
const CENTRE_PULL := 0.4

var _nodes: Dictionary = {}
var _edges: Array = []


func compute(nodes: Dictionary, edges: Array) -> Dictionary:
	_nodes = nodes
	_edges = edges
	var positions: Dictionary = {}
	var routes: Array = []
	routes.resize(edges.size())
	var reversed_count := 0
	var y := 0.0
	for component in _components():
		var part := _layout_component(component["ids"], component["edges"])
		var bounds: Rect2 = part["bounds"]
		var shift := Vector2(-bounds.position.x, y - bounds.position.y)
		for id in part["positions"]:
			positions[id] = part["positions"][id] + shift
		for e in part["routes"]:
			var points: PackedVector2Array = part["routes"][e]
			for i in points.size():
				points[i] += shift
			routes[e] = points
		reversed_count += int(part["reversed"])
		y += bounds.size.y + COMPONENT_GAP
	return {"positions": positions, "routes": routes, "reversed": reversed_count}


# --- Components -------------------------------------------------------------------

func _components() -> Array:
	var neighbours: Dictionary = {}
	var ids: Array = _nodes.keys()
	ids.sort()
	for id in ids:
		neighbours[id] = []
	for e in _edges.size():
		neighbours[_edges[e]["from"]].append(_edges[e]["to"])
		neighbours[_edges[e]["to"]].append(_edges[e]["from"])
	var component_of: Dictionary = {}
	var components: Array = []
	for start in ids:
		if component_of.has(start):
			continue
		var members: Array = [start]
		component_of[start] = components.size()
		var i := 0
		while i < members.size():
			for other in neighbours[members[i]]:
				if not component_of.has(other):
					component_of[other] = components.size()
					members.append(other)
			i += 1
		components.append({"ids": members, "edges": []})
	for e in _edges.size():
		components[component_of[_edges[e]["from"]]]["edges"].append(e)
	components.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["ids"].size() > b["ids"].size())
	return components


# --- One connected component --------------------------------------------------

func _layout_component(ids: Array, edge_indices: Array) -> Dictionary:
	var weights := _edge_weights(ids, edge_indices)
	var reversed := _break_cycles(ids, edge_indices)
	var rank := _assign_ranks(ids, edge_indices, weights, reversed)

	# Items: real boxes plus one lane point per column a link passes through.
	var layer_count := 0
	for id in ids:
		layer_count = maxi(layer_count, int(rank[id]) + 1)
	var layers: Array = []
	for i in layer_count:
		layers.append([])
	var layer_of: Dictionary = {}
	for id in _initial_order(ids, edge_indices, rank):
		layers[rank[id]].append(id)
		layer_of[id] = rank[id]

	var up: Dictionary = {}     # item -> [[other, weight, own offset, other offset]] in the previous column
	var down: Dictionary = {}   # same, next column
	var side: Dictionary = {}   # same column (U-turn lanes and their box)
	var lanes: Dictionary = {}  # edge -> lane items in route order
	for e in edge_indices:
		var edge: Dictionary = _edges[e]
		var u: String = edge["from"]
		var v: String = edge["to"]
		var w: float = weights[e]
		var out_y := _port(u, "out", edge["kind"]).y
		var in_y := _port(v, "in", edge["kind"]).y
		var ra: int = rank[u]
		var rb: int = rank[v]
		var chain: Array = []
		if rb > ra:
			for layer in range(ra + 1, rb):
				chain.append(_add_lane(e, layer, layers, layer_of))
			var previous := u
			var previous_offset := out_y
			for lane in chain:
				_link(up, down, previous, lane, w, previous_offset, 0.0)
				previous = lane
				previous_offset = 0.0
			_link(up, down, previous, v, w, previous_offset, in_y)
		else:
			for layer in range(ra, rb - 1, -1):
				chain.append(_add_lane(e, layer, layers, layer_of))
			for i in range(chain.size() - 1):
				# Walking backwards: chain[i] is in column L, chain[i + 1] in column L - 1.
				_link(up, down, chain[i + 1], chain[i], w, 0.0, 0.0)
			_link_side(side, chain[0], u, w, 0.0, out_y)
			_link_side(side, chain[chain.size() - 1], v, w, 0.0, in_y)
		lanes[e] = chain

	_order_layers(layers, up, down, side)
	var columns := _columns(layers)
	var y := _place_vertically(layers, up, down, side)
	return _build_result(ids, edge_indices, rank, layers, layer_of, columns, y, lanes, reversed)


func _edge_weights(ids: Array, edge_indices: Array) -> Dictionary:
	var degree: Dictionary = {}
	for id in ids:
		degree[id] = 0
	for e in edge_indices:
		degree[_edges[e]["from"]] += 1
		degree[_edges[e]["to"]] += 1
	var degrees: Array = degree.values()
	degrees.sort()
	var hub_threshold := maxf(8.0, 2.5 * float(degrees[degrees.size() / 2]))
	var weights: Dictionary = {}
	for e in edge_indices:
		var w := WEAK_WEIGHT if _edges[e].get("weak", false) else 1.0
		if degree[_edges[e]["from"]] >= hub_threshold or degree[_edges[e]["to"]] >= hub_threshold:
			w *= HUB_WEIGHT
		weights[e] = w
	return weights


## Returns the strong edges that must be reversed to make the strong graph acyclic.
func _break_cycles(ids: Array, edge_indices: Array) -> Dictionary:
	var outgoing: Dictionary = {}
	var in_degree: Dictionary = {}
	for id in ids:
		outgoing[id] = []
		in_degree[id] = 0
	for e in edge_indices:
		if not _edges[e].get("weak", false):
			outgoing[_edges[e]["from"]].append(e)
			in_degree[_edges[e]["to"]] += 1
	var start_order: Array = ids.duplicate()
	start_order.sort_custom(func(a: String, b: String) -> bool:
		return in_degree[a] < in_degree[b] or (in_degree[a] == in_degree[b] and a < b))

	var reversed: Dictionary = {}
	var state: Dictionary = {}
	for start in start_order:
		if state.has(start):
			continue
		state[start] = 1
		var stack: Array = [[start, 0]]
		while not stack.is_empty():
			var top: Array = stack[stack.size() - 1]
			var edges_out: Array = outgoing[top[0]]
			if top[1] >= edges_out.size():
				state[top[0]] = 2
				stack.pop_back()
				continue
			var e: int = edges_out[top[1]]
			top[1] += 1
			var child: String = _edges[e]["to"]
			if state.get(child, 0) == 1:
				reversed[e] = true
			elif not state.has(child):
				state[child] = 1
				stack.append([child, 0])
	return reversed


func _assign_ranks(ids: Array, edge_indices: Array, weights: Dictionary, reversed: Dictionary) -> Dictionary:
	var before: Dictionary = {}  # hard constraints: id -> ids that must be in an earlier column
	var after: Dictionary = {}
	var wishes: Dictionary = {}  # id -> [[other, delta, weight]]: ideally rank = rank[other] + delta
	for id in ids:
		before[id] = []
		after[id] = []
		wishes[id] = []
	for e in edge_indices:
		var u: String = _edges[e]["from"]
		var v: String = _edges[e]["to"]
		if reversed.has(e):
			var t := u
			u = v
			v = t
		if not _edges[e].get("weak", false):
			before[v].append(u)
			after[u].append(v)
		wishes[u].append([v, -1, weights[e]])
		wishes[v].append([u, 1, weights[e]])

	# Longest path from the causes.
	var rank: Dictionary = {}
	var remaining: Dictionary = {}
	var queue: Array = []
	for id in ids:
		rank[id] = 0
		remaining[id] = before[id].size()
		if remaining[id] == 0:
			queue.append(id)
	var topo: Array = []
	while not queue.is_empty():
		var id: String = queue.pop_front()
		topo.append(id)
		for next in after[id]:
			rank[next] = maxi(rank[next], rank[id] + 1)
			remaining[next] -= 1
			if remaining[next] == 0:
				queue.append(next)
	var width := 0
	for id in ids:
		width = maxi(width, rank[id])

	# Shorten links: move each box within its allowed range to the weighted median of its wishes.
	for _pass in 40:
		var changed := false
		for id in topo:
			if wishes[id].is_empty():
				continue
			var lo := 0
			for other in before[id]:
				lo = maxi(lo, rank[other] + 1)
			var hi := width
			for other in after[id]:
				hi = mini(hi, rank[other] - 1)
			if lo > hi:
				continue
			var values: Array = []
			for wish in wishes[id]:
				values.append([int(rank[wish[0]]) + int(wish[1]), float(wish[2])])
			var best := clampi(_weighted_median(values), lo, hi)
			if best != rank[id]:
				rank[id] = best
				changed = true
		if not changed:
			break

	# Drop empty columns.
	var used: Array = []
	for id in ids:
		if not used.has(rank[id]):
			used.append(rank[id])
	used.sort()
	for id in ids:
		rank[id] = used.find(rank[id])
	return rank


static func _weighted_median(values: Array) -> int:
	values.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var total := 0.0
	for v in values:
		total += v[1]
	var acc := 0.0
	for v in values:
		acc += v[1]
		if acc >= total * 0.5:
			return v[0]
	return values[values.size() - 1][0]


## Breadth-first from the causes, so related boxes start close together.
func _initial_order(ids: Array, edge_indices: Array, rank: Dictionary) -> Array:
	var neighbours: Dictionary = {}
	for id in ids:
		neighbours[id] = []
	for e in edge_indices:
		neighbours[_edges[e]["from"]].append(_edges[e]["to"])
		neighbours[_edges[e]["to"]].append(_edges[e]["from"])
	var starts: Array = ids.duplicate()
	starts.sort_custom(func(a: String, b: String) -> bool: return rank[a] < rank[b] or (rank[a] == rank[b] and a < b))
	var order: Array = []
	var seen: Dictionary = {}
	for start in starts:
		if seen.has(start):
			continue
		seen[start] = true
		var queue: Array = [start]
		while not queue.is_empty():
			var id: String = queue.pop_front()
			order.append(id)
			var next_ids: Array = neighbours[id].duplicate()
			next_ids.sort()
			for other in next_ids:
				if not seen.has(other):
					seen[other] = true
					queue.append(other)
	return order


static func _add_lane(e: int, layer: int, layers: Array, layer_of: Dictionary) -> String:
	var lane := "~%d:%d" % [e, layer]
	layers[layer].append(lane)
	layer_of[lane] = layer
	return lane


## Links `a` (column L) to `b` (column L + 1).
static func _link(up: Dictionary, down: Dictionary, a: String, b: String, w: float, a_offset: float, b_offset: float) -> void:
	if not down.has(a):
		down[a] = []
	if not up.has(b):
		up[b] = []
	down[a].append([b, w, a_offset, b_offset])
	up[b].append([a, w, b_offset, a_offset])


static func _link_side(side: Dictionary, lane: String, box: String, w: float, lane_offset: float, box_offset: float) -> void:
	if not side.has(lane):
		side[lane] = []
	if not side.has(box):
		side[box] = []
	side[lane].append([box, w * 2.0, lane_offset, box_offset])
	side[box].append([lane, w * 0.5, box_offset, lane_offset])


static func _is_lane(item: String) -> bool:
	return item.begins_with("~")


# --- Ordering -------------------------------------------------------------------

func _order_layers(layers: Array, up: Dictionary, down: Dictionary, side: Dictionary) -> void:
	var pos: Dictionary = {}
	for layer in layers:
		for i in layer.size():
			pos[layer[i]] = i
	var best: Array = layers.duplicate(true)
	var best_crossings := _crossings(layers, down, pos)
	for sweep in ORDER_SWEEPS:
		var downward := sweep % 2 == 0
		var neighbours := up if downward else down
		var indices: Array = range(1, layers.size()) if downward else range(layers.size() - 2, -1, -1)
		for li in indices:
			var layer: Array = layers[li]
			var centre: Dictionary = {}
			for item in layer:
				var total := 0.0
				var weight := 0.0
				for link in neighbours.get(item, []):
					total += float(pos[link[0]]) * link[1]
					weight += link[1]
				# Keep U-turn lanes right next to the box they turn around.
				for link in side.get(item, []):
					if _is_lane(item):
						total += (float(pos[link[0]]) + 0.5) * link[1]
						weight += link[1]
				centre[item] = total / weight if weight > 0.0 else float(pos[item])
			layer.sort_custom(func(a: String, b: String) -> bool:
				return centre[a] < centre[b] or (centre[a] == centre[b] and pos[a] < pos[b]))
			for i in layer.size():
				pos[layer[i]] = i
		var crossings := _crossings(layers, down, pos)
		if crossings < best_crossings:
			best_crossings = crossings
			best = layers.duplicate(true)
	for li in layers.size():
		layers[li] = best[li]


static func _crossings(layers: Array, down: Dictionary, pos: Dictionary) -> int:
	var total := 0
	for li in range(layers.size() - 1):
		var pairs: Array = []
		for item in layers[li]:
			for link in down.get(item, []):
				pairs.append([pos[item], pos[link[0]]])
		pairs.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
		var lower: Array = []
		for p in pairs:
			lower.append(p[1])
		total += _count_inversions(lower)
	return total


static func _count_inversions(values: Array) -> int:
	if values.size() < 2:
		return 0
	var middle := values.size() / 2
	var left: Array = values.slice(0, middle)
	var right: Array = values.slice(middle)
	var count := _count_inversions(left) + _count_inversions(right)
	var i := 0
	var j := 0
	var k := 0
	while i < left.size() and j < right.size():
		if left[i] <= right[j]:
			values[k] = left[i]
			i += 1
		else:
			values[k] = right[j]
			count += left.size() - i
			j += 1
		k += 1
	while i < left.size():
		values[k] = left[i]
		i += 1
		k += 1
	while j < right.size():
		values[k] = right[j]
		j += 1
		k += 1
	return count


# --- Coordinates ----------------------------------------------------------------

func _columns(layers: Array) -> Array:
	var columns: Array = []
	var x := 0.0
	for layer in layers:
		var width := 40.0
		for item in layer:
			if not _is_lane(item):
				width = maxf(width, _size(item).x)
		columns.append({"x": x, "width": width})
		x += width + LAYER_GAP
	return columns


func _place_vertically(layers: Array, up: Dictionary, down: Dictionary, side: Dictionary) -> Dictionary:
	var y: Dictionary = {}
	for layer in layers:
		var cursor := 0.0
		for i in layer.size():
			y[layer[i]] = cursor
			cursor += _height(layer[i]) + (_gap(layer[i], layer[i + 1]) if i + 1 < layer.size() else 0.0)

	for sweep in PLACE_SWEEPS:
		var use_up := sweep % 2 == 0 or sweep >= PLACE_SWEEPS - 4
		var use_down := sweep % 2 == 1 or sweep >= PLACE_SWEEPS - 4
		var indices: Array = range(layers.size()) if sweep % 2 == 0 else range(layers.size() - 1, -1, -1)
		for li in indices:
			var layer: Array = layers[li]
			var desired: Array = []
			var weights: Array = []
			for item in layer:
				var total := 0.0
				var weight := 0.0
				var sources: Array = side.get(item, []).duplicate()
				if use_up:
					sources.append_array(up.get(item, []))
				if use_down:
					sources.append_array(down.get(item, []))
				for link in sources:
					# Align this item's anchor with the other item's anchor.
					total += (float(y[link[0]]) + float(link[3]) - float(link[2])) * float(link[1])
					weight += float(link[1])
				if not _is_lane(item):
					total += -_height(item) * 0.5 * CENTRE_PULL
					weight += CENTRE_PULL
				if weight > 0.0:
					desired.append(total / weight)
					weights.append(weight)
				else:
					desired.append(float(y[item]))
					weights.append(0.01)
			var placed := _place_in_order(layer, desired, weights)
			for i in layer.size():
				y[layer[i]] = placed[i]
	return y


## Weighted least-squares fit of `desired` keeping the column order and minimum gaps
## (pool-adjacent-violators on positions shifted by the space each item needs).
func _place_in_order(layer: Array, desired: Array, weights: Array) -> Array:
	var offsets: Array = []
	var acc := 0.0
	for i in layer.size():
		offsets.append(acc)
		acc += _height(layer[i]) + (_gap(layer[i], layer[i + 1]) if i + 1 < layer.size() else 0.0)
	var blocks: Array = []  # [weighted sum, weight, count]
	for i in layer.size():
		var target: float = desired[i] - offsets[i]
		blocks.append([target * weights[i], weights[i], 1])
		while blocks.size() > 1:
			var last: Array = blocks[blocks.size() - 1]
			var previous: Array = blocks[blocks.size() - 2]
			if previous[0] / previous[1] <= last[0] / last[1]:
				break
			previous[0] += last[0]
			previous[1] += last[1]
			previous[2] += last[2]
			blocks.pop_back()
	var result: Array = []
	var index := 0
	for block in blocks:
		var value: float = block[0] / block[1]
		for _k in block[2]:
			result.append(value + offsets[index])
			index += 1
	return result


func _height(item: String) -> float:
	return 0.0 if _is_lane(item) else _size(item).y


static func _gap(a: String, b: String) -> float:
	return NODE_GAP if not _is_lane(a) and not _is_lane(b) else LANE_GAP


func _size(id: String) -> Vector2:
	return _nodes[id].get("size", Vector2(120, 60))


func _port(id: String, side_name: String, kind: String) -> Vector2:
	var ports: Dictionary = _nodes[id].get(side_name, {})
	if ports.has(kind):
		return ports[kind]
	var size := _size(id)
	return Vector2(size.x if side_name == "out" else 0.0, size.y * 0.5)


# --- Result and routing ---------------------------------------------------------

func _build_result(ids: Array, edge_indices: Array, rank: Dictionary, layers: Array, layer_of: Dictionary, columns: Array, y: Dictionary, lanes: Dictionary, reversed: Dictionary) -> Dictionary:
	var positions: Dictionary = {}
	var bounds := Rect2()
	var first := true
	for id in ids:
		var column: Dictionary = columns[rank[id]]
		var size := _size(id)
		positions[id] = Vector2(column["x"] + (column["width"] - size.x) * 0.5, y[id])
		var rect := Rect2(positions[id], size)
		bounds = rect if first else bounds.merge(rect)
		first = false

	var routes: Dictionary = {}
	var backwards := 0
	for e in edge_indices:
		var edge: Dictionary = _edges[e]
		var u: String = edge["from"]
		var v: String = edge["to"]
		var forward: bool = rank[v] > rank[u]
		if not forward:
			backwards += 1
		var waypoints: Array = [[positions[u] + _port(u, "out", edge["kind"]), Vector2.RIGHT]]
		for lane in lanes[e]:
			var column: Dictionary = columns[layer_of[lane]]
			var left := Vector2(column["x"], y[lane])
			var right := Vector2(column["x"] + column["width"], y[lane])
			if forward:
				waypoints.append([left, Vector2.RIGHT])
				waypoints.append([right, Vector2.RIGHT])
			else:
				waypoints.append([right, Vector2.LEFT])
				waypoints.append([left, Vector2.LEFT])
		waypoints.append([positions[v] + _port(v, "in", edge["kind"]), Vector2.RIGHT])
		var points := _curve_through(waypoints)
		for p in points:
			bounds = bounds.expand(p)
		routes[e] = points
	return {"positions": positions, "routes": routes, "bounds": bounds, "reversed": backwards}


## Joins waypoints (position + travel direction) with cubic Beziers whose handles follow the
## travel direction: straight runs along a lane, smooth S-curves between columns, U-turns
## where a backward link reverses direction.
static func _curve_through(waypoints: Array) -> PackedVector2Array:
	var points := PackedVector2Array([waypoints[0][0]])
	for i in range(1, waypoints.size()):
		var a: Vector2 = waypoints[i - 1][0]
		var a_dir: Vector2 = waypoints[i - 1][1]
		var b: Vector2 = waypoints[i][0]
		var b_dir: Vector2 = waypoints[i][1]
		if a_dir == b_dir and is_equal_approx(a.y, b.y) and signf(b.x - a.x) == signf(a_dir.x):
			points.append(b)
			continue
		var handle := clampf(a.distance_to(b) * 0.45, 30.0, 140.0)
		var c1 := a + a_dir * handle
		var c2 := b - b_dir * handle
		for s in range(1, SEGMENT_SAMPLES + 1):
			var t := float(s) / SEGMENT_SAMPLES
			var mt := 1.0 - t
			points.append(a * mt * mt * mt + c1 * 3.0 * mt * mt * t + c2 * 3.0 * mt * t * t + b * t * t * t)
	return points
