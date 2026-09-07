-module(preflow).
-export([preflow/0, node_loop/3]).

% set to 1 for debugging output
-define(PRINT, 1).

% preflow-push for undirected graph using actors.
%
% the nodes and a controller are actors and current flows are stored in a table (erlang ets)
% the edge records never change after reading from stdin
%
% the graph has an initial copy of the nodes but these are never updated and all changes to
% the nodes are done using recursion. so for instance, after a push, the excess is reduced in the node
% and since erlang is a functional language, the excess is not modified but instead a new node
% is returned from the push (and similar functions).
% 
% to know which actor to send a push to, say from U to V (integers), the record graph below has an
% array of actors indexed by node index.

-record(edge, { u, v, c }).

-record(node, { i, h, e, adj, source, sink }).	

% i:		index and only used for printing to see which node it is
% h:		height
% e:		excess preflow
% adj:		adjacency list of edge indices.

-record(graph, { n, m, nodes, edges, node_actors, flows }).
% 		n nodes and m edges stored in arrays. node_actors is also an
%		array. flows is a mutable table indexed by edge number and
%		containing the current flow counted from u to v.

pr(Format, Args) -> 
	case ?PRINT of
	1	-> io:format(Format, Args);
	_	-> 0
	end.

set_node_index(Nodes, N, N) -> Nodes;

set_node_index(Nodes, I, N) ->
	Node = array:get(I, Nodes),
	Node1 = Node#node{i = I},
	Nodes1 = array:set(I, Node1, Nodes),
	set_node_index(Nodes1, I+1, N).

