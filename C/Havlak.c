/* Copyright (c) 2001-2016 Stefan Marr
 * Copyright (c) 2024 Rochus Keller <me@rochus-keller.ch> (for C99 migration)
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the 'Software'), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.*/
// Copyright 2011 Google Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


// NOTE that alloc/dealloc eats up most of the time/performance; a more efficient allocator
// than the standard one would help

#include "Havlak.h"
#include "som/Vector.h"
#include "som/Set.h"
#include "som/Dictionary.h"
#include <stdio.h>
#include <assert.h>
#include <stdlib.h>

typedef struct BasicBlock BasicBlock;
typedef struct ControlFlowGraph ControlFlowGraph;
typedef struct BasicBlockEdge BasicBlockEdge;
typedef struct SimpleLoop SimpleLoop;
typedef struct UnionFindNode UnionFindNode;
typedef struct LoopStructureGraph LoopStructureGraph;

struct BasicBlock {
    Vector* inEdges; // Vector<BasicBlock*>
    Vector* outEdges; // Vector<BasicBlock*>
    int name;
};

static BasicBlock* BasicBlock_create(int name) {
    BasicBlock* me = malloc(sizeof(BasicBlock));
    me->name = name;
    me->inEdges = Vector_createDefault(sizeof(BasicBlock*));
    me->outEdges = Vector_createDefault(sizeof(BasicBlock*));
    return me;
}

static void BasicBlock_dispose(BasicBlock* me)
{
    Vector_dispose(me->inEdges);
    Vector_dispose(me->outEdges);
    free(me);
}

static Vector* BasicBlock_getInEdges(BasicBlock* me) {
    return me->inEdges;
}

static Vector* BasicBlock_getOutEdges(BasicBlock* me)  {
    return me->outEdges;
}

static int BasicBlock_getNumPred(BasicBlock* me) {
    return Vector_size(me->inEdges);
}

static void BasicBlock_addOutEdge(BasicBlock* me, BasicBlock* to) {
    Vector_append(me->outEdges,&to);
}

static void BasicBlock_addInEdge(BasicBlock* me, BasicBlock* from) {
    Vector_append(me->inEdges,&from);
}

static int BasicBlock_hash(const Bytes key) {
    BasicBlock** me = (BasicBlock**)key;
    assert(me);
    return (*me)->name;
}

struct BasicBlockEdge {

    BasicBlock* from;
    BasicBlock* to;
};

struct ControlFlowGraph {

    Vector*  basicBlockMap; // Vector<BasicBlock*>
    BasicBlock* startNode;
    Vector* edgeList; // Vector<BasicBlockEdge*>
};

static ControlFlowGraph* ControlFlowGraph_create() {
    ControlFlowGraph* me = malloc(sizeof(ControlFlowGraph));
    me->startNode = 0;
    me->basicBlockMap = Vector_createDefault(sizeof(BasicBlock*));
    me->edgeList = Vector_createDefault(sizeof(BasicBlockEdge*));
    return me;
}

static void ControlFlowGraph_dispose(ControlFlowGraph* me) {
    for( int i = 0; i < Vector_size(me->basicBlockMap); i++ )
    {
        BasicBlock* bb = *(BasicBlock**)Vector_at(me->basicBlockMap,i);
        BasicBlock_dispose(bb);
    }
    for( int i = 0; i < Vector_size(me->edgeList); i++ )
    {
        BasicBlockEdge* be = *(BasicBlockEdge**)Vector_at(me->edgeList,i);
        free(be);
    }
    Vector_dispose(me->basicBlockMap);
    Vector_dispose(me->edgeList);
    free(me);
}

static void ControlFlowGraph_addEdge(ControlFlowGraph* me, BasicBlockEdge* edge) {
    Vector_append(me->edgeList, &edge);
}

static int ControlFlowGraph_getNumNodes(ControlFlowGraph* me) {
    return Vector_size(me->basicBlockMap);
}

static BasicBlock* ControlFlowGraph_getStartBasicBlock(ControlFlowGraph* me) {
    return me->startNode;
}

static Vector* ControlFlowGraph_getBasicBlocks(ControlFlowGraph* me) {
    return me->basicBlockMap;
}

static BasicBlock* ControlFlowGraph_createNode(ControlFlowGraph* me, int name) {
    BasicBlock* node;
    if ( name < Vector_size(me->basicBlockMap) && *(BasicBlock**)Vector_at(me->basicBlockMap, name)) {
        node = *(BasicBlock**)Vector_at(me->basicBlockMap, name);
    } else {
        node = BasicBlock_create(name);
        Vector_atPut(me->basicBlockMap, name, &node);
    }

    if (ControlFlowGraph_getNumNodes(me) == 1) {
        me->startNode = node;
    }
    return node;
}

