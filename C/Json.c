/*******************************************************************************
 * Copyright (c) 2024 Rochus Keller <me@rochus-keller.ch> (for C99 migration)
 * Copyright (c) 2015 Stefan Marr
 * Copyright (c) 2013, 2015 EclipseSource.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 ******************************************************************************/

#include "Json.h"
#include "som/Vector.h"
#include <string.h>
#include <assert.h>
#include <stdlib.h>

typedef struct JsonObject JsonObject;
typedef struct JsonArray JsonArray;
typedef struct JsonValue JsonValue;
typedef struct JsonString JsonString;
typedef struct JsonNumber JsonNumber;
typedef struct JsonLiteral JsonLiteral;

struct Vtable {
    bool (*isObject)(JsonValue*);
    bool (*isArray)(JsonValue*);
    bool (*isNumber)(JsonValue*);
    bool (*isString)(JsonValue*);
    bool (*isBoolean)(JsonValue*);
    bool (*isTrue)(JsonValue*);
    bool (*isFalse)(JsonValue*);
    bool (*isNull)(JsonValue*);
    JsonObject* (*asObject)(JsonValue*);
    JsonArray* (*asArray)(JsonValue*);
    void (*destructor)(JsonValue*);
};

static bool JsonValue_isObject(JsonValue* me) {
    return false;
}

static bool JsonValue_isArray(JsonValue* me) {
    return false;
}

static bool JsonValue_isNumber(JsonValue* me) {
    return false;
}

static bool JsonValue_isString(JsonValue* me) {
    return false;
}

static bool JsonValue_isBoolean(JsonValue* me) {
    return false;
}

static bool JsonValue_isTrue(JsonValue* me) {
    return false;
}

static bool JsonValue_isFalse(JsonValue* me) {
    return false;
}

static bool JsonValue_isNull(JsonValue* me) {
    return false;
}

static JsonObject* JsonValue_asObject(JsonValue* me) {
    assert(0); // "Not an object"
}

static JsonArray* JsonValue_asArray(JsonValue* me) {
    assert(0); // "Not an array"
}

static void JsonValue_destructor(JsonValue* v) {
}

static const struct Vtable JsonValue_vtbl = {
    JsonValue_isObject,
    JsonValue_isArray,
    JsonValue_isNumber,
    JsonValue_isString,
    JsonValue_isBoolean,
    JsonValue_isTrue,
    JsonValue_isFalse,
    JsonValue_isNull,
    JsonValue_asObject,
    JsonValue_asArray,
    JsonValue_destructor
};

static JsonValue* toDelete = 0;

struct JsonValue {
    JsonValue* next;
    struct Vtable* vtbl;
};

struct HashIndexTable {

    int* hashTable;
    int len;
};

static void HashIndexTable_init(struct HashIndexTable* tbl)
{
    tbl->len = 32;
    tbl->hashTable = calloc(sizeof(int),tbl->len);
}

static int HashIndexTable_stringHash(const char* s) {
    // this is not a proper hash, but sufficient for the benchmark,
    // and very portable!
    return strlen(s) * 1402589;
}

static int HashIndexTable_hashSlotFor(struct HashIndexTable* me, const char* element) {
    return HashIndexTable_stringHash(element) & me->len - 1;
}

static int HashIndexTable_get(struct HashIndexTable* me, const char* name) {
    int slot = HashIndexTable_hashSlotFor(me, name);
    // subtract 1, 0 stands for empty
    return (me->hashTable[slot] & 0xff) - 1;
}

static void HashIndexTable_add(struct HashIndexTable* me, const char* name, int index) {
    int slot = HashIndexTable_hashSlotFor(me, name);
    if (index < 0xff) {
        // increment by 1, 0 stands for empty
        me->hashTable[slot] = (index + 1) & 0xff;
    } else {
        me->hashTable[slot] = 0;
    }
}

struct JsonObject {
    JsonValue base;
    Vector* names; // const char*
    Vector* values; // JsonValue*
    struct HashIndexTable table;
};

static bool JsonObject_isObject(JsonValue* me) {
    return true;
}

static JsonObject* JsonObject_asObject(JsonValue* me) {
    return me;
}

static void JsonObject_destructor(JsonObject* me) {
    free(me->table.hashTable);
    for( int i = 0; i < Vector_size(me->names); i++ )
        free(*(char**)Vector_at(me->names,i) );
    Vector_dispose(me->names);
    Vector_dispose(me->values);
}

static const struct Vtable JsonObject_vtbl = {
    JsonObject_isObject,
    JsonValue_isArray,
    JsonValue_isNumber,
    JsonValue_isString,
    JsonValue_isBoolean,
    JsonValue_isTrue,
    JsonValue_isFalse,
    JsonValue_isNull,
    JsonObject_asObject,
    JsonValue_asArray,
    JsonObject_destructor
};

static JsonObject* JsonObject_create()
{
    JsonObject* me = malloc(sizeof(JsonObject));
    me->base.next = toDelete;
    toDelete = me;
    me->base.vtbl = &JsonObject_vtbl;
    me->names = Vector_createDefault(sizeof(const char*));
    me->values = Vector_createDefault(sizeof(JsonValue*));
    HashIndexTable_init(&me->table);
    return me;
}

static JsonObject* JsonObject_add(JsonObject* me, char* name, JsonValue* value) {
    const int len = name ? strlen(name) : 0;
    if ( len == 0 ) {
        assert(0); // "name is null"
    }
    if (value == 0) {
        assert(0); // "value is null"
    }
    HashIndexTable_add(&me->table, name, Vector_size(me->names) );
    Vector_append(me->names, &name);
    Vector_append(me->values, &value);
    return me;
}

static int JsonObject_indexOf(JsonObject* me, const char* name) {
    int index = HashIndexTable_get(&me->table,name);
    if (index != -1 && strcmp(name,*(char**)Vector_at(me->names,index)) == 0) {
        return index;
    }
    assert(0); // "Not needed for benchmark"
}

static JsonValue* JsonObject_get(JsonObject* me, const char* name) {
    const int len = name ? strlen(name) : 0;
    if ( len == 0 ) {
        assert(0); // "name is null"
    }
    const int index = JsonObject_indexOf(me, name);
    return index == -1 ? 0 : *(JsonValue**)Vector_at(me->values,index);
}

static int JsonObject_size(JsonObject* me) {
    return Vector_size(me->names);
}

static bool JsonObject_isEmpty(JsonObject* me) {
    return Vector_isEmpty(me->names);
}

struct JsonArray {
    JsonValue base;
    Vector* values; // JsonValue*
};

static bool JsonArray_isArray(JsonValue* me) {
    return true;
}

static JsonArray* JsonArray_asArray(JsonValue* me) {
    return me;
}

static void JsonArray_destructor(JsonArray* me) {
    Vector_dispose(me->values);
}

static const struct Vtable JsonArray_vtbl = {
    JsonValue_isObject,
    JsonArray_isArray,
    JsonValue_isNumber,
    JsonValue_isString,
    JsonValue_isBoolean,
    JsonValue_isTrue,
    JsonValue_isFalse,
    JsonValue_isNull,
    JsonValue_asObject,
    JsonArray_asArray,
    JsonArray_destructor
};

