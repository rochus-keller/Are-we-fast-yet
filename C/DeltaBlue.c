/* Copyright (c) 2024 Rochus Keller <me@rochus-keller.ch> (for C99 migration)
 *
 * This benchmark is derived from Mario Wolczko's Java and Smalltalk version of
 * DeltaBlue.
 *
 * It is modified to use the SOM class library and Java 8 features.
 * License details:
 *   http://web.archive.org/web/20050825101121/http://www.sunlabs.com/people/mario/java_benchmarking/index.html
 */

#include "DeltaBlue.h"
#include "som/Dictionary.h"
#include <stdlib.h>
#include <assert.h>

typedef struct Sym Sym;
typedef struct Strength Strength;
typedef struct Planner Planner;
typedef struct Variable Variable;
typedef struct AbstractConstraint AbstractConstraint;
typedef struct Plan Plan;
typedef union Constraint Constraint;

struct Sym {
    int hash;
};

static Sym* Sym_create(int hash) {
    Sym* me = malloc(sizeof(Sym));
    me->hash = hash;
    return me;
}

static int Sym_hash(const Bytes data) {
    Sym* me = *(Sym**)data;
    return me->hash;
}

static Sym* ABSOLUTE_STRONGEST;
static Sym* REQUIRED;
static Sym* STRONG_PREFERRED;
static Sym* PREFERRED;
static Sym* STRONG_DEFAULT;
static Sym* DEFAULT;
static Sym* WEAK_DEFAULT;
static Sym* ABSOLUTE_WEAKEST;

struct Strength {
    int arithmeticValue;
    Sym*   symbolicValue;
};

static Strength* absoluteWeakest_ = 0;
static Strength* required_ = 0;
static IdentityDictionary*  strengthTable = 0; // IdentityDictionary<Sym*, int, Sym::Hash>
static IdentityDictionary* strengthConstant = 0; // IdentityDictionary<Sym*, Strength*, Sym::Hash>

static Strength* Strength_create(Sym* symbolicValue) {
    Strength* me = malloc(sizeof(Strength));
    me->symbolicValue = symbolicValue;
    assert(strengthTable);
    me->arithmeticValue = *(int*)Dictionary_at(strengthTable, &symbolicValue);
    return me;
}

static void Strength_createStrengthTable() {
    strengthTable = Dictionary_create(sizeof(Sym*),sizeof(int), Sym_hash);
    int tmp;
    tmp = -10000; Dictionary_atPut(strengthTable, &ABSOLUTE_STRONGEST, &tmp);
    tmp = -800; Dictionary_atPut(strengthTable, &REQUIRED, &tmp);
    tmp = -600; Dictionary_atPut(strengthTable, &STRONG_PREFERRED,&tmp);
    tmp = -400; Dictionary_atPut(strengthTable, &PREFERRED,&tmp);
    tmp = -200; Dictionary_atPut(strengthTable, &STRONG_DEFAULT,&tmp);
    tmp = 0; Dictionary_atPut(strengthTable, &DEFAULT,&tmp);
    tmp = 500; Dictionary_atPut(strengthTable, &WEAK_DEFAULT,&tmp);
    tmp = 10000; Dictionary_atPut(strengthTable, &ABSOLUTE_WEAKEST,&tmp);
}

static void Strength_createStrengthConstants() {
    strengthConstant = Dictionary_create(sizeof(Sym*), sizeof(Strength*), Sym_hash);
    Vector* keys = Vector_createDefault(sizeof(Sym*)); // Vector<Sym*>
    Dictionary_getKeys(strengthTable,keys);
    for( int i = 0; i < Vector_size(keys); i++ )
    {
        Sym* key = *(Sym**)Vector_at(keys, i);
        Strength* tmp = Strength_create(key);
        Dictionary_atPut(strengthConstant, &key, &tmp);
    }
    Vector_dispose(keys);
}

static Strength* Strength_of(Sym* sym) {
    return *(Strength**)Dictionary_at(strengthConstant, &sym);
}

static void Strength_init()
{
    if( ABSOLUTE_STRONGEST )
        return;
    ABSOLUTE_STRONGEST = Sym_create(0);
    REQUIRED           = Sym_create(1);
    STRONG_PREFERRED   = Sym_create(2);
    PREFERRED          = Sym_create(3);
    STRONG_DEFAULT     = Sym_create(4);
    DEFAULT            = Sym_create(5);
    WEAK_DEFAULT       = Sym_create(6);
    ABSOLUTE_WEAKEST   = Sym_create(7);
    Strength_createStrengthTable();
    Strength_createStrengthConstants();
    absoluteWeakest_   = Strength_of(ABSOLUTE_WEAKEST);
    required_          = Strength_of(REQUIRED);
}

static void Strength_deinit()
{
    Vector* vals = Vector_createDefault(sizeof(Strength*)); // Vector<Strength*>
    Dictionary_getValues(strengthConstant, vals);
    for( int i = 0; i < Vector_size(vals); i++ )
        free( *(Strength**)Vector_at(vals, i) );
    Vector_dispose(vals);

    free(ABSOLUTE_STRONGEST);
    free(REQUIRED);
    free(STRONG_PREFERRED);
    free(PREFERRED);
    free(STRONG_DEFAULT);
    free(DEFAULT);
    free(WEAK_DEFAULT);
    free(ABSOLUTE_WEAKEST);
    ABSOLUTE_STRONGEST = 0;
    REQUIRED           = 0;
    STRONG_PREFERRED   = 0;
    PREFERRED          = 0;
    STRONG_DEFAULT     = 0;
    DEFAULT            = 0;
    WEAK_DEFAULT       = 0;
    ABSOLUTE_WEAKEST   = 0;

    Dictionary_dispose(strengthTable);
    strengthTable = 0;

    Dictionary_dispose(strengthConstant);
    strengthConstant = 0;
}

static Strength* Strength_absoluteWeakest() {
    return absoluteWeakest_;
}

static Strength* Strength_required() {
    return required_;
}

static int Strength_getArithmeticValue(Strength* me) {
    return me->arithmeticValue;
}

static bool Strength_sameAs(Strength* me, Strength* s) {
    return me->arithmeticValue == Strength_getArithmeticValue(s);
}

