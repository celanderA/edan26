#include <assert.h>
#include <ctype.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include "pthread_barrier.h"

#define PRINT 0 /* enable/disable prints. */

#if PRINT
#define pr(...)                       \
	do                                \
	{                                 \
		fprintf(stderr, __VA_ARGS__); \
	} while (0)
#else
#define pr(...) /* no effect at all */
#endif

#define MIN(a, b) (((a) <= (b)) ? (a) : (b))

/* introduce names for some structs. a struct is like a class, except
 * it cannot be extended and has no member methods, and everything is
 * public.
 *
 * using typedef like this means we can avoid writing 'struct' in
 * every declaration. no new type is introduded and only a shorter name.
 *
 */

#define NBR_THREADS 3

typedef struct graph_t graph_t;
typedef struct node_t node_t;
typedef struct edge_t edge_t;
typedef struct list_t list_t;

struct list_t
{
	edge_t *edge;
	list_t *next;
};

struct node_t
{
	int height;	  /* height.			*/
	int excess;	  /* excess flow.			*/
	list_t *adj;  /* adjacency list.		*/
	node_t *next; /* with excess preflow.		*/
	int in_excess;
};

struct edge_t
{
	node_t *u;	  /* one of the two nodes.	*/
	node_t *v;	  /* the other. 			*/
	int flow;	  /* flow > 0 if from u to v.	*/
	int capacity; /* capacity.			*/
};

struct graph_t
{
	int nbr_nodes;		 /* nodes.			*/
	int nbr_edges;		 /* edges.			*/
	node_t *nodes;		 /* array of n nodes.		*/
	edge_t *edges;		 /* array of m edges.		*/
	node_t *source;		 /* source.			*/
	node_t *sink;		 /* sink.			*/
	node_t *excess_list; /* nodes with e > 0 except s,t.	*/
	node_t *next_excess_list;
	int phase2;
	int finish;
};

static char *progname;

#if PRINT

static int id(graph_t *g, node_t *v)
{

	return v - g->v;
}
#endif

void error(const char *fmt, ...)
{

	va_list ap;
	char buf[BUFSIZ];

	va_start(ap, fmt);
	vsprintf(buf, fmt, ap);

	if (progname != NULL)
		fprintf(stderr, "%s: ", progname);

	fprintf(stderr, "error: %s\n", buf);
	exit(1);
}

static int next_int()
{
	int x;
	int c;

	x = 0;
	while (isdigit(c = getchar()))
		x = 10 * x + c - '0';

	return x;
}

static void *xmalloc(size_t s)
{
	void *p;

	p = malloc(s);

	if (p == NULL)
		error("out of memory: malloc(%zu) failed", s);

	return p;
}

static void *xcalloc(size_t n, size_t s)
{
	void *p;

	p = xmalloc(n * s);

	/* memset sets everything (in this case) to 0. */
	memset(p, 0, n * s);

	return p;
}

static void add_edge(node_t *u, edge_t *e)
{
	list_t *p;

	/* allocate memory for a list link and put it first
	 * in the adjacency list of u.
	 *
	 */

	p = xmalloc(sizeof(list_t));
	p->edge = e;
	p->next = u->adj;
	u->adj = p;
}

static void connect(node_t *u, node_t *v, int c, edge_t *e)
{
	/* connect two nodes by putting a shared (same object)
	 * in their adjacency lists.
	 *
	 */

	e->u = u;
	e->v = v;
	e->capacity = c;

	add_edge(u, e);
	add_edge(v, e);
}

static graph_t *new_graph(FILE *in, int n, int m)
{
	graph_t *g;
	node_t *u;
	node_t *v;
	int i;
	int a;
	int b;
	int c;

	g = xmalloc(sizeof(graph_t));

	g->nbr_nodes = n;
	g->nbr_edges = m;

	g->nodes = xcalloc(n, sizeof(node_t));
	g->edges = xcalloc(m, sizeof(edge_t));

	g->source = &g->nodes[0];
	g->sink = &g->nodes[n - 1];
	g->excess_list = NULL;
	g->next_excess_list = NULL;
	g->phase2 = 0;
	g->finish = 0;

	for (i = 0; i < m; i += 1)
	{
		a = next_int();
		b = next_int();
		c = next_int();
		u = &g->nodes[a];
		v = &g->nodes[b];
		connect(u, v, c, g->edges + i);
	}

	return g;
}

static void enter_excess(graph_t *g, node_t *v)
{
	if (v == g->sink || v == g->source)
		return;

	if (v->in_excess)
		return;

	v->in_excess = 1;

	if (g->phase2)
	{
		v->next = g->next_excess_list;
		g->next_excess_list = v;
	}
	else
	{
		v->next = g->excess_list;
		g->excess_list = v;
	}
}

static node_t *leave_excess(graph_t *g)
{
	node_t *v;

	/* take any node from the set of nodes with excess preflow
	 * and for simplicity we always take the first.
	 *
	 */

	v = g->excess_list;

	if (v != NULL)
		g->excess_list = v->next;

	return v;
}

static void push(graph_t *g, node_t *u, node_t *v, edge_t *e)
{
	int d; /* remaining capacity of the edge. */

	pr("push from %d to %d: ", id(g, u), id(g, v));
	pr("f = %d, c = %d, so ", e->f, e->c);

	if (u == e->u)
	{
		d = MIN(u->excess, e->capacity - e->flow);
		e->flow += d;
	}
	else
	{
		d = MIN(u->excess, e->capacity + e->flow);
		e->flow -= d;
	}

	pr("pushing %d\n", d);

	u->excess -= d;
	v->excess += d;

	/* the following are always true. */

	assert(d >= 0);
	assert(u->excess >= 0);
	assert(abs(e->flow) <= e->capacity);

	if (u->excess > 0)
	{

		/* still some remaining so let u push more. */

		enter_excess(g, u);
	}

	if (v->excess == d)
	{

		/* since v has d excess now it had zero before and
		 * can now push.
		 *
		 */

		enter_excess(g, v);
	}
}