static BasicBlockEdge* BasicBlockEdge_create(ControlFlowGraph *cfg, int fromName, int toName)
{
    BasicBlockEdge* me = malloc(sizeof(BasicBlockEdge));
    me->from = ControlFlowGraph_createNode(cfg, fromName);
    me->to   = ControlFlowGraph_createNode(cfg, toName);

    BasicBlock_addOutEdge(me->from, me->to);
    BasicBlock_addInEdge(me->to, me->from);

    ControlFlowGraph_addEdge(cfg,me);
    return me;
}

struct SimpleLoop {

    IdentitySet* basicBlocks; // IdentitySet<BasicBlock*>
    IdentitySet* children; // IdentitySet<SimpleLoop*>
    SimpleLoop* parent;

    bool isRoot_;
    int     nestingLevel;
};

static void SimpleLoop_addChildLoop(SimpleLoop* me, SimpleLoop* loop) {
    Set_add(me->children, &loop);
}

static SimpleLoop* SimpleLoop_create(BasicBlock* bb) {
    SimpleLoop* me = malloc(sizeof(SimpleLoop));
    me->parent = 0;
    me->isRoot_ = false;
    me->nestingLevel = 0;
    me->basicBlocks = Set_create(sizeof(BasicBlock*));
    me->children = Set_create(sizeof(SimpleLoop*));
    if (bb != 0) {
        Set_add(me->basicBlocks, &bb);
    }
    return me;
}

static void SimpleLoop_dispose(SimpleLoop* me) {
    Set_dispose(me->basicBlocks);
    Set_dispose(me->children);
    free(me);
}

static void SimpleLoop_addNode(SimpleLoop* me, BasicBlock* bb) {
    Set_add(me->basicBlocks, &bb);
}

static IdentitySet* SimpleLoop_getChildren(SimpleLoop* me) {
    return me->children;
}

static SimpleLoop* SimpleLoop_getParent(SimpleLoop* me) {
    return me->parent;
}

static int SimpleLoop_getNestingLevel(SimpleLoop* me) {
    return me->nestingLevel;
}

static bool SimpleLoop_isRoot(SimpleLoop* me) {   // Note: fct and var are same!
    return me->isRoot_;
}

static void SimpleLoop_setIsRoot(SimpleLoop* me) {
    me->isRoot_ = true;
}

void SimpleLoop_setParent(SimpleLoop* me, SimpleLoop* parent) {
    me->parent = parent;
    SimpleLoop_addChildLoop(me->parent, me);
}

void SimpleLoop_setNestingLevel(SimpleLoop* me, int level) {
    me->nestingLevel = level;
    if (level == 0) {
        SimpleLoop_setIsRoot(me);
    }
}

struct UnionFindNode {

    UnionFindNode* parent;
    BasicBlock*    bb;
    SimpleLoop*    loop;
    int           dfsNumber;
};

static UnionFindNode* UnionFindNode_create() {
    UnionFindNode* me = malloc(sizeof(UnionFindNode));
    me->parent = 0;
    me->bb = 0;
    me->loop = 0;
    me->dfsNumber = 0;
    return me;
}

static void UnionFindNode_initNode(UnionFindNode* me, BasicBlock* bb, int dfsNumber) {
    me->parent     = me;
    me->bb         = bb;
    me->dfsNumber  = dfsNumber;
    me->loop       = 0;
}

static void UnionFindNode_unite(UnionFindNode* me, UnionFindNode* basicBlock) { // orig union
    me->parent = basicBlock;
}

static BasicBlock* UnionFindNode_getBb(UnionFindNode* me)  {
    return me->bb;
}

static SimpleLoop* UnionFindNode_getLoop(UnionFindNode* me) {
    return me->loop;
}

static int UnionFindNode_getDfsNumber(UnionFindNode* me) {
    return me->dfsNumber;
}

static void UnionFindNode_setLoop(UnionFindNode* me, SimpleLoop* loop) {
    me->loop = loop;
}

static void UnionFindNode_findSet_iter(const Bytes value, void* data)
{
    UnionFindNode* parent = data;
    UnionFindNode* iter = *(UnionFindNode**)value;
    UnionFindNode_unite(iter, parent);
}

static UnionFindNode* UnionFindNode_findSet(UnionFindNode* me) {
    Vector* nodeList; // Vector<UnionFindNode*>
    nodeList = Vector_createDefault(sizeof(UnionFindNode*));

    UnionFindNode* node = me;
    while (node != node->parent) {
        if (node->parent != node->parent->parent) {
            Vector_append(nodeList, &node);
        }
        node = node->parent;
    }

    Vector_forEach(nodeList, UnionFindNode_findSet_iter, me->parent);
    Vector_dispose(nodeList);
    return node;
}

struct LoopStructureGraph {

    SimpleLoop* root;
    Vector* loops; // Vector<SimpleLoop*>
    int loopCounter;
};