static bool Strength_stronger(Strength* me, Strength* s) {
    return me->arithmeticValue < Strength_getArithmeticValue(s);
}

static bool Strength_weaker(Strength* me, Strength* s) {
    return me->arithmeticValue > Strength_getArithmeticValue(s);
}

static Strength* Strength_strongest(Strength* me, Strength* s) {
    return Strength_stronger(s,me) ? s : me;
}

static Strength* Strength_weakest(Strength* me, Strength* s) {
    return Strength_weaker(s, me) ? s : me;
}

typedef enum ConstraintType { NoType = 0, EqualityConstraintType = 23434728, ScaleConstraintType = 583204892,
                      EditConstraintType = 68201024, StayConstraintType = 23498140233 } ConstraintType;

struct AbstractConstraint {
    ConstraintType type;
    Strength* strength;
};

typedef struct UnaryConstraint {
    AbstractConstraint base;
    Variable* output; // possible output variable
    bool  satisfied; // true if I am currently satisfied
} UnaryConstraint;

typedef struct EditConstraint {
    UnaryConstraint base;
} EditConstraint ;

typedef struct StayConstraint  {
    UnaryConstraint base;
} StayConstraint;

enum Direction { FORWARD = 1, BACKWARD = 2 };

typedef struct BinaryConstraint {
    AbstractConstraint base;
    Variable* v1;
    Variable* v2;          // possible output variables
    int direction;  // Direction
} BinaryConstraint;

typedef struct EqualityConstraint {
    BinaryConstraint base;
} EqualityConstraint;

typedef struct ScaleConstraint {
    BinaryConstraint base;
    Variable* scale;  // scale factor input variable
    Variable* offset; // offset input variable
} ScaleConstraint;

union Constraint {
    ConstraintType type;
    AbstractConstraint abstract;
    UnaryConstraint unary;
    EditConstraint edit;
    StayConstraint stay;
    BinaryConstraint binary;
    EqualityConstraint equality;
    ScaleConstraint scale;
};

static Constraint* Constraint_create(ConstraintType t) {
    Constraint* me = malloc(sizeof(Constraint));
    me->type = t;
    return me;
}

static void Constraint_dispose(Constraint* me) {
    free(me);
}

// Normal constraints are not input constraints. An input constraint
// is one that depends on external state, such as the mouse, the
// keyboard, a clock, or some arbitrary piece of imperative code.
static bool Constraint_isInput(Constraint* me);

// Answer true if this constraint is satisfied in the current solution.
static bool Constraint_isSatisfied(Constraint* me);


// Add myself to the constraint graph.
static void Constraint_addToGraph(Constraint* me);

// Remove myself from the constraint graph.
static void Constraint_removeFromGraph(Constraint* me);

// Decide if I can be satisfied and record that decision. The output
// of the chosen method must not have the given mark and must have
// a walkabout strength less than that of this constraint.
static int Constraint_chooseMethod(Constraint* me, int mark); // Direction

// Enforce this constraint. Assume that it is satisfied.
static void Constraint_execute(Constraint* me);


static void Constraint_inputsDo(Constraint* me, ValueIterator fn, void* data);

static bool Constraint_inputsHasOne(Constraint* me, TestIterator fn, void* data);

// Record the fact that I am unsatisfied.
static void Constraint_markUnsatisfied(Constraint* me);

// Answer my current output variable. Raise an error if I am not
// currently satisfied.
static Variable* Constraint_getOutput(Constraint* me);

// Calculate the walkabout strength, the stay flag, and, if it is
// 'stay', the value for the current output of this
// constraint. Assume this constraint is satisfied.
static void Constraint_recalculate(Constraint* me);


static void AbstractConstraint_init(AbstractConstraint* me, Sym* strength) {
    me->strength = Strength_of(strength);
}

static Strength* AbstractConstraint_getStrength(AbstractConstraint* me) {
    return me->strength;
}

// Activate this constraint and attempt to satisfy it.
static void AbstractConstraint_addConstraint(AbstractConstraint* me, Planner* planner);

// Deactivate this constraint, remove it from the constraint graph,
// possibly causing other constraints to be satisfied, and destroy
// it.
static void AbstractConstraint_destroyConstraint(AbstractConstraint* me, Planner* planner);

// Assume that I am satisfied. Answer true if all my current inputs
// are known. A variable is known if either a) it is 'stay' (i.e. it
// is a constant at plan execution time), b) it has the given mark
// (indicating that it has been computed by a constraint appearing
// earlier in the plan), or c) it is not determined by any
// constraint.
static bool AbstractConstraint_inputsKnown(AbstractConstraint* me, int mark);

// Attempt to find a way to enforce this constraint. If successful,
// record the solution, perhaps modifying the current dataflow
// graph. Answer the constraint that this constraint overrides, if
// there is one, or nil, if there isn't.
// Assume: I am not already satisfied.
//
static AbstractConstraint* AbstractConstraint_satisfy(Constraint* me, int mark, Planner* planner);

struct Variable {
    unsigned int test;
    int value_;       // my value; changed by constraints
    Vector* constraints; // normal constraints that reference me, Vector<Constraint*>
    Constraint* determinedBy; // the constraint that currently determines
    // my value (or null if there isn't one)
    int mark;        // used by the planner to mark constraints
    Strength* walkStrength; // my walkabout strength
    bool  stay;        // true if I am a planning-time constant
};

#define VARIABLE_TEST 0xcacacafe

static Variable* Variable_create() {
    Variable* me = (Variable*)malloc(sizeof(Variable));
    me->test = VARIABLE_TEST;
    me->value_ = 0;
    me->constraints = Vector_createDefault(sizeof(Constraint*));
    me->determinedBy = 0;
    me->walkStrength = Strength_absoluteWeakest();
    me->stay = true;
    me->mark = 0;
    return me;
}

static void Variable_assure(Variable* me) {
    if( me == 0 )
        return;
    assert(me->test == VARIABLE_TEST);
}

static void Variable_dispose(Variable* me) {
    Variable_assure(me);
    Vector_dispose(me->constraints);
    free(me);
}