mark_source_and_sink(Nodes, N) -> 
	Source = array:get(0, Nodes),
	Sink = array:get(N-1, Nodes),
	Nodes1 = array:set(0, Source#node{h = N, source = true }, Nodes),
	array:set(N-1, Sink#node{ sink = true }, Nodes1).

make_nodes(N) -> 
	Nodes = array:new(N, { default, #node{i = 0, h = 0, e = 0, adj = [], source = false, sink = false }}),
	Nodes1 = mark_source_and_sink(Nodes,N),
	set_node_index(Nodes1, 0, N).

make_edges(M) -> array:new(M, { default, #edge{u = 0, v = 0, c = 0 }}).

add_edge_to_node(Nodes, U, I) ->
	U0 = array:get(U, Nodes),
	#node{adj = Adj} = U0,
	U1 = U0#node{adj = [I|Adj]},
	array:set(U, U1, Nodes).

% read u,v,c for each edge from stdin and put Nodes and Edges in a graph when we have read all M edges.
read_edges(N, M, M, Nodes, Edges, T) -> #graph{n = N, m = M, nodes = Nodes, edges = Edges, flows = T};

read_edges(N, I, M, N0, E0,T) ->
	{ok,[U,V,C]} = io:fread("","~d ~d ~d"),
	E1 = array:set(I, #edge{u = U, v = V, c = C }, E0),
	N1 = add_edge_to_node(N0, U, I),
	N2 = add_edge_to_node(N1, V, I),
	ets:insert(T,{I,0}), % edge index I is a key and flow 0 is a value
	read_edges(N, I+1, M, N2, E1,T).

read_graph(N, M, Nodes, Edges) -> 
	T = ets:new(flows,[public,ordered_set]),
	read_edges(N, 0, M, Nodes, Edges, T).

other(U, Edge) -> 
	#edge{u = UU, v = VV } = Edge,
	case U of 
		UU -> VV;
		VV -> UU
	end.

node(G, I) ->
	#graph{nodes = Nodes } = G,
	array:get(I, Nodes).

edge(G, I) ->
	#graph{edges = Edges } = G,
	array:get(I, Edges).

edge_capacity(G, I) ->
	E = edge(G, I),
	#edge{ c = C } = E,
	C.

node_actor(G, U) ->
	#graph{node_actors = Node_actors } = G,
	array:get(U, Node_actors).

% how much can flow on edge I be increased by U?
available_capacity(G, U, I) ->

	Edge = edge(G, I),

	#edge{ u = UU, v = VV, c = C } = Edge,

	F = edge_flow(G,I),

	D = if 	
		U == UU -> C - F;
		U == VV -> C + F
	end,

	pr("=============== available capacity on ~p for ~p is ~p~n", [Edge, U, D]),

	D.  

print(G) ->
	case ?PRINT of
	1	-> 
			#graph{ n = N, m = M, nodes= Nodes, edges = Edges, node_actors = Node_actors } = G,
			pr("n = ~p~n", [N]),
			pr("m = ~p~n", [M]),
			pr("nodes = ~p~n", [array:to_list(Nodes)]),
			pr("edges = ~p~n", [array:to_list(Edges)]),
			pr("node_actors = ~p~n", [Node_actors]);
	_	-> 0
	end.

edge_flow(G,I) -> 
	#graph{flows = Flows } = G,
	pr("I=~p ~p~n", [I,ets:lookup(Flows, I)]),
	[{I,F}] = ets:lookup(Flows, I),
	pr("I=~p f=~p~n", [I,F]),
	F.

update_flow(G, I, U, D ) ->
	% U pushed D 
	Edge = edge(G,I),
	#edge{u = UU, v = VV } = Edge,
	#graph{flows = Flows } = G,
	[{I,F}] = ets:lookup(Flows, I),
	pr("D = ~p, F = ~p~n", [D, F]),
	case U of 
		UU -> ets:insert(Flows, {I,F+D});
		VV -> ets:insert(Flows, {I,F-D})
	end.
	
% discharge tries to push but never waits.
discharge(Node, C, G, []) -> Node;

discharge(Node, C, G, [I|Adj]) ->
	
	#node{i = U, e = E } = Node,

	% do push here...

	true = (E > 0).

node_loop(Node, C, G) ->

	pr("~s ~p: node = ~p~n", [?FUNCTION_NAME,?LINE,Node]),

	receive 
		{ C, hello } ->		pr("node ~p got hello~n", [Node]),
						C ! { self(), hello },
						node_loop(Node, C, G);

		Fel		->		erlang:exit(?LINE)
	end.

start_node_actor(G, N, N) -> G;

start_node_actor(G, I, N) ->
	A = node_actor(G, I),
	A ! { self(), start, G },
	start_node_actor(G, I+1, N). 

make_node_actor(G0, N, N) -> G0;

make_node_actor(G0, I, N) ->
	#graph { node_actors = A0 } = G0,
	Node = node(G0, I),
	Actor = spawn(preflow, node_loop, [Node, self(), G0]),
	A1 = array:set(I, Actor, A0),
	Actor ! { self(), hello },
	G1 = G0#graph { node_actors = A1 },
	make_node_actor(G1, I+1, N). 

count_node_actors(N,N) -> N;
count_node_actors(I,N) -> 
	pr("so far got ~p hello~n", [I]),
	receive 
		{ Node, hello } -> 
			pr("got hello from ~p~n", [Node]),
			count_node_actors(I+1, N)
	end.

make_actors(G0) ->
	#graph { n = N } = G0,
	Node_actors = array:new(N),
	G1 = G0#graph { node_actors = Node_actors },
	G2 = make_node_actor(G1, 0, N),
	count_node_actors(0, N),
	pr("all nodes said hello~n", []),
	print(G2),
	G2.

control(G0) ->
	#graph { n = N } = G0,

	G1 = make_actors(G0),

	S = node_actor(G1, 0),
	T = node_actor(G1, N-1),

	start_node_actor(G1, 0, N-1).

	% decide when to print result and where to find it (either excess of sink or abs(excess of source))

	% good idea to enter a control_loop waiting for messages...



preflow() -> 
	pr("preflow push in erlang~n", []),

	{ok,[N,M,_,_]} = io:fread("","~d ~d ~d ~d"),

	Nodes0 = make_nodes(N),
	E0 = make_edges(M),
	G0 = read_graph(N, M, Nodes0, E0),
	print(G0),

	control(G0).