static LoopStructureGraph* LoopStructureGraph_create() {
    LoopStructureGraph* me = malloc(sizeof(LoopStructureGraph));
    me->loopCounter = 0;
    me->root = SimpleLoop_create(0);
    SimpleLoop_setNestingLevel(me->root, 0);
    me->loopCounter += 1;
    me->loops = Vector_createDefault(sizeof(SimpleLoop*));
    Vector_append(me->loops, &me->root);
    return me;
}

static void LoopStructureGraph_dispose(LoopStructureGraph* me)
{
    for( int i = 0; i < Vector_size(me->loops); i++ )
    {
        SimpleLoop* sl = *(SimpleLoop**)Vector_at(me->loops, i);
        SimpleLoop_dispose(sl);
    }
    Vector_dispose(me->loops);
    free(me);
}

static int LoopStructureGraph_getNumLoops(LoopStructureGraph* me) {
    return Vector_size(me->loops);
}

static SimpleLoop* LoopStructureGraph_createNewLoop(LoopStructureGraph* me, BasicBlock* bb, bool isReducible) {
    SimpleLoop* loop = SimpleLoop_create(bb);
    me->loopCounter += 1;
    Vector_append(me->loops, &loop);
    return loop;
}

static void LoopStructureGraph_calculateNestingLevel_iter(const Bytes value, void* data)
{
    SimpleLoop* root = data;
    SimpleLoop* loop = *(SimpleLoop**)value;

    if (!SimpleLoop_isRoot(loop)) {
        if (SimpleLoop_getParent(loop) == 0) {
            SimpleLoop_setParent(loop, root);
        }
    }
}

static void LoopStructureGraph_calculateNestingLevelRec(SimpleLoop* loop, int depth);

static void LoopStructureGraph_calculateNestingLevel(LoopStructureGraph* me) {
    // link up all 1st level loops to artificial root node.

    Vector_forEach(me->loops, LoopStructureGraph_calculateNestingLevel_iter, me->root);

    // recursively traverse the tree and assign levels.
    LoopStructureGraph_calculateNestingLevelRec(me->root, 0);
}

struct LoopStructureGraph_calculateNestingLevelRec_Iter {
    SimpleLoop* loop;
    int depth;
};

#define MAX(a,b) (((a)>(b))?(a):(b))
static void LoopStructureGraph_calculateNestingLevelRec_iter(const Bytes value, void* data)
{
    struct LoopStructureGraph_calculateNestingLevelRec_Iter* iter = data;
    SimpleLoop* liter = *(SimpleLoop**)value;
    LoopStructureGraph_calculateNestingLevelRec(liter, iter->depth + 1);

    SimpleLoop_setNestingLevel(iter->loop, MAX(SimpleLoop_getNestingLevel(iter->loop),
                              1 + SimpleLoop_getNestingLevel(liter)));
}

static void LoopStructureGraph_calculateNestingLevelRec(SimpleLoop* loop, int depth) {
    struct LoopStructureGraph_calculateNestingLevelRec_Iter iter;
    iter.loop = loop;
    iter.depth = depth;

    Set_forEach(SimpleLoop_getChildren(loop), LoopStructureGraph_calculateNestingLevelRec_iter, &iter);
}

/**
 * enum BasicBlockClass
 *
 * Basic Blocks and Loops are being classified as regular, irreducible,
 * and so on. This enum contains a symbolic name for all these classifications
 */
enum BasicBlockClass {
    BB_TOP,          // uninitialized
    BB_NONHEADER,    // a regular BB
    BB_REDUCIBLE,    // reducible loop
    BB_SELF,         // single BB loop
    BB_IRREDUCIBLE,  // irreducible loop
    BB_DEAD,         // a dead BB
    BB_LAST          // Sentinel
};

enum { UNVISITED = 0xffffffff, MAXNONBACKPREDS = (32 * 1024) };

typedef struct HavlakLoopFinder {

    ControlFlowGraph*   cfg;      // Control Flow Graph
    LoopStructureGraph* lsg;      // Loop Structure Graph

    Vector*             nonBackPreds; // Vector<Set<int>>
    Vector*             backPreds; // Vector<Vector<int>>
    IdentityDictionary* number; // Number: IdentityDictionary<BasicBlock*, int, BasicBlock_Hash>
    int                 maxSize;
    Vector*             header; // Vector<int>
    Vector*             type; // Vector<BasicBlockClass>
    Vector*             last; // Vector<int>
    Vector*             nodes; // Vector<UnionFindNode*>

} HavlakLoopFinder;

static void HavlakLoopFinder_init(HavlakLoopFinder* me, ControlFlowGraph* cfg, LoopStructureGraph* lsg) {
    me->maxSize = 0;
    me->cfg = cfg;
    me->lsg = lsg;
    me->nonBackPreds = Vector_createDefault(sizeof(Set*));
    me->backPreds = Vector_createDefault(sizeof(Vector*));
    me->number = Dictionary_create(sizeof(BasicBlock*), sizeof(int), BasicBlock_hash);
    me->header = Vector_createDefault(sizeof(int));
    me->type = Vector_createDefault(sizeof(enum BasicBlockClass));
    me->last = Vector_createDefault(sizeof(int));
    me->nodes = Vector_createDefault(sizeof(UnionFindNode*));
}