static JsonArray* JsonArray_create()
{
    JsonArray* me = malloc(sizeof(JsonArray));
    me->base.next = toDelete;
    toDelete = me;
    me->base.vtbl = &JsonArray_vtbl;
    me->values = Vector_createDefault(sizeof(JsonValue*));
    return me;
}

static JsonArray* JsonArray_add(JsonArray* me, JsonValue* value) {
    if (value == 0) {
        assert(0); // "value is null"
    }
    Vector_append(me->values, &value);
    return me;
}

static int JsonArray_size(JsonArray* me) {
    return Vector_size(me->values);
}

static JsonValue* JsonArray_get(JsonArray* me, int index) {
    return *(JsonValue**)Vector_at(me->values, index);
}

struct JsonString {
    JsonValue base;
    char* string;
};

static bool JsonString_isString(JsonValue* me) {
    return true;
}

static void JsonString_destructor(JsonString* me) {
    free(me->string);
}

static const struct Vtable JsonString_vtbl = {
    JsonValue_isObject,
    JsonValue_isArray,
    JsonValue_isNumber,
    JsonString_isString,
    JsonValue_isBoolean,
    JsonValue_isTrue,
    JsonValue_isFalse,
    JsonValue_isNull,
    JsonValue_asObject,
    JsonValue_asArray,
    JsonString_destructor
};

static JsonString* JsonString_create(const char* str)
{
    JsonString* me = malloc(sizeof(JsonString));
    me->base.next = toDelete;
    toDelete = me;
    me->base.vtbl = &JsonString_vtbl;
    me->string = str; // str is allocated and ownership passed here
    return me;
}

struct JsonNumber {
    JsonValue base;
    char* string;
};

static bool JsonNumber_isNumber(JsonValue* me) {
    return true;
}

static void JsonNumber_destructor(JsonNumber* me) {
    free(me->string);
}

static const struct Vtable JsonNumber_vtbl = {
    JsonValue_isObject,
    JsonValue_isArray,
    JsonNumber_isNumber,
    JsonValue_isString,
    JsonValue_isBoolean,
    JsonValue_isTrue,
    JsonValue_isFalse,
    JsonValue_isNull,
    JsonValue_asObject,
    JsonValue_asArray,
    JsonNumber_destructor
};

static JsonNumber* JsonNumber_create(const char* str)
{
    JsonNumber* me = malloc(sizeof(JsonNumber));
    me->base.next = toDelete;
    toDelete = me;
    me->base.vtbl = &JsonNumber_vtbl;
    if (strlen(str) == 0) {
        assert(0); // "string is null"
    }
    me->string = str; // str is allocated and ownership passed here
    return me;
}

static const char JsonNumber_toString(JsonNumber* me) {
    return me->string;
}

struct JsonLiteral  {
    JsonValue base;
    const char* value;
    bool isNull_;
    bool isTrue_;
    bool isFalse_;
};

static bool JsonLiteral_isNull(JsonLiteral* me) {
    return me->isNull_;
}

static bool JsonLiteral_isTrue(JsonLiteral* me) {
    return me->isTrue_;
}

static bool JsonLiteral_isFalse(JsonLiteral* me) {
    return me->isFalse_;
}

static bool JsonLiteral_isBoolean(JsonLiteral* me) {
    return me->isTrue_ || me->isFalse_;
}

static const struct Vtable JsonLiteral_vtbl = {
    JsonValue_isObject,
    JsonValue_isArray,
    JsonValue_isNumber,
    JsonValue_isString,
    JsonLiteral_isBoolean,
    JsonLiteral_isTrue,
    JsonLiteral_isFalse,
    JsonLiteral_isNull,
    JsonValue_asObject,
    JsonValue_asArray,
    JsonValue_destructor
};

static JsonLiteral* JsonLiteral_create(const char* value)
{
    JsonLiteral* me = malloc(sizeof(JsonLiteral));
    me->base.next = toDelete;
    toDelete = me;
    me->base.vtbl = &JsonLiteral_vtbl;
    me->value = value; // str const and not owned
    me->isNull_  = strcmp(value,"null") == 0;
    me->isTrue_  = strcmp(value, "true") == 0;
    me->isFalse_ = strcmp(value, "false") == 0;
    return me;
}

static const char JsonLiteral_toString(JsonLiteral* me) {
    return me->value;
}

struct StringBuffer {
    char* buf;
    int len;
    int pos;
};

static void StringBuffer_init(struct StringBuffer* me) {
    me->buf = 0;
    me->len = 0;
    me->pos = 0;
}

static void StringBuffer_append(struct StringBuffer* me, const char* str, int len)
{
    if( me->buf == 0 )
    {
        me->buf = malloc(2 * len);
        me->len = 2 * len;
        me->pos = len;
        memcpy(me->buf,str,len);
    } else {
        if( me->pos + len + 1 > me->len )
        {
            me->buf = realloc(me->buf,me->len * 2);
            me->len *= 2;
        }
        memcpy(me->buf + me->pos, str, len);
        me->pos += len;
    }
}

typedef struct JsonPureStringParser {
    const char* input;
    int len;
    int index;
    int line;
    int column;
    char current;
    struct StringBuffer captureBuffer;
    int captureStart;
    JsonValue* NULL_;
    JsonValue* TRUE;
    JsonValue* FALSE;
} JsonPureStringParser;

static void JsonPureStringParser_init(JsonPureStringParser* me, const char* string) {
    me->input = string;
    me->len = strlen(me->input);
    me->index = -1;
    me->line = 1;
    me->captureStart = -1;
    me->column = 0;
    StringBuffer_init(&me->captureBuffer);
    me->NULL_ = JsonLiteral_create("null");
    me->TRUE = JsonLiteral_create("true");
    me->FALSE = JsonLiteral_create("false");
    me->current = 0;
}

static JsonPureStringParser_deinit(JsonPureStringParser* me)
{
    if( me->captureBuffer.buf )
        free(me->captureBuffer.buf);
}

static bool JsonPureStringParser_isWhiteSpace(JsonPureStringParser* me) {
    return me->current == ' ' || me->current == '\t' || me->current == '\n' || me->current == '\r';
}

static bool JsonPureStringParser_isDigit(JsonPureStringParser* me) {
    const char ch = me->current;
    return '0' == ch ||
            '1' == ch ||
            '2' == ch ||
            '3' == ch ||
            '4' == ch ||
            '5' == ch ||
            '6' == ch ||
            '7' == ch ||
            '8' == ch ||
            '9' == ch;
}

static void JsonPureStringParser_read(JsonPureStringParser* me) {
    if ( me->current == '\n') {
        me->line++;
        me->column = 0;
    }
    me->index++;
    if (me->index < me->len) {
        me->current = me->input[me->index];
    } else {
        me->current = 0;
    }
}

