#[macro_use] extern crate text_io;

use std::sync::{Mutex,Arc};
use std::collections::LinkedList;
use std::cmp;
use std::thread;
use std::collections::VecDeque;

struct Node {
	index:	usize,			/* index of itself for debugging.	*/
	excess:	i32,			/* excess preflow.			*/
	height:	i32,			/* height.				*/
}

struct Edge {
	u:      	usize,   // unsigned int
	v:      	usize,
	flow:      	i32, // signed int
	capacity:   i32,
}

impl Node {
	fn new(ii:usize) -> Node {
		Node { index: ii, excess: 0, height: 0 }
	}

}

impl Edge {
	fn new(uu:usize, vv:usize,cc:i32) -> Edge {
			Edge { u: uu, v: vv, flow: 0, capacity: cc }      
	}
}


fn main() {

	let n: usize = read!();		/* n nodes.						*/
	let m: usize = read!();		/* m edges.						*/
	let _c: usize = read!();	/* underscore avoids warning about an unused variable.	*/
	let _p: usize = read!();	/* c and p are in the input from 6railwayplanning.	*/
	let mut nodes = vec![];
	let mut edges = vec![];
	let mut adj: Vec<LinkedList<usize>> =Vec::with_capacity(n);
	let mut excess: VecDeque<usize> = VecDeque::new();
	let debug = false;

	let source = 0;
	let target = n-1;

	println!("n = {}", n);
	println!("m = {}", m);

	for i in 0..n {
		let mut u:Node = Node::new(i);
		if i == source {
			u.height = n as i32;
		}
		nodes.push(Arc::new(Mutex::new(u))); 
		adj.push(LinkedList::new());
	}

	for i in 0..m {
		let u: usize = read!();
		let v: usize = read!();
		let c: i32 = read!();
		let e:Edge = Edge::new(u,v,c);
		adj[u].push_back(i);
		adj[v].push_back(i);
		edges.push(Arc::new(Mutex::new(e))); 
	}

	if debug {
		for i in 0..n {
			print!("adj[{}] = ", i);
			let iter = adj[i].iter();

			for e in iter {
				print!("e = {}, ", e);
			}
			println!("");
		}
	}
	
	println!("initial pushes");
	let iter = adj[source].iter();

    for &idx in iter {
        let mut edge = edges[idx].lock().unwrap();

        let neighbor_i = if edge.u == source {
            edge.v
        } else if edge.v == source {
            edge.u
        } else {
            panic!("Illegal state");
        };

        let capacity = edge.capacity;
        edge.flow = capacity;

        let mut source_node = nodes[source].lock().unwrap();
        let mut neighbor_node = nodes[neighbor_i].lock().unwrap();

        source_node.excess -= capacity; 
        neighbor_node.excess += capacity;  

        add_to_excess_list(neighbor_i, &mut excess, target);
	}

	let shared_adj = Arc::new(adj);
	let shared_edges = Arc::new(edges);
	let shared_nodes = Arc::new(nodes);
	
	
	let nbrThreads = 4;



	let mut thread_list = vec![];

	println!("Starting {} threads: ", nbrThreads);


	for thread_i in 0..nbrThreads{
		let t_adj = Arc::clone(&shared_adj);
		let t_edges = Arc::clone(&shared_edges);
		let t_nodes = Arc::clone(&shared_nodes);

		let mut i = thread_i;
		let mut thread_nodes_index = vec![];

		while i < n {
			thread_nodes_index.push(i);
			i += nbrThreads;
		}

		let t = thread::spawn(move || {
			loop{
				let mut active_nodes: VecDeque<usize> = VecDeque::new();
				for &i in &thread_nodes_index {
					if i == 0 || i == target { 
						continue;
					}
					let current_node = &t_nodes[i].lock().unwrap();
					if current_node.excess > 0 {
						active_nodes.push_back(i);
					}
				}

				//termenating condition
				if active_nodes.is_empty() {
					let source_node = t_nodes[0].lock().unwrap();
					let target_node = t_nodes[target].lock().unwrap();

					if source_node.excess.abs() == target_node.excess.abs() {
						return;
					}
					continue
				}

				let current_node_index = active_nodes.pop_front().unwrap();

				// push relable logic
				let iter = t_adj[current_node_index].iter();
				for &idx in iter{
					let mut edge = t_edges[idx].lock().unwrap();

					let other_i;
					let d;

					if current_node_index == edge.u{
						other_i = edge.v;
						d = 1;
					}else{
						other_i = edge.u;
						d =-1;
					}
					//locking nodes
					let mut u; let mut v;
					if current_node_index < other_i {
						u = t_nodes[current_node_index].lock().unwrap();
						v = t_nodes[other_i].lock().unwrap();
					}else{
						v = t_nodes[other_i].lock().unwrap();
						u = t_nodes[current_node_index].lock().unwrap();
					}

					let can_push = u.height > v.height && d * edge.flow < edge.capacity;
					if can_push{
						push(&mut u, &mut v, &mut edge, target)
					}
				}

				let mut u = t_nodes[current_node_index].lock().unwrap();
				if u.excess > 0 {
					relabel(&mut u);
				}

			}

		});

		thread_list.push(t);
	}

	for t in thread_list{
		t.join().unwrap();
	}

	

	//paralellisera härifrån:

	/** while !excess.is_empty() {
		let mut _c = 0;
		let node_idx = excess.pop_front().unwrap();

		let u = &mut nodes[node_idx].lock().unwrap();
		let iter = adj[node_idx].iter();

		for &edge_idx in iter{
			if u.excess == 0 {
				break;
			}
			let curr_edge =  &mut edges[edge_idx].lock().unwrap();

			let other_i; 
			let d;
			if node_idx == curr_edge.u{
				other_i = curr_edge.v;
				d = 1;
			}else{
				other_i = curr_edge.u;
				d =-1;
			}
			let v = &mut nodes[other_i].lock().unwrap();
			let can_push = u.height > v.height && d * curr_edge.flow < curr_edge.capacity;
			if can_push { 
				push(u, v, &mut *curr_edge, &mut excess, target);

			}
		}
		if u.excess > 0 {
			relabel(u);
			add_to_excess_list(u.index, &mut excess, target);

		}

	}
		*/


	println!("f = {}", shared_nodes[target].lock().unwrap().excess);

}

fn push(u: &mut Node, v: &mut Node, edge: &mut Edge, sink: usize){
	let d;
	if u.index == edge.u{
		d = cmp::min(u.excess, edge.capacity - edge.flow);
		edge.flow += d;
	}else{
		d = cmp::min(u.excess, edge.capacity + edge.flow);
		edge.flow -=d; 
	}

	u.excess -=d;
	v.excess += d;

	assert!(d >= 0);
	assert!(u.excess >= 0);
	assert!(edge.flow.abs() <= edge.capacity);
}

fn relabel(node: &mut Node){
	if node.excess <= 0{
		panic!("Error: Tried to relabel node {} with excess {}", node.index, node.excess)
	}
	node.height+= 1;

}
fn add_to_excess_list(node_i: usize, excess: &mut VecDeque<usize>, target: usize) {
	// println!("Adding node {} to excess list", node_i);
	if node_i != 0 && node_i != target {
		excess.push_back(node_i);
	}
}