static void HavlakLoopFinder_deinit(HavlakLoopFinder* me)
{
    for( int i = 0; i < Vector_size(me->nodes); i++ )
    {
        UnionFindNode* n = *(UnionFindNode**)Vector_at(me->nodes, i);
        free(n);
        n = 0;
        Vector_atPut(me->nodes, i,&n);
    }

    for( int i = 0; i < Vector_size(me->nonBackPreds); i++ )
        Set_dispose( *(Set**)Vector_at(me->nonBackPreds,i) );
    Vector_dispose(me->nonBackPreds);
    for( int i = 0; i < Vector_size(me->backPreds); i++ )
        Vector_dispose(*(Vector**)Vector_at(me->backPreds,i));
    Vector_dispose(me->backPreds);

    Dictionary_dispose(me->number);
    Vector_dispose(me->header);
    Vector_dispose(me->type);
    Vector_dispose(me->last);
    Vector_dispose(me->nodes);
}

//
// IsAncestor
//
// As described in the paper, determine whether a node 'w' is a
// "true" ancestor for node 'v'.
//
// Dominance can be tested quickly using a pre-order trick
// for depth-first spanning trees. This is why DFS is the first
// thing we run below.
//
static bool HavlakLoopFinder_isAncestor(HavlakLoopFinder* me, int w, int v) {
    return w <= v && v <= *(int*)Vector_at(me->last, w);
}

//
// DFS - Depth-First-Search
//
// DESCRIPTION:
// Simple depth first traversal along out edges with node numbering.
//
static int HavlakLoopFinder_doDFS(HavlakLoopFinder* me, BasicBlock* currentNode, int current) {
    UnionFindNode_initNode(*(UnionFindNode**)Vector_at(me->nodes, current), currentNode, current);
    Dictionary_atPut(me->number, &currentNode, &current);

    int lastId = current;
    Vector* outerBlocks = BasicBlock_getOutEdges(currentNode); // Vector<BasicBlock*>

    for (int i = 0; i < Vector_size(outerBlocks); i++) {
        BasicBlock* target = *(BasicBlock**)Vector_at(outerBlocks, i);
        int* n = (int*)Dictionary_at(me->number, &target);
        if ( n && *n == UNVISITED) {
            lastId = HavlakLoopFinder_doDFS(me, target, lastId + 1);
        }
    }

    Vector_atPut(me->last, current, &lastId);
    return lastId;
}

static void HavlakLoopFinder_initAllNodes_iter(const Bytes value, void* data)
{
    IdentityDictionary* number = data;
    BasicBlock* bb = *(BasicBlock**)value;
    const int tmp = UNVISITED;
    Dictionary_atPut(number, &bb, &tmp);
}

static void HavlakLoopFinder_initAllNodes(HavlakLoopFinder* me) {
    // Step a:
    //   - initialize all nodes as unvisited.
    //   - depth-first traversal and numbering.
    //   - unreached BB's are marked as dead.
    //
    Vector* vec = ControlFlowGraph_getBasicBlocks(me->cfg); // Vector<BasicBlock*>
    for( int i = 0; i < Vector_size(vec); i++ ) {
        BasicBlock* bb = *(BasicBlock**)Vector_at(vec,i);
        const int tmp = UNVISITED;
        Dictionary_atPut(me->number, &bb, &tmp); // IdentityDictionary<BasicBlock*, int, BasicBlock_Hash>
    }
    //Vector_forEach(vec, HavlakLoopFinder_initAllNodes_iter, me->number);

    HavlakLoopFinder_doDFS(me, ControlFlowGraph_getStartBasicBlock(me->cfg), 0);
}

struct HavlakLoopFinder_processEdges_Iter {
    HavlakLoopFinder* that;
    int w;
};

static Set* getNonBackPreds(Vector* vec, int i)
{
    Set* s = *(Set**)Vector_at(vec,i);
    if( s == 0 )
    {
        s = Set_create(sizeof(int));
        Vector_atPut(vec, i, &s);
    }
    return s;
}

static void HavlakLoopFinder_processEdges_iter(const Bytes value, void* data)
{
    struct HavlakLoopFinder_processEdges_Iter* iter = data;
    BasicBlock* nodeV = *(BasicBlock**)value;
    int* v = (int*)Dictionary_at(iter->that->number, &nodeV);
    if (v && *v != UNVISITED) {
        if (HavlakLoopFinder_isAncestor(iter->that,iter->w, *v)) {
            Vector* tmp = *(Vector**)Vector_at(iter->that->backPreds,iter->w); // Vector<int>
            if( tmp == 0 ) {
                tmp = Vector_createDefault(sizeof(int));
                Vector_atPut(iter->that->backPreds,iter->w, &tmp);
            }
            Vector_append(tmp, v);
        } else {
            Set_add(getNonBackPreds(iter->that->nonBackPreds,iter->w), v); // Vector<Set<int>>
        }
    }
}

