/* This code is derived from the SOM benchmarks, see AUTHORS.md file.
 *
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
 * THE SOFTWARE.
 */

#include "RedBlackTree.h"
#include <stdbool.h>
#include <stdlib.h>
#include <assert.h>
#include <memory.h>

enum Color {
    RED, BLACK
};

typedef struct Node Node;

struct Node {
    Bytes key;
    Bytes value;
    Node* left;
    Node* right;
    Node* parent;
    enum Color color;
};

static Node* Node_create(const Bytes key, const Bytes value)
{
    Node* me = malloc(sizeof(Node));
    me->key = key; // owns
    me->value = value; // owns
    me->left = 0;
    me->right = 0;
    me->parent = 0;
    me->color = RED;
    return me;
}

static void Node_dispose(Node* me)
{
    if( me->left )
        Node_dispose(me->left);
    if( me->right )
        Node_dispose(me->right);
    if( me->key )
        free(me->key);
    if( me->value )
        free(me->value);
    free(me);
}

static Node* Node_treeMinimum(Node* x) {
    Node* current = x;
    while (current->left != 0) {
        current = current->left;
    }
    return current;
}

static Node* Node_successor(Node* me) {
    Node* x = me;
    if (x->right != 0) {
        return Node_treeMinimum(x->right);
    }
    Node* y = x->parent;
    while (y != 0 && x == y->right) {
        x = y;
        y = y->parent;
    }
    return y;
}

struct RedBlackTree {
    Node* root;
    bool isNewEntry;
    Node* newNode;
    Bytes oldValue;
    int keySize, valueSize;
    RedBlackTree_compare compare;
};

RedBlackTree* RedBlackTree_create(int keySize, int valueSize, RedBlackTree_compare f)
{
    RedBlackTree* me = malloc(sizeof(RedBlackTree));
    me->root = 0;
    me->isNewEntry = false;
    me->newNode = 0;
    me->oldValue = 0;
    me->keySize = keySize;
    assert( keySize > 0 );
    me->valueSize = valueSize;
    assert( valueSize > 0 );
    me->compare = f;
    assert(f != 0);
    return me;
}

void RedBlackTree_dispose(RedBlackTree* me)
{
    if( me->root )
        Node_dispose(me->root);
    if( me->oldValue )
        free(me->oldValue);
    free(me);
}

static Node* findNode(RedBlackTree* me, const Bytes key) {
    Node* current = me->root;
    while (current != 0) {
        int comparisonResult = me->compare(key, current->key);
        if (comparisonResult == 0) {
            return current;
        }
        if (comparisonResult < 0) {
            current = current->left;
        } else {
            current = current->right;
        }
    }
    return 0;
}

static void InsertResult(RedBlackTree* me, bool isNewEntry, Node* newNode, Bytes oldValue) {
    me->isNewEntry = isNewEntry;
    me->newNode = newNode;
    if( me->oldValue )
        free(me->oldValue);
    me->oldValue = oldValue;
}

static void treeInsert(RedBlackTree* me, const Bytes key, const Bytes value) {
    Node* y = 0;
    Node* x = me->root;

    Bytes v = malloc(me->valueSize);
    memcpy(v, value, me->valueSize);

    while (x != 0) {
        y = x;
        const int comparisonResult = me->compare(key, x->key);
        if (comparisonResult < 0) {
            x = x->left;
        } else if (comparisonResult > 0) {
            x = x->right;
        } else {
            Bytes oldValue = x->value;
            x->value = v;
            InsertResult(me, false, 0, oldValue);
            return;
        }
    }

    Bytes k = malloc(me->keySize);
    memcpy(k, key, me->keySize);

    Node* z = Node_create(k, v);
    z->parent = y;
    if (y == 0) {
        me->root = z;
    } else {
        if ( me->compare(key, y->key) < 0) {
            y->left = z;
        } else {
            y->right = z;
        }
    }
    InsertResult(me, true, z, 0);
}

static Node* leftRotate(RedBlackTree* me, Node* x) {
    Node* y = x->right;

    // Turn y's left subtree into x's right subtree.
    x->right = y->left;
    if (y->left != 0) {
        y->left->parent = x;
    }

    // Link x's parent to y.
    y->parent = x->parent;
    if (x->parent == 0) {
        me->root = y;
    } else {
        if (x == x->parent->left) {
            x->parent->left = y;
        } else {
            x->parent->right = y;
        }
    }

    // Put x on y's left.
    y->left = x;
    x->parent = y;

    return y;
}

Node* rightRotate(RedBlackTree* me, Node* y) {
    Node* x = y->left;

    // Turn x's right subtree into y's left subtree.
    y->left = x->right;
    if (x->right != 0) {
        x->right->parent = y;
    }

    // Link y's parent to x;
    x->parent = y->parent;
    if (y->parent == 0) {
        me->root = x;
    } else {
        if (y == y->parent->left) {
            y->parent->left = x;
        } else {
            y->parent->right = x;
        }
    }

    x->right = y;
    y->parent = x;

    return x;
}