static bool Variable_getStay(Variable* me) {
    Variable_assure(me);
    return me->stay;
}

static void Variable_setStay(Variable* me, bool v) {
    Variable_assure(me);
    me->stay = v;
}

static int Variable_getValue(Variable* me) {
    Variable_assure(me);
    return me->value_;
}

static void Variable_setValue(Variable* me,int value) {
    Variable_assure(me);
    me->value_ = value;
}

static Variable* Variable_value(int aValue) {
    Variable* v = Variable_create();
    Variable_setValue(v, aValue);
    return v;
}

// Add the given constraint to the set of all constraints that refer to me.
static void Variable_addConstraint(Variable* me, Constraint* c) {
    Variable_assure(me);
    Vector_append(me->constraints, &c);
}

static Vector* Variable_getConstraints(Variable* me) {
    Variable_assure(me);
    return me->constraints;
}

static Constraint* Variable_getDeterminedBy(Variable* me) {
    Variable_assure(me);
    return me->determinedBy;
}

static void Variable_setDeterminedBy(Variable* me, Constraint* c) {
    Variable_assure(me);
    me->determinedBy = c;
}

static int Variable_getMark(Variable* me) {
    Variable_assure(me);
    return me->mark;
}

static void Variable_setMark(Variable* me, int markValue) {
    Variable_assure(me);
    me->mark = markValue;
}

// Remove all traces of c from this variable.
static void Variable_removeConstraint(Variable* me, Constraint* c) {
    Variable_assure(me);
    Vector_remove(me->constraints, &c);
    if (me->determinedBy == c) {
        me->determinedBy = 0;
    }
}

static Strength* Variable_getWalkStrength(Variable* me) {
    Variable_assure(me);
    return me->walkStrength;
}

static void Variable_setWalkStrength(Variable* me, Strength* strength) {
    Variable_assure(me);
    me->walkStrength = strength;
}

struct Plan {
    Vector* constraints; // Vector<AbstractConstraint*>
};

static Plan* Plan_create() {
    Plan* me = malloc(sizeof(Plan));
    me->constraints = Vector_create(sizeof(Constraint*), 15);
    return me;
}

static void Plan_dispose(Plan* me) {
    Vector_dispose(me->constraints);
    free(me);
}

static void Plan_execute(Plan* me) {
    for( int i = 0; i < Vector_size(me->constraints); i++ ) {
        Constraint* c = *(Constraint**)Vector_at(me->constraints, i);
        Constraint_execute(c);
    }
}

struct Planner {
    int currentMark;
};

static Planner* Planner_create() {
    Planner* me = malloc(sizeof(Planner));
    me->currentMark = 1;
    return me;
}

// Select a previously unused mark value.
static int Planner_newMark(Planner* me) {
    me->currentMark++;
    return me->currentMark;
}

// Attempt to satisfy the given constraint and, if successful,
// incrementally update the dataflow graph. Details: If satifying
// the constraint is successful, it may override a weaker constraint
// on its output. The algorithm attempts to resatisfy that
// constraint using some other method. This process is repeated
// until either a) it reaches a variable that was not previously
// determined by any constraint or b) it reaches a constraint that
// is too weak to be satisfied using any of its methods. The
// variables of constraints that have been processed are marked with
// a unique mark value so that we know where we've been. This allows
// the algorithm to avoid getting into an infinite loop even if the
// constraint graph has an inadvertent cycle.
//
static void Planner_incrementalAdd(Planner* me, Constraint* c) {
    int mark = Planner_newMark(me);
    Constraint* overridden = AbstractConstraint_satisfy(c, mark, me);

    while (overridden != 0) {
        overridden = AbstractConstraint_satisfy(overridden, mark, me);
    }
}

static void Planner_change(Planner* me, Variable* var, int newValue);

static void Planner_constraintsConsuming(Planner* me, Variable* v,
                                         ValueIterator fn, void* data) // ForEachInterface<Constraint*>
{
    Constraint* determiningC = Variable_getDeterminedBy(v);
    for( int i = 0; i < Vector_size(Variable_getConstraints(v)); i++ )
    {
        Constraint* c = *(Constraint**)Vector_at(Variable_getConstraints(v), i);
        if (c != determiningC && Constraint_isSatisfied(c)) {
            fn(&c, data);
        }
    }
}

static void Planner_removePropagateFrom_iter1(const Bytes value, void* data) {
    Vector* todo = data;
    Constraint* c = *(Constraint**)value;
    Constraint_recalculate(c);
    Variable* var = Constraint_getOutput(c);
    Variable_assure(var);
    Vector_append(todo, &var);
}

static int Planner_removePropagateFrom_iter2(const Bytes lhs, const Bytes rhs, void* data) {
    Constraint* c1 = *(Constraint**)lhs;
    Constraint* c2 = *(Constraint**)rhs;
    return Strength_stronger(AbstractConstraint_getStrength(c1), AbstractConstraint_getStrength(c2)) ? -1 : 1;
}

// Update the walkabout strengths and stay flags of all variables
// downstream of the given constraint. Answer a collection of
// unsatisfied constraints sorted in order of decreasing strength.
static void Planner_removePropagateFrom(Planner* me, Variable* out,
                                        Vector* unsatisfied) // Vector<Constraint*>
{

    Variable_setDeterminedBy(out, 0);
    Variable_setWalkStrength(out, Strength_absoluteWeakest());
    Variable_setStay(out, true);

    Vector* todo = Vector_createDefault(sizeof(Variable*)); // Vector<Variable*>
    Vector_append(todo, &out);

    while (!Vector_isEmpty(todo)) {
        Variable* v = *(Variable**)Vector_removeFirst(todo);
        Variable_assure(v);

        for(int i = 0; i < Vector_size(Variable_getConstraints(v)); i++ )
        {
            Constraint* c = *(Constraint**)Vector_at(Variable_getConstraints(v),i);
            if (!Constraint_isSatisfied(c)) { Vector_append(unsatisfied, &c); }
        }

        Planner_constraintsConsuming(me, v, Planner_removePropagateFrom_iter1, todo);
    }
    Vector_dispose(todo);

    Vector_sort(unsatisfied, Planner_removePropagateFrom_iter2,0);
}