static void HavlakLoopFinder_processEdges(HavlakLoopFinder* me, BasicBlock* nodeW, int w) {
    if (BasicBlock_getNumPred(nodeW) > 0) {
        struct HavlakLoopFinder_processEdges_Iter iter;
        iter.that = me;
        iter.w = w;
        Vector_forEach(BasicBlock_getInEdges(nodeW), HavlakLoopFinder_processEdges_iter, &iter);
    }
}

static void HavlakLoopFinder_identifyEdges(HavlakLoopFinder* me, int size) {
    // Step b:
    //   - iterate over all nodes.
    //
    //   A backedge comes from a descendant in the DFS tree, and non-backedges
    //   from non-descendants (following Tarjan).
    //
    //   - check incoming edges 'v' and add them to either
    //     - the list of backedges (backPreds) or
    //     - the list of non-backedges (nonBackPreds)
    //
    for (int w = 0; w < size; w++) {
        const int tmp = 0;
        Vector_atPut(me->header, w, &tmp);
        const enum BasicBlockClass tmp2 = BB_NONHEADER;
        Vector_atPut(me->type, w, &tmp2);

        BasicBlock* nodeW = UnionFindNode_getBb((*(UnionFindNode***)Vector_at(me->nodes, w)));
        if (nodeW == 0) {
            const enum BasicBlockClass tmp = BB_DEAD;
            Vector_atPut(me->type, w, &tmp);
        } else {
            HavlakLoopFinder_processEdges(me, nodeW, w);
        }
    }
}

struct HavlakLoopFinder_stepEProcessNonBackPreds_Iter {
    HavlakLoopFinder* that;
    int w;
    Vector* nodePool; // Vector<UnionFindNode*>
    Vector* workList; // Vector<UnionFindNode*>
};

static bool HavlakLoopFinder_stepEProcessNonBackPreds_iter_iter(const Bytes value, void* data)
{
    UnionFindNode* ydash = data;
    UnionFindNode* e = *(UnionFindNode**)value;
    return e == ydash;
}

static void HavlakLoopFinder_stepEProcessNonBackPreds_iter(const Bytes value, void* data)
{
    struct HavlakLoopFinder_stepEProcessNonBackPreds_Iter* d = data;
    const int* iter = value;
    UnionFindNode* y = *(UnionFindNode**)Vector_at(d->that->nodes, *iter);
    UnionFindNode* ydash = UnionFindNode_findSet(y);

    if (!HavlakLoopFinder_isAncestor(d->that, d->w, UnionFindNode_getDfsNumber(ydash))) {
        const enum BasicBlockClass tmp = BB_IRREDUCIBLE;
        Vector_atPut(d->that->type, d->w, &tmp);
        const int tmp2 = UnionFindNode_getDfsNumber(ydash);
        Set_add(getNonBackPreds(d->that->nonBackPreds, d->w), &tmp2);
    } else {
        if (UnionFindNode_getDfsNumber(ydash) != d->w) {
            if (!Vector_hasSome(d->nodePool, HavlakLoopFinder_stepEProcessNonBackPreds_iter_iter, ydash)) {
                Vector_append(d->workList, &ydash);
                Vector_append(d->nodePool, &ydash);
            }
        }
    }
}

static void HavlakLoopFinder_stepEProcessNonBackPreds(HavlakLoopFinder* me, int w,
                              Vector* nodePool, // Vector<UnionFindNode*>
                              Vector* workList, // Vector<UnionFindNode*>
                              UnionFindNode* x) {
    struct HavlakLoopFinder_stepEProcessNonBackPreds_Iter iter;
    iter.nodePool = nodePool;
    iter.that = me;
    iter.w = w;
    iter.workList = workList;

    Set* s = *(Set**)Vector_at(me->nonBackPreds, UnionFindNode_getDfsNumber(x));
    if( s )
        Set_forEach(s, HavlakLoopFinder_stepEProcessNonBackPreds_iter, &iter);
}

struct HavlakLoopFinder_stepD_Iter {
    HavlakLoopFinder* that;
    int w;
    Vector* nodePool; // Vector<UnionFindNode*>
};

static void HavlakLoopFinder_stepD_iter(const Bytes value, void* data)
{
    struct HavlakLoopFinder_stepD_Iter* iter = data;
    int* v = value;
    if (*v != iter->w) {
        UnionFindNode* tmp = UnionFindNode_findSet(*(UnionFindNode**)Vector_at(iter->that->nodes, *v));
        Vector_append(iter->nodePool, &tmp);
    } else {
        const enum BasicBlockClass tmp = BB_SELF;
        Vector_atPut(iter->that->type, iter->w, &tmp);
    }
}

