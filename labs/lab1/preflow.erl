-module(preflow).
-export([preflow/0, node_loop/3]).
% set to 1 for debugging output
-define(PRINT, 0).

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
% 		n nodes and m edges stored in arrays. 
% 		node_actors is also an array. 
% 		flows is a mutable table indexed by edge number and containing the current flow counted from u to v.

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
	#edge{u = From, v = VV } = Edge,
	case U of 
		From -> VV;
		VV -> From
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

	#edge{ u = From, v = To, c = C } = Edge,

	F = edge_flow(G,I),

	D = if 	
		U == From -> C - F
		;
		U == To -> C + F
	end,

	pr("Available capacity on edge (~p, ~p) is ~p~n", [From, To, D]),

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
	%pr("I=~p ~p~n", [I,ets:lookup(Flows, I)]),
	[{I,F}] = ets:lookup(Flows, I),
	%pr("I=~p f=~p~n", [I,F]),
	F.

update_flow(G, EdgeIndex, ToNode, Delta) ->
	% FromNode pushed Delta
	Edge = edge(G,EdgeIndex),

	#edge{u = From, v = To } = Edge,
	#graph{flows = Flows } = G,

	[{ EdgeIndex, Flow }] = ets:lookup(Flows, EdgeIndex),
	pr("Node ~p pushing ~p on edge (~p, ~p) ~n", [ToNode, Delta, From, To]),

	case ToNode of 
		From ->
			NewFlow = Flow-Delta, 
			pr("Updating flow for ~p, new flow ~p~n", [Edge, NewFlow]),
			ets:insert(Flows, {EdgeIndex,NewFlow});
		To -> 
			NewFlow = Flow+Delta, 
			pr("Updating flow for ~p, new flow ~p~n", [Edge, NewFlow]),
			ets:insert(Flows, {EdgeIndex,NewFlow})
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
	G1 = G0#graph { node_actors = A1 },
	make_node_actor(G1, I+1, N). 

make_actors(G0) ->
	#graph { n = N } = G0,
	Node_actors = array:new(N),
	G1 = G0#graph { node_actors = Node_actors },
	G2 = make_node_actor(G1, 0, N),
	%pr("all nodes said hello~n", []),
	print(G2),
	G2.

% ReceiverNode is the node that received the push request
handle_push_request(ReceiverNode, C, G, FromActor, EdgeIndex, Height, Amount) ->
    
	#node{i = ReceiverNodeI, h = ReceiverHeight, e = Excess} = ReceiverNode,

	case ReceiverHeight < Height of 
		true -> 
			update_flow(G, EdgeIndex, ReceiverNodeI, Amount),
			NewExcess =  Excess + Amount,
			pr("Node ~p accepted a push of ~p, new excess: ~p~n", [ReceiverNodeI, Amount, NewExcess]),
			NewNode = ReceiverNode#node{ e = NewExcess },
			FromActor ! {self(), accept, EdgeIndex, Amount },
			NewNode; % return the new node.
				
		false -> 
			FromActor ! {self(), reject, EdgeIndex},
			pr("Node ~p rejecting push from ~p, their height: ~p, my height: ~p~n", [ReceiverNodeI, FromActor, Height, ReceiverHeight]),
			ReceiverNode
	end.


wait_for_response(Node, C, Graph, [I|Adj])->
    receive 
        {From, accept, I, Amount} ->
            #node{e = Excess, source = IsSource} = Node,
            NewExcess = Excess - Amount,
            NewNode = Node#node{e = NewExcess},

            % Om Källan fick sitt överskott ändrat (t.ex. vid rejekt/retur), rapporera det
            if IsSource -> 
				C ! {self(), source_excess, NewExcess}; 
				true -> ok 
		end,

            case NewExcess of 
                0 -> 
                    node_loop(NewNode, C, Graph);
                _ -> 
                    discharge(NewNode, C, Graph, Adj)
            end;

        {From, reject, I} ->
            discharge(Node, C, Graph, Adj);

        {From, push, EdgeIndex, HeightFrom, Amount} ->
            NewNode = handle_push_request(Node, C, Graph, From, EdgeIndex, HeightFrom, Amount),
            wait_for_response(NewNode, C, Graph, [I|Adj]);

        _Other ->
            true = false
    end.

% discharge tries to push but never waits.
discharge(Node, C, Graph, []) ->  % base case, no neighbors left to discharge to should be changed to increasing height.

	#node {i = Index, h = Height, e = Excess} = Node,

	pr("Node ~p cannot push more but ~p excess left, increase height from ~p to ~p~n", [Index, Excess, Height, Height+1]),

	NewNode = Node#node{h = Height + 1}, % fyfan.
    #node{adj = Adj} = NewNode,
	discharge(NewNode, C, Graph, Adj);