static bool JsonPureStringParser_readChar(JsonPureStringParser* me, char ch) {
    if (me->current != ch ) {
        return false;
    }
    JsonPureStringParser_read(me);
    return true;
}

static void JsonPureStringParser_readRequiredChar(JsonPureStringParser* me, char ch) {
    if (!JsonPureStringParser_readChar(me, ch)) {
        assert(0); // "expected '" + ch + "'"
    }
}

static bool JsonPureStringParser_readDigit(JsonPureStringParser* me) {
    if (!JsonPureStringParser_isDigit(me)) {
        return false;
    }
    JsonPureStringParser_read(me);
    return true;
}

static void JsonPureStringParser_skipWhiteSpace(JsonPureStringParser* me) {
    while (JsonPureStringParser_isWhiteSpace(me)) {
        JsonPureStringParser_read(me);
    }
}

static void JsonPureStringParser_startCapture(JsonPureStringParser* me) {
    me->captureStart = me->index;
}

static void JsonPureStringParser_pauseCapture(JsonPureStringParser* me) {
    int end = me->current == 0 ? me->index : me->index - 1;
    StringBuffer_append(&me->captureBuffer, me->input + me->captureStart, end + 1 - me->captureStart);
    me->captureStart = -1;
}

static char* JsonPureStringParser_endCapture(JsonPureStringParser* me) {
    int end = me->current == 0 ? me->index : me->index - 1;
    char* captured;
    StringBuffer_append(&me->captureBuffer, me->input + me->captureStart, end + 1 - me->captureStart);
    captured = me->captureBuffer.buf;
    captured[me->captureBuffer.pos] = 0;
    StringBuffer_init( &me->captureBuffer );
    me->captureStart = -1;
    return captured;
}

static void JsonPureStringParser_readEscape(JsonPureStringParser* me) {
    JsonPureStringParser_read(me);
    switch(me->current) {
    case '"':
    case '/':
    case '\\':
        StringBuffer_append(&me->captureBuffer, &me->current, 1);
        break;
    case 'b':
        StringBuffer_append(&me->captureBuffer, "\b", 1);
        break;
    case 'f':
        StringBuffer_append(& me->captureBuffer, "\f", 1);
        break;
    case 'n':
        StringBuffer_append(&me->captureBuffer, "\n", 1);
        break;
    case 'r':
        StringBuffer_append(&me->captureBuffer, "\r", 1);
        break;
    case 't':
        StringBuffer_append(&me->captureBuffer,"\t", 1);
        break;
    default:
        assert(0); // "expected valid escape sequence"
    }
    JsonPureStringParser_read(me);
}

static char* JsonPureStringParser_readStringInternal(JsonPureStringParser* me) {
    JsonPureStringParser_read(me);
    JsonPureStringParser_startCapture(me);
    while (me->current != '"') {
        if (me->current == '\\') {
            JsonPureStringParser_pauseCapture(me);
            JsonPureStringParser_readEscape(me);
            JsonPureStringParser_startCapture(me);
        } else {
            JsonPureStringParser_read(me);
        }
    }
    char* string = JsonPureStringParser_endCapture(me);
    JsonPureStringParser_read(me);
    return string;
}

static bool JsonPureStringParser_readFraction(JsonPureStringParser* me) {
    if (!JsonPureStringParser_readChar(me, '.')) {
        return false;
    }
    if (!JsonPureStringParser_readDigit(me)) {
        assert(0); // "expected digit"
    }
    // Checkstyle: stop
    while (JsonPureStringParser_readDigit(me)) { }
    // Checkstyle: resume
    return true;
}

static bool JsonPureStringParser_readExponent(JsonPureStringParser* me) {
    if (!JsonPureStringParser_readChar(me, 'e') && !JsonPureStringParser_readChar(me, 'E')) {
        return false;
    }
    if (!JsonPureStringParser_readChar(me, '+')) {
        JsonPureStringParser_readChar(me, '-');
    }
    if (!JsonPureStringParser_readDigit(me)) {
        assert(0); // "expected digit"
    }

    // Checkstyle: stop
    while (JsonPureStringParser_readDigit(me)) { }
    // Checkstyle: resume
    return true;
}

static JsonValue* JsonPureStringParser_readNumber(JsonPureStringParser* me) {
    JsonPureStringParser_startCapture(me);
    JsonPureStringParser_readChar(me,'-');
    char firstDigit = me->current;
    if (!JsonPureStringParser_readDigit(me)) {
        assert(0); // "expected digit"
    }
    if (firstDigit != '0') {
        // Checkstyle: stop
        while (JsonPureStringParser_readDigit(me)) { }
        // Checkstyle: resume
    }
    JsonPureStringParser_readFraction(me);
    JsonPureStringParser_readExponent(me);
    return JsonNumber_create(JsonPureStringParser_endCapture(me));
}

static char* JsonPureStringParser_readName(JsonPureStringParser* me) {
    if (me->current != '"') {
        assert(0); // "expected name"
    }
    return JsonPureStringParser_readStringInternal(me);
}

static JsonValue* JsonPureStringParser_readValue(JsonPureStringParser* me);

static JsonArray* JsonPureStringParser_readArray(JsonPureStringParser* me) {
    JsonPureStringParser_read(me);
    JsonArray* array = JsonArray_create();
    JsonPureStringParser_skipWhiteSpace(me);
    if (JsonPureStringParser_readChar(me,']')) {
        return array;
    }
    do {
        JsonPureStringParser_skipWhiteSpace(me);
        JsonArray_add(array, JsonPureStringParser_readValue(me));
        JsonPureStringParser_skipWhiteSpace(me);
    } while (JsonPureStringParser_readChar(me,','));
    if (!JsonPureStringParser_readChar(me,']')) {
        assert(0); // "expected ',' or ']'"
    }
    return array;
}

static JsonObject* JsonPureStringParser_readObject(JsonPureStringParser* me) {
    JsonPureStringParser_read(me);
    JsonObject* object = JsonObject_create();
    JsonPureStringParser_skipWhiteSpace(me);
    if (JsonPureStringParser_readChar(me,'}')) {
        return object;
    }
    do {
        JsonPureStringParser_skipWhiteSpace(me);
        char* name = JsonPureStringParser_readName(me);
        JsonPureStringParser_skipWhiteSpace(me);
        if (!JsonPureStringParser_readChar(me,':')) {
            assert(0); // "expected ':'"
        }
        JsonPureStringParser_skipWhiteSpace(me);
        JsonObject_add(object, name, JsonPureStringParser_readValue(me));
        JsonPureStringParser_skipWhiteSpace(me);
    } while (JsonPureStringParser_readChar(me,','));

    if (!JsonPureStringParser_readChar(me,'}')) {
        assert(0); // "expected ',' or '}'"
    }
    return object;
}

static JsonValue* JsonPureStringParser_readString(JsonPureStringParser* me) {
    return JsonString_create(JsonPureStringParser_readStringInternal(me));
}

static JsonValue* JsonPureStringParser_readNull(JsonPureStringParser* me) {
    JsonPureStringParser_read(me);
    JsonPureStringParser_readRequiredChar(me, 'u');
    JsonPureStringParser_readRequiredChar(me, 'l');
    JsonPureStringParser_readRequiredChar(me, 'l');
    return me->NULL_;
}