static void relabel(graph_t *g, node_t *u)
{
	u->height += 1;

	pr("relabel %d now h = %d\n", id(g, u), u->h);

	enter_excess(g, u);
}

static node_t *other(node_t *u, edge_t *e)
{
	if (u == e->u)
		return e->v;
	else
		return e->u;
}

pthread_barrier_t barrier1;

struct work_args_t
{
	graph_t *graph;
	int id;
	node_t **worklist;
	int work_count;
	struct work_args_t *all_args;
};

void discharge(graph_t *g, node_t *u)
{
	while (u->excess > 0)
	{
		edge_t *e = NULL;
		list_t *p = u->adj;
		node_t *v = NULL;
		int b;

		while (p != NULL)
		{
			e = p->edge;
			p = p->next;

			if (u == e->u)
			{
				v = e->v;
				b = 1;
			}
			else
			{
				v = e->u;
				b = -1;
			}

			if (u->height > v->height &&
				b * e->flow < e->capacity)
			{
				break;
			}

			v = NULL;
		}

		if (v != NULL)
		{
			push(g, u, v, e);
		}
		else
		{
			relabel(g, u);
		}
	}
}

void *work(void *arg)
{
	struct work_args_t *args = arg;
	graph_t *g = args->graph;

	while (1)
	{
		args->work_count = 0;

		node_t *u = g->excess_list;

		for (int i = 0; i < args->id && u != NULL; i++)
		{
			u = u->next;
		}

		while (u != NULL)
		{
			args->worklist[args->work_count++] = u;

			for (int i = 0; i < NBR_THREADS && u != NULL; i++)
			{
				u = u->next;
			}
		}

		pthread_barrier_wait(&barrier1);

		// phase 2 one thread does all the pushes and relabels
		if (args->id == 0)
		{
			g->phase2 = 1;
			g->next_excess_list = NULL;
			int totalwork = 0;

			for (int i = 0; i < NBR_THREADS; i++)
			{
				totalwork += args->all_args[i].work_count;
			}

			if (totalwork == 0)
			{
				g->finish = 1;
			}

			else
			{
				for (int i = 0; i < NBR_THREADS; i++)
				{
					for (int j = 0; j < args->all_args[i].work_count; j++)
					{
						node_t *u = args->all_args[i].worklist[j];
						printf("thread 0: discharging node %ld\n", u - g->nodes);
						u->in_excess = 0;
						discharge(g, u);
					}
				}
			}
			g->excess_list = g->next_excess_list;
			g->next_excess_list = NULL;
			g->phase2 = 0;
		}

		pthread_barrier_wait(&barrier1);
		if (g->finish)
		{
			break;
		}
	}

	return NULL;
}

int preflow(graph_t *g)
{
	node_t *s;
	node_t *u;
	node_t *v;
	edge_t *e;
	list_t *p;
	int b;

	s = g->source;
	s->height = g->nbr_nodes;

	p = s->adj;

	/* start by pushing as much as possible (limited by
	 * the edge capacity) from the source to its neighbors.
	 *
	 */

	while (p != NULL)
	{
		e = p->edge;
		p = p->next;

		s->excess += e->capacity;
		push(g, s, other(s, e), e);
	}

	struct work_args_t thread_args[NBR_THREADS];
	pthread_barrier_init(&barrier1, NULL, NBR_THREADS);
	pthread_t thread[NBR_THREADS];
	for (int i = 0; i < NBR_THREADS; i++)
	{
		thread_args[i].graph = g;
		thread_args[i].id = i;
		thread_args[i].worklist = malloc(g->nbr_nodes * sizeof(node_t *));
		thread_args[i].work_count = 0;
		thread_args[i].all_args = thread_args;
		if (pthread_create(&thread[i], NULL, work, &thread_args[i]) != 0)
		{
			error("error when creating pthreads \n");
		}
		printf("creating thread %d \n", i);
	}
	for (int i = 0; i < NBR_THREADS; i++)
	{
		if (pthread_join(thread[i], NULL) != 0)
		{
			error("pthread join error");
		}
		printf("Destroying thread %d \n", i);
	}

	return g->sink->excess;
}

static void free_graph(graph_t *g)
{
	int i;
	list_t *p;
	list_t *q;

	for (i = 0; i < g->nbr_nodes; i += 1)
	{
		p = g->nodes[i].adj;
		while (p != NULL)
		{
			q = p->next;
			free(p);
			p = q;
		}
	}
	free(g->nodes);
	free(g->edges);
	free(g);
}

int main(int argc, char *argv[])
{
	FILE *in;	/* input file set to stdin	*/
	graph_t *g; /* undirected graph. 		*/
	int f;		/* output from preflow.		*/
	int n;		/* number of nodes.		*/
	int m;		/* number of edges.		*/

	progname = argv[0]; /* name is a string in argv[0]. */

	in = stdin; /* same as System.in in Java.	*/

	n = next_int();
	m = next_int();

	/* skip C and P from the 6railwayplanning lab in EDAF05 */
	next_int();
	next_int();

	g = new_graph(in, n, m);

	fclose(in);

	f = preflow(g);

	printf("f = %d\n", f);

	free_graph(g);

	return 0;
}
