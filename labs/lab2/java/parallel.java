import java.util.Scanner;
import java.util.concurrent.locks.ReentrantLock;
import java.util.Iterator;
import java.util.ListIterator;
import java.util.LinkedList;

// should use rentrantlock 

// lock the shared list. Excess 

// lock the nodes when doing something with them. Lock order should be lowest index frist 

import java.io.*;

class Graph {

    int s;
    int t;
    int n;
    int m;
    Node excess; // list of nodes with excess preflow

    ReentrantLock queueLock = new ReentrantLock();
    private ReentrantLock nodeLock[];
    Node node[];
    Edge edge[];

    Graph(Node node[], Edge edge[]) {
        this.node = node;
        this.n = node.length;
        this.edge = edge;
        this.m = edge.length;
        nodeLock = new ReentrantLock[node.length];
        for (int i = 0; i < node.length; i++) {
            nodeLock[i] = new ReentrantLock();
        }
    }

    void enter_excess(Node u) {
        if (u != node[s] && u != node[t]) {
            u.next = excess;
            excess = u;
        }
    }

    Node other(Edge a, Node u) {
        if (a.u == u)
            return a.v;
        else
            return a.u;
    }

    void relabel(Node u) {
        u.h += 1;
        enter_excess(u);
    }

    void push(Node u, Node v, Edge a) {
        // pushing from u to v on edge a
        // find the amount that is allwoed to push min(flow, capacity ± flow)
        int oldVExcess = v.e;
        int amount;
        if (a.u == u) {
            amount = Math.min(u.e, a.c - a.f);
            a.f += amount;
        } else {
            amount = Math.min(u.e, a.c + a.f);
            a.f -= amount;
        }

        u.e -= amount;
        v.e += amount;

        assert (amount >= 0);
        assert (u.e >= 0);
        assert (Math.abs(a.f) <= a.c);

        if (v.e > 0 && !(oldVExcess > 0)) {
            enter_excess(v);
        }
        if (u.e > 0) {
            enter_excess(u);
        }

    }

    void makeshit() throws InterruptedException {

        ListIterator<Edge> iter;
        int b;
        Edge a;
        Node u;
        Node v;
        while (true) {
            try {
                queueLock.lock();
                u = excess;
                if (u == null) {
                    return;
                }
                v = null;
                a = null;
                excess = u.next;

            } finally {
                // lås upp
                queueLock.unlock();
            }
            iter = u.adj.listIterator();
            while ((iter.hasNext())) {
                a = iter.next();

                if (u == a.u) {
                    v = a.v;
                    b = 1;
                } else {
                    v = a.u;
                    b = -1;
                }
                lockIn(u, v);
                boolean breaking = false;
                if (u.h > v.h && b * a.f < a.c) {
                    breaking = true;
                }
                nodeLock[u.i].unlock();
                nodeLock[v.i].unlock();
                if (breaking) {
                    break;
                }
                v = null;

            }
            if (v != null) {
                lockIn(u, v);
                queueLock.lock();
                push(u, v, a);
                queueLock.unlock();
                nodeLock[u.i].unlock();
                nodeLock[v.i].unlock();
            } else {
                nodeLock[u.i].lock();
                queueLock.lock();
                relabel(u);
                queueLock.unlock();
                nodeLock[u.i].unlock();
            }
        }

    }

    int preflow(int s, int t) {
        ListIterator<Edge> iter;
        // int b;
        Edge a;
        // Node u;
        // Node v;

        this.s = s;
        this.t = t;
        node[s].h = n; // sets height

        iter = node[s].adj.listIterator();
        while (iter.hasNext()) {
            a = iter.next();

            node[s].e += a.c;

            push(node[s], other(a, node[s]), a);
        }
        Thread[] threads = new Thread[8];

        for (int i = 0; i < threads.length; i++) {
            threads[i] = new Thread(() -> {
                try {
                    makeshit(); // should be push relabel logic with locks

                } catch (Exception e) {
                    // DO NOTHING.
                    System.exit(1);
                }
            });
            threads[i].start();
        }

        for (int i = 0; i < threads.length; i++) {
            try {
                threads[i].join();
            } catch (Exception e) {
                // do nothing
            }
        }
        System.out.println("Result " + node[t].e);
        return node[t].e;
    }

    void lockIn(Node u, Node v) {
        if (u.i < v.i) {
            nodeLock[u.i].lock();
            nodeLock[v.i].lock();
        } else {
            nodeLock[v.i].lock();
            nodeLock[u.i].lock();
        }
    }
}

class Node {
    int h;
    int e;
    int i;
    Node next;
    LinkedList<Edge> adj;

    Node(int i) {
        this.i = i;
        adj = new LinkedList<Edge>();
    }
}

class Edge {
    Node u;
    Node v;
    int f;
    int c;

    Edge(Node u, Node v, int c) {
        this.u = u;
        this.v = v;
        this.c = c;

    }
}

class Preflow {
    public static void main(String args[]) {
        double begin = System.currentTimeMillis();
        Scanner s = new Scanner(System.in);
        int n;
        int m;
        int i;
        int u;
        int v;
        int c;
        int f;
        Graph g;

        n = s.nextInt();
        m = s.nextInt();
        s.nextInt();
        s.nextInt();
        Node[] node = new Node[n];
        Edge[] edge = new Edge[m];

        for (i = 0; i < n; i += 1)
            node[i] = new Node(i);

        for (i = 0; i < m; i += 1) {
            u = s.nextInt();
            v = s.nextInt();
            c = s.nextInt();
            edge[i] = new Edge(node[u], node[v], c);
            node[u].adj.addLast(edge[i]);
            node[v].adj.addLast(edge[i]);
        }

        g = new Graph(node, edge);
        f = g.preflow(0, n - 1);
        double end = System.currentTimeMillis();
        System.out.println("t = " + (end - begin) / 1000.0 + " s");
        System.out.println("f = " + f);
    }

}