static JsonValue* JsonPureStringParser_readTrue(JsonPureStringParser* me) {
    JsonPureStringParser_read(me);
    JsonPureStringParser_readRequiredChar(me, 'r');
    JsonPureStringParser_readRequiredChar(me, 'u');
    JsonPureStringParser_readRequiredChar(me, 'e');
    return me->TRUE;
}

static JsonValue* JsonPureStringParser_readFalse(JsonPureStringParser* me) {
    JsonPureStringParser_read(me);
    JsonPureStringParser_readRequiredChar(me, 'a');
    JsonPureStringParser_readRequiredChar(me, 'l');
    JsonPureStringParser_readRequiredChar(me, 's');
    JsonPureStringParser_readRequiredChar(me, 'e');
    return me->FALSE;
}

static JsonValue* JsonPureStringParser_readValue(JsonPureStringParser* me) {
    switch(me->current) {
    case 'n':
        return JsonPureStringParser_readNull(me);
    case 't':
        return JsonPureStringParser_readTrue(me);
    case 'f':
        return JsonPureStringParser_readFalse(me);
    case '"':
        return JsonPureStringParser_readString(me);
    case '[':
        return JsonPureStringParser_readArray(me);
    case '{':
        return JsonPureStringParser_readObject(me);
    case '-':
    case '0':
    case '1':
    case '2':
    case '3':
    case '4':
    case '5':
    case '6':
    case '7':
    case '8':
    case '9':
        return JsonPureStringParser_readNumber(me);
    default:
        assert(0); // "expected value"
    }
}

static bool JsonPureStringParser_isEndOfText(JsonPureStringParser* me) {
    return me->current == 0;
}

static JsonValue* JsonPureStringParser_parse(JsonPureStringParser* me) {
    JsonPureStringParser_read(me);
    JsonPureStringParser_skipWhiteSpace(me);
    JsonValue* result = JsonPureStringParser_readValue(me);
    JsonPureStringParser_skipWhiteSpace(me);
    if (!JsonPureStringParser_isEndOfText(me)) {
        assert(0); // "Unexpected character"
    }
    return result;
}

static void JsonValue_delete(JsonValue*o)
{
    if( o->next )
        JsonValue_delete(o->next);
    o->vtbl->destructor(o);
    free(o);
}