// Entry point for retracting a constraint. Remove the given
// constraint and incrementally update the dataflow graph.
// Details: Retracting the given constraint may allow some currently
// unsatisfiable downstream constraint to be satisfied. We therefore collect
// a list of unsatisfied downstream constraints and attempt to
// satisfy each one in turn. This list is traversed by constraint
// strength, strongest first, as a heuristic for avoiding
// unnecessarily adding and then overriding weak constraints.
// Assume: c is satisfied.
//
static void Planner_incrementalRemove(Planner* me, Constraint* c) {
    Variable* out = Constraint_getOutput(c);
    Variable_assure(out);
    Constraint_markUnsatisfied(c);
    Constraint_removeFromGraph(c);

    Vector* unsatisfied = Vector_createDefault(sizeof(Constraint*)); // Vector<Constraint*>
    Planner_removePropagateFrom(me, out,unsatisfied);
    for( int i = 0; i < Vector_size(unsatisfied); i++ ) {
        Constraint* cc = *(Constraint**)Vector_at(unsatisfied, i);
        Planner_incrementalAdd(me, cc);
    }
    Vector_dispose(unsatisfied);
}

static void Planner_addConstraintsConsumingTo(Planner* me, Variable* v,
                                              Vector* coll)  // Vector<Constraint*>
{
    Constraint* determiningC = Variable_getDeterminedBy(v);

    for( int i = 0; i < Vector_size(Variable_getConstraints(v)); i++ )
    {
        Constraint* c = *(Constraint**)Vector_at(Variable_getConstraints(v), i);
        if (c != determiningC && Constraint_isSatisfied(c)) {
            Vector_append(coll, &c);
        }
    }
}

// Extract a plan for resatisfaction starting from the given source
// constraints, usually a set of input constraints. This method
// assumes that stay optimization is desired; the plan will contain
// only constraints whose output variables are not stay. Constraints
// that do no computation, such as stay and edit constraints, are
// not included in the plan.
// Details: The outputs of a constraint are marked when it is added
// to the plan under construction. A constraint may be appended to
// the plan when all its input variables are known. A variable is
// known if either a) the variable is marked (indicating that has
// been computed by a constraint appearing earlier in the plan), b)
// the variable is 'stay' (i.e. it is a constant at plan execution
// time), or c) the variable is not determined by any
// constraint. The last provision is for past states of history
// variables, which are not stay but which are also not computed by
// any constraint.
// Assume: sources are all satisfied.
//
static Plan* Planner_makePlan(Planner* me, const Vector* sources)  // Vector<Constraint*>
{
    int mark = Planner_newMark(me);
    Plan* plan = Plan_create();
    Vector* todo = Vector_copy(sources);

    while (!Vector_isEmpty(todo)) {
        Constraint* c = *(Constraint**)Vector_removeFirst(todo);

        if (Variable_getMark(Constraint_getOutput(c)) != mark && AbstractConstraint_inputsKnown(c, mark)) {
            // not in plan already and eligible for inclusion
            Vector_append(plan->constraints, &c);
            Variable_setMark(Constraint_getOutput(c), mark);
            Planner_addConstraintsConsumingTo(me, Constraint_getOutput(c), todo);
        }
    }
    Vector_dispose(todo);
    return plan;
}

// Extract a plan for resatisfaction starting from the outputs of
// the given constraints, usually a set of input constraints.
//
static Plan* Planner_extractPlanFromConstraints(Planner* me,
                         const Vector* constraints) // Vector<Constraint*>
{
    Vector* sources = Vector_createDefault(sizeof(Constraint*)); // Vector<Constraint*>

    for( int i = 0; i < Vector_size(constraints); i++ )
    {
        Constraint* c = *(Constraint**)Vector_at(constraints, i);
        if (Constraint_isInput(c) && Constraint_isSatisfied(c)) {
            Vector_append(sources, &c);
        }
    }

    Plan* res = Planner_makePlan(me, sources);
    Vector_dispose(sources);
    return res;
}

// Recompute the walkabout strengths and stay flags of all variables
// downstream of the given constraint and recompute the actual
// values of all variables whose stay flag is true. If a cycle is
// detected, remove the given constraint and answer
// false. Otherwise, answer true.
// Details: Cycles are detected when a marked variable is
// encountered downstream of the given constraint. The sender is
// assumed to have marked the inputs of the given constraint with
// the given mark. Thus, encountering a marked node downstream of
// the output constraint means that there is a path from the
// constraint's output to one of its inputs.
//
static bool Planner_addPropagate(Planner* me, Constraint* c, int mark) {
    Vector* todo = Vector_createDefault(sizeof(Constraint*)); // Vector<Constraint*>
    Vector_append(todo, &c);

    while (!Vector_isEmpty(todo)) {
        Constraint* d = *(Constraint**)Vector_removeFirst(todo);

        if (Variable_getMark(Constraint_getOutput(d)) == mark) {
            Planner_incrementalRemove(me, c);
            return false;
        }
        Constraint_recalculate(d);
        Planner_addConstraintsConsumingTo(me, Constraint_getOutput(d), todo);
    }
    Vector_dispose(todo);
    return true;
}

// This is the standard DeltaBlue benchmark. A long chain of
// equality constraints is constructed with a stay constraint on
// one end. An edit constraint is then added to the opposite end
// and the time is measured for adding and removing this
// constraint, and extracting and executing a constraint
// satisfaction plan. There are two cases. In case 1, the added
// constraint is stronger than the stay constraint and values must
// propagate down the entire length of the chain. In case 2, the
// added constraint is weaker than the stay constraint so it cannot
// be accomodated. The cost in this case is, of course, very
// low. Typical situations lie somewhere between these two
// extremes.
//
static void Planner_chainTest(int n);

// This test constructs a two sets of variables related to each
// other by a simple linear transformation (scale and offset). The
// time is measured to change a variable on either side of the
// mapping and to change the scale and offset factors.
//
static void Planner_projectionTest(int n);


// Answer true if this constraint is satisfied in the current solution.
static bool UnaryConstraint_isSatisfied(UnaryConstraint* me) {
    return me->satisfied;
}