discharge(Node, C, Graph, [I|Adj]) ->
	#node { i = NodeIndex } = Node,

    #node{i = U, h = Height, e = Excess, source = Source} = Node,
	%-record(node, { i, h, e, adj, source, sink }).	

    Capacity = available_capacity(Graph, U, I),

	pr("Discharging node ~p with Excess ~p ~n", [NodeIndex, Excess]),
	case Capacity == 0 of
		true -> 
			discharge(Node, C, Graph, Adj);
		false ->
			Delta = if
				not Source -> 
					lists:min([Excess, Capacity]);
				Source -> Capacity
			end,

			V = other(U,edge(Graph, I) ),

			VActor = node_actor(Graph, V),

			%pr("U=~p V=~p I=~p VActor=~p~n", [U, V, I, VActor]),
			VActor ! {self(), push, I, Height, Delta},

			wait_for_response(Node, C, Graph, [I|Adj])
	end.

% Initial push
start_push(Node, C, Graph, []) -> 
    % När Källan har skickat ut allt initialt flöde rapporterar vi det negativa överskottet
    #node{e = E} = Node,
    C ! {self(), source_excess, E},
    node_loop(Node, C, Graph);
start_push(Node, C, Graph, [I|Adj]) ->
	pr("should be active, thread: ~p ~n", [ self()]),

	C ! {self(), hello},
    
	#node{i = U, h = Height} = Node,
	
	%-record(node, { i, h, e, adj, source, sink }).	
	
	pr("source height: ~p~n",[Height]),
    
	Capacity = available_capacity(Graph, U, I),

	V = other(U,edge(Graph, I)),

    VActor = node_actor(Graph, V),

    VActor ! {self(), push, I, Height, Capacity},
	#node {e = E} = Node,
	NewNode = Node#node {e = E - Capacity},

	receive
        {VActor, accept, I, Amount} -> 
			pr("",[]);
			%NewNode = Node#node {e = e - Amount};

        {VActor, reject, I} -> 
			pr("bad stuff, source got a reject ~n",[]),
			true = false % stop program if this happens
	end,
	start_push(NewNode, C, Graph, Adj).


node_loop(Node, C, G) ->
    #node {i = I, adj = Adj, e = Excess, source = Source} = Node,

    receive 
        { C, start, G2 } ->
            node_loop(Node, C, G2);
        
        { C, forcepush } ->
            start_push(Node, C, G, Adj);

        { From, push, EdgeIndex, Height, Amount } ->
            NewNode = handle_push_request(Node, C, G, From, EdgeIndex, Height, Amount),

            #node {adj = Adj2, e = Excess2, sink = IsSink, source = IsSource} = NewNode,           
            
			% if sink or source, send excess to control loop
            if 
                IsSink -> 
                    C ! { self(), sink_excess, Excess2 };
                IsSource -> 
                    C ! { self(), source_excess, Excess2 };
                true -> 
                    ok
            end,

            % om inte sink eller source gör discharge
            case {Excess2 > 0, IsSink, IsSource} of
                {true, false, false} -> 
                    discharge(NewNode, C, G, Adj2);
                _ -> 
                    node_loop(NewNode, C, G)
            end;

        _Other ->    
            node_loop(Node, C, G)
    end.


control_loop(G, S, T, SE, TE) ->
    % algorithm is done when abs(source excess == abs sink excess)
    case (SE =/= undefined) andalso (TE =/= undefined) andalso (abs(SE) =:= TE) of
        true ->
            TE; % maxflow
        false ->
            receive
                {S, source_excess, Excess} ->
                    pr("Controller updated Source excess: ~p~n", [Excess]),
                    control_loop(G, S, T, Excess, TE);

                {T, sink_excess, Excess} ->
                    pr("Controller updated Sink excess: ~p~n", [Excess]),
                    control_loop(G, S, T, SE, Excess);

                _Other ->
                    control_loop(G, S, T, SE, TE)
            end
    end.


control(G0) ->
    #graph { n = N } = G0,
    G1 = make_actors(G0),

    S = node_actor(G1, 0),
    T = node_actor(G1, N-1),

    start_node_actor(G1, 0, N-1),

    pr("################ STARTING ALGORITHM ################~n", []),
    
    S ! { self(), forcepush },

    % start loop but sink and source excess is undefind so the algrotihm do not terminate directly
    control_loop(G1, S, T, undefined, undefined).


preflow() -> 
	pr("preflow push in erlang~n", []),

	{ok,[N,M,_,_]} = io:fread("","~d ~d ~d ~d"),

	Nodes0 = make_nodes(N),
	E0 = make_edges(M),
	G0 = read_graph(N, M, Nodes0, E0),
	print(G0),

	Result = control(G0),

	pr("##################### ALGORITHM FINISH ################~n", []),

	io:format("f = ~p~n", [Result])
	.