static void HavlakLoopFinder_stepD(HavlakLoopFinder* me, int w,
                                   Vector* nodePool // Vector<UnionFindNode*>
                                   ) {

    struct HavlakLoopFinder_stepD_Iter iter;
    iter.nodePool = nodePool;
    iter.that = me;
    iter.w = w;
    Vector* vec = *(Vector**)Vector_at(me->backPreds, w);
    if( vec )
        Vector_forEach(vec, HavlakLoopFinder_stepD_iter, &iter);
}

struct HavlakLoopFinder_setLoopAttributes_Iter {
    HavlakLoopFinder* that;
    int w;
    SimpleLoop* loop;
};

static void HavlakLoopFinder_setLoopAttributes_iter(const Bytes value, void* data)
{
    struct HavlakLoopFinder_setLoopAttributes_Iter* iter = data;
    UnionFindNode* node = *(UnionFindNode**)value;

    // Add nodes to loop descriptor.
    Vector_atPut(iter->that->header, UnionFindNode_getDfsNumber(node), &iter->w);
    UnionFindNode_unite(node, *(UnionFindNode**)Vector_at(iter->that->nodes, iter->w));

    // Nested loops are not added, but linked together.
    if (UnionFindNode_getLoop(node) != 0) {
        SimpleLoop_setParent(UnionFindNode_getLoop(node), iter->loop);
    } else {
        SimpleLoop_addNode(iter->loop, UnionFindNode_getBb(node));
    }
}

static void HavlakLoopFinder_setLoopAttributes(HavlakLoopFinder* me,
                                               int w, Vector* nodePool, // Vector<UnionFindNode*>
                                               SimpleLoop* loop) {
    // At this point, one can set attributes to the loop, such as:
    //
    // the bottom node:
    //    iter  = backPreds[w].begin();
    //    loop bottom is: nodes[iter].node);
    //
    // the number of backedges:
    //    backPreds[w].size()
    //
    // whether this loop is reducible:
    //    type[w] != BasicBlockClass.BB_IRREDUCIBLE
    //
    UnionFindNode_setLoop(*(UnionFindNode**)Vector_at(me->nodes, w), loop);

    struct HavlakLoopFinder_setLoopAttributes_Iter iter;
    iter.loop = loop;
    iter.that = me;
    iter.w = w;

    Vector_forEach(nodePool, HavlakLoopFinder_setLoopAttributes_iter, &iter);
}

//
// findLoops
//
// Find loops and build loop forest using Havlak's algorithm, which
// is derived from Tarjan. Variable names and step numbering has
// been chosen to be identical to the nomenclature in Havlak's
// paper (which, in turn, is similar to the one used by Tarjan).
//

static void HavlakLoopFinder_findLoops_iter(const Bytes value, void* data)
{
    Vector* workList = data;
    UnionFindNode* niter = *(UnionFindNode**)value;
    Vector_append(workList, &niter);
}

