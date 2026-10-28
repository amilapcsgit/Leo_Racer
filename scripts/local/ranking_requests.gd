class_name LeoRankingRequests
extends RefCounted
static func query(store: RefCounted, tree: SceneTree, mode: int, performance: String, vehicle: String, laps: bool, track: String, revision: int, ruleset: String, current: Callable=Callable()) -> Array:
	var request: int=store.query_async(mode,performance,vehicle,laps,track,revision,ruleset)
	if request<0:return []
	while not store.request_ready(request):
		if not current.is_null() and (not current.is_valid() or not current.call()):
			store.cancel_request(request);return []
		await tree.process_frame
	if not current.is_null() and (not current.is_valid() or not current.call()):store.cancel_request(request);return []
	return store.take_query(request)
