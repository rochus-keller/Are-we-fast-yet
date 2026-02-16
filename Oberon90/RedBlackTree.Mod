(* This code is derived from the SOM benchmarks, see AUTHORS.md file.
 *
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

MODULE RedBlackTree;

IMPORT SOM;

CONST
  RED = 0; BLACK = 1;

TYPE
  CompareFunc* = PROCEDURE(a, b: SOM.Object): INTEGER;
  ForEachFunc* = PROCEDURE(key, value: SOM.Object; data: SOM.Object);

  Node = POINTER TO NodeDesc;
  NodeDesc = RECORD
    key, value: SOM.Object;
    left, right, parent: Node;
    color: INTEGER;
  END;

  Tree* = POINTER TO TreeDesc;
  TreeDesc* = RECORD (SOM.ObjectDesc)
    root: Node;
    compare: CompareFunc;
  END;

PROCEDURE CreateNode(key, value: SOM.Object): Node;
  VAR n: Node;
BEGIN
  NEW(n);
  n.key := key; n.value := value;
  n.left := NIL; n.right := NIL; n.parent := NIL;
  n.color := RED;
  RETURN n
END CreateNode;

PROCEDURE TreeMinimum(x: Node): Node;
  VAR current: Node;
BEGIN
  current := x;
  WHILE current.left # NIL DO current := current.left END;
  RETURN current
END TreeMinimum;

PROCEDURE Successor(me: Node): Node;
  VAR x, y: Node;
BEGIN
  x := me;
  IF x.right # NIL THEN RETURN TreeMinimum(x.right) END;
  y := x.parent;
  WHILE (y # NIL) & (x = y.right) DO
    x := y; y := y.parent;
  END;
  RETURN y
END Successor;

PROCEDURE FindNode(t: Tree; key: SOM.Object): Node;
  VAR current: Node; cmp: INTEGER;
BEGIN
  current := t.root;
  WHILE current # NIL DO
    cmp := t.compare(key, current.key);
    IF cmp = 0 THEN RETURN current
    ELSIF cmp < 0 THEN current := current.left
    ELSE current := current.right
    END;
  END;
  RETURN NIL
END FindNode;

PROCEDURE LeftRotate(t: Tree; x: Node): Node;
  VAR y: Node;
BEGIN
  y := x.right;
  x.right := y.left;
  IF y.left # NIL THEN y.left.parent := x END;
  y.parent := x.parent;
  IF x.parent = NIL THEN t.root := y
  ELSIF x = x.parent.left THEN x.parent.left := y
  ELSE x.parent.right := y
  END;
  y.left := x;
  x.parent := y;
  RETURN y
END LeftRotate;

PROCEDURE RightRotate(t: Tree; y: Node): Node;
  VAR x: Node;
BEGIN
  x := y.left;
  y.left := x.right;
  IF x.right # NIL THEN x.right.parent := y END;
  x.parent := y.parent;
  IF y.parent = NIL THEN t.root := x
  ELSIF y = y.parent.left THEN y.parent.left := x
  ELSE y.parent.right := x
  END;
  x.right := y;
  y.parent := x;
  RETURN x
END RightRotate;

PROCEDURE TreeInsert(t: Tree; key, value: SOM.Object; VAR isNew: BOOLEAN; VAR newNode: Node; VAR oldValue: SOM.Object);
  VAR y, x: Node; cmp: INTEGER; z: Node;
BEGIN
  y := NIL; x := t.root;
  WHILE x # NIL DO
    y := x;
    cmp := t.compare(key, x.key);
    IF cmp < 0 THEN x := x.left
    ELSIF cmp > 0 THEN x := x.right
    ELSE
      oldValue := x.value;
      x.value := value;
      isNew := FALSE; newNode := NIL;
      RETURN
    END;
  END;
  z := CreateNode(key, value);
  z.parent := y;
  IF y = NIL THEN t.root := z
  ELSIF t.compare(key, y.key) < 0 THEN y.left := z
  ELSE y.right := z
  END;
  isNew := TRUE; newNode := z; oldValue := NIL;
END TreeInsert;

PROCEDURE RemoveFixup(t: Tree; x, xParent: Node);
  VAR w: Node; xP: Node;
BEGIN
  xP := xParent;
  WHILE (x # t.root) & ((x = NIL) OR (x.color = BLACK)) DO
    IF x = xP.left THEN
      w := xP.right;
      IF w.color = RED THEN
        w.color := BLACK; xP.color := RED;
        LeftRotate(t, xP);
        w := xP.right;
      END;
      IF ((w.left = NIL) OR (w.left.color = BLACK)) & ((w.right = NIL) OR (w.right.color = BLACK)) THEN
        w.color := RED; x := xP; xP := x.parent;
      ELSE
        IF (w.right = NIL) OR (w.right.color = BLACK) THEN
          w.left.color := BLACK; w.color := RED;
          RightRotate(t, w);
          w := xP.right;
        END;
        w.color := xP.color; xP.color := BLACK;
        IF w.right # NIL THEN w.right.color := BLACK END;
        LeftRotate(t, xP);
        x := t.root; xP := x.parent;
      END;
    ELSE
      w := xP.left;
      IF w.color = RED THEN
        w.color := BLACK; xP.color := RED;
        RightRotate(t, xP);
        w := xP.left;
      END;
      IF ((w.right = NIL) OR (w.right.color = BLACK)) & ((w.left = NIL) OR (w.left.color = BLACK)) THEN
        w.color := RED; x := xP; xP := x.parent;
      ELSE
        IF (w.left = NIL) OR (w.left.color = BLACK) THEN
          w.right.color := BLACK; w.color := RED;
          LeftRotate(t, w);
          w := xP.left;
        END;
        w.color := xP.color; xP.color := BLACK;
        IF w.left # NIL THEN w.left.color := BLACK END;
        RightRotate(t, xP);
        x := t.root; xP := x.parent;
      END;
    END;
  END;
  IF x # NIL THEN x.color := BLACK END;
END RemoveFixup;

PROCEDURE Create*(cmp: CompareFunc): Tree;
  VAR t: Tree;
BEGIN
  NEW(t); t.root := NIL; t.compare := cmp;
  RETURN t
END Create;

PROCEDURE Put*(t: Tree; key, value: SOM.Object): SOM.Object;
  VAR isNew: BOOLEAN; newN: Node; oldVal: SOM.Object;
      x, y: Node;
BEGIN
  TreeInsert(t, key, value, isNew, newN, oldVal);
  IF ~isNew THEN RETURN oldVal END;
  x := newN;
  WHILE (x # t.root) & (x.parent.color = RED) DO
    IF x.parent = x.parent.parent.left THEN
      y := x.parent.parent.right;
      IF (y # NIL) & (y.color = RED) THEN
        x.parent.color := BLACK; y.color := BLACK;
        x.parent.parent.color := RED;
        x := x.parent.parent;
      ELSE
        IF x = x.parent.right THEN x := x.parent; LeftRotate(t, x) END;
        x.parent.color := BLACK;
        x.parent.parent.color := RED;
        RightRotate(t, x.parent.parent);
      END;
    ELSE
      y := x.parent.parent.left;
      IF (y # NIL) & (y.color = RED) THEN
        x.parent.color := BLACK; y.color := BLACK;
        x.parent.parent.color := RED;
        x := x.parent.parent;
      ELSE
        IF x = x.parent.left THEN x := x.parent; RightRotate(t, x) END;
        x.parent.color := BLACK;
        x.parent.parent.color := RED;
        LeftRotate(t, x.parent.parent);
      END;
    END;
  END;
  t.root.color := BLACK;
  RETURN NIL
END Put;

PROCEDURE Get*(t: Tree; key: SOM.Object): SOM.Object;
  VAR n: Node;
BEGIN
  n := FindNode(t, key);
  IF n = NIL THEN RETURN NIL END;
  RETURN n.value
END Get;

PROCEDURE Remove*(t: Tree; key: SOM.Object): SOM.Object;
  VAR z, y, x: Node; xParent: Node; result: SOM.Object;
BEGIN
  z := FindNode(t, key);
  IF z = NIL THEN RETURN NIL END;
  IF (z.left = NIL) OR (z.right = NIL) THEN y := z
  ELSE y := Successor(z)
  END;
  IF y.left # NIL THEN x := y.left ELSE x := y.right END;
  IF x # NIL THEN
    x.parent := y.parent; xParent := x.parent;
  ELSE
    xParent := y.parent;
  END;
  IF y.parent = NIL THEN t.root := x
  ELSIF y = y.parent.left THEN y.parent.left := x
  ELSE y.parent.right := x
  END;
  IF y # z THEN
    IF y.color = BLACK THEN RemoveFixup(t, x, xParent) END;
    y.parent := z.parent; y.color := z.color;
    y.left := z.left; y.right := z.right;
    IF z.left # NIL THEN z.left.parent := y END;
    IF z.right # NIL THEN z.right.parent := y END;
    IF z.parent # NIL THEN
      IF z.parent.left = z THEN z.parent.left := y
      ELSE z.parent.right := y
      END;
    ELSE t.root := y
    END;
  ELSIF y.color = BLACK THEN
    RemoveFixup(t, x, xParent);
  END;
  RETURN z.value
END Remove;

PROCEDURE ForEach*(t: Tree; iter: ForEachFunc; data: SOM.Object);
  VAR current: Node;
BEGIN
  IF t.root = NIL THEN RETURN END;
  current := TreeMinimum(t.root);
  WHILE current # NIL DO
    iter(current.key, current.value, data);
    current := Successor(current);
  END;
END ForEach;

END RedBlackTree.
