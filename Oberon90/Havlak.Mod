(* Copyright (c) 2001-2016 Stefan Marr
 * Copyright (c) 2026 Rochus Keller <me@rochus-keller.ch> (for Oberon 90 migration)
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
 * THE SOFTWARE.
 *)

MODULE Havlak;

IMPORT SOM, Benchmark, Out;

CONST
  BBTOP = 0; BBNONHEADER = 1; BBREDUCIBLE = 2;
  BBSELF = 3; BBIRREDUCIBLE = 4; BBDEAD = 5; BBLAST = 6;
  UNVISITED = -1;
  MAXNONBACKPREDS = 32 * 1024;

TYPE
  INT32 = SOM.INT32;

  Havlak* = POINTER TO HavlakDesc;
  HavlakDesc* = RECORD (Benchmark.BenchmarkDesc) END;

  BasicBlock = POINTER TO BasicBlockDesc;
  BasicBlockDesc = RECORD (SOM.ObjectDesc)
    inEdges, outEdges: SOM.Vector;
    name: INT32;
  END;

  BasicBlockEdge = POINTER TO BasicBlockEdgeDesc;
  BasicBlockEdgeDesc = RECORD (SOM.ObjectDesc)
    from, to: BasicBlock;
  END;

  ControlFlowGraph = POINTER TO ControlFlowGraphDesc;
  ControlFlowGraphDesc = RECORD (SOM.ObjectDesc)
    basicBlockMap: SOM.Vector;
    startNode: BasicBlock;
    edgeList: SOM.Vector;
  END;

  SimpleLoop = POINTER TO SimpleLoopDesc;
  SimpleLoopDesc = RECORD (SOM.ObjectDesc)
    basicBlocks: SOM.Set;
    children: SOM.Set;
    parent: SimpleLoop;
    isRoot: BOOLEAN;
    nestingLevel: INT32;
  END;

  UnionFindNode = POINTER TO UnionFindNodeDesc;
  UnionFindNodeDesc = RECORD (SOM.ObjectDesc)
    parent: UnionFindNode;
    bb: BasicBlock;
    loop: SimpleLoop;
    dfsNumber: INT32;
  END;

  LoopStructureGraph = POINTER TO LoopStructureGraphDesc;
  LoopStructureGraphDesc = RECORD (SOM.ObjectDesc)
    root: SimpleLoop;
    loops: SOM.Vector;
    loopCounter: INT32;
  END;

  HavlakLoopFinder = POINTER TO HavlakLoopFinderDesc;
  HavlakLoopFinderDesc = RECORD (SOM.ObjectDesc)
    cfg: ControlFlowGraph;
    lsg: LoopStructureGraph;
    nonBackPreds: SOM.Vector;
    backPreds: SOM.Vector;
    number: SOM.Dictionary;
    maxSize: INT32;
    header: SOM.IntVector;
    type: SOM.IntVector;
    last: SOM.IntVector;
    nodes: SOM.Vector;
  END;

  LoopTesterApp = POINTER TO LoopTesterAppDesc;
  LoopTesterAppDesc = RECORD (SOM.ObjectDesc)
    cfg: ControlFlowGraph;
    lsg: LoopStructureGraph;
  END;

VAR
  NumLoops, NumNodes: INT32;

(* --- BasicBlock --- *)

PROCEDURE CreateBasicBlock(name: INT32): BasicBlock;
  VAR bb: BasicBlock;
BEGIN
  NEW(bb);
  bb.name := name;
  bb.inEdges := SOM.CreateVector(0);
  bb.outEdges := SOM.CreateVector(0);
  RETURN bb
END CreateBasicBlock;

(* --- ControlFlowGraph --- *)

PROCEDURE CreateControlFlowGraph(): ControlFlowGraph;
  VAR cfg: ControlFlowGraph;
BEGIN
  NEW(cfg);
  cfg.startNode := NIL;
  cfg.basicBlockMap := SOM.CreateVector(0);
  cfg.edgeList := SOM.CreateVector(0);
  RETURN cfg
END CreateControlFlowGraph;