// Add myself to the constraint graph.
static void UnaryConstraint_addToGraph(UnaryConstraint* me) {
    Variable_addConstraint(me->output,me);
    me->satisfied = false;
}

// Remove myself from the constraint graph.
static void UnaryConstraint_removeFromGraph(UnaryConstraint* me) {
    if (me->output != 0) {
        Variable_removeConstraint(me->output, me);
    }
    me->satisfied = false;
}

static void UnaryConstraint_execute(UnaryConstraint* me) {
} // do nothing.

// Decide if I can be satisfied and record that decision.
static int UnaryConstraint_chooseMethod(UnaryConstraint* me, int mark) {
    me->satisfied = Variable_getMark(me->output) != mark
            && Strength_stronger(me->base.strength, Variable_getWalkStrength(me->output));
    return 0;
}

static void UnaryConstraint_inputsDo(UnaryConstraint* me, ValueIterator fn, void* data) {
    // I have no input variables
}

static bool UnaryConstraint_inputsHasOne(UnaryConstraint* me, TestIterator fn, void* data) {
    return false;
};

// Record the fact that I am unsatisfied.
static void UnaryConstraint_markUnsatisfied(UnaryConstraint* me) {
    me->satisfied = false;
}

// Answer my current output variable.
static Variable* UnaryConstraint_getOutput(UnaryConstraint* me) {
    return me->output;
}

// Calculate the walkabout strength, the stay flag, and, if it is
// 'stay', the value for the current output of this
// constraint. Assume this constraint is satisfied."
static void UnaryConstraint_recalculate(UnaryConstraint* me) {
    Variable_setWalkStrength(me->output, me->base.strength);
    Variable_setStay(me->output, !Constraint_isInput(me));
    if (Variable_getStay(me->output)) {
        Constraint_execute(me); // stay optimization
    }
}

static void UnaryConstraint_init(UnaryConstraint* me, Variable* v, Sym* strength, Planner* planner) {
    AbstractConstraint_init(&me->base,strength);
    me->output = v;
    Variable_assure(v);
    me->satisfied = false;
    AbstractConstraint_addConstraint(me, planner);
}

// I indicate that a variable is to be changed by imperative code.
static bool EditConstraint_isInput(EditConstraint* me) {
    return true;
}



static EditConstraint* EditConstraint_create(Variable* v, Sym* strength, Planner* planner) {
    Variable_assure(v);
    EditConstraint* me = Constraint_create(EditConstraintType);
    UnaryConstraint_init(me, v, strength, planner );
    return me;
}


// Install a stay constraint with the given strength on the given variable.
static StayConstraint* StayConstraint_create(Variable* v, Sym* strength, Planner* planner) {
    Variable_assure(v);
    StayConstraint* me = Constraint_create(StayConstraintType);
    UnaryConstraint_init(me, v, strength, planner );
    return me;
}

// Answer true if this constraint is satisfied in the current solution.
static bool BinaryConstraint_isSatisfied(BinaryConstraint* me) {
    return me->direction != 0;
}

// Add myself to the constraint graph.
static void BinaryConstraint_addToGraph(BinaryConstraint* me) {
    Variable_addConstraint(me->v1, me);
    Variable_addConstraint(me->v2, me);
    me->direction = 0;
}

// Remove myself from the constraint graph.
static void BinaryConstraint_removeFromGraph(BinaryConstraint* me) {
    if (me->v1 != 0) {
        Variable_removeConstraint(me->v1, me);
    }
    if (me->v2 != 0) {
        Variable_removeConstraint(me->v2, me);
    }
    me->direction = 0;
}

static void BinaryConstraint_execute(BinaryConstraint* me) {
} // do nothing.

// Decide if I can be satisfied and which way I should flow based on
// the relative strength of the variables I relate, and record that
// decision.
//
static int BinaryConstraint_chooseMethod(BinaryConstraint* me, int mark) {
    if (Variable_getMark(me->v1) == mark) {
        if (Variable_getMark(me->v2) != mark && Strength_stronger(me->base.strength, Variable_getWalkStrength(me->v2))) {
            me->direction = FORWARD;
            return me->direction;
        } else {
            me->direction = 0;
            return me->direction;
        }
    }

    if (Variable_getMark(me->v2) == mark) {
        if (Variable_getMark(me->v1) != mark && Strength_stronger(me->base.strength, Variable_getWalkStrength(me->v1))) {
            me->direction = BACKWARD;
            return me->direction;
        } else {
            me->direction = 0;
            return me->direction;
        }
    }

    // If we get here, neither variable is marked, so we have a choice.
    if (Strength_weaker(Variable_getWalkStrength(me->v1), Variable_getWalkStrength(me->v2))) {
        if (Strength_stronger(me->base.strength, Variable_getWalkStrength(me->v1))) {
            me->direction = BACKWARD;
            return me->direction;
        } else {
            me->direction = 0;
            return me->direction;
        }
    } else {
        if (Strength_stronger(me->base.strength, Variable_getWalkStrength(me->v2))) {
            me->direction = FORWARD;
            return me->direction;
        } else {
            me->direction = 0;
            return me->direction;
        }
    }
}

static void BinaryConstraint_inputsDo(BinaryConstraint* me, ValueIterator fn, void* data) {
    if (me->direction == FORWARD) {
        fn(&me->v1, data);
    } else {
        fn(&me->v2, data);
    }
}

static bool BinaryConstraint_inputsHasOne(BinaryConstraint* me, TestIterator fn, void* data) {
    if (me->direction == FORWARD) {
        return fn(&me->v1, data);
    } else {
        return fn(&me->v2, data);
    }
}

// Record the fact that I am unsatisfied.
static void BinaryConstraint_markUnsatisfied(BinaryConstraint* me) {
    me->direction = 0;
}


// Answer my current output variable.
static Variable* BinaryConstraint_getOutput(BinaryConstraint* me) {
    return me->direction == FORWARD ? me->v2 : me->v1;
}

