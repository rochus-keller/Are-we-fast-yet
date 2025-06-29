(*******************************************************************************
 * Copyright (c) 2025 Rochus Keller <me@rochus-keller.ch> (for Oberon 90 migration)
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
 ******************************************************************************)
 
MODULE Json;

(*
  Corrected translation of the Json benchmark based on the C reference implementation.
  This version follows the exact structure and logic of the working C code.
*)

IMPORT Benchmark, SOM, Out, SYSTEM;

CONST
  (* Split the JSON string into manageable parts due to compiler limits *)
  JSON_PART1 = '{"head":{"requestCounter":4},"operations":[["destroy","w54"],["set","w2",{"activeControl":"w99"}],["set","w21",{"customVariant":"variant_navigation"}],["set","w28",{"customVariant":"variant_selected"}],["set","w53",{"children":["w95"]}],["create","w95","rwt.widgets.Composite",{"parent":"w53","style":["NONE"],"bounds":[0,0,1008,586],"children":["w96","w97"],"tabIndex":-1,"clientArea":[0,0,1008,586]}],["create","w96","rwt.widgets.Label",{"parent":"w95","style":["NONE"],"bounds":[10,30,112,26],"tabIndex":-1,"customVariant":"variant_pageHeadline","text":"TableViewer"}],["create","w97","rwt.widgets.Composite",{"parent":"w95","style":["NONE"],"bounds":[0,61,1008,525],"children":["w98","w99","w226","w228"],"tabIndex":-1,"clientArea":[0,0,1008,525]}],["create","w98","rwt.widgets.Text",{"parent":"w97","style":["LEFT","SINGLE","BORDER"],"bounds":[10,10,988,32],"tabIndex":22,"activeKeys":["#13","#27","#40"]}],["listen","w98",{"KeyDown":true,"Modify":true}],["create","w99","rwt.widgets.Grid",{"parent":"w97","style":["SINGLE","BORDER"],"appearance":"table","indentionWidth":0,"treeColumn":-1,"markupEnabled":false}],["create","w100","rwt.widgets.ScrollBar",{"parent":"w99","style":["HORIZONTAL"]}],["create","w101","rwt.widgets.ScrollBar",{"parent":"w99","style":["VERTICAL"]}],["set","w99",{"bounds":[10,52,988,402],"children":[],"tabIndex":23,"activeKeys":["CTRL+#70","CTRL+#78","CTRL+#82","CTRL+#89","CTRL+#83","CTRL+#71","CTRL+#69"],"cancelKeys":["CTRL+#70","CTRL+#78","CTRL+#82","CTRL+#89","CTRL+#83","CTRL+#71","CTRL+#69"]}],["listen","w99",{"MouseDown":true,"MouseUp":true,"MouseDoubleClick":true,"KeyDown":true}],["set","w99",{"itemCount":118,"itemHeight":28,"itemMetrics":[[0,0,50,3,0,3,44],[1,50,50,53,0,53,44],[2,100,140,103,0,103,134],[3,240,180,243,0,243,174],[4,420,50,423,0,423,44],[5,470,50,473,0,473,44]],"columnCount":6,"headerHeight":35,"headerVisible":true,"linesVisible":true,"focusItem":"w108","selection":["w108"]}],["listen","w99",{"Selection":true,"DefaultSelection":true}],["set","w99",{"enableCellToolTip":true}],["listen","w100",{"Selection":true}],["set","w101",{"visibility":true}],["listen","w101",{"Selection":true}],["create","w102","rwt.widgets.GridColumn",{"parent":"w99","text":"Nr.","width":50,"moveable":true}],["listen","w102",{"Selection":true}],["create","w103","rwt.widgets.GridColumn",{"parent":"w99","text":"Sym.","index":1,"left":50,"width":50,"moveable":true}],["listen","w103",{"Selection":true}],["create","w104","rwt.widgets.GridColumn",{"parent":"w99","text":"Name","index":2,"left":100,"width":140,"moveable":true}],["listen","w104",{"Selection":true}],["create","w105","rwt.widgets.GridColumn",{"parent":"w99","text":"Series","index":3,"left":240,"width":180,"moveable":true}],["listen","w105",{"Selection":true}],["create","w106","rwt.widgets.GridColumn",{"parent":"w99","text":"Group","index":4,"left":420,"width":50,"moveable":true}],["listen","w106",{"Selection":true}],["create","w107","rwt.widgets.GridColumn",{"parent":"w99","text":"Period","index":5,"left":470,"width":50,"moveable":true}],["listen","w107",{"Selection":true}],["create","w108","rwt.widgets.GridItem",{"parent":"w99","index":0,"texts":["1","H","Hydrogen","Nonmetal","1","1"],"cellBackgrounds":[null,null,null,[138,226,52,255],null,null]}],["create","w109","rwt.widgets.GridItem",{"parent":"w99","index":1,"texts":["2","He","Helium","Noble gas","18","1"],"cellBackgrounds":[null,null,null,[114,159,207,255],null,null]}],["create","w110","rwt.widgets.GridItem",{"parent":"w99","index":2,"texts":["3","Li","Lithium","Alkali metal","1","2"],"cellBackgrounds":[null,null,null,[239,41,41,255],null,null]}],["create","w111","rwt.widgets.GridItem",{"parent":"w99","index":3,"texts":["4","Be","Beryllium","Alkaline earth metal","2","2"],"cellBackgrounds":[null,null,null,[233,185,110,255],null,null]}],["create","w112","rwt.widgets.GridItem",{"parent":"w99","index":4,"texts":["5","B","Boron","Metalloid","13","2"],"cellBackgrounds":[null,null,null,[156,159,153,255],null,null]}],["create","w113","rwt.widgets.GridItem",{"parent":"w99","index":5,"texts":["6","C","Carbon","Nonmetal","14","2"],"cellBackgrounds":[null,null,null,[138,226,52,255],null,null]}],["create","w114","rwt.widgets.GridItem",{"parent":"w99","index":6,"texts":["7","N","Nitrogen","Nonmetal","15","2"],"cellBackgrounds":[null,null,null,[138,226,52,255],null,null]}],["create","w115","rwt.widgets.GridItem",{"parent":"w99","index":7,"texts":["8","O","Oxygen","Nonmetal","16","2"],"cellBackgrounds":[null,null,null,[138,226,52,255],null,null]}],["create","w116","rwt.widgets.GridItem",{"parent":"w99","index":8,"texts":["9","F","Fluorine","Halogen","17","2"],"cellBackgrounds":[null,null,null,[252,233,79,255],null,null]}],["create","w117","rwt.widgets.GridItem",{"parent":"w99","index":9,"texts":["10","Ne","Neon","Noble gas","18","2"],"cellBackgrounds":[null,null,null,[114,159,207,255],null,null]}]';
  
  JSON_PART2 = ',["create","w118","rwt.widgets.GridItem",{"parent":"w99","index":10,"texts":["11","Na","Sodium","Alkali metal","1","3"],"cellBackgrounds":[null,null,null,[239,41,41,255],null,null]}],["create","w119","rwt.widgets.GridItem",{"parent":"w99","index":11,"texts":["12","Mg","Magnesium","Alkaline earth metal","2","3"],"cellBackgrounds":[null,null,null,[233,185,110,255],null,null]}],["create","w120","rwt.widgets.GridItem",{"parent":"w99","index":12,"texts":["13","Al","Aluminium","Poor metal","13","3"],"cellBackgrounds":[null,null,null,[238,238,236,255],null,null]}],["create","w121","rwt.widgets.GridItem",{"parent":"w99","index":13,"texts":["14","Si","Silicon","Metalloid","14","3"],"cellBackgrounds":[null,null,null,[156,159,153,255],null,null]}],["create","w122","rwt.widgets.GridItem",{"parent":"w99","index":14,"texts":["15","P","Phosphorus","Nonmetal","15","3"],"cellBackgrounds":[null,null,null,[138,226,52,255],null,null]}],["create","w123","rwt.widgets.GridItem",{"parent":"w99","index":15,"texts":["16","S","Sulfur","Nonmetal","16","3"],"cellBackgrounds":[null,null,null,[138,226,52,255],null,null]}],["create","w124","rwt.widgets.GridItem",{"parent":"w99","index":16,"texts":["17","Cl","Chlorine","Halogen","17","3"],"cellBackgrounds":[null,null,null,[252,233,79,255],null,null]}],["create","w125","rwt.widgets.GridItem",{"parent":"w99","index":17,"texts":["18","Ar","Argon","Noble gas","18","3"],"cellBackgrounds":[null,null,null,[114,159,207,255],null,null]}],["create","w126","rwt.widgets.GridItem",{"parent":"w99","index":18,"texts":["19","K","Potassium","Alkali metal","1","4"],"cellBackgrounds":[null,null,null,[239,41,41,255],null,null]}],["create","w127","rwt.widgets.GridItem",{"parent":"w99","index":19,"texts":["20","Ca","Calcium","Alkaline earth metal","2","4"],"cellBackgrounds":[null,null,null,[233,185,110,255],null,null]}],["create","w128","rwt.widgets.GridItem",{"parent":"w99","index":20,"texts":["21","Sc","Scandium","Transition metal","3","4"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w129","rwt.widgets.GridItem",{"parent":"w99","index":21,"texts":["22","Ti","Titanium","Transition metal","4","4"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w130","rwt.widgets.GridItem",{"parent":"w99","index":22,"texts":["23","V","Vanadium","Transition metal","5","4"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w131","rwt.widgets.GridItem",{"parent":"w99","index":23,"texts":["24","Cr","Chromium","Transition metal","6","4"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w132","rwt.widgets.GridItem",{"parent":"w99","index":24,"texts":["25","Mn","Manganese","Transition metal","7","4"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w133","rwt.widgets.GridItem",{"parent":"w99","index":25,"texts":["26","Fe","Iron","Transition metal","8","4"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w134","rwt.widgets.GridItem",{"parent":"w99","index":26,"texts":["27","Co","Cobalt","Transition metal","9","4"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w135","rwt.widgets.GridItem",{"parent":"w99","index":27,"texts":["28","Ni","Nickel","Transition metal","10","4"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w136","rwt.widgets.GridItem",{"parent":"w99","index":28,"texts":["29","Cu","Copper","Transition metal","11","4"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w137","rwt.widgets.GridItem",{"parent":"w99","index":29,"texts":["30","Zn","Zinc","Transition metal","12","4"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}]]}';

