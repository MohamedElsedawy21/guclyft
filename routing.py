import heapq
from math import radians, sin, cos, sqrt, atan2

# Coordinates for every node
coords = {
    "Gate 1": (29.9845162, 31.4401108),
    "Gate 3": (29.987325099999996, 31.438234999999995),
    "Gate 4": (29.988299299999998, 31.438218700000004),
    "BendG1-G3": (29.9846965, 31.4381564),
    "C1":(29.9869242,31.4387965),
    "C1-G3": (29.9868464, 31.4383620)
}

# Graph: distances in meters (measured along actual roads)
graph = {
    "Gate 1": {"BendG1-G3": 190},
    "BendG1-G3": {"Gate 1": 190, "Gate 3": 300, "Gate 4": 400, "C1-G3": 50},
    "Gate 3": {"BendG1-G3": 300, "Gate 4": 108, "C1-G3": 50},
    "Gate 4": {"BendG1-G3": 400, "Gate 3": 108, "C1-G3": 150},
    "C1": {"C1-G3": 40},
    "C1-G3": {"C1": 40, "Gate 3": 50, "Gate 4": 150}


}
AVERAGE_SPEED_KMH = 20


def haversine(lat1, lon1, lat2, lon2):
    R = 6371000
    dlat, dlon = radians(lat2-lat1), radians(lon2-lon1)
    a = sin(dlat/2)**2 + cos(radians(lat1))*cos(radians(lat2))*sin(dlon/2)**2
    return 2 * R * atan2(sqrt(a), sqrt(1-a))



 
def a_star(graph, coords, start, end):
    def heuristic(node):
        lat1, lon1 = coords[node]
        lat2, lon2 = coords[end]
        return haversine(lat1, lon1, lat2, lon2)
 
    g_score = {node: float('inf') for node in graph}
    g_score[start] = 0
    f_score = {node: float('inf') for node in graph}
    f_score[start] = heuristic(start)
 
    previous = {node: None for node in graph}
    queue = [(f_score[start], start)]
    visited = set()
 
    while queue:
        current_f, current_node = heapq.heappop(queue)
        if current_node in visited:
            continue
        visited.add(current_node)
        if current_node == end:
            break
        for neighbor, weight in graph[current_node].items():
            tentative_g = g_score[current_node] + weight
            if tentative_g < g_score[neighbor]:
                g_score[neighbor] = tentative_g
                f_score[neighbor] = tentative_g + heuristic(neighbor)
                previous[neighbor] = current_node
                heapq.heappush(queue, (f_score[neighbor], neighbor))
 
    path = []
    node = end
    while node is not None:
        path.append(node)
        node = previous[node]
    path.reverse()
    if g_score[end] == float('inf'):
        return None, float('inf')
    return path, g_score[end]


def distance_to_eta(distance_m, speed_kmh=AVERAGE_SPEED_KMH):
    """Convert a distance in meters to an estimated travel time."""
    if distance_m == float('inf'):
        return float('inf')
    speed_m_per_min = (speed_kmh * 1000) / 60   # km/h -> meters/minute
    minutes = distance_m / speed_m_per_min
    return minutes
 
def get_route(graph, coords, start, end, speed_kmh=AVERAGE_SPEED_KMH):
    """One call that returns path, distance, and ETA together."""
    path, distance = a_star(graph, coords, start, end)
    eta_minutes = distance_to_eta(distance, speed_kmh)
    return {
        "path": path,
        "distance_m": round(distance, 1) if distance != float('inf') else None,
        "eta_minutes": round(eta_minutes, 1) if eta_minutes != float('inf') else None,
    }
if __name__ == "__main__":
    pairs = [("Gate 1","C1")]
    print("Dijkstra vs A* comparison:\n")
    for start, end in pairs:
        a_path, a_dist, a_eta =  result = get_route(graph, coords, start, end)
        print(f"{start} -> {end}: path={result['path']}, "
              f"distance={result['distance_m']}m, eta={result['eta_minutes']} min")