static void removeFixup(RedBlackTree* me, Node* x, Node* xParent) {
    while (x != me->root && (x == 0 || x->color == BLACK)) {
        if (x == xParent->left) {
            // Note: the text points out that w cannot be null. The reason is not obvious from
            // simply looking at the code; it comes about from the properties of the red-black
            // tree.
            Node* w = xParent->right;
            if (w->color == RED) {
                // Case 1
                w->color = BLACK;
                xParent->color = RED;
                leftRotate(me, xParent);
                w = xParent->right;
            }
            if ((w->left == 0 || w->left->color == BLACK)
                    && (w->right == 0 || w->right->color == BLACK)) {
                // Case 2
                w->color = RED;
                x = xParent;
                xParent = x->parent;
            } else {
                if (w->right == 0 || w->right->color == BLACK) {
                    // Case 3
                    w->left->color = BLACK;
                    w->color = RED;
                    rightRotate(me, w);
                    w = xParent->right;
                }
                // Case 4
                w->color = xParent->color;
                xParent->color = BLACK;
                if (w->right != 0) {
                    w->right->color = BLACK;
                }
                leftRotate(me, xParent);
                x = me->root;
                xParent = x->parent;
            }
        } else {
            // Same as "then" clause with "right" and "left" exchanged.
            Node* w = xParent->left;
            if (w->color == RED) {
                // Case 1
                w->color = BLACK;
                xParent->color = RED;
                rightRotate(me, xParent);
                w = xParent->left;
            }
            if ((w->right == 0 || w->right->color == BLACK)
                    && (w->left == 0 || w->left->color == BLACK)) {
                // Case 2
                w->color = RED;
                x = xParent;
                xParent = x->parent;
            } else {
                if (w->left == 0 || w->left->color == BLACK) {
                    // Case 3
                    w->right->color = BLACK;
                    w->color = RED;
                    leftRotate(me, w);
                    w = xParent->left;
                }
                // Case 4
                w->color = xParent->color;
                xParent->color = BLACK;
                if (w->left != 0) {
                    w->left->color = BLACK;
                }
                rightRotate(me, xParent);
                x = me->root;
                xParent = x->parent;
            }
        }
    }
    if (x != 0) {
        x->color = BLACK;
    }
}

Bytes RedBlackTree_put(RedBlackTree* me, const Bytes key, const Bytes value)
{
    treeInsert(me, key, value);
    if (!me->isNewEntry) {
        return me->oldValue;
    }
    Node* x = me->newNode;

    while (x != me->root && x->parent->color == RED) {
        if (x->parent == x->parent->parent->left) {
            Node* y = x->parent->parent->right;
            if (y != 0 && y->color == RED) {
                // Case 1
                x->parent->color = BLACK;
                y->color = BLACK;
                x->parent->parent->color = RED;
                x = x->parent->parent;
            } else {
                if (x == x->parent->right) {
                    // Case 2
                    x = x->parent;
                    leftRotate(me, x);
                }
                // Case 3
                x->parent->color = BLACK;
                x->parent->parent->color = RED;
                rightRotate(me, x->parent->parent);
            }
        } else {
            // Same as "then" clause with "right" and "left" exchanged.
            Node* y = x->parent->parent->left;
            if (y != 0 && y->color == RED) {
                // Case 1
                x->parent->color = BLACK;
                y->color = BLACK;
                x->parent->parent->color = RED;
                x = x->parent->parent;
            } else {
                if (x == x->parent->left) {
                    // Case 2
                    x = x->parent;
                    rightRotate(me, x);
                }
                // Case 3
                x->parent->color = BLACK;
                x->parent->parent->color = RED;
                leftRotate(me, x->parent->parent);
            }
        }
    }

    me->root->color = BLACK;
    return 0;
}

Bytes RedBlackTree_remove(RedBlackTree* me, const Bytes key)
{
    // NOTE: apparently we don't get here during CD, otherwise we
    // should take care of Node dealloc
    Node* z = findNode(me, key);
    if (z == 0) {
        return 0;
    }

    // Y is the node to be unlinked from the tree.
    Node* y;
    if (z->left == 0 || z->right == 0) {
        y = z;
    } else {
        y = Node_successor(z);
    }

    // Y is guaranteed to be non-null at this point.
    Node* x;
    if (y->left != 0) {
        x = y->left;
    } else {
        x = y->right;
    }

    // X is the child of y which might potentially replace y in the tree. X might be null at
    // this point.
    Node* xParent;
    if (x != 0) {
        x->parent = y->parent;
        xParent = x->parent;
    } else {
        xParent = y->parent;
    }
    if (y->parent == 0) {
        me->root = x;
    } else {
        if (y == y->parent->left) {
            y->parent->left = x;
        } else {
            y->parent->right = x;
        }
    }

    if (y != z) {
        if (y->color == BLACK) {
            removeFixup(me, x, xParent);
        }

        y->parent = z->parent;
        y->color = z->color;
        y->left = z->left;
        y->right = z->right;

        if (z->left != 0) {
            z->left->parent = y;
        }
        if (z->right != 0) {
            z->right->parent = y;
        }
        if (z->parent != 0) {
            if (z->parent->left == z) {
                z->parent->left = y;
            } else {
                z->parent->right = y;
            }
        } else {
            me->root = y;
        }
    } else if (y->color == BLACK) {
        removeFixup(me, x, xParent);
    }

    return z->value;
}

Bytes RedBlackTree_get(RedBlackTree* me, const Bytes key)
{
    Node* node = findNode(me, key);
    if (node == 0) {
        return 0;
    }
    return node->value;
}

void RedBlackTree_forEach(RedBlackTree* me, RedBlackTree_iter iter, void* data) {
    if (me->root == 0) {
        return;
    }
    Node* current = Node_treeMinimum(me->root);
    while (current != 0) {
        iter(current->key, current->value, data);
        current = Node_successor(current);
    }
}