static const char* rapBenchmarkMinified = "{\"head\":{\"requestCounter\":4},\"operations\":[[\"destroy\",\"w54\"],[\"set\",\"w2\",{\"activeControl\":\"w99\"}],[\"set\",\"w21\",{\"customVariant\":\"variant_navigation\"}],[\"set\",\"w28\",{\"customVariant\":\"variant_selected\"}],[\"set\",\"w53\",{\"children\":[\"w95\"]}],[\"create\",\"w95\",\"rwt.widgets.Composite\",{\"parent\":\"w53\",\"style\":[\"NONE\"],\"bounds\":[0,0,1008,586],\"children\":[\"w96\",\"w97\"],\"tabIndex\":-1,\"clientArea\":[0,0,1008,586]}],[\"create\",\"w96\",\"rwt.widgets.Label\",{\"parent\":\"w95\",\"style\":[\"NONE\"],\"bounds\":[10,30,112,26],\"tabIndex\":-1,\"customVariant\":\"variant_pageHeadline\",\"text\":\"TableViewer\"}],[\"create\",\"w97\",\"rwt.widgets.Composite\",{\"parent\":\"w95\",\"style\":[\"NONE\"],\"bounds\":[0,61,1008,525],\"children\":[\"w98\",\"w99\",\"w226\",\"w228\"],\"tabIndex\":-1,\"clientArea\":[0,0,1008,525]}],[\"create\",\"w98\",\"rwt.widgets.Text\",{\"parent\":\"w97\",\"style\":[\"LEFT\",\"SINGLE\",\"BORDER\"],\"bounds\":[10,10,988,32],\"tabIndex\":22,\"activeKeys\":[\"#13\",\"#27\",\"#40\"]}],[\"listen\",\"w98\",{\"KeyDown\":true,\"Modify\":true}],[\"create\",\"w99\",\"rwt.widgets.Grid\",{\"parent\":\"w97\",\"style\":[\"SINGLE\",\"BORDER\"],\"appearance\":\"table\",\"indentionWidth\":0,\"treeColumn\":-1,\"markupEnabled\":false}],[\"create\",\"w100\",\"rwt.widgets.ScrollBar\",{\"parent\":\"w99\",\"style\":[\"HORIZONTAL\"]}],[\"create\",\"w101\",\"rwt.widgets.ScrollBar\",{\"parent\":\"w99\",\"style\":[\"VERTICAL\"]}],[\"set\",\"w99\",{\"bounds\":[10,52,988,402],\"children\":[],\"tabIndex\":23,\"activeKeys\":[\"CTRL+#70\",\"CTRL+#78\",\"CTRL+#82\",\"CTRL+#89\",\"CTRL+#83\",\"CTRL+#71\",\"CTRL+#69\"],\"cancelKeys\":[\"CTRL+#70\",\"CTRL+#78\",\"CTRL+#82\",\"CTRL+#89\",\"CTRL+#83\",\"CTRL+#71\",\"CTRL+#69\"]}],[\"listen\",\"w99\",{\"MouseDown\":true,\"MouseUp\":true,\"MouseDoubleClick\":true,\"KeyDown\":true}],[\"set\",\"w99\",{\"itemCount\":118,\"itemHeight\":28,\"itemMetrics\":[[0,0,50,3,0,3,44],[1,50,50,53,0,53,44],[2,100,140,103,0,103,134],[3,240,180,243,0,243,174],[4,420,50,423,0,423,44],[5,470,50,473,0,473,44]],\"columnCount\":6,\"headerHeight\":35,\"headerVisible\":true,\"linesVisible\":true,\"focusItem\":\"w108\",\"selection\":[\"w108\"]}],[\"listen\",\"w99\",{\"Selection\":true,\"DefaultSelection\":true}],[\"set\",\"w99\",{\"enableCellToolTip\":true}],[\"listen\",\"w100\",{\"Selection\":true}],[\"set\",\"w101\",{\"visibility\":true}],[\"listen\",\"w101\",{\"Selection\":true}],[\"create\",\"w102\",\"rwt.widgets.GridColumn\",{\"parent\":\"w99\",\"text\":\"Nr.\",\"width\":50,\"moveable\":true}],[\"listen\",\"w102\",{\"Selection\":true}],[\"create\",\"w103\",\"rwt.widgets.GridColumn\",{\"parent\":\"w99\",\"text\":\"Sym.\",\"index\":1,\"left\":50,\"width\":50,\"moveable\":true}],[\"listen\",\"w103\",{\"Selection\":true}],[\"create\",\"w104\",\"rwt.widgets.GridColumn\",{\"parent\":\"w99\",\"text\":\"Name\",\"index\":2,\"left\":100,\"width\":140,\"moveable\":true}],[\"listen\",\"w104\",{\"Selection\":true}],[\"create\",\"w105\",\"rwt.widgets.GridColumn\",{\"parent\":\"w99\",\"text\":\"Series\",\"index\":3,\"left\":240,\"width\":180,\"moveable\":true}],[\"listen\",\"w105\",{\"Selection\":true}],[\"create\",\"w106\",\"rwt.widgets.GridColumn\",{\"parent\":\"w99\",\"text\":\"Group\",\"index\":4,\"left\":420,\"width\":50,\"moveable\":true}],[\"listen\",\"w106\",{\"Selection\":true}],[\"create\",\"w107\",\"rwt.widgets.GridColumn\",{\"parent\":\"w99\",\"text\":\"Period\",\"index\":5,\"left\":470,\"width\":50,\"moveable\":true}],[\"listen\",\"w107\",{\"Selection\":true}],[\"create\",\"w108\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":0,\"texts\":[\"1\",\"H\",\"Hydrogen\",\"Nonmetal\",\"1\",\"1\"],\"cellBackgrounds\":[null,null,null,[138,226,52,255],null,null]}],[\"create\",\"w109\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":1,\"texts\":[\"2\",\"He\",\"Helium\",\"Noble gas\",\"18\",\"1\"],\"cellBackgrounds\":[null,null,null,[114,159,207,255],null,null]}],[\"create\",\"w110\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":2,\"texts\":[\"3\",\"Li\",\"Lithium\",\"Alkali metal\",\"1\",\"2\"],\"cellBackgrounds\":[null,null,null,[239,41,41,255],null,null]}],[\"create\",\"w111\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":3,\"texts\":[\"4\",\"Be\",\"Beryllium\",\"Alkaline earth metal\",\"2\",\"2\"],\"cellBackgrounds\":[null,null,null,[233,185,110,255],null,null]}],[\"create\",\"w112\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":4,\"texts\":[\"5\",\"B\",\"Boron\",\"Metalloid\",\"13\",\"2\"],\"cellBackgrounds\":[null,null,null,[156,159,153,255],null,null]}],[\"create\",\"w113\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":5,\"texts\":[\"6\",\"C\",\"Carbon\",\"Nonmetal\",\"14\",\"2\"],\"cellBackgrounds\":[null,null,null,[138,226,52,255],null,null]}],[\"create\",\"w114\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":6,\"texts\":[\"7\",\"N\",\"Nitrogen\",\"Nonmetal\",\"15\",\"2\"],\"cellBackgrounds\":[null,null,null,[138,226,52,255],null,null]}],[\"create\",\"w115\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":7,\"texts\":[\"8\",\"O\",\"Oxygen\",\"Nonmetal\",\"16\",\"2\"],\"cellBackgrounds\":[null,null,null,[138,226,52,255],null,null]}],[\"create\",\"w116\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":8,\"texts\":[\"9\",\"F\",\"Fluorine\",\"Halogen\",\"17\",\"2\"],\"cellBackgrounds\":[null,null,null,[252,233,79,255],null,null]}],[\"create\",\"w117\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":9,\"texts\":[\"10\",\"Ne\",\"Neon\",\"Noble gas\",\"18\",\"2\"],\"cellBackgrounds\":[null,null,null,[114,159,207,255],null,null]}],[\"create\",\"w118\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":10,\"texts\":[\"11\",\"Na\",\"Sodium\",\"Alkali metal\",\"1\",\"3\"],\"cellBackgrounds\":[null,null,null,[239,41,41,255],null,null]}],[\"create\",\"w119\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":11,\"texts\":[\"12\",\"Mg\",\"Magnesium\",\"Alkaline earth metal\",\"2\",\"3\"],\"cellBackgrounds\":[null,null,null,[233,185,110,255],null,null]}],[\"create\",\"w120\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":12,\"texts\":[\"13\",\"Al\",\"Aluminium\",\"Poor metal\",\"13\",\"3\"],\"cellBackgrounds\":[null,null,null,[238,238,236,255],null,null]}],[\"create\",\"w121\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":13,\"texts\":[\"14\",\"Si\",\"Silicon\",\"Metalloid\",\"14\",\"3\"],\"cellBackgrounds\":[null,null,null,[156,159,153,255],null,null]}],[\"create\",\"w122\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":14,\"texts\":[\"15\",\"P\",\"Phosphorus\",\"Nonmetal\",\"15\",\"3\"],\"cellBackgrounds\":[null,null,null,[138,226,52,255],null,null]}],[\"create\",\"w123\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":15,\"texts\":[\"16\",\"S\",\"Sulfur\",\"Nonmetal\",\"16\",\"3\"],\"cellBackgrounds\":[null,null,null,[138,226,52,255],null,null]}],[\"create\",\"w124\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":16,\"texts\":[\"17\",\"Cl\",\"Chlorine\",\"Halogen\",\"17\",\"3\"],\"cellBackgrounds\":[null,null,null,[252,233,79,255],null,null]}],[\"create\",\"w125\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":17,\"texts\":[\"18\",\"Ar\",\"Argon\",\"Noble gas\",\"18\",\"3\"],\"cellBackgrounds\":[null,null,null,[114,159,207,255],null,null]}],[\"create\",\"w126\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":18,\"texts\":[\"19\",\"K\",\"Potassium\",\"Alkali metal\",\"1\",\"4\"],\"cellBackgrounds\":[null,null,null,[239,41,41,255],null,null]}],[\"create\",\"w127\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":19,\"texts\":[\"20\",\"Ca\",\"Calcium\",\"Alkaline earth metal\",\"2\",\"4\"],\"cellBackgrounds\":[null,null,null,[233,185,110,255],null,null]}],[\"create\",\"w128\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":20,\"texts\":[\"21\",\"Sc\",\"Scandium\",\"Transition metal\",\"3\",\"4\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w129\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":21,\"texts\":[\"22\",\"Ti\",\"Titanium\",\"Transition metal\",\"4\",\"4\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w130\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":22,\"texts\":[\"23\",\"V\",\"Vanadium\",\"Transition metal\",\"5\",\"4\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w131\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":23,\"texts\":[\"24\",\"Cr\",\"Chromium\",\"Transition metal\",\"6\",\"4\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w132\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":24,\"texts\":[\"25\",\"Mn\",\"Manganese\",\"Transition metal\",\"7\",\"4\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w133\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":25,\"texts\":[\"26\",\"Fe\",\"Iron\",\"Transition metal\",\"8\",\"4\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w134\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":26,\"texts\":[\"27\",\"Co\",\"Cobalt\",\"Transition metal\",\"9\",\"4\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w135\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":27,\"texts\":[\"28\",\"Ni\",\"Nickel\",\"Transition metal\",\"10\",\"4\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w136\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":28,\"texts\":[\"29\",\"Cu\",\"Copper\",\"Transition metal\",\"11\",\"4\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w137\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":29,\"texts\":[\"30\",\"Zn\",\"Zinc\",\"Transition metal\",\"12\",\"4\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w138\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":30,\"texts\":[\"31\",\"Ga\",\"Gallium\",\"Poor metal\",\"13\",\"4\"],\"cellBackgrounds\":[null,null,null,[238,238,236,255],null,null]}],[\"create\",\"w139\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":31,\"texts\":[\"32\",\"Ge\",\"Germanium\",\"Metalloid\",\"14\",\"4\"],\"cellBackgrounds\":[null,null,null,[156,159,153,255],null,null]}],[\"create\",\"w140\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":32,\"texts\":[\"33\",\"As\",\"Arsenic\",\"Metalloid\",\"15\",\"4\"],\"cellBackgrounds\":[null,null,null,[156,159,153,255],null,null]}],[\"create\",\"w141\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":33,\"texts\":[\"34\",\"Se\",\"Selenium\",\"Nonmetal\",\"16\",\"4\"],\"cellBackgrounds\":[null,null,null,[138,226,52,255],null,null]}],[\"create\",\"w142\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":34,\"texts\":[\"35\",\"Br\",\"Bromine\",\"Halogen\",\"17\",\"4\"],\"cellBackgrounds\":[null,null,null,[252,233,79,255],null,null]}],[\"create\",\"w143\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":35,\"texts\":[\"36\",\"Kr\",\"Krypton\",\"Noble gas\",\"18\",\"4\"],\"cellBackgrounds\":[null,null,null,[114,159,207,255],null,null]}],[\"create\",\"w144\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":36,\"texts\":[\"37\",\"Rb\",\"Rubidium\",\"Alkali metal\",\"1\",\"5\"],\"cellBackgrounds\":[null,null,null,[239,41,41,255],null,null]}],[\"create\",\"w145\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":37,\"texts\":[\"38\",\"Sr\",\"Strontium\",\"Alkaline earth metal\",\"2\",\"5\"],\"cellBackgrounds\":[null,null,null,[233,185,110,255],null,null]}],[\"create\",\"w146\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":38,\"texts\":[\"39\",\"Y\",\"Yttrium\",\"Transition metal\",\"3\",\"5\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w147\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":39,\"texts\":[\"40\",\"Zr\",\"Zirconium\",\"Transition metal\",\"4\",\"5\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w148\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":40,\"texts\":[\"41\",\"Nb\",\"Niobium\",\"Transition metal\",\"5\",\"5\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w149\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":41,\"texts\":[\"42\",\"Mo\",\"Molybdenum\",\"Transition metal\",\"6\",\"5\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w150\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":42,\"texts\":[\"43\",\"Tc\",\"Technetium\",\"Transition metal\",\"7\",\"5\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w151\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":43,\"texts\":[\"44\",\"Ru\",\"Ruthenium\",\"Transition metal\",\"8\",\"5\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w152\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":44,\"texts\":[\"45\",\"Rh\",\"Rhodium\",\"Transition metal\",\"9\",\"5\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w153\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":45,\"texts\":[\"46\",\"Pd\",\"Palladium\",\"Transition metal\",\"10\",\"5\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w154\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":46,\"texts\":[\"47\",\"Ag\",\"Silver\",\"Transition metal\",\"11\",\"5\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w155\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":47,\"texts\":[\"48\",\"Cd\",\"Cadmium\",\"Transition metal\",\"12\",\"5\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w156\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":48,\"texts\":[\"49\",\"In\",\"Indium\",\"Poor metal\",\"13\",\"5\"],\"cellBackgrounds\":[null,null,null,[238,238,236,255],null,null]}],[\"create\",\"w157\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":49,\"texts\":[\"50\",\"Sn\",\"Tin\",\"Poor metal\",\"14\",\"5\"],\"cellBackgrounds\":[null,null,null,[238,238,236,255],null,null]}],[\"create\",\"w158\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":50,\"texts\":[\"51\",\"Sb\",\"Antimony\",\"Metalloid\",\"15\",\"5\"],\"cellBackgrounds\":[null,null,null,[156,159,153,255],null,null]}],[\"create\",\"w159\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":51,\"texts\":[\"52\",\"Te\",\"Tellurium\",\"Metalloid\",\"16\",\"5\"],\"cellBackgrounds\":[null,null,null,[156,159,153,255],null,null]}],[\"create\",\"w160\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":52,\"texts\":[\"53\",\"I\",\"Iodine\",\"Halogen\",\"17\",\"5\"],\"cellBackgrounds\":[null,null,null,[252,233,79,255],null,null]}],[\"create\",\"w161\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":53,\"texts\":[\"54\",\"Xe\",\"Xenon\",\"Noble gas\",\"18\",\"5\"],\"cellBackgrounds\":[null,null,null,[114,159,207,255],null,null]}],[\"create\",\"w162\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":54,\"texts\":[\"55\",\"Cs\",\"Caesium\",\"Alkali metal\",\"1\",\"6\"],\"cellBackgrounds\":[null,null,null,[239,41,41,255],null,null]}],[\"create\",\"w163\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":55,\"texts\":[\"56\",\"Ba\",\"Barium\",\"Alkaline earth metal\",\"2\",\"6\"],\"cellBackgrounds\":[null,null,null,[233,185,110,255],null,null]}],[\"create\",\"w164\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":56,\"texts\":[\"57\",\"La\",\"Lanthanum\",\"Lanthanide\",\"3\",\"6\"],\"cellBackgrounds\":[null,null,null,[173,127,168,255],null,null]}],[\"create\",\"w165\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":57,\"texts\":[\"58\",\"Ce\",\"Cerium\",\"Lanthanide\",\"3\",\"6\"],\"cellBackgrounds\":[null,null,null,[173,127,168,255],null,null]}],[\"create\",\"w166\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":58,\"texts\":[\"59\",\"Pr\",\"Praseodymium\",\"Lanthanide\",\"3\",\"6\"],\"cellBackgrounds\":[null,null,null,[173,127,168,255],null,null]}],[\"create\",\"w167\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":59,\"texts\":[\"60\",\"Nd\",\"Neodymium\",\"Lanthanide\",\"3\",\"6\"],\"cellBackgrounds\":[null,null,null,[173,127,168,255],null,null]}],[\"create\",\"w168\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":60,\"texts\":[\"61\",\"Pm\",\"Promethium\",\"Lanthanide\",\"3\",\"6\"],\"cellBackgrounds\":[null,null,null,[173,127,168,255],null,null]}],[\"create\",\"w169\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":61,\"texts\":[\"62\",\"Sm\",\"Samarium\",\"Lanthanide\",\"3\",\"6\"],\"cellBackgrounds\":[null,null,null,[173,127,168,255],null,null]}],[\"create\",\"w170\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":62,\"texts\":[\"63\",\"Eu\",\"Europium\",\"Lanthanide\",\"3\",\"6\"],\"cellBackgrounds\":[null,null,null,[173,127,168,255],null,null]}],[\"create\",\"w171\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":63,\"texts\":[\"64\",\"Gd\",\"Gadolinium\",\"Lanthanide\",\"3\",\"6\"],\"cellBackgrounds\":[null,null,null,[173,127,168,255],null,null]}],[\"create\",\"w172\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":64,\"texts\":[\"65\",\"Tb\",\"Terbium\",\"Lanthanide\",\"3\",\"6\"],\"cellBackgrounds\":[null,null,null,[173,127,168,255],null,null]}],[\"create\",\"w173\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":65,\"texts\":[\"66\",\"Dy\",\"Dysprosium\",\"Lanthanide\",\"3\",\"6\"],\"cellBackgrounds\":[null,null,null,[173,127,168,255],null,null]}],[\"create\",\"w174\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":66,\"texts\":[\"67\",\"Ho\",\"Holmium\",\"Lanthanide\",\"3\",\"6\"],\"cellBackgrounds\":[null,null,null,[173,127,168,255],null,null]}],[\"create\",\"w175\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":67,\"texts\":[\"68\",\"Er\",\"Erbium\",\"Lanthanide\",\"3\",\"6\"],\"cellBackgrounds\":[null,null,null,[173,127,168,255],null,null]}],[\"create\",\"w176\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":68,\"texts\":[\"69\",\"Tm\",\"Thulium\",\"Lanthanide\",\"3\",\"6\"],\"cellBackgrounds\":[null,null,null,[173,127,168,255],null,null]}],[\"create\",\"w177\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":69,\"texts\":[\"70\",\"Yb\",\"Ytterbium\",\"Lanthanide\",\"3\",\"6\"],\"cellBackgrounds\":[null,null,null,[173,127,168,255],null,null]}],[\"create\",\"w178\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":70,\"texts\":[\"71\",\"Lu\",\"Lutetium\",\"Lanthanide\",\"3\",\"6\"],\"cellBackgrounds\":[null,null,null,[173,127,168,255],null,null]}],[\"create\",\"w179\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":71,\"texts\":[\"72\",\"Hf\",\"Hafnium\",\"Transition metal\",\"4\",\"6\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w180\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":72,\"texts\":[\"73\",\"Ta\",\"Tantalum\",\"Transition metal\",\"5\",\"6\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w181\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":73,\"texts\":[\"74\",\"W\",\"Tungsten\",\"Transition metal\",\"6\",\"6\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w182\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":74,\"texts\":[\"75\",\"Re\",\"Rhenium\",\"Transition metal\",\"7\",\"6\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w183\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":75,\"texts\":[\"76\",\"Os\",\"Osmium\",\"Transition metal\",\"8\",\"6\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w184\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":76,\"texts\":[\"77\",\"Ir\",\"Iridium\",\"Transition metal\",\"9\",\"6\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w185\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":77,\"texts\":[\"78\",\"Pt\",\"Platinum\",\"Transition metal\",\"10\",\"6\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w186\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":78,\"texts\":[\"79\",\"Au\",\"Gold\",\"Transition metal\",\"11\",\"6\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w187\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":79,\"texts\":[\"80\",\"Hg\",\"Mercury\",\"Transition metal\",\"12\",\"6\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w188\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":80,\"texts\":[\"81\",\"Tl\",\"Thallium\",\"Poor metal\",\"13\",\"6\"],\"cellBackgrounds\":[null,null,null,[238,238,236,255],null,null]}],[\"create\",\"w189\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":81,\"texts\":[\"82\",\"Pb\",\"Lead\",\"Poor metal\",\"14\",\"6\"],\"cellBackgrounds\":[null,null,null,[238,238,236,255],null,null]}],[\"create\",\"w190\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":82,\"texts\":[\"83\",\"Bi\",\"Bismuth\",\"Poor metal\",\"15\",\"6\"],\"cellBackgrounds\":[null,null,null,[238,238,236,255],null,null]}],[\"create\",\"w191\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":83,\"texts\":[\"84\",\"Po\",\"Polonium\",\"Metalloid\",\"16\",\"6\"],\"cellBackgrounds\":[null,null,null,[156,159,153,255],null,null]}],[\"create\",\"w192\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":84,\"texts\":[\"85\",\"At\",\"Astatine\",\"Halogen\",\"17\",\"6\"],\"cellBackgrounds\":[null,null,null,[252,233,79,255],null,null]}],[\"create\",\"w193\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":85,\"texts\":[\"86\",\"Rn\",\"Radon\",\"Noble gas\",\"18\",\"6\"],\"cellBackgrounds\":[null,null,null,[114,159,207,255],null,null]}],[\"create\",\"w194\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":86,\"texts\":[\"87\",\"Fr\",\"Francium\",\"Alkali metal\",\"1\",\"7\"],\"cellBackgrounds\":[null,null,null,[239,41,41,255],null,null]}],[\"create\",\"w195\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":87,\"texts\":[\"88\",\"Ra\",\"Radium\",\"Alkaline earth metal\",\"2\",\"7\"],\"cellBackgrounds\":[null,null,null,[233,185,110,255],null,null]}],[\"create\",\"w196\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":88,\"texts\":[\"89\",\"Ac\",\"Actinium\",\"Actinide\",\"3\",\"7\"],\"cellBackgrounds\":[null,null,null,[173,127,168,255],null,null]}],[\"create\",\"w197\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":89,\"texts\":[\"90\",\"Th\",\"Thorium\",\"Actinide\",\"3\",\"7\"],\"cellBackgrounds\":[null,null,null,[173,127,168,255],null,null]}],[\"create\",\"w198\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":90,\"texts\":[\"91\",\"Pa\",\"Protactinium\",\"Actinide\",\"3\",\"7\"],\"cellBackgrounds\":[null,null,null,[173,127,168,255],null,null]}],[\"create\",\"w199\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":91,\"texts\":[\"92\",\"U\",\"Uranium\",\"Actinide\",\"3\",\"7\"],\"cellBackgrounds\":[null,null,null,[173,127,168,255],null,null]}],[\"create\",\"w200\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":92,\"texts\":[\"93\",\"Np\",\"Neptunium\",\"Actinide\",\"3\",\"7\"],\"cellBackgrounds\":[null,null,null,[173,127,168,255],null,null]}],[\"create\",\"w201\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":93,\"texts\":[\"94\",\"Pu\",\"Plutonium\",\"Actinide\",\"3\",\"7\"],\"cellBackgrounds\":[null,null,null,[173,127,168,255],null,null]}],[\"create\",\"w202\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":94,\"texts\":[\"95\",\"Am\",\"Americium\",\"Actinide\",\"3\",\"7\"],\"cellBackgrounds\":[null,null,null,[173,127,168,255],null,null]}],[\"create\",\"w203\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":95,\"texts\":[\"96\",\"Cm\",\"Curium\",\"Actinide\",\"3\",\"7\"],\"cellBackgrounds\":[null,null,null,[173,127,168,255],null,null]}],[\"create\",\"w204\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":96,\"texts\":[\"97\",\"Bk\",\"Berkelium\",\"Actinide\",\"3\",\"7\"],\"cellBackgrounds\":[null,null,null,[173,127,168,255],null,null]}],[\"create\",\"w205\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":97,\"texts\":[\"98\",\"Cf\",\"Californium\",\"Actinide\",\"3\",\"7\"],\"cellBackgrounds\":[null,null,null,[173,127,168,255],null,null]}],[\"create\",\"w206\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":98,\"texts\":[\"99\",\"Es\",\"Einsteinium\",\"Actinide\",\"3\",\"7\"],\"cellBackgrounds\":[null,null,null,[173,127,168,255],null,null]}],[\"create\",\"w207\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":99,\"texts\":[\"100\",\"Fm\",\"Fermium\",\"Actinide\",\"3\",\"7\"],\"cellBackgrounds\":[null,null,null,[173,127,168,255],null,null]}],[\"create\",\"w208\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":100,\"texts\":[\"101\",\"Md\",\"Mendelevium\",\"Actinide\",\"3\",\"7\"],\"cellBackgrounds\":[null,null,null,[173,127,168,255],null,null]}],[\"create\",\"w209\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":101,\"texts\":[\"102\",\"No\",\"Nobelium\",\"Actinide\",\"3\",\"7\"],\"cellBackgrounds\":[null,null,null,[173,127,168,255],null,null]}],[\"create\",\"w210\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":102,\"texts\":[\"103\",\"Lr\",\"Lawrencium\",\"Actinide\",\"3\",\"7\"],\"cellBackgrounds\":[null,null,null,[173,127,168,255],null,null]}],[\"create\",\"w211\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":103,\"texts\":[\"104\",\"Rf\",\"Rutherfordium\",\"Transition metal\",\"4\",\"7\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w212\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":104,\"texts\":[\"105\",\"Db\",\"Dubnium\",\"Transition metal\",\"5\",\"7\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w213\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":105,\"texts\":[\"106\",\"Sg\",\"Seaborgium\",\"Transition metal\",\"6\",\"7\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w214\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":106,\"texts\":[\"107\",\"Bh\",\"Bohrium\",\"Transition metal\",\"7\",\"7\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w215\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":107,\"texts\":[\"108\",\"Hs\",\"Hassium\",\"Transition metal\",\"8\",\"7\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w216\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":108,\"texts\":[\"109\",\"Mt\",\"Meitnerium\",\"Transition metal\",\"9\",\"7\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w217\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":109,\"texts\":[\"110\",\"Ds\",\"Darmstadtium\",\"Transition metal\",\"10\",\"7\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w218\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":110,\"texts\":[\"111\",\"Rg\",\"Roentgenium\",\"Transition metal\",\"11\",\"7\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w219\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":111,\"texts\":[\"112\",\"Uub\",\"Ununbium\",\"Transition metal\",\"12\",\"7\"],\"cellBackgrounds\":[null,null,null,[252,175,62,255],null,null]}],[\"create\",\"w220\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":112,\"texts\":[\"113\",\"Uut\",\"Ununtrium\",\"Poor metal\",\"13\",\"7\"],\"cellBackgrounds\":[null,null,null,[238,238,236,255],null,null]}],[\"create\",\"w221\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":113,\"texts\":[\"114\",\"Uuq\",\"Ununquadium\",\"Poor metal\",\"14\",\"7\"],\"cellBackgrounds\":[null,null,null,[238,238,236,255],null,null]}],[\"create\",\"w222\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":114,\"texts\":[\"115\",\"Uup\",\"Ununpentium\",\"Poor metal\",\"15\",\"7\"],\"cellBackgrounds\":[null,null,null,[238,238,236,255],null,null]}],[\"create\",\"w223\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":115,\"texts\":[\"116\",\"Uuh\",\"Ununhexium\",\"Poor metal\",\"16\",\"7\"],\"cellBackgrounds\":[null,null,null,[238,238,236,255],null,null]}],[\"create\",\"w224\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":116,\"texts\":[\"117\",\"Uus\",\"Ununseptium\",\"Halogen\",\"17\",\"7\"],\"cellBackgrounds\":[null,null,null,[252,233,79,255],null,null]}],[\"create\",\"w225\",\"rwt.widgets.GridItem\",{\"parent\":\"w99\",\"index\":117,\"texts\":[\"118\",\"Uuo\",\"Ununoctium\",\"Noble gas\",\"18\",\"7\"],\"cellBackgrounds\":[null,null,null,[114,159,207,255],null,null]}],[\"create\",\"w226\",\"rwt.widgets.Composite\",{\"parent\":\"w97\",\"style\":[\"BORDER\"],\"bounds\":[10,464,988,25],\"children\":[\"w227\"],\"tabIndex\":-1,\"clientArea\":[0,0,986,23]}],[\"create\",\"w227\",\"rwt.widgets.Label\",{\"parent\":\"w226\",\"style\":[\"NONE\"],\"bounds\":[10,10,966,3],\"tabIndex\":-1,\"text\":\"Hydrogen (H)\"}],[\"create\",\"w228\",\"rwt.widgets.Label\",{\"parent\":\"w97\",\"style\":[\"WRAP\"],\"bounds\":[10,499,988,16],\"tabIndex\":-1,\"foreground\":[150,150,150,255],\"font\":[[\"Verdana\",\"Lucida Sans\",\"Arial\",\"Helvetica\",\"sans-serif\"],10,false,false],\"text\":\"Shortcuts: [CTRL+F] - Filter | Sort by: [CTRL+R] - Number, [CTRL+Y] - Symbol, [CTRL+N] - Name, [CTRL+S] - Series, [CTRL+G] - Group, [CTRL+E] - Period\"}],[\"set\",\"w1\",{\"focusControl\":\"w99\"}],[\"call\",\"rwt.client.BrowserNavigation\",\"addToHistory\",{\"entries\":[[\"tableviewer\",\"TableViewer\"]]}]]}";
static JsonValue* result = 0;