static void HavlakLoopFinder_findLoops(HavlakLoopFinder* me) {
    if (ControlFlowGraph_getStartBasicBlock(me->cfg) == 0) {
        return;
    }

    int size = ControlFlowGraph_getNumNodes(me->cfg);

    for( int i = 0; i < Vector_size(me->nonBackPreds); i++ )
        Set_dispose( *(Set**)Vector_at(me->nonBackPreds,i) );
    Vector_removeAll(me->nonBackPreds);
    for( int i = 0; i < Vector_size(me->backPreds); i++ )
        Vector_dispose(*(Vector**)Vector_at(me->backPreds,i));
    Vector_removeAll(me->backPreds);
    Dictionary_removeAll(me->number);

    if (size > me->maxSize) {
        Vector_expand(me->header, size);
        Vector_expand(me->type, size);
        Vector_expand(me->last, size);
        Vector_expand(me->nodes, size);
        Vector_expand(me->backPreds, size);
        Vector_expand(me->nonBackPreds, size);
        me->maxSize = size;
    }

    for (int i = 0; i < size; ++i) {
        UnionFindNode* tmp = UnionFindNode_create();
        Vector_atPut(me->nodes, i, &tmp);
    }

    HavlakLoopFinder_initAllNodes(me);
    HavlakLoopFinder_identifyEdges(me, size);

    // Start node is root of all other loops.
    Vector_atPut(me->header, 0, &(int){0});

    // Step c:
    //
    // The outer loop, unchanged from Tarjan. It does nothing except
    // for those nodes which are the destinations of backedges.
    // For a header node w, we chase backward from the sources of the
    // backedges adding nodes to the set P, representing the body of
    // the loop headed by w.
    //
    // By running through the nodes in reverse of the DFST preorder,
    // we ensure that inner loop headers will be processed before the
    // headers for surrounding loops.
    //
    for (int w = size - 1; w >= 0; w--) {
        // this is 'P' in Havlak's paper
        Vector* nodePool = Vector_createDefault(sizeof(UnionFindNode*)); // Vector<UnionFindNode*>

        BasicBlock* nodeW = UnionFindNode_getBb(*(UnionFindNode**)Vector_at(me->nodes, w));
        if (nodeW != 0) {
            HavlakLoopFinder_stepD(me, w, nodePool);

            // Copy nodePool to workList.
            //
            Vector* workList = Vector_createDefault(sizeof(UnionFindNode*)); // Vector<UnionFindNode*>

            Vector_forEach(nodePool, HavlakLoopFinder_findLoops_iter, workList);

            if (Vector_size(nodePool) != 0) {
                const enum BasicBlockClass tmp = BB_REDUCIBLE;
                Vector_atPut(me->type, w, &tmp);
            }

            // work the list...
            //
            while (!Vector_isEmpty(workList)) {
                UnionFindNode* x = *(UnionFindNode**)Vector_removeFirst(workList);

                // Step e:
                //
                // Step e represents the main difference from Tarjan's method.
                // Chasing upwards from the sources of a node w's backedges. If
                // there is a node y' that is not a descendant of w, w is marked
                // the header of an irreducible loop, there is another entry
                // into this loop that avoids w.
                //

                // The algorithm has degenerated. Break and
                // return in this case.
                //
                int nonBackSize = Set_size(*(Set**)Vector_at(me->nonBackPreds, UnionFindNode_getDfsNumber(x)));
                if (nonBackSize > MAXNONBACKPREDS) {
                    Vector_dispose(nodePool);
                    Vector_dispose(workList);
                    return;
                }
                HavlakLoopFinder_stepEProcessNonBackPreds(me, w, nodePool, workList, x);
            }

            // Collapse/Unionize nodes in a SCC to a single node
            // For every SCC found, create a loop descriptor and link it in.
            //
            if ((Vector_size(nodePool) > 0) || *(enum BasicBlockClass*)Vector_at(me->type, w) == BB_SELF) {
                SimpleLoop* loop = LoopStructureGraph_createNewLoop(
                            me->lsg, nodeW, *(enum BasicBlockClass*)Vector_at(me->type, w) != BB_IRREDUCIBLE);
                HavlakLoopFinder_setLoopAttributes(me, w, nodePool, loop);
            }
            Vector_dispose(workList);
        }
        Vector_dispose(nodePool);
    }  // Step c
}  // findLoops

typedef struct LoopTesterApp {

    ControlFlowGraph*   cfg;
    LoopStructureGraph* lsg;
} LoopTesterApp;

static void LoopTesterApp_init(LoopTesterApp* me) {
    me->cfg = ControlFlowGraph_create();
    me->lsg = LoopStructureGraph_create();
    ControlFlowGraph_createNode(me->cfg, 0);
}

static void LoopTesterApp_deinit(LoopTesterApp* me)
{
    LoopStructureGraph_dispose(me->lsg);
    ControlFlowGraph_dispose(me->cfg);
}

// Create 4 basic blocks, corresponding to and if/then/else clause
// with a CFG that looks like a diamond
static int LoopTesterApp_buildDiamond(LoopTesterApp* me, int start) {
    int bb0 = start;
    BasicBlockEdge_create(me->cfg, bb0, bb0 + 1);
    BasicBlockEdge_create(me->cfg, bb0, bb0 + 2);
    BasicBlockEdge_create(me->cfg, bb0 + 1, bb0 + 3);
    BasicBlockEdge_create(me->cfg, bb0 + 2, bb0 + 3);

    return bb0 + 3;
}

// Connect two existing nodes
static void LoopTesterApp_buildConnect(LoopTesterApp* me, int start, int end) {
    BasicBlockEdge_create(me->cfg, start, end);
}

// Form a straight connected sequence of n basic blocks
static int LoopTesterApp_buildStraight(LoopTesterApp* me, int start,  int n) {
    for (int i = 0; i < n; i++) {
        LoopTesterApp_buildConnect(me, start + i, start + i + 1);
    }
    return start + n;
}

// Construct a simple loop with two diamonds in it
static int LoopTesterApp_buildBaseLoop(LoopTesterApp* me, int from) {
    int header   = LoopTesterApp_buildStraight(me, from, 1);
    int diamond1 = LoopTesterApp_buildDiamond(me, header);
    int d11      = LoopTesterApp_buildStraight(me, diamond1, 1);
    int diamond2 = LoopTesterApp_buildDiamond(me, d11);
    int footer   = LoopTesterApp_buildStraight(me, diamond2, 1);
    LoopTesterApp_buildConnect(me, diamond2, d11);
    LoopTesterApp_buildConnect(me, diamond1, header);

    LoopTesterApp_buildConnect(me, footer, from);
    footer = LoopTesterApp_buildStraight(me, footer, 1);
    return footer;
}