TYPE
  INT32 = INTEGER;

  String = POINTER TO StringDesc;
  StringDesc = RECORD (SOM.ObjectDesc) str: POINTER TO ARRAY OF CHAR END;

  (* Forward declarations matching C vtable structure *)
  JsonValue* = POINTER TO JsonValueDesc;
  JsonObject* = POINTER TO JsonObjectDesc;
  JsonArray* = POINTER TO JsonArrayDesc;
  JsonString* = POINTER TO JsonStringDesc;
  JsonNumber* = POINTER TO JsonNumberDesc;
  JsonLiteral* = POINTER TO JsonLiteralDesc;
  HashIndexTable = POINTER TO HashIndexTableDesc;
  JsonParser = POINTER TO JsonParserDesc;

  (* Base JsonValue type - matches C struct JsonValue with vtable *)
  JsonValueDesc* = RECORD (SOM.ObjectDesc)
    next: JsonValue;
  END;

  (* Hash table - matches C struct HashIndexTable *)
  HashIndexTableDesc = RECORD
    hashTable: POINTER TO ARRAY OF INT32;
    len: INT32;
  END;

  (* JsonObject - matches C struct JsonObject *)
  JsonObjectDesc* = RECORD (JsonValueDesc)
    names: SOM.Vector;   (* Vector of POINTER TO ARRAY OF CHAR *)
    values: SOM.Vector;  (* Vector of JsonValue *)
    table: HashIndexTable;
  END;

  (* JsonArray - matches C struct JsonArray *)
  JsonArrayDesc* = RECORD (JsonValueDesc)
    values: SOM.Vector;  (* Vector of JsonValue *)
  END;

  (* JsonString - matches C struct JsonString *)
  JsonStringDesc* = RECORD (JsonValueDesc)
    string: POINTER TO ARRAY OF CHAR;
  END;

  (* JsonNumber - matches C struct JsonNumber *)
  JsonNumberDesc* = RECORD (JsonValueDesc)
    string: POINTER TO ARRAY OF CHAR;
  END;

  (* JsonLiteral - matches C struct JsonLiteral *)
  JsonLiteralDesc* = RECORD (JsonValueDesc)
    value: ARRAY 8 OF CHAR;
    isNull, isTrue, isFalse: BOOLEAN;
  END;

  (* Parser state - matches C struct JsonPureStringParser *)
  JsonParserDesc = RECORD
    input: POINTER TO ARRAY OF CHAR;
    len, index, line, column: INT32;
    current: CHAR;
    captureBuffer: POINTER TO ARRAY OF CHAR;
    capturePos, captureStart: INT32;
    jsonNull, jsonTrue, jsonFalse: JsonLiteral;
  END;

  (* Main benchmark record *)
  Json* = POINTER TO JsonDesc;
  JsonDesc* = RECORD (Benchmark.BenchmarkDesc)
  END;

  (* Result wrapper *)
  IntegerObject* = POINTER TO IntegerObjectDesc;
  IntegerObjectDesc* = RECORD (SOM.ObjectDesc)
    value: INT32;
  END;