// Calculate the walkabout strength, the stay flag, and, if it is
// 'stay', the value for the current output of this
// constraint. Assume this constraint is satisfied.
//
static void BinaryConstraint_recalculate(BinaryConstraint* me) {
    Variable* in;
    Variable* out;

    if (me->direction == FORWARD) {
        in = me->v1; out = me->v2;
    } else {
        in = me->v2; out = me->v1;
    }

    Variable_setWalkStrength(out, Strength_weakest(me->base.strength, Variable_getWalkStrength(in)));
    Variable_setStay(out, Variable_getStay(in));
    if (Variable_getStay(out)) {
        Constraint_execute(me);
    }
}

static void BinaryConstraint_init(BinaryConstraint* me, Variable* var1, Variable* var2,
                 Sym* strength, Planner* planner) {
    AbstractConstraint_init(&me->base, strength);
    me->v1 = var1;
    me->v2 = var2;
    Variable_assure(var1);
    Variable_assure(var2);
    me->direction = 0;
}

// Enforce this constraint. Assume that it is satisfied.
static void EqualityConstraint_execute(EqualityConstraint* me) {
    if (me->base.direction == FORWARD) {
        Variable_setValue(me->base.v2, Variable_getValue(me->base.v1));
    } else {
        Variable_setValue(me->base.v1, Variable_getValue(me->base.v2));
    }
}

// Install a constraint with the given strength equating the given
// variables.
static EqualityConstraint* EqualityConstraint_create(Variable* var1, Variable* var2,
                   Sym* strength, Planner* planner) {
    EqualityConstraint* me = Constraint_create(EqualityConstraintType);
    BinaryConstraint_init(me, var1, var2, strength, planner);
    AbstractConstraint_addConstraint(me, planner);
    return me;
}


// Add myself to the constraint graph.
static void ScaleConstraint_addToGraph(ScaleConstraint* me) {
    Variable_addConstraint(me->base.v1, me);
    Variable_addConstraint(me->base.v2, me);
    Variable_addConstraint(me->scale, me);
    Variable_addConstraint(me->offset, me);
    me->base.direction = 0;
}

// Remove myself from the constraint graph.
static void ScaleConstraint_removeFromGraph(ScaleConstraint* me) {
    if (me->base.v1 != 0) { Variable_removeConstraint(me->base.v1, me); }
    if (me->base.v2 != 0) { Variable_removeConstraint(me->base.v2, me); }
    if (me->scale  != 0) { Variable_removeConstraint(me->scale, me); }
    if (me->offset != 0) { Variable_removeConstraint(me->offset, me); }
    me->base.direction = 0;
}

// Enforce this constraint. Assume that it is satisfied.
static void ScaleConstraint_execute(ScaleConstraint* me) {
    if (me->base.direction == FORWARD) {
        Variable_setValue(me->base.v2, Variable_getValue(me->base.v1) * Variable_getValue(me->scale) +
                          Variable_getValue(me->offset));
    } else {
        Variable_setValue(me->base.v1, (Variable_getValue(me->base.v2) - Variable_getValue(me->offset)) /
                              Variable_getValue(me->scale));
    }
}

static void ScaleConstraint_inputsDo(ScaleConstraint* me, ValueIterator fn, void* data) {
    if (me->base.direction == FORWARD) {
        fn(&me->base.v1,data);
        fn(&me->scale, data);
        fn(&me->offset,data);
    } else {
        fn(&me->base.v2, data);
        fn(&me->scale, data);
        fn(&me->offset, data);
    }
}

// Calculate the walkabout strength, the stay flag, and, if it is
// 'stay', the value for the current output of this
// constraint. Assume this constraint is satisfied.
static void ScaleConstraint_recalculate(ScaleConstraint* me) {
    Variable* in;
    Variable* out;

    if (me->base.direction == FORWARD) {
        in  = me->base.v1; out = me->base.v2;
    } else {
        out = me->base.v1; in  = me->base.v2;
    }

    Variable_setWalkStrength(out, Strength_weakest(me->base.base.strength, Variable_getWalkStrength(in)));
    Variable_setStay(out, Variable_getStay(in) && Variable_getStay(me->scale) && Variable_getStay(me->offset));
    if (Variable_getStay(out)) {
        Constraint_execute(me); // stay optimization
    }
}

static ScaleConstraint* ScaleConstraint_create(Variable* src, Variable* scale,
                Variable* offset, Variable* dest, Sym* strength, Planner* planner) {
    ScaleConstraint* me = Constraint_create(ScaleConstraintType);
    BinaryConstraint_init(me, src, dest, strength, planner);
    me->scale = scale;
    me->offset = offset;
    AbstractConstraint_addConstraint(me,planner);
    return me;
}

static void AbstractConstraint_addConstraint(AbstractConstraint* me, Planner *planner)
{
    Constraint_addToGraph(me);
    Planner_incrementalAdd(planner, me);
}

static void AbstractConstraint_destroyConstraint(AbstractConstraint* me, Planner *planner)
{
    if (Constraint_isSatisfied(me)) {
        Planner_incrementalRemove(planner, me);
    }
    Constraint_removeFromGraph(me);
}

static int AbstractConstraint_inputsKnown_iter(const Bytes value, void* data) {
    int* mark = data;
    Variable* v = *(Variable**)value;
    Variable_assure(v);
    return !(Variable_getMark(v) == *mark || Variable_getStay(v) || Variable_getDeterminedBy(v) == 0);
}

static bool AbstractConstraint_inputsKnown(AbstractConstraint* me, int mark)
{
    return !Constraint_inputsHasOne(me, AbstractConstraint_inputsKnown_iter, &mark);
}

static void AbstractConstraint_satisfy_iter(const Bytes value, void* data) { // ForEachInterface<Variable*>
    int* mark = data;
    Variable* in = *(Variable**)value;
    Variable_assure(in);
    Variable_setMark(in, *mark);
}