static void LoopTesterApp_constructSimpleCFG(LoopTesterApp* me) {
    ControlFlowGraph_createNode(me->cfg, 0);
    LoopTesterApp_buildBaseLoop(me, 0);
    ControlFlowGraph_createNode(me->cfg, 1);
    BasicBlockEdge_create(me->cfg, 0, 2);
}

static void LoopTesterApp_findLoops(LoopTesterApp* me, LoopStructureGraph* loopStructure) {
    HavlakLoopFinder finder;
    HavlakLoopFinder_init(&finder, me->cfg, loopStructure);
    HavlakLoopFinder_findLoops(&finder);
    HavlakLoopFinder_deinit(&finder);
}

static void LoopTesterApp_addDummyLoops(LoopTesterApp* me, int numDummyLoops) {
    for (int dummyloop = 0; dummyloop < numDummyLoops; dummyloop++) {
        LoopTesterApp_findLoops(me, me->lsg);
    }
}

static void LoopTesterApp_constructCFG(LoopTesterApp* me, int parLoops, int pparLoops, int ppparLoops) {
    int n = 2;

    for (int parlooptrees = 0; parlooptrees < parLoops; parlooptrees++) {
        ControlFlowGraph_createNode(me->cfg, n + 1);
        LoopTesterApp_buildConnect(me, 2, n + 1);
        n += 1;

        for (int i = 0; i < pparLoops; i++) {
            int top = n;
            n = LoopTesterApp_buildStraight(me, n, 1);
            for (int j = 0; j < ppparLoops; j++) {
                n = LoopTesterApp_buildBaseLoop(me, n);
            }
            int bottom = LoopTesterApp_buildStraight(me, n, 1);
            LoopTesterApp_buildConnect(me, n, top);
            n = bottom;
        }
        LoopTesterApp_buildConnect(me, n, 1);
    }
}

static int NumLoops = 0;
static int NumNodes = 0;

static void LoopTesterApp_main(LoopTesterApp* me, int numDummyLoops, int findLoopIterations,
                 int parLoops, int pparLoops, int ppparLoops) {
    LoopTesterApp_constructSimpleCFG(me);
    LoopTesterApp_addDummyLoops(me, numDummyLoops);
    LoopTesterApp_constructCFG(me, parLoops, pparLoops, ppparLoops);

    // Performing Loop Recognition, 1 Iteration, then findLoopIteration
    LoopTesterApp_findLoops(me, me->lsg);
    Vector* toDelete = Vector_createDefault(sizeof(LoopStructureGraph*)); // Vector<LoopStructureGraph*>
    for (int i = 0; i < findLoopIterations; i++) {
        LoopStructureGraph* l = LoopStructureGraph_create();
        Vector_append(toDelete, &l);
        LoopTesterApp_findLoops(me, l);
    }

    LoopStructureGraph_calculateNestingLevel(me->lsg);
    for( int i = 0; i < Vector_size(toDelete); i++ )
        LoopStructureGraph_dispose(*(LoopStructureGraph**)Vector_at(toDelete, i));
    Vector_dispose(toDelete);
    NumLoops = LoopStructureGraph_getNumLoops(me->lsg);
    NumNodes = ControlFlowGraph_getNumNodes(me->cfg);
}

static bool Havlak_verifyResult(int a, int b, int innerIterations)
{
    if (innerIterations == 15000) { return a == 46602 && b == 5213; }
    if (innerIterations ==  1500) { return a ==  6102 && b == 5213; }
    if (innerIterations ==   150) { return a ==  2052 && b == 5213; }
    if (innerIterations ==    15) { return a ==  1647 && b == 5213; }
    if (innerIterations ==     1) { return a ==  1605 && b == 5213; }

    // Checkstyle: stop
    fprintf(stderr, "No verification result for %d found\n", innerIterations);
    fprintf(stderr, "Result is: %d, %d\n", a, b);
    // Checkstyle: resume

    return false;

}

static bool Havlak_innerBenchmarkLoop(Benchmark* me, int innerIterations)
{
    LoopTesterApp app;
    LoopTesterApp_init(&app);

    LoopTesterApp_main(&app, innerIterations, 50, 10 /* was 100 */, 10, 5);

    bool res = Havlak_verifyResult(NumLoops, NumNodes, innerIterations);
    LoopTesterApp_deinit(&app);
    return res;
}

static int benchmark() {
    assert(0); // "Should never be reached"
}

static bool verifyResult(int result) {
    assert(0); // "Should never be reached"
}

Benchmark*Havlak_create()
{
    Benchmark* bench = (Benchmark*)malloc(sizeof(Benchmark));
    bench->benchmark = benchmark;
    bench->verifyResult = verifyResult;
    bench->dispose = 0;
    bench->innerBenchmarkLoop = Havlak_innerBenchmarkLoop;
    return bench;
}