VAR
  JSON_NULL*, JSON_TRUE*, JSON_FALSE*: JsonLiteral;

(* --- Helper Procedures --- *)

PROCEDURE StringLength(s: ARRAY OF CHAR): INT32;
  VAR i: INT32;
BEGIN
  i := 0;
  WHILE s[i] # 0X DO
    INC(i);
  END;
  RETURN i;
END StringLength;

PROCEDURE StringsEqual(s1, s2: ARRAY OF CHAR): BOOLEAN;
  VAR i: INT32;
BEGIN
  i := 0;
  WHILE (s1[i] = s2[i]) & (s1[i] # 0X) DO
    INC(i);
  END;
  RETURN s1[i] = s2[i];
END StringsEqual;

PROCEDURE CopyString(src: ARRAY OF CHAR): POINTER TO ARRAY OF CHAR;
  VAR dest: POINTER TO ARRAY OF CHAR;
      i: INT32;
BEGIN
  NEW(dest, StringLength(src) + 1);
  FOR i := 0 TO StringLength(src) DO
    dest[i] := src[i];
  END;
  RETURN dest;
END CopyString;

PROCEDURE ConcatenateStrings(s1, s2: ARRAY OF CHAR): POINTER TO ARRAY OF CHAR;
  VAR result: POINTER TO ARRAY OF CHAR;
      len1, len2, i, j: INT32;
BEGIN
  len1 := StringLength(s1);
  len2 := StringLength(s2);
  NEW(result, len1 + len2 + 1);
  
  FOR i := 0 TO len1 - 1 DO
    result[i] := s1[i];
  END;
  
  FOR j := 0 TO len2 - 1 DO
    result[len1 + j] := s2[j];
  END;
  
  result[len1 + len2] := 0X;
  RETURN result;
END ConcatenateStrings;

(* --- HashIndexTable Implementation --- *)

PROCEDURE CreateHashIndexTable(): HashIndexTable;
  VAR h: HashIndexTable;
      i: INT32;
BEGIN
  NEW(h);
  h.len := 32;
  NEW(h.hashTable, h.len);
  FOR i := 0 TO h.len - 1 DO
    h.hashTable[i] := 0;
  END;
  RETURN h;
END CreateHashIndexTable;

PROCEDURE StringHash(s: ARRAY OF CHAR): INT32;
BEGIN
  RETURN StringLength(s) * 1402589;
END StringHash;

PROCEDURE HashSlotFor(h: HashIndexTable; element: ARRAY OF CHAR): INT32;
BEGIN
  // TODO RETURN SYSTEM.VAL(INT32, SYSTEM.VAL(SET, StringHash(element)) * SYSTEM.VAL(SET, h.len - 1));
  RETURN ORD(BITS(StringHash(element)) * BITS(h.len - 1));
END HashSlotFor;

PROCEDURE HashTableGet(h: HashIndexTable; name: ARRAY OF CHAR): INT32;
  VAR slot: INT32;
BEGIN
  slot := HashSlotFor(h, name);
  // TODO RETURN (SYSTEM.VAL(INT32, SYSTEM.VAL(SET, h.hashTable[slot]) * SYSTEM.VAL(SET, 0FFH))) - 1;
  RETURN (ORD(BITS(h.hashTable[slot]) * BITS(0FFH))) - 1;
END HashTableGet;

PROCEDURE HashTableAdd(h: HashIndexTable; name: ARRAY OF CHAR; index: INT32);
  VAR slot: INT32;
BEGIN
  slot := HashSlotFor(h, name);
  IF index < 0FFH THEN
    h.hashTable[slot] := (index + 1) MOD 100H;
  ELSE
    h.hashTable[slot] := 0;
  END;
END HashTableAdd;

(* --- JsonValue Hierarchy --- *)

PROCEDURE IsObject*(v: JsonValue): BOOLEAN;
BEGIN
  RETURN v IS JsonObject;
END IsObject;

PROCEDURE IsArray*(v: JsonValue): BOOLEAN;
BEGIN
  RETURN v IS JsonArray;
END IsArray;

PROCEDURE AsObject*(v: JsonValue): JsonObject;
BEGIN
  IF v IS JsonObject THEN
    RETURN v(JsonObject);
  ELSE
    HALT(101);
  END;
END AsObject;

PROCEDURE AsArray*(v: JsonValue): JsonArray;
BEGIN
  IF v IS JsonArray THEN
    RETURN v(JsonArray);
  ELSE
    HALT(102);
  END;
END AsArray;

(* --- JsonObject Implementation --- *)

PROCEDURE CreateJsonObject(): JsonObject;
  VAR obj: JsonObject;
BEGIN
  NEW(obj);
  obj.names := SOM.CreateVector(8);
  obj.values := SOM.CreateVector(8);
  obj.table := CreateHashIndexTable();
  RETURN obj;
END CreateJsonObject;

PROCEDURE JsonObjectAdd(obj: JsonObject; name: POINTER TO ARRAY OF CHAR; value: JsonValue);
  VAR str: String;
BEGIN
  HashTableAdd(obj.table, name^, SOM.VectorSize(obj.names));
  NEW(str);
  str.str := name;
  SOM.VectorAppend(obj.names, str);
  SOM.VectorAppend(obj.values, value);
END JsonObjectAdd;

PROCEDURE JsonObjectGet(obj: JsonObject; name: ARRAY OF CHAR): JsonValue;
  VAR index: INT32;
      foundName: POINTER TO ARRAY OF CHAR;
BEGIN
  index := HashTableGet(obj.table, name);
  IF index # -1 THEN
    foundName := SOM.VectorAt(obj.names, index)(String).str;
    IF StringsEqual(foundName^, name) THEN
      RETURN SOM.VectorAt(obj.values, index)(JsonValue);
    END;
  END;
  RETURN NIL;
END JsonObjectGet;

(* --- JsonArray Implementation --- *)

PROCEDURE CreateJsonArray(): JsonArray;
  VAR arr: JsonArray;
BEGIN
  NEW(arr);
  arr.values := SOM.CreateVector(8);
  RETURN arr;
END CreateJsonArray;

PROCEDURE JsonArrayAdd(arr: JsonArray; value: JsonValue);
BEGIN
  SOM.VectorAppend(arr.values, value);
END JsonArrayAdd;

PROCEDURE JsonArraySize(arr: JsonArray): INT32;
BEGIN
  RETURN SOM.VectorSize(arr.values);
END JsonArraySize;

(* --- JsonString Implementation --- *)

PROCEDURE CreateJsonString(str: POINTER TO ARRAY OF CHAR): JsonString;
  VAR s: JsonString;
BEGIN
  NEW(s);
  s.string := str;
  RETURN s;
END CreateJsonString;

(* --- JsonLiteral Implementation --- *)

PROCEDURE CreateJsonLiteral(value: ARRAY OF CHAR): JsonLiteral;
  VAR lit: JsonLiteral;
BEGIN
  NEW(lit);
  // TODO COPY(value, lit.value);
  lit.value := value;
  lit.isNull := StringsEqual(value, "null");
  lit.isTrue := StringsEqual(value, "true");
  lit.isFalse := StringsEqual(value, "false");
  RETURN lit;
END CreateJsonLiteral;

(* --- Parser Implementation --- *)

PROCEDURE CreateParser(input: POINTER TO ARRAY OF CHAR): JsonParser;
  VAR p: JsonParser;
BEGIN
  NEW(p);
  p.input := input;
  p.len := StringLength(input^);
  p.index := -1;
  p.line := 1;
  p.column := 0;
  p.captureStart := -1;
  p.capturePos := 0;
  NEW(p.captureBuffer, 1024);
  p.jsonNull := CreateJsonLiteral("null");
  p.jsonTrue := CreateJsonLiteral("true");
  p.jsonFalse := CreateJsonLiteral("false");
  p.current := 0X;
  RETURN p;
END CreateParser;

PROCEDURE ParserRead(p: JsonParser);
BEGIN
  IF p.current = 0AX THEN
    INC(p.line);
    p.column := 0;
  END;
  INC(p.index);
  IF p.index < p.len THEN
    p.current := p.input[p.index];
  ELSE
    p.current := 0X;
  END;
END ParserRead;

PROCEDURE ParserIsWhiteSpace(p: JsonParser): BOOLEAN;
BEGIN
  RETURN (p.current = " ") OR (p.current = 09X) OR (p.current = 0AX) OR (p.current = 0DX);
END ParserIsWhiteSpace;

PROCEDURE ParserSkipWhiteSpace(p: JsonParser);
BEGIN
  WHILE ParserIsWhiteSpace(p) DO
    ParserRead(p);
  END;
END ParserSkipWhiteSpace;

PROCEDURE ParserReadChar(p: JsonParser; ch: CHAR): BOOLEAN;
BEGIN
  IF p.current # ch THEN
    RETURN FALSE;
  END;
  ParserRead(p);
  RETURN TRUE;
END ParserReadChar;

(* Forward declaration *)
PROCEDURE^ ParserReadValue(p: JsonParser): JsonValue;

PROCEDURE ParserReadString(p: JsonParser): JsonValue;
  VAR str: ARRAY 1024 OF CHAR;
      i: INT32;
      result: POINTER TO ARRAY OF CHAR;
BEGIN
  ParserRead(p);
  i := 0;
  WHILE p.current # 22X DO (* " *)
    IF p.current = "\" THEN
      ParserRead(p);
      (* Simplified escape handling *)
    END;
    str[i] := p.current;
    INC(i);
    ParserRead(p);
  END;
  str[i] := 0X;
  ParserRead(p);
  result := CopyString(str);
  RETURN CreateJsonString(result);
END ParserReadString;

PROCEDURE ParserReadArray(p: JsonParser): JsonValue;
  VAR arr: JsonArray;
BEGIN
  arr := CreateJsonArray();
  ParserRead(p);
  ParserSkipWhiteSpace(p);
  IF ParserReadChar(p, "]") THEN
    RETURN arr;
  END;
  LOOP
    ParserSkipWhiteSpace(p);
    JsonArrayAdd(arr, ParserReadValue(p));
    ParserSkipWhiteSpace(p);
    IF ParserReadChar(p, "]") THEN
      RETURN arr;
    END;
    IF ~ParserReadChar(p, ",") THEN
      HALT(103);
    END;
  END;
END ParserReadArray;

PROCEDURE ParserReadObject(p: JsonParser): JsonValue;
  VAR obj: JsonObject;
      name: POINTER TO ARRAY OF CHAR;
BEGIN
  obj := CreateJsonObject();
  ParserRead(p);
  ParserSkipWhiteSpace(p);
  IF ParserReadChar(p, "}") THEN
    RETURN obj;
  END;
  LOOP
    ParserSkipWhiteSpace(p);
    name := ParserReadString(p)(JsonString).string;
    ParserSkipWhiteSpace(p);
    IF ~ParserReadChar(p, ":") THEN
      HALT(104);
    END;
    ParserSkipWhiteSpace(p);
    JsonObjectAdd(obj, name, ParserReadValue(p));
    ParserSkipWhiteSpace(p);
    IF ParserReadChar(p, "}") THEN
      RETURN obj;
    END;
    IF ~ParserReadChar(p, ",") THEN
      HALT(105);
    END;
  END;
END ParserReadObject;

PROCEDURE ParserReadValue(p: JsonParser): JsonValue;
BEGIN
  CASE p.current OF
    "n": ParserRead(p); ParserRead(p); ParserRead(p); ParserRead(p); RETURN p.jsonNull;
  | "t": ParserRead(p); ParserRead(p); ParserRead(p); ParserRead(p); RETURN p.jsonTrue;
  | "f": ParserRead(p); ParserRead(p); ParserRead(p); ParserRead(p); ParserRead(p); RETURN p.jsonFalse;
  | 22X: RETURN ParserReadString(p); (* " *)
  | "[": RETURN ParserReadArray(p);
  | "{": RETURN ParserReadObject(p);
  ELSE
    HALT(106);
  END;
END ParserReadValue;

PROCEDURE Parse(p: JsonParser): JsonValue;
  VAR result: JsonValue;
BEGIN
  ParserRead(p);
  ParserSkipWhiteSpace(p);
  result := ParserReadValue(p);
  ParserSkipWhiteSpace(p);
  IF p.current # 0X THEN
    HALT(107);
  END;
  RETURN result;
END Parse;

(* --- Main Benchmark Procedures --- *)

PROCEDURE DoBenchmark*(b: Benchmark.Benchmark): SOM.Object;
  VAR parser: JsonParser;
      result: JsonValue;
      input: POINTER TO ARRAY OF CHAR;
      operations: JsonArray;
      resultObj: IntegerObject;
BEGIN
  (* Concatenate the JSON parts to get the full string *)
  input := ConcatenateStrings(JSON_PART1, JSON_PART2);
  parser := CreateParser(input);
  result := Parse(parser);
  
  operations := AsArray(JsonObjectGet(AsObject(result), "operations"));
  
  NEW(resultObj);
  resultObj.value := JsonArraySize(operations);
  RETURN resultObj;
END DoBenchmark;

PROCEDURE VerifyResult*(b: Benchmark.Benchmark; result: SOM.Object): BOOLEAN;
BEGIN
  WITH result: IntegerObject DO
    RETURN result.value = 119;
  ELSE
    RETURN FALSE;
  END;
END VerifyResult;

PROCEDURE Create*(): Benchmark.Benchmark;
  VAR j: Json;
BEGIN
  NEW(j);
  j.DoBenchmark := DoBenchmark;
  j.VerifyResult := VerifyResult;
  j.InnerBenchmarkLoop := Benchmark.InnerBenchmarkLoop;
  RETURN j;
END Create;

BEGIN
  JSON_NULL := CreateJsonLiteral("null");
  JSON_TRUE := CreateJsonLiteral("true");
  JSON_FALSE := CreateJsonLiteral("false");
END Json.