static AbstractConstraint *AbstractConstraint_satisfy(Constraint* me, int mark, Planner *planner)
{
    Constraint* overridden = 0;

    Constraint_chooseMethod(me, mark);

    if (Constraint_isSatisfied(me)) {
        // constraint can be satisfied
        // mark inputs to allow cycle detection in addPropagate
        Constraint_inputsDo(me,AbstractConstraint_satisfy_iter, &mark);

        Variable* out = Constraint_getOutput(me);
        Variable_assure(out);
        overridden = Variable_getDeterminedBy(out);
        if (overridden != 0) {
            Constraint_markUnsatisfied(overridden);
        }
        Variable_setDeterminedBy(out, me);
        if (!Planner_addPropagate(planner, me, mark)) {
            assert(0); // "Cycle encountered"
        }
        Variable_setMark(out, mark);
    } else {
        overridden = 0;
        if (Strength_sameAs(me->abstract.strength, Strength_required())) {
            assert(0); // "Could not satisfy a required constraint"
        }
    }
    return overridden;
}

static bool Constraint_isInput(Constraint* me) {
    switch(me->type)
    {
    case EditConstraintType:
        return EditConstraint_isInput(&me->edit);
    case StayConstraintType:
    case EqualityConstraintType:
    case ScaleConstraintType:
        break;
    default:
        assert(0);
    }
    return false;
}

static bool Constraint_isSatisfied(Constraint* me) {
    switch(me->type)
    {
    case EditConstraintType:
    case StayConstraintType:
        return UnaryConstraint_isSatisfied(&me->unary);
    case EqualityConstraintType:
    case ScaleConstraintType:
        return BinaryConstraint_isSatisfied(&me->binary);
    default:
        assert(0);
    }
    return false;
}

static void Constraint_addToGraph(Constraint* me) {
    switch(me->type)
    {
    case EditConstraintType:
    case StayConstraintType:
        UnaryConstraint_addToGraph(&me->unary);
        break;
    case EqualityConstraintType:
        BinaryConstraint_addToGraph(&me->binary);
        break;
    case ScaleConstraintType:
        ScaleConstraint_addToGraph(&me->scale);
        break;
    default:
        assert(0);
    }
}

static void Constraint_removeFromGraph(Constraint* me) {
    switch(me->type)
    {
    case EditConstraintType:
    case StayConstraintType:
        UnaryConstraint_removeFromGraph(&me->unary);
        break;
    case EqualityConstraintType:
        BinaryConstraint_removeFromGraph(&me->binary);
        break;
    case ScaleConstraintType:
        ScaleConstraint_removeFromGraph(&me->scale);
        break;
    default:
        assert(0);
    }
}

static int Constraint_chooseMethod(Constraint* me, int mark) { // Direction
    switch(me->type)
    {
    case EditConstraintType:
    case StayConstraintType:
        return UnaryConstraint_chooseMethod(&me->unary, mark);
    case EqualityConstraintType:
        return BinaryConstraint_chooseMethod(&me->binary, mark);
    case ScaleConstraintType:
        return BinaryConstraint_chooseMethod(&me->scale, mark);
    default:
        assert(0);
    }
    return 0;
}

static void Constraint_execute(Constraint* me) {
    switch(me->type)
    {
    case EditConstraintType:
    case StayConstraintType:
        UnaryConstraint_execute(&me->unary);
        break;
    case EqualityConstraintType:
        EqualityConstraint_execute(&me->equality);
        break;
    case ScaleConstraintType:
        ScaleConstraint_execute(&me->scale);
        break;
    default:
        assert(0);
    }
}


static void Constraint_inputsDo(Constraint* me, ValueIterator fn, void* data) {
    switch(me->type)
    {
    case EditConstraintType:
    case StayConstraintType:
        UnaryConstraint_inputsDo(&me->unary, fn, data);
        break;
    case EqualityConstraintType:
        BinaryConstraint_inputsDo(&me->binary, fn, data);
        break;
    case ScaleConstraintType:
        ScaleConstraint_inputsDo(&me->scale, fn, data);
        break;
    default:
        assert(0);
    }
}

static bool Constraint_inputsHasOne(Constraint* me, TestIterator fn, void* data) {
    switch(me->type)
    {
    case EditConstraintType:
    case StayConstraintType:
        return UnaryConstraint_inputsHasOne(&me->unary, fn, data);
    case EqualityConstraintType:
    case ScaleConstraintType:
        return BinaryConstraint_inputsHasOne(&me->binary, fn, data);
    default:
        assert(0);
    }
    return false;
}

static void Constraint_markUnsatisfied(Constraint* me) {
    switch(me->type)
    {
    case EditConstraintType:
    case StayConstraintType:
        UnaryConstraint_markUnsatisfied(&me->unary);
        break;
    case EqualityConstraintType:
    case ScaleConstraintType:
        BinaryConstraint_markUnsatisfied(&me->binary);
        break;
    default:
        assert(0);
    }
}

static Variable* Constraint_getOutput(Constraint* me) {
    switch(me->type)
    {
    case EditConstraintType:
    case StayConstraintType:
        return UnaryConstraint_getOutput(&me->unary);
    case EqualityConstraintType:
    case ScaleConstraintType:
        return BinaryConstraint_getOutput(&me->binary);
    default:
        assert(0);
    }
    return 0;
}

static void Constraint_recalculate(Constraint* me) {
    switch(me->type)
    {
    case EditConstraintType:
    case StayConstraintType:
        UnaryConstraint_recalculate(&me->unary);
        break;
    case EqualityConstraintType:
        BinaryConstraint_recalculate(&me->binary);
        break;
    case ScaleConstraintType:
        ScaleConstraint_recalculate(&me->scale);
        break;
    default:
        assert(0);
    }
}

static void Planner_change(Planner* me, Variable *var, int newValue)
{
    EditConstraint* editC = EditConstraint_create(var, PREFERRED, me);

    Vector* editV = Vector_createDefault(sizeof(AbstractConstraint*)); // Vector<AbstractConstraint*>
    Vector_append(editV, &editC);
    Plan* plan = Planner_extractPlanFromConstraints(me, editV);
    for (int i = 0; i < 10; i++) {
        Variable_setValue(var, newValue);
        Plan_execute(plan);
    }
    AbstractConstraint_destroyConstraint(editC, me);
    Constraint_dispose(editC);
    Vector_dispose(editV);
    Plan_dispose(plan);
}