static int benchmark(Benchmark* me)
{
    JsonPureStringParser p;
    JsonPureStringParser_init(&p,rapBenchmarkMinified);
    result = JsonPureStringParser_parse(&p);
    JsonPureStringParser_deinit(&p);
    return 0;
}

static bool verifyResult(Benchmark* me, int r)
{
    bool res = false;
    if( result == 0 )
        goto cleanup;
    if (!result->vtbl->isObject(result))
        goto cleanup;
    JsonValue* tmp = JsonObject_get(result->vtbl->asObject(result),"head");
    if (!tmp->vtbl->isObject(tmp))
        goto cleanup;
    tmp = tmp = JsonObject_get(result->vtbl->asObject(result),"operations");
    if (!tmp->vtbl->isArray(tmp))
        goto cleanup;
    tmp = JsonObject_get(result->vtbl->asObject(result),"operations");
    res = JsonArray_size(tmp->vtbl->asArray(tmp)) == 156;
cleanup:
    JsonValue_delete(toDelete);
    toDelete = 0;
    return res;
}

Benchmark*Json_create()
{
    Benchmark* bench = (Benchmark*)malloc(sizeof(Benchmark));
    bench->benchmark = benchmark;
    bench->verifyResult = verifyResult;
    bench->dispose = 0;
    bench->innerBenchmarkLoop = 0;
    return bench;
}