PROCEDURE CFGCreateNode(cfg: ControlFlowGraph; name: INT32): BasicBlock;
  VAR node: BasicBlock;
BEGIN
  IF (name < SOM.VectorSize(cfg.basicBlockMap)) & (SOM.VectorAt(cfg.basicBlockMap, name) # NIL) THEN
    node := SOM.VectorAt(cfg.basicBlockMap, name)(BasicBlock);
  ELSE
    node := CreateBasicBlock(name);
    SOM.VectorAtPut(cfg.basicBlockMap, name, node);
  END;
  IF SOM.VectorSize(cfg.basicBlockMap) = 1 THEN
    cfg.startNode := node;
  END;
  RETURN node
END CFGCreateNode;

(* --- BasicBlockEdge --- *)

PROCEDURE CreateBasicBlockEdge(cfg: ControlFlowGraph; fromName, toName: INT32): BasicBlockEdge;
  VAR e: BasicBlockEdge;
BEGIN
  NEW(e);
  e.from := CFGCreateNode(cfg, fromName);
  e.to := CFGCreateNode(cfg, toName);
  SOM.VectorAppend(e.from.outEdges, e.to);
  SOM.VectorAppend(e.to.inEdges, e.from);
  SOM.VectorAppend(cfg.edgeList, e);
  RETURN e
END CreateBasicBlockEdge;

(* --- SimpleLoop --- *)

PROCEDURE CreateSimpleLoop(bb: BasicBlock): SimpleLoop;
  VAR sl: SimpleLoop;
BEGIN
  NEW(sl);
  sl.parent := NIL;
  sl.isRoot := FALSE;
  sl.nestingLevel := 0;
  sl.basicBlocks := SOM.CreateSet(0);
  sl.children := SOM.CreateSet(0);
  IF bb # NIL THEN SOM.SetAdd(sl.basicBlocks, bb) END;
  RETURN sl
END CreateSimpleLoop;

PROCEDURE SetParent(me, parent: SimpleLoop);
BEGIN
  me.parent := parent;
  SOM.SetAdd(parent.children, me);
END SetParent;

PROCEDURE SetNestingLevel(me: SimpleLoop; level: INT32);
BEGIN
  me.nestingLevel := level;
  IF level = 0 THEN me.isRoot := TRUE END;
END SetNestingLevel;

(* --- UnionFindNode --- *)

PROCEDURE CreateUnionFindNode(): UnionFindNode;
  VAR n: UnionFindNode;
BEGIN
  NEW(n);
  n.parent := NIL; n.bb := NIL; n.loop := NIL; n.dfsNumber := 0;
  RETURN n
END CreateUnionFindNode;

PROCEDURE InitNode(n: UnionFindNode; bb: BasicBlock; dfsNumber: INT32);
BEGIN
  n.parent := n;
  n.bb := bb;
  n.dfsNumber := dfsNumber;
  n.loop := NIL;
END InitNode;

PROCEDURE FindSet(me: UnionFindNode): UnionFindNode;
  VAR nodeList: SOM.Vector; node: UnionFindNode; i: INT32;
BEGIN
  nodeList := SOM.CreateVector(0);
  node := me;
  WHILE node # node.parent DO
    IF node.parent # node.parent.parent THEN
      SOM.VectorAppend(nodeList, node);
    END;
    node := node.parent;
  END;
  FOR i := 0 TO SOM.VectorSize(nodeList) - 1 DO
    SOM.VectorAt(nodeList, i)(UnionFindNode).parent := me.parent;
  END;
  RETURN node
END FindSet;

(* --- LoopStructureGraph --- *)

PROCEDURE CreateLoopStructureGraph(): LoopStructureGraph;
  VAR lsg: LoopStructureGraph;
BEGIN
  NEW(lsg);
  lsg.loopCounter := 0;
  lsg.root := CreateSimpleLoop(NIL);
  SetNestingLevel(lsg.root, 0);
  INC(lsg.loopCounter);
  lsg.loops := SOM.CreateVector(0);
  SOM.VectorAppend(lsg.loops, lsg.root);
  RETURN lsg
END CreateLoopStructureGraph;

PROCEDURE LSGCreateNewLoop(lsg: LoopStructureGraph; bb: BasicBlock; isReducible: BOOLEAN): SimpleLoop;
  VAR loop: SimpleLoop;
BEGIN
  loop := CreateSimpleLoop(bb);
  INC(lsg.loopCounter);
  SOM.VectorAppend(lsg.loops, loop);
  RETURN loop
END LSGCreateNewLoop;

PROCEDURE CalculateNestingLevelRec(loop: SimpleLoop; depth: INT32);
  VAR i: INT32; child: SimpleLoop; nl: INT32;
BEGIN
  FOR i := 0 TO SOM.VectorSize(loop.children.items) - 1 DO
    child := SOM.VectorAt(loop.children.items, i)(SimpleLoop);
    CalculateNestingLevelRec(child, depth + 1);
    nl := loop.nestingLevel;
    IF 1 + child.nestingLevel > nl THEN nl := 1 + child.nestingLevel END;
    loop.nestingLevel := nl;
    IF nl = 0 THEN loop.isRoot := TRUE END;
  END;
END CalculateNestingLevelRec;

PROCEDURE CalculateNestingLevel(lsg: LoopStructureGraph);
  VAR i: INT32; loop: SimpleLoop;
BEGIN
  FOR i := 0 TO SOM.VectorSize(lsg.loops) - 1 DO
    loop := SOM.VectorAt(lsg.loops, i)(SimpleLoop);
    IF ~loop.isRoot & (loop.parent = NIL) THEN
      SetParent(loop, lsg.root);
    END;
  END;
  CalculateNestingLevelRec(lsg.root, 0);
END CalculateNestingLevel;

(* --- HavlakLoopFinder --- *)

PROCEDURE BasicBlockHash(obj: SOM.Object): INT32;
BEGIN
  RETURN obj(BasicBlock).name
END BasicBlockHash;

PROCEDURE CreateHavlakLoopFinder(cfg: ControlFlowGraph; lsg: LoopStructureGraph): HavlakLoopFinder;
  VAR h: HavlakLoopFinder;
BEGIN
  NEW(h);
  h.maxSize := 0;
  h.cfg := cfg;
  h.lsg := lsg;
  h.nonBackPreds := SOM.CreateVector(0);
  h.backPreds := SOM.CreateVector(0);
  h.number := SOM.CreateDictionary(BasicBlockHash);
  h.header := SOM.CreateIntVector(0);
  h.type := SOM.CreateIntVector(0);
  h.last := SOM.CreateIntVector(0);
  h.nodes := SOM.CreateVector(0);
  RETURN h
END CreateHavlakLoopFinder;

PROCEDURE IsAncestor(h: HavlakLoopFinder; w, v: INT32): BOOLEAN;
BEGIN
  RETURN (w <= v) & (v <= SOM.IntVectorAt(h.last, w))
END IsAncestor;

PROCEDURE GetNonBackPreds(vec: SOM.Vector; i: INT32): SOM.IntSet;
  VAR obj: SOM.Object; s: SOM.IntSet;
BEGIN
  obj := SOM.VectorAt(vec, i);
  IF obj = NIL THEN
    s := SOM.CreateIntSet(0);
    SOM.VectorAtPut(vec, i, s);
    RETURN s
  ELSE
    RETURN obj(SOM.IntSet)
  END
END GetNonBackPreds;

PROCEDURE GetBackPreds(vec: SOM.Vector; i: INT32): SOM.IntVector;
  VAR obj: SOM.Object; v: SOM.IntVector;
BEGIN
  obj := SOM.VectorAt(vec, i);
  IF obj = NIL THEN
    v := SOM.CreateIntVector(0);
    SOM.VectorAtPut(vec, i, v);
    RETURN v
  ELSE
    RETURN obj(SOM.IntVector)
  END
END GetBackPreds;

PROCEDURE DoDFS(h: HavlakLoopFinder; currentNode: BasicBlock; current: INT32): INT32;
  VAR lastId, i: INT32; target: BasicBlock; nObj: SOM.Object; n: INT32;
      node: UnionFindNode;
BEGIN
  node := SOM.VectorAt(h.nodes, current)(UnionFindNode);
  InitNode(node, currentNode, current);
  SOM.DictionaryAtPut(h.number, currentNode, SOM.CreateIntObject(current));
  lastId := current;
  FOR i := 0 TO SOM.VectorSize(currentNode.outEdges) - 1 DO
    target := SOM.VectorAt(currentNode.outEdges, i)(BasicBlock);
    nObj := SOM.DictionaryAt(h.number, target);
    IF nObj # NIL THEN
      n := nObj(SOM.IntObject).value;
      IF n = UNVISITED THEN
        lastId := DoDFS(h, target, lastId + 1);
      END;
    END;
  END;
  SOM.IntVectorAtPut(h.last, current, lastId);
  RETURN lastId
END DoDFS;

PROCEDURE InitAllNodes(h: HavlakLoopFinder);
  VAR i: INT32; bb: BasicBlock;
BEGIN
  FOR i := 0 TO SOM.VectorSize(h.cfg.basicBlockMap) - 1 DO
    bb := SOM.VectorAt(h.cfg.basicBlockMap, i)(BasicBlock);
    SOM.DictionaryAtPut(h.number, bb, SOM.CreateIntObject(UNVISITED));
  END;
  DoDFS(h, h.cfg.startNode, 0);
END InitAllNodes;

PROCEDURE ProcessEdges(h: HavlakLoopFinder; nodeW: BasicBlock; w: INT32);
  VAR i: INT32; nodeV: BasicBlock; nObj: SOM.Object; v: INT32;
      bp: SOM.IntVector;
BEGIN
  IF SOM.VectorSize(nodeW.inEdges) > 0 THEN
    FOR i := 0 TO SOM.VectorSize(nodeW.inEdges) - 1 DO
      nodeV := SOM.VectorAt(nodeW.inEdges, i)(BasicBlock);
      nObj := SOM.DictionaryAt(h.number, nodeV);
      IF nObj # NIL THEN
        v := nObj(SOM.IntObject).value;
        IF v # UNVISITED THEN
          IF IsAncestor(h, w, v) THEN
            bp := GetBackPreds(h.backPreds, w);
            SOM.IntVectorAppend(bp, v);
          ELSE
            SOM.IntSetAdd(GetNonBackPreds(h.nonBackPreds, w), v);
          END;
        END;
      END;
    END;
  END;
END ProcessEdges;

PROCEDURE IdentifyEdges(h: HavlakLoopFinder; size: INT32);
  VAR w: INT32; nodeW: BasicBlock; node: UnionFindNode;
BEGIN
  FOR w := 0 TO size - 1 DO
    SOM.IntVectorAtPut(h.header, w, 0);
    SOM.IntVectorAtPut(h.type, w, BBNONHEADER);
    node := SOM.VectorAt(h.nodes, w)(UnionFindNode);
    nodeW := node.bb;
    IF nodeW = NIL THEN
      SOM.IntVectorAtPut(h.type, w, BBDEAD);
    ELSE
      ProcessEdges(h, nodeW, w);
    END;
  END;
END IdentifyEdges;

PROCEDURE NodePoolContains(nodePool: SOM.Vector; ydash: UnionFindNode): BOOLEAN;
  VAR i: INT32;
BEGIN
  FOR i := 0 TO SOM.VectorSize(nodePool) - 1 DO
    IF SOM.VectorAt(nodePool, i) = ydash THEN RETURN TRUE END;
  END;
  RETURN FALSE
END NodePoolContains;

PROCEDURE StepEProcessNonBackPreds(h: HavlakLoopFinder; w: INT32;
                                    nodePool, workList: SOM.Vector; x: UnionFindNode);
  VAR nbpObj: SOM.Object; nbp: SOM.IntSet;
      i: INT32; iter: INT32; y, ydash: UnionFindNode;
BEGIN
  nbpObj := SOM.VectorAt(h.nonBackPreds, x.dfsNumber);
  IF nbpObj # NIL THEN
    nbp := nbpObj(SOM.IntSet);
    FOR i := 0 TO SOM.IntVectorSize(nbp.items) - 1 DO
      iter := SOM.IntVectorAt(nbp.items, i);
      y := SOM.VectorAt(h.nodes, iter)(UnionFindNode);
      ydash := FindSet(y);
      IF ~IsAncestor(h, w, ydash.dfsNumber) THEN
        SOM.IntVectorAtPut(h.type, w, BBIRREDUCIBLE);
        SOM.IntSetAdd(GetNonBackPreds(h.nonBackPreds, w), ydash.dfsNumber);
      ELSE
        IF ydash.dfsNumber # w THEN
          IF ~NodePoolContains(nodePool, ydash) THEN
            SOM.VectorAppend(workList, ydash);
            SOM.VectorAppend(nodePool, ydash);
          END;
        END;
      END;
    END;
  END;
END StepEProcessNonBackPreds;

PROCEDURE StepD(h: HavlakLoopFinder; w: INT32; nodePool: SOM.Vector);
  VAR bpObj: SOM.Object; bp: SOM.IntVector;
      i, v: INT32; tmp: UnionFindNode;
BEGIN
  bpObj := SOM.VectorAt(h.backPreds, w);
  IF bpObj # NIL THEN
    bp := bpObj(SOM.IntVector);
    FOR i := 0 TO SOM.IntVectorSize(bp) - 1 DO
      v := SOM.IntVectorAt(bp, i);
      IF v # w THEN
        tmp := FindSet(SOM.VectorAt(h.nodes, v)(UnionFindNode));
        SOM.VectorAppend(nodePool, tmp);
      ELSE
        SOM.IntVectorAtPut(h.type, w, BBSELF);
      END;
    END;
  END;
END StepD;

PROCEDURE SetLoopAttributes(h: HavlakLoopFinder; w: INT32; nodePool: SOM.Vector; loop: SimpleLoop);
  VAR i: INT32; node: UnionFindNode;
BEGIN
  SOM.VectorAt(h.nodes, w)(UnionFindNode).loop := loop;
  FOR i := 0 TO SOM.VectorSize(nodePool) - 1 DO
    node := SOM.VectorAt(nodePool, i)(UnionFindNode);
    SOM.IntVectorAtPut(h.header, node.dfsNumber, w);
    node.parent := SOM.VectorAt(h.nodes, w)(UnionFindNode);
    IF node.loop # NIL THEN
      SetParent(node.loop, loop);
    ELSE
      SOM.SetAdd(loop.basicBlocks, node.bb);
    END;
  END;
END SetLoopAttributes;

PROCEDURE FindLoops(h: HavlakLoopFinder);
  VAR size, w, i: INT32;
      nodePool, workList: SOM.Vector;
      nodeW: BasicBlock; x: UnionFindNode;
      nonBackSize: INT32; nbpObj: SOM.Object;
      loop: SimpleLoop;
BEGIN
  IF h.cfg.startNode = NIL THEN RETURN END;
  size := SOM.VectorSize(h.cfg.basicBlockMap);

  SOM.VectorRemoveAll(h.nonBackPreds);
  SOM.VectorRemoveAll(h.backPreds);
  SOM.DictionaryRemoveAll(h.number);

  IF size > h.maxSize THEN
    SOM.IntVectorExpand(h.header, size);
    SOM.IntVectorExpand(h.type, size);
    SOM.IntVectorExpand(h.last, size);
    SOM.VectorExpand(h.nodes, size);
    SOM.VectorExpand(h.backPreds, size);
    SOM.VectorExpand(h.nonBackPreds, size);
    h.maxSize := size;
  END;

  FOR i := 0 TO size - 1 DO
    SOM.VectorAtPut(h.nodes, i, CreateUnionFindNode());
  END;

  InitAllNodes(h);
  IdentifyEdges(h, size);

  SOM.IntVectorAtPut(h.header, 0, 0);

  w := size - 1;
  WHILE w >= 0 DO
    nodePool := SOM.CreateVector(0);
    nodeW := SOM.VectorAt(h.nodes, w)(UnionFindNode).bb;
    IF nodeW # NIL THEN
      StepD(h, w, nodePool);

      workList := SOM.CreateVector(0);
      FOR i := 0 TO SOM.VectorSize(nodePool) - 1 DO
        SOM.VectorAppend(workList, SOM.VectorAt(nodePool, i));
      END;

      IF SOM.VectorSize(nodePool) # 0 THEN
        SOM.IntVectorAtPut(h.type, w, BBREDUCIBLE);
      END;

      WHILE ~SOM.VectorIsEmpty(workList) DO
        x := SOM.VectorRemoveFirst(workList)(UnionFindNode);
        nonBackSize := 0;
        nbpObj := SOM.VectorAt(h.nonBackPreds, x.dfsNumber);
        IF nbpObj # NIL THEN
          nonBackSize := SOM.IntSetSize(nbpObj(SOM.IntSet));
        END;
        IF nonBackSize > MAXNONBACKPREDS THEN
          RETURN
        END;
        StepEProcessNonBackPreds(h, w, nodePool, workList, x);
      END;

      IF (SOM.VectorSize(nodePool) > 0) OR (SOM.IntVectorAt(h.type, w) = BBSELF) THEN
        loop := LSGCreateNewLoop(h.lsg, nodeW, SOM.IntVectorAt(h.type, w) # BBIRREDUCIBLE);
        SetLoopAttributes(h, w, nodePool, loop);
      END;
    END;
    DEC(w);
  END;
END FindLoops;

(* --- LoopTesterApp --- *)

PROCEDURE CreateLoopTesterApp(): LoopTesterApp;
  VAR app: LoopTesterApp;
BEGIN
  NEW(app);
  app.cfg := CreateControlFlowGraph();
  app.lsg := CreateLoopStructureGraph();
  CFGCreateNode(app.cfg, 0);
  RETURN app
END CreateLoopTesterApp;

PROCEDURE BuildDiamond(app: LoopTesterApp; start: INT32): INT32;
  VAR bb0: INT32; e: BasicBlockEdge;
BEGIN
  bb0 := start;
  e := CreateBasicBlockEdge(app.cfg, bb0, bb0 + 1);
  e := CreateBasicBlockEdge(app.cfg, bb0, bb0 + 2);
  e := CreateBasicBlockEdge(app.cfg, bb0 + 1, bb0 + 3);
  e := CreateBasicBlockEdge(app.cfg, bb0 + 2, bb0 + 3);
  RETURN bb0 + 3
END BuildDiamond;

PROCEDURE BuildConnect(app: LoopTesterApp; start, End: INT32);
  VAR e: BasicBlockEdge;
BEGIN
  e := CreateBasicBlockEdge(app.cfg, start, End);
END BuildConnect;

PROCEDURE BuildStraight(app: LoopTesterApp; start, n: INT32): INT32;
  VAR i: INT32;
BEGIN
  FOR i := 0 TO n - 1 DO
    BuildConnect(app, start + i, start + i + 1);
  END;
  RETURN start + n
END BuildStraight;

PROCEDURE BuildBaseLoop(app: LoopTesterApp; from: INT32): INT32;
  VAR header, diamond1, d11, diamond2, footer: INT32;
BEGIN
  header := BuildStraight(app, from, 1);
  diamond1 := BuildDiamond(app, header);
  d11 := BuildStraight(app, diamond1, 1);
  diamond2 := BuildDiamond(app, d11);
  footer := BuildStraight(app, diamond2, 1);
  BuildConnect(app, diamond2, d11);
  BuildConnect(app, diamond1, header);
  BuildConnect(app, footer, from);
  footer := BuildStraight(app, footer, 1);
  RETURN footer
END BuildBaseLoop;

PROCEDURE ConstructSimpleCFG(app: LoopTesterApp);
  VAR bb: BasicBlock; e: BasicBlockEdge;
BEGIN
  bb := CFGCreateNode(app.cfg, 0);
  BuildBaseLoop(app, 0);
  bb := CFGCreateNode(app.cfg, 1);
  e := CreateBasicBlockEdge(app.cfg, 0, 2);
END ConstructSimpleCFG;

PROCEDURE AppFindLoops(app: LoopTesterApp; loopStructure: LoopStructureGraph);
  VAR finder: HavlakLoopFinder;
BEGIN
  finder := CreateHavlakLoopFinder(app.cfg, loopStructure);
  FindLoops(finder);
END AppFindLoops;

PROCEDURE AddDummyLoops(app: LoopTesterApp; numDummyLoops: INT32);
  VAR i: INT32;
BEGIN
  FOR i := 0 TO numDummyLoops - 1 DO
    AppFindLoops(app, app.lsg);
  END;
END AddDummyLoops;

PROCEDURE ConstructCFG(app: LoopTesterApp; parLoops, pparLoops, ppparLoops: INT32);
  VAR n, i, j, top, bottom: INT32; bb: BasicBlock;
BEGIN
  n := 2;
  FOR i := 0 TO parLoops - 1 DO
    bb := CFGCreateNode(app.cfg, n + 1);
    BuildConnect(app, 2, n + 1);
    INC(n);
    FOR j := 0 TO pparLoops - 1 DO
      top := n;
      n := BuildStraight(app, n, 1);
      FOR bottom := 0 TO ppparLoops - 1 DO
        n := BuildBaseLoop(app, n);
      END;
      bottom := BuildStraight(app, n, 1);
      BuildConnect(app, n, top);
      n := bottom;
    END;
    BuildConnect(app, n, 1);
  END;
END ConstructCFG;

PROCEDURE AppMain(app: LoopTesterApp; numDummyLoops, findLoopIterations,
                  parLoops, pparLoops, ppparLoops: INT32);
  VAR i: INT32; l: LoopStructureGraph;
BEGIN
  ConstructSimpleCFG(app);
  AddDummyLoops(app, numDummyLoops);
  ConstructCFG(app, parLoops, pparLoops, ppparLoops);

  AppFindLoops(app, app.lsg);
  FOR i := 0 TO findLoopIterations - 1 DO
    l := CreateLoopStructureGraph();
    AppFindLoops(app, l);
  END;

  CalculateNestingLevel(app.lsg);
  NumLoops := SOM.VectorSize(app.lsg.loops);
  NumNodes := SOM.VectorSize(app.cfg.basicBlockMap);
END AppMain;

(* --- Benchmark Interface --- *)

PROCEDURE HavlakVerifyResult(a, b, innerIterations: INT32): BOOLEAN;
BEGIN
  IF innerIterations = 15000 THEN RETURN (a = 46602) & (b = 5213) END;
  IF innerIterations =  1500 THEN RETURN (a =  6102) & (b = 5213) END;
  IF innerIterations =   150 THEN RETURN (a =  2052) & (b = 5213) END;
  IF innerIterations =    15 THEN RETURN (a =  1647) & (b = 5213) END;
  IF innerIterations =     1 THEN RETURN (a =  1605) & (b = 5213) END;
  Out.String("No verification result for "); Out.Int(innerIterations, 0); Out.Ln;
  Out.String("Result is: "); Out.Int(a, 0); Out.String(", "); Out.Int(b, 0); Out.Ln;
  RETURN FALSE
END HavlakVerifyResult;

PROCEDURE InnerBenchmarkLoop*(b: Benchmark.Benchmark; innerIterations: INTEGER): BOOLEAN;
  VAR app: LoopTesterApp;
BEGIN
  app := CreateLoopTesterApp();
  AppMain(app, innerIterations, 50, 10, 10, 5);
  RETURN HavlakVerifyResult(NumLoops, NumNodes, innerIterations)
END InnerBenchmarkLoop;

PROCEDURE DoBenchmark*(b: Benchmark.Benchmark): SOM.Object;
BEGIN
  HALT(99); RETURN NIL
END DoBenchmark;

PROCEDURE VerifyResult*(b: Benchmark.Benchmark; result: SOM.Object): BOOLEAN;
BEGIN
  HALT(99); RETURN FALSE
END VerifyResult;

PROCEDURE Create*(): Havlak;
  VAR h: Havlak;
BEGIN
  NEW(h);
  h.InnerBenchmarkLoop := InnerBenchmarkLoop;
  h.DoBenchmark := DoBenchmark;
  h.VerifyResult := VerifyResult;
  RETURN h
END Create;

END Havlak.