static void Planner_chainTest(int n)
{
    Planner* planner = Planner_create();
    Vector* toDelete = Vector_createDefault(sizeof(AbstractConstraint*)); // Vector<AbstractConstraint*>
    const int varsLen = n + 1;
    Vector* vars = Vector_create(sizeof(Variable*), varsLen); // Vector<Variable*>
    for( int i = 0; i < varsLen; i++ ) {
        Variable* var = Variable_create();
        Vector_atPut(vars, i, &var);
    }

    AbstractConstraint* tmp;

    // Build chain of n equality constraints
    for (int i = 0; i < n; i++) {
        Variable* v1 = *(Variable**)Vector_at(vars, i);
        Variable_assure(v1);
        Variable* v2 = *(Variable**)Vector_at(vars, i + 1);
        Variable_assure(v2);
        tmp = EqualityConstraint_create(v1, v2, REQUIRED, planner);
        Vector_append(toDelete, &tmp);
    }

    tmp = StayConstraint_create(*(Variable**)Vector_at(vars, n), STRONG_DEFAULT, planner);
    Vector_append(toDelete, &tmp );
    AbstractConstraint* editC = EditConstraint_create(*(Variable**)Vector_at(vars, 0), PREFERRED, planner);
    Vector_append(toDelete, &editC );

    Vector* editV = Vector_createDefault(sizeof(AbstractConstraint*)); // Vector<AbstractConstraint*>
    Vector_append(editV, &editC);
    Plan* plan = Planner_extractPlanFromConstraints(planner, editV);
    for (int i = 0; i < 100; i++) {
        Variable* v = *(Variable**)Vector_at(vars, 0);
        Variable_assure(v);
        Variable_setValue(v, i);
        Plan_execute(plan);
        v = *(Variable**)Vector_at(vars, n);
        Variable_assure(v);
        if (Variable_getValue(v) != i) {
            assert(0); // "Chain test failed!"
        }
    }
    AbstractConstraint_destroyConstraint(editC, planner);

    for( int i = 0; i < Vector_size(vars); i++ )
        Variable_dispose( *(Variable**)Vector_at(vars, i) );

    for( int i = 0; i < Vector_size(toDelete); i++ ) {
        AbstractConstraint* c = *(AbstractConstraint**)Vector_at(toDelete, i);
        Constraint_dispose(c);
    }

    Plan_dispose(plan);
    free(planner);
    Vector_dispose(toDelete);
    Vector_dispose(editV);
    Vector_dispose(vars);
}

static void Planner_projectionTest(int n)
{
    Planner* planner = Planner_create();

    Vector* dests = Vector_createDefault(sizeof(Variable*)); // Vector<Variable*>
    Vector* toDelete = Vector_createDefault(sizeof(Variable*)); // Vector<Variable*>
    Vector* toDelete2 = Vector_createDefault(sizeof(AbstractConstraint*)); // Vector<AbstractConstraint*>

    Variable* scale  = Variable_value(10);
    Variable* offset = Variable_value(1000);
    Vector_append(toDelete, &scale);
    Vector_append(toDelete, &offset);

    Variable* src = 0;
    Variable* dst = 0;
    AbstractConstraint* tmp;
    for (int i = 1; i <= n; i++) {
        src = Variable_value(i);
        dst = Variable_value(i);
        Vector_append(toDelete, &src);
        Vector_append(toDelete, &dst);
        Vector_append(dests, &dst);
        tmp = StayConstraint_create(src, DEFAULT, planner);
        Vector_append(toDelete2, &tmp);
        tmp = ScaleConstraint_create(src, scale, offset, dst, REQUIRED, planner);
        Vector_append(toDelete2, &tmp);
    }

    Planner_change(planner, src, 17);
    if (Variable_getValue(dst) != 1170) {
        assert(0); // "Projection test 1 failed!"
    }

    Planner_change(planner, dst, 1050);
    if (Variable_getValue(src) != 5) {
        assert(0); // "Projection test 2 failed!"
    }

    Planner_change(planner, scale, 5);
    for (int i = 0; i < n - 1; ++i) {
        Variable* v = *(Variable**)Vector_at(dests, i);
        if (Variable_getValue(v) != (i + 1) * 5 + 1000) {
            assert(0); // "Projection test 3 failed!"
        }
    }

    Planner_change(planner, offset, 2000);
    for (int i = 0; i < n - 1; ++i) {
        Variable* v = *(Variable**)Vector_at(dests, i);
        if (Variable_getValue(v) != (i + 1) * 5 + 2000) {
            assert(0); // "Projection test 4 failed!"
        }
    }

    for( int i = 0; i < Vector_size(toDelete); i++ )
        Variable_dispose( *(Variable**)Vector_at(toDelete, i) );
    for( int i = 0; i < Vector_size(toDelete2); i++ ) {
        AbstractConstraint* c = *(AbstractConstraint**)Vector_at(toDelete2, i);
        Constraint_dispose(c);
    }

    free(planner);
    Vector_dispose(dests);
    Vector_dispose(toDelete);
    Vector_dispose(toDelete2);
}


#if 0


class Planner {

public:
    // Not used:

    // The given variable has changed. Propagate values downstream.
    void propagateFrom(Variable* v) {
        Vector<AbstractConstraint*> todo;
        addConstraintsConsumingTo(v, todo);

        while (!todo.isEmpty()) {
            AbstractConstraint* c = todo.removeFirst();
            c->execute();
            addConstraintsConsumingTo(c->getOutput(), todo);
        }
    }
};

#endif

static bool DeltaBlue_innerBenchmarkLoop(Benchmark* me, int innerIterations)
{
    Strength_init();
    Planner_chainTest(innerIterations);
    Planner_projectionTest(innerIterations);
    Strength_deinit();
    return true;
}

static int benchmark() {
    assert(0); // "Should never be reached"
}

static bool verifyResult(int result) {
    assert(0); // "Should never be reached"
}

Benchmark*DeltaBlue_create()
{
    Benchmark* bench = (Benchmark*)malloc(sizeof(Benchmark));
    bench->benchmark = benchmark;
    bench->verifyResult = verifyResult;
    bench->dispose = 0;
    bench->innerBenchmarkLoop = DeltaBlue_innerBenchmarkLoop;
    return bench;
}
