(* Copyright (c) 2015 Stefan Marr
 * Copyright (c) 2013, 2015 EclipseSource.
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

MODULE Json;

IMPORT SOM, SYSTEM, Benchmark, Out;

CONST
  DQUOTE = 22X;
  BSLASH = 5CX;
  JSONLEN = 25820;

TYPE
  INT32 = SOM.INT32;
  Chars = POINTER TO ARRAY OF CHAR;

  Json* = POINTER TO JsonDesc;
  JsonDesc* = RECORD (Benchmark.BenchmarkDesc) END;

  JsonValue = POINTER TO JsonValueDesc;
  JsonValueDesc = RECORD (SOM.ObjectDesc) END;

  JsonObject = POINTER TO JsonObjectDesc;
  JsonObjectDesc = RECORD (JsonValueDesc)
    names: SOM.Vector;
    values: SOM.Vector;
    hashTable: POINTER TO ARRAY OF INT32;
    hashLen: INT32;
  END;

  JsonArray = POINTER TO JsonArrayDesc;
  JsonArrayDesc = RECORD (JsonValueDesc)
    values: SOM.Vector;
  END;

  JsonString = POINTER TO JsonStringDesc;
  JsonStringDesc = RECORD (JsonValueDesc)
    string: Chars;
  END;

  JsonNumber = POINTER TO JsonNumberDesc;
  JsonNumberDesc = RECORD (JsonValueDesc)
    string: Chars;
  END;

  JsonLiteral = POINTER TO JsonLiteralDesc;
  JsonLiteralDesc = RECORD (JsonValueDesc)
    isNull, isTrue, isFalse: BOOLEAN;
  END;

  StringObject = POINTER TO StringObjectDesc;
  StringObjectDesc = RECORD (SOM.ObjectDesc)
    str: Chars;
  END;

  Parser = POINTER TO ParserDesc;
  ParserDesc = RECORD
    input: Chars;
    len: INT32;
    index: INT32;
    line: INT32;
    column: INT32;
    current: CHAR;
    captureBuf: Chars;
    captureLen: INT32;
    capturePos: INT32;
    captureStart: INT32;
    Null: JsonLiteral;
    True: JsonLiteral;
    False: JsonLiteral;
  END;

VAR
  jsonString: Chars;
  readValueFunc: PROCEDURE (p: Parser): JsonValue;

(* --- String Utilities --- *)

PROCEDURE CharsLen(s: Chars): INT32;
  VAR i: INT32;
BEGIN
  i := 0;
  WHILE (i < LEN(s^)) & (s[i] # 0X) DO INC(i) END;
  RETURN i
END CharsLen;

PROCEDURE CharsEqualStr(a: Chars; b: ARRAY OF CHAR): BOOLEAN;
  VAR i: INT32;
BEGIN
  i := 0;
  WHILE (i < LEN(a^)) & (i < LEN(b)) & (a[i] # 0X) & (b[i] # 0X) & (a[i] = b[i]) DO
    INC(i);
  END;
  RETURN ((i >= LEN(a^)) OR (a[i] = 0X)) & ((i >= LEN(b)) OR (b[i] = 0X))
END CharsEqualStr;

PROCEDURE CopyChars(dst: Chars; VAR pos: INT32; src: ARRAY OF CHAR);
  VAR i: INT32;
BEGIN
  i := 0;
  WHILE (i < LEN(src)) & (src[i] # 0X) DO
    dst[pos] := src[i];
    INC(pos); INC(i);
  END;
END CopyChars;

(* --- JSON String Building --- *)
PROCEDURE BuildPart1(s: Chars; VAR pos: INT32);
BEGIN
  CopyChars(s, pos, '{"head":{"requestCounter":4},"operations":[["destroy","w54"],["set","w2",{"activeControl":"w99"}],["set","w21",{"customVariant":"variant_navigation"}],["set","w28",{"customVariant":"variant_selected"}],["set","w53",{"children":["w95"]}],["create","w95","rwt.widgets.Composite",{"parent":"w53","style":["NONE"],"bounds":[0,0,1008,586],"children":["w96","w97"],"tabIndex":-1,"clientArea":[0,0,1008,586]');
  CopyChars(s, pos, '}],["create","w96","rwt.widgets.Label",{"parent":"w95","style":["NONE"],"bounds":[10,30,112,26],"tabIndex":-1,"customVariant":"variant_pageHeadline","text":"TableViewer"}],["create","w97","rwt.widgets.Composite",{"parent":"w95","style":["NONE"],"bounds":[0,61,1008,525],"children":["w98","w99","w226","w228"],"tabIndex":-1,"clientArea":[0,0,1008,525]}],["create","w98","rwt.widgets.Text",{"parent":"w');
  CopyChars(s, pos, '97","style":["LEFT","SINGLE","BORDER"],"bounds":[10,10,988,32],"tabIndex":22,"activeKeys":["#13","#27","#40"]}],["listen","w98",{"KeyDown":true,"Modify":true}],["create","w99","rwt.widgets.Grid",{"parent":"w97","style":["SINGLE","BORDER"],"appearance":"table","indentionWidth":0,"treeColumn":-1,"markupEnabled":false}],["create","w100","rwt.widgets.ScrollBar",{"parent":"w99","style":["HORIZONTAL"]}]');
  CopyChars(s, pos, ',["create","w101","rwt.widgets.ScrollBar",{"parent":"w99","style":["VERTICAL"]}],["set","w99",{"bounds":[10,52,988,402],"children":[],"tabIndex":23,"activeKeys":["CTRL+#70","CTRL+#78","CTRL+#82","CTRL+#89","CTRL+#83","CTRL+#71","CTRL+#69"],"cancelKeys":["CTRL+#70","CTRL+#78","CTRL+#82","CTRL+#89","CTRL+#83","CTRL+#71","CTRL+#69"]}],["listen","w99",{"MouseDown":true,"MouseUp":true,"MouseDoubleClick');
  CopyChars(s, pos, '":true,"KeyDown":true}],["set","w99",{"itemCount":118,"itemHeight":28,"itemMetrics":[[0,0,50,3,0,3,44],[1,50,50,53,0,53,44],[2,100,140,103,0,103,134],[3,240,180,243,0,243,174],[4,420,50,423,0,423,44],[5,470,50,473,0,473,44]],"columnCount":6,"headerHeight":35,"headerVisible":true,"linesVisible":true,"focusItem":"w108","selection":["w108"]}],["listen","w99",{"Selection":true,"DefaultSelection":true}');
  CopyChars(s, pos, '],["set","w99",{"enableCellToolTip":true}],["listen","w100",{"Selection":true}],["set","w101",{"visibility":true}],["listen","w101",{"Selection":true}],["create","w102","rwt.widgets.GridColumn",{"parent":"w99","text":"Nr.","width":50,"moveable":true}],["listen","w102",{"Selection":true}],["create","w103","rwt.widgets.GridColumn",{"parent":"w99","text":"Sym.","index":1,"left":50,"width":50,"moveabl');
  CopyChars(s, pos, 'e":true}],["listen","w103",{"Selection":true}],["create","w104","rwt.widgets.GridColumn",{"parent":"w99","text":"Name","index":2,"left":100,"width":140,"moveable":true}],["listen","w104",{"Selection":true}],["create","w105","rwt.widgets.GridColumn",{"parent":"w99","text":"Series","index":3,"left":240,"width":180,"moveable":true}],["listen","w105",{"Selection":true}],["create","w106","rwt.widgets.G');
  CopyChars(s, pos, 'ridColumn",{"parent":"w99","text":"Group","index":4,"left":420,"width":50,"moveable":true}],["listen","w106",{"Selection":true}],["create","w107","rwt.widgets.GridColumn",{"parent":"w99","text":"Period","index":5,"left":470,"width":50,"moveable":true}],["listen","w107",{"Selection":true}],["create","w108","rwt.widgets.GridItem",{"parent":"w99","index":0,"texts":["1","H","Hydrogen","Nonmetal","1","');
  CopyChars(s, pos, '1"],"cellBackgrounds":[null,null,null,[138,226,52,255],null,null]}],["create","w109","rwt.widgets.GridItem",{"parent":"w99","index":1,"texts":["2","He","Helium","Noble gas","18","1"],"cellBackgrounds":[null,null,null,[114,159,207,255],null,null]}],["create","w110","rwt.widgets.GridItem",{"parent":"w99","index":2,"texts":["3","Li","Lithium","Alkali metal","1","2"],"cellBackgrounds":[null,null,null,');
  CopyChars(s, pos, '[239,41,41,255],null,null]}],["create","w111","rwt.widgets.GridItem",{"parent":"w99","index":3,"texts":["4","Be","Beryllium","Alkaline earth metal","2","2"],"cellBackgrounds":[null,null,null,[233,185,110,255],null,null]}],["create","w112","rwt.widgets.GridItem",{"parent":"w99","index":4,"texts":["5","B","Boron","Metalloid","13","2"],"cellBackgrounds":[null,null,null,[156,159,153,255],null,null]}],');
  CopyChars(s, pos, '["create","w113","rwt.widgets.GridItem",{"parent":"w99","index":5,"texts":["6","C","Carbon","Nonmetal","14","2"],"cellBackgrounds":[null,null,null,[138,226,52,255],null,null]}],["create","w114","rwt.widgets.GridItem",{"parent":"w99","index":6,"texts":["7","N","Nitrogen","Nonmetal","15","2"],"cellBackgrounds":[null,null,null,[138,226,52,255],null,null]}],["create","w115","rwt.widgets.GridItem",{"pa');
  CopyChars(s, pos, 'rent":"w99","index":7,"texts":["8","O","Oxygen","Nonmetal","16","2"],"cellBackgrounds":[null,null,null,[138,226,52,255],null,null]}],["create","w116","rwt.widgets.GridItem",{"parent":"w99","index":8,"texts":["9","F","Fluorine","Halogen","17","2"],"cellBackgrounds":[null,null,null,[252,233,79,255],null,null]}],["create","w117","rwt.widgets.GridItem",{"parent":"w99","index":9,"texts":["10","Ne","Neo');
  CopyChars(s, pos, 'n","Noble gas","18","2"],"cellBackgrounds":[null,null,null,[114,159,207,255],null,null]}],["create","w118","rwt.widgets.GridItem",{"parent":"w99","index":10,"texts":["11","Na","Sodium","Alkali metal","1","3"],"cellBackgrounds":[null,null,null,[239,41,41,255],null,null]}],["create","w119","rwt.widgets.GridItem",{"parent":"w99","index":11,"texts":["12","Mg","Magnesium","Alkaline earth metal","2","3"');
  CopyChars(s, pos, '],"cellBackgrounds":[null,null,null,[233,185,110,255],null,null]}],["create","w120","rwt.widgets.GridItem",{"parent":"w99","index":12,"texts":["13","Al","Aluminium","Poor metal","13","3"],"cellBackgrounds":[null,null,null,[238,238,236,255],null,null]}],["create","w121","rwt.widgets.GridItem",{"parent":"w99","index":13,"texts":["14","Si","Silicon","Metalloid","14","3"],"cellBackgrounds":[null,null,');
  CopyChars(s, pos, 'null,[156,159,153,255],null,null]}],["create","w122","rwt.widgets.GridItem",{"parent":"w99","index":14,"texts":["15","P","Phosphorus","Nonmetal","15","3"],"cellBackgrounds":[null,null,null,[138,226,52,255],null,null]}],["create","w123","rwt.widgets.GridItem",{"parent":"w99","index":15,"texts":["16","S","Sulfur","Nonmetal","16","3"],"cellBackgrounds":[null,null,null,[138,226,52,255],null,null]}],["');
  CopyChars(s, pos, 'create","w124","rwt.widgets.GridItem",{"parent":"w99","index":16,"texts":["17","Cl","Chlorine","Halogen","17","3"],"cellBackgrounds":[null,null,null,[252,233,79,255],null,null]}],["create","w125","rwt.widgets.GridItem",{"parent":"w99","index":17,"texts":["18","Ar","Argon","Noble gas","18","3"],"cellBackgrounds":[null,null,null,[114,159,207,255],null,null]}],["create","w126","rwt.widgets.GridItem",');
  CopyChars(s, pos, '{"parent":"w99","index":18,"texts":["19","K","Potassium","Alkali metal","1","4"],"cellBackgrounds":[null,null,null,[239,41,41,255],null,null]}],["create","w127","rwt.widgets.GridItem",{"parent":"w99","index":19,"texts":["20","Ca","Calcium","Alkaline earth metal","2","4"],"cellBackgrounds":[null,null,null,[233,185,110,255],null,null]}],["create","w128","rwt.widgets.GridItem",{"parent":"w99","index"');
  CopyChars(s, pos, ':20,"texts":["21","Sc","Scandium","Transition metal","3","4"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w129","rwt.widgets.GridItem",{"parent":"w99","index":21,"texts":["22","Ti","Titanium","Transition metal","4","4"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w130","rwt.widgets.GridItem",{"parent":"w99","index":22,"texts":["23","V",');
  CopyChars(s, pos, '"Vanadium","Transition metal","5","4"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w131","rwt.widgets.GridItem",{"parent":"w99","index":23,"texts":["24","Cr","Chromium","Transition metal","6","4"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w132","rwt.widgets.GridItem",{"parent":"w99","index":24,"texts":["25","Mn","Manganese","Transitio');
  CopyChars(s, pos, 'n metal","7","4"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w133","rwt.widgets.GridItem",{"parent":"w99","index":25,"texts":["26","Fe","Iron","Transition metal","8","4"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w134","rwt.widgets.GridItem",{"parent":"w99","index":26,"texts":["27","Co","Cobalt","Transition metal","9","4"],"cellBackg');
  CopyChars(s, pos, 'rounds":[null,null,null,[252,175,62,255],null,null]}],["create","w135","rwt.widgets.GridItem",{"parent":"w99","index":27,"texts":["28","Ni","Nickel","Transition metal","10","4"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w136","rwt.widgets.GridItem",{"parent":"w99","index":28,"texts":["29","Cu","Copper","Transition metal","11","4"],"cellBackgrounds":[null,null,null,');
END BuildPart1;

PROCEDURE BuildPart2(s: Chars; VAR pos: INT32);
BEGIN
  CopyChars(s, pos, '[252,175,62,255],null,null]}],["create","w137","rwt.widgets.GridItem",{"parent":"w99","index":29,"texts":["30","Zn","Zinc","Transition metal","12","4"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w138","rwt.widgets.GridItem",{"parent":"w99","index":30,"texts":["31","Ga","Gallium","Poor metal","13","4"],"cellBackgrounds":[null,null,null,[238,238,236,255],null,null]}],');
  CopyChars(s, pos, '["create","w139","rwt.widgets.GridItem",{"parent":"w99","index":31,"texts":["32","Ge","Germanium","Metalloid","14","4"],"cellBackgrounds":[null,null,null,[156,159,153,255],null,null]}],["create","w140","rwt.widgets.GridItem",{"parent":"w99","index":32,"texts":["33","As","Arsenic","Metalloid","15","4"],"cellBackgrounds":[null,null,null,[156,159,153,255],null,null]}],["create","w141","rwt.widgets.Gr');
  CopyChars(s, pos, 'idItem",{"parent":"w99","index":33,"texts":["34","Se","Selenium","Nonmetal","16","4"],"cellBackgrounds":[null,null,null,[138,226,52,255],null,null]}],["create","w142","rwt.widgets.GridItem",{"parent":"w99","index":34,"texts":["35","Br","Bromine","Halogen","17","4"],"cellBackgrounds":[null,null,null,[252,233,79,255],null,null]}],["create","w143","rwt.widgets.GridItem",{"parent":"w99","index":35,"te');
  CopyChars(s, pos, 'xts":["36","Kr","Krypton","Noble gas","18","4"],"cellBackgrounds":[null,null,null,[114,159,207,255],null,null]}],["create","w144","rwt.widgets.GridItem",{"parent":"w99","index":36,"texts":["37","Rb","Rubidium","Alkali metal","1","5"],"cellBackgrounds":[null,null,null,[239,41,41,255],null,null]}],["create","w145","rwt.widgets.GridItem",{"parent":"w99","index":37,"texts":["38","Sr","Strontium","Alka');
  CopyChars(s, pos, 'line earth metal","2","5"],"cellBackgrounds":[null,null,null,[233,185,110,255],null,null]}],["create","w146","rwt.widgets.GridItem",{"parent":"w99","index":38,"texts":["39","Y","Yttrium","Transition metal","3","5"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w147","rwt.widgets.GridItem",{"parent":"w99","index":39,"texts":["40","Zr","Zirconium","Transition metal","4",');
  CopyChars(s, pos, '"5"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w148","rwt.widgets.GridItem",{"parent":"w99","index":40,"texts":["41","Nb","Niobium","Transition metal","5","5"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w149","rwt.widgets.GridItem",{"parent":"w99","index":41,"texts":["42","Mo","Molybdenum","Transition metal","6","5"],"cellBackgrounds');
  CopyChars(s, pos, '":[null,null,null,[252,175,62,255],null,null]}],["create","w150","rwt.widgets.GridItem",{"parent":"w99","index":42,"texts":["43","Tc","Technetium","Transition metal","7","5"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w151","rwt.widgets.GridItem",{"parent":"w99","index":43,"texts":["44","Ru","Ruthenium","Transition metal","8","5"],"cellBackgrounds":[null,null,null,[');
  CopyChars(s, pos, '252,175,62,255],null,null]}],["create","w152","rwt.widgets.GridItem",{"parent":"w99","index":44,"texts":["45","Rh","Rhodium","Transition metal","9","5"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w153","rwt.widgets.GridItem",{"parent":"w99","index":45,"texts":["46","Pd","Palladium","Transition metal","10","5"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,');
  CopyChars(s, pos, 'null]}],["create","w154","rwt.widgets.GridItem",{"parent":"w99","index":46,"texts":["47","Ag","Silver","Transition metal","11","5"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w155","rwt.widgets.GridItem",{"parent":"w99","index":47,"texts":["48","Cd","Cadmium","Transition metal","12","5"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w156');
  CopyChars(s, pos, '","rwt.widgets.GridItem",{"parent":"w99","index":48,"texts":["49","In","Indium","Poor metal","13","5"],"cellBackgrounds":[null,null,null,[238,238,236,255],null,null]}],["create","w157","rwt.widgets.GridItem",{"parent":"w99","index":49,"texts":["50","Sn","Tin","Poor metal","14","5"],"cellBackgrounds":[null,null,null,[238,238,236,255],null,null]}],["create","w158","rwt.widgets.GridItem",{"parent":"w');
  CopyChars(s, pos, '99","index":50,"texts":["51","Sb","Antimony","Metalloid","15","5"],"cellBackgrounds":[null,null,null,[156,159,153,255],null,null]}],["create","w159","rwt.widgets.GridItem",{"parent":"w99","index":51,"texts":["52","Te","Tellurium","Metalloid","16","5"],"cellBackgrounds":[null,null,null,[156,159,153,255],null,null]}],["create","w160","rwt.widgets.GridItem",{"parent":"w99","index":52,"texts":["53","I');
  CopyChars(s, pos, '","Iodine","Halogen","17","5"],"cellBackgrounds":[null,null,null,[252,233,79,255],null,null]}],["create","w161","rwt.widgets.GridItem",{"parent":"w99","index":53,"texts":["54","Xe","Xenon","Noble gas","18","5"],"cellBackgrounds":[null,null,null,[114,159,207,255],null,null]}],["create","w162","rwt.widgets.GridItem",{"parent":"w99","index":54,"texts":["55","Cs","Caesium","Alkali metal","1","6"],"cel');
  CopyChars(s, pos, 'lBackgrounds":[null,null,null,[239,41,41,255],null,null]}],["create","w163","rwt.widgets.GridItem",{"parent":"w99","index":55,"texts":["56","Ba","Barium","Alkaline earth metal","2","6"],"cellBackgrounds":[null,null,null,[233,185,110,255],null,null]}],["create","w164","rwt.widgets.GridItem",{"parent":"w99","index":56,"texts":["57","La","Lanthanum","Lanthanide","3","6"],"cellBackgrounds":[null,null,');
  CopyChars(s, pos, 'null,[173,127,168,255],null,null]}],["create","w165","rwt.widgets.GridItem",{"parent":"w99","index":57,"texts":["58","Ce","Cerium","Lanthanide","3","6"],"cellBackgrounds":[null,null,null,[173,127,168,255],null,null]}],["create","w166","rwt.widgets.GridItem",{"parent":"w99","index":58,"texts":["59","Pr","Praseodymium","Lanthanide","3","6"],"cellBackgrounds":[null,null,null,[173,127,168,255],null,nu');
  CopyChars(s, pos, 'll]}],["create","w167","rwt.widgets.GridItem",{"parent":"w99","index":59,"texts":["60","Nd","Neodymium","Lanthanide","3","6"],"cellBackgrounds":[null,null,null,[173,127,168,255],null,null]}],["create","w168","rwt.widgets.GridItem",{"parent":"w99","index":60,"texts":["61","Pm","Promethium","Lanthanide","3","6"],"cellBackgrounds":[null,null,null,[173,127,168,255],null,null]}],["create","w169","rwt.w');
  CopyChars(s, pos, 'idgets.GridItem",{"parent":"w99","index":61,"texts":["62","Sm","Samarium","Lanthanide","3","6"],"cellBackgrounds":[null,null,null,[173,127,168,255],null,null]}],["create","w170","rwt.widgets.GridItem",{"parent":"w99","index":62,"texts":["63","Eu","Europium","Lanthanide","3","6"],"cellBackgrounds":[null,null,null,[173,127,168,255],null,null]}],["create","w171","rwt.widgets.GridItem",{"parent":"w99"');
  CopyChars(s, pos, ',"index":63,"texts":["64","Gd","Gadolinium","Lanthanide","3","6"],"cellBackgrounds":[null,null,null,[173,127,168,255],null,null]}],["create","w172","rwt.widgets.GridItem",{"parent":"w99","index":64,"texts":["65","Tb","Terbium","Lanthanide","3","6"],"cellBackgrounds":[null,null,null,[173,127,168,255],null,null]}],["create","w173","rwt.widgets.GridItem",{"parent":"w99","index":65,"texts":["66","Dy",');
  CopyChars(s, pos, '"Dysprosium","Lanthanide","3","6"],"cellBackgrounds":[null,null,null,[173,127,168,255],null,null]}],["create","w174","rwt.widgets.GridItem",{"parent":"w99","index":66,"texts":["67","Ho","Holmium","Lanthanide","3","6"],"cellBackgrounds":[null,null,null,[173,127,168,255],null,null]}],["create","w175","rwt.widgets.GridItem",{"parent":"w99","index":67,"texts":["68","Er","Erbium","Lanthanide","3","6"],');
  CopyChars(s, pos, '"cellBackgrounds":[null,null,null,[173,127,168,255],null,null]}],["create","w176","rwt.widgets.GridItem",{"parent":"w99","index":68,"texts":["69","Tm","Thulium","Lanthanide","3","6"],"cellBackgrounds":[null,null,null,[173,127,168,255],null,null]}],["create","w177","rwt.widgets.GridItem",{"parent":"w99","index":69,"texts":["70","Yb","Ytterbium","Lanthanide","3","6"],"cellBackgrounds":[null,null,nul');
  CopyChars(s, pos, 'l,[173,127,168,255],null,null]}],["create","w178","rwt.widgets.GridItem",{"parent":"w99","index":70,"texts":["71","Lu","Lutetium","Lanthanide","3","6"],"cellBackgrounds":[null,null,null,[173,127,168,255],null,null]}],["create","w179","rwt.widgets.GridItem",{"parent":"w99","index":71,"texts":["72","Hf","Hafnium","Transition metal","4","6"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,nul');
  CopyChars(s, pos, 'l]}],["create","w180","rwt.widgets.GridItem",{"parent":"w99","index":72,"texts":["73","Ta","Tantalum","Transition metal","5","6"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w181","rwt.widgets.GridItem",{"parent":"w99","index":73,"texts":["74","W","Tungsten","Transition metal","6","6"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w182","');
  CopyChars(s, pos, 'rwt.widgets.GridItem",{"parent":"w99","index":74,"texts":["75","Re","Rhenium","Transition metal","7","6"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w183","rwt.widgets.GridItem",{"parent":"w99","index":75,"texts":["76","Os","Osmium","Transition metal","8","6"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w184","rwt.widgets.GridItem",{"p');
END BuildPart2;

PROCEDURE BuildPart3(s: Chars; VAR pos: INT32);
BEGIN
  CopyChars(s, pos, 'arent":"w99","index":76,"texts":["77","Ir","Iridium","Transition metal","9","6"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w185","rwt.widgets.GridItem",{"parent":"w99","index":77,"texts":["78","Pt","Platinum","Transition metal","10","6"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w186","rwt.widgets.GridItem",{"parent":"w99","index":7');
  CopyChars(s, pos, '8,"texts":["79","Au","Gold","Transition metal","11","6"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w187","rwt.widgets.GridItem",{"parent":"w99","index":79,"texts":["80","Hg","Mercury","Transition metal","12","6"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w188","rwt.widgets.GridItem",{"parent":"w99","index":80,"texts":["81","Tl","Tha');
  CopyChars(s, pos, 'llium","Poor metal","13","6"],"cellBackgrounds":[null,null,null,[238,238,236,255],null,null]}],["create","w189","rwt.widgets.GridItem",{"parent":"w99","index":81,"texts":["82","Pb","Lead","Poor metal","14","6"],"cellBackgrounds":[null,null,null,[238,238,236,255],null,null]}],["create","w190","rwt.widgets.GridItem",{"parent":"w99","index":82,"texts":["83","Bi","Bismuth","Poor metal","15","6"],"cell');
  CopyChars(s, pos, 'Backgrounds":[null,null,null,[238,238,236,255],null,null]}],["create","w191","rwt.widgets.GridItem",{"parent":"w99","index":83,"texts":["84","Po","Polonium","Metalloid","16","6"],"cellBackgrounds":[null,null,null,[156,159,153,255],null,null]}],["create","w192","rwt.widgets.GridItem",{"parent":"w99","index":84,"texts":["85","At","Astatine","Halogen","17","6"],"cellBackgrounds":[null,null,null,[252,');
  CopyChars(s, pos, '233,79,255],null,null]}],["create","w193","rwt.widgets.GridItem",{"parent":"w99","index":85,"texts":["86","Rn","Radon","Noble gas","18","6"],"cellBackgrounds":[null,null,null,[114,159,207,255],null,null]}],["create","w194","rwt.widgets.GridItem",{"parent":"w99","index":86,"texts":["87","Fr","Francium","Alkali metal","1","7"],"cellBackgrounds":[null,null,null,[239,41,41,255],null,null]}],["create",');
  CopyChars(s, pos, '"w195","rwt.widgets.GridItem",{"parent":"w99","index":87,"texts":["88","Ra","Radium","Alkaline earth metal","2","7"],"cellBackgrounds":[null,null,null,[233,185,110,255],null,null]}],["create","w196","rwt.widgets.GridItem",{"parent":"w99","index":88,"texts":["89","Ac","Actinium","Actinide","3","7"],"cellBackgrounds":[null,null,null,[173,127,168,255],null,null]}],["create","w197","rwt.widgets.GridIt');
  CopyChars(s, pos, 'em",{"parent":"w99","index":89,"texts":["90","Th","Thorium","Actinide","3","7"],"cellBackgrounds":[null,null,null,[173,127,168,255],null,null]}],["create","w198","rwt.widgets.GridItem",{"parent":"w99","index":90,"texts":["91","Pa","Protactinium","Actinide","3","7"],"cellBackgrounds":[null,null,null,[173,127,168,255],null,null]}],["create","w199","rwt.widgets.GridItem",{"parent":"w99","index":91,"t');
  CopyChars(s, pos, 'exts":["92","U","Uranium","Actinide","3","7"],"cellBackgrounds":[null,null,null,[173,127,168,255],null,null]}],["create","w200","rwt.widgets.GridItem",{"parent":"w99","index":92,"texts":["93","Np","Neptunium","Actinide","3","7"],"cellBackgrounds":[null,null,null,[173,127,168,255],null,null]}],["create","w201","rwt.widgets.GridItem",{"parent":"w99","index":93,"texts":["94","Pu","Plutonium","Actinid');
  CopyChars(s, pos, 'e","3","7"],"cellBackgrounds":[null,null,null,[173,127,168,255],null,null]}],["create","w202","rwt.widgets.GridItem",{"parent":"w99","index":94,"texts":["95","Am","Americium","Actinide","3","7"],"cellBackgrounds":[null,null,null,[173,127,168,255],null,null]}],["create","w203","rwt.widgets.GridItem",{"parent":"w99","index":95,"texts":["96","Cm","Curium","Actinide","3","7"],"cellBackgrounds":[null,n');
  CopyChars(s, pos, 'ull,null,[173,127,168,255],null,null]}],["create","w204","rwt.widgets.GridItem",{"parent":"w99","index":96,"texts":["97","Bk","Berkelium","Actinide","3","7"],"cellBackgrounds":[null,null,null,[173,127,168,255],null,null]}],["create","w205","rwt.widgets.GridItem",{"parent":"w99","index":97,"texts":["98","Cf","Californium","Actinide","3","7"],"cellBackgrounds":[null,null,null,[173,127,168,255],null,');
  CopyChars(s, pos, 'null]}],["create","w206","rwt.widgets.GridItem",{"parent":"w99","index":98,"texts":["99","Es","Einsteinium","Actinide","3","7"],"cellBackgrounds":[null,null,null,[173,127,168,255],null,null]}],["create","w207","rwt.widgets.GridItem",{"parent":"w99","index":99,"texts":["100","Fm","Fermium","Actinide","3","7"],"cellBackgrounds":[null,null,null,[173,127,168,255],null,null]}],["create","w208","rwt.wid');
  CopyChars(s, pos, 'gets.GridItem",{"parent":"w99","index":100,"texts":["101","Md","Mendelevium","Actinide","3","7"],"cellBackgrounds":[null,null,null,[173,127,168,255],null,null]}],["create","w209","rwt.widgets.GridItem",{"parent":"w99","index":101,"texts":["102","No","Nobelium","Actinide","3","7"],"cellBackgrounds":[null,null,null,[173,127,168,255],null,null]}],["create","w210","rwt.widgets.GridItem",{"parent":"w99');
  CopyChars(s, pos, '","index":102,"texts":["103","Lr","Lawrencium","Actinide","3","7"],"cellBackgrounds":[null,null,null,[173,127,168,255],null,null]}],["create","w211","rwt.widgets.GridItem",{"parent":"w99","index":103,"texts":["104","Rf","Rutherfordium","Transition metal","4","7"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w212","rwt.widgets.GridItem",{"parent":"w99","index":104,"tex');
  CopyChars(s, pos, 'ts":["105","Db","Dubnium","Transition metal","5","7"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w213","rwt.widgets.GridItem",{"parent":"w99","index":105,"texts":["106","Sg","Seaborgium","Transition metal","6","7"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w214","rwt.widgets.GridItem",{"parent":"w99","index":106,"texts":["107","Bh","');
  CopyChars(s, pos, 'Bohrium","Transition metal","7","7"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w215","rwt.widgets.GridItem",{"parent":"w99","index":107,"texts":["108","Hs","Hassium","Transition metal","8","7"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w216","rwt.widgets.GridItem",{"parent":"w99","index":108,"texts":["109","Mt","Meitnerium","Transit');
  CopyChars(s, pos, 'ion metal","9","7"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w217","rwt.widgets.GridItem",{"parent":"w99","index":109,"texts":["110","Ds","Darmstadtium","Transition metal","10","7"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w218","rwt.widgets.GridItem",{"parent":"w99","index":110,"texts":["111","Rg","Roentgenium","Transition metal"');
  CopyChars(s, pos, ',"11","7"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w219","rwt.widgets.GridItem",{"parent":"w99","index":111,"texts":["112","Uub","Ununbium","Transition metal","12","7"],"cellBackgrounds":[null,null,null,[252,175,62,255],null,null]}],["create","w220","rwt.widgets.GridItem",{"parent":"w99","index":112,"texts":["113","Uut","Ununtrium","Poor metal","13","7"],"cellBac');
  CopyChars(s, pos, 'kgrounds":[null,null,null,[238,238,236,255],null,null]}],["create","w221","rwt.widgets.GridItem",{"parent":"w99","index":113,"texts":["114","Uuq","Ununquadium","Poor metal","14","7"],"cellBackgrounds":[null,null,null,[238,238,236,255],null,null]}],["create","w222","rwt.widgets.GridItem",{"parent":"w99","index":114,"texts":["115","Uup","Ununpentium","Poor metal","15","7"],"cellBackgrounds":[null,nu');
  CopyChars(s, pos, 'll,null,[238,238,236,255],null,null]}],["create","w223","rwt.widgets.GridItem",{"parent":"w99","index":115,"texts":["116","Uuh","Ununhexium","Poor metal","16","7"],"cellBackgrounds":[null,null,null,[238,238,236,255],null,null]}],["create","w224","rwt.widgets.GridItem",{"parent":"w99","index":116,"texts":["117","Uus","Ununseptium","Halogen","17","7"],"cellBackgrounds":[null,null,null,[252,233,79,25');
  CopyChars(s, pos, '5],null,null]}],["create","w225","rwt.widgets.GridItem",{"parent":"w99","index":117,"texts":["118","Uuo","Ununoctium","Noble gas","18","7"],"cellBackgrounds":[null,null,null,[114,159,207,255],null,null]}],["create","w226","rwt.widgets.Composite",{"parent":"w97","style":["BORDER"],"bounds":[10,464,988,25],"children":["w227"],"tabIndex":-1,"clientArea":[0,0,986,23]}],["create","w227","rwt.widgets.La');
  CopyChars(s, pos, 'bel",{"parent":"w226","style":["NONE"],"bounds":[10,10,966,3],"tabIndex":-1,"text":"Hydrogen (H)"}],["create","w228","rwt.widgets.Label",{"parent":"w97","style":["WRAP"],"bounds":[10,499,988,16],"tabIndex":-1,"foreground":[150,150,150,255],"font":[["Verdana","Lucida Sans","Arial","Helvetica","sans-serif"],10,false,false],"text":"Shortcuts: [CTRL+F] - Filter | Sort by: [CTRL+R] - Number, [CTRL+Y] -');
  CopyChars(s, pos, ' Symbol, [CTRL+N] - Name, [CTRL+S] - Series, [CTRL+G] - Group, [CTRL+E] - Period"}],["set","w1",{"focusControl":"w99"}],["call","rwt.client.BrowserNavigation","addToHistory",{"entries":[["tableviewer","TableViewer"]]}]]}');
END BuildPart3;

PROCEDURE BuildJsonString(): Chars;
  VAR s: Chars; pos: INT32;
BEGIN
  NEW(s, JSONLEN + 1);
  pos := 0;
  BuildPart1(s, pos);
  BuildPart2(s, pos);
  BuildPart3(s, pos);
  s[pos] := 0X;
  RETURN s
END BuildJsonString;

(* --- JSON Type Constructors --- *)

PROCEDURE CreateJsonObject(): JsonObject;
  VAR o: JsonObject; i: INT32;
BEGIN
  NEW(o);
  o.names := SOM.CreateVector(0);
  o.values := SOM.CreateVector(0);
  o.hashLen := 32;
  NEW(o.hashTable, o.hashLen);
  FOR i := 0 TO o.hashLen - 1 DO o.hashTable[i] := 0 END;
  RETURN o
END CreateJsonObject;

PROCEDURE CreateJsonArray(): JsonArray;
  VAR a: JsonArray;
BEGIN
  NEW(a);
  a.values := SOM.CreateVector(0);
  RETURN a
END CreateJsonArray;

PROCEDURE CreateJsonString(s: Chars): JsonString;
  VAR js: JsonString;
BEGIN
  NEW(js);
  js.string := s;
  RETURN js
END CreateJsonString;

PROCEDURE CreateJsonNumber(s: Chars): JsonNumber;
  VAR n: JsonNumber;
BEGIN
  NEW(n);
  n.string := s;
  RETURN n
END CreateJsonNumber;

PROCEDURE CreateJsonLiteral(value: ARRAY OF CHAR): JsonLiteral;
  VAR l: JsonLiteral;
BEGIN
  NEW(l);
  l.isNull := (value[0] = "n");
  l.isTrue := (value[0] = "t");
  l.isFalse := (value[0] = "f");
  RETURN l
END CreateJsonLiteral;

PROCEDURE CreateStringObject(s: Chars): StringObject;
  VAR o: StringObject;
BEGIN
  NEW(o);
  o.str := s;
  RETURN o
END CreateStringObject;

(* --- HashIndexTable Operations --- *)

PROCEDURE HashSlotFor(hashLen: INT32; name: Chars): INT32;
  VAR h: INT32;
BEGIN
  h := CharsLen(name) * 1402589;
  h := SYSTEM.VAL(INT32, SYSTEM.VAL(SET, h) * SYSTEM.VAL(SET, hashLen - 1));
  IF h < 0 THEN h := -h END;
  RETURN h
END HashSlotFor;

PROCEDURE HashTableAdd(hashTable: POINTER TO ARRAY OF INT32; hashLen: INT32; name: Chars; index: INT32);
  VAR slot: INT32;
BEGIN
  slot := HashSlotFor(hashLen, name);
  IF index < 0FFH THEN
    hashTable[slot] := (index + 1) MOD 256;
  ELSE
    hashTable[slot] := 0;
  END;
END HashTableAdd;

PROCEDURE HashTableGet(hashTable: POINTER TO ARRAY OF INT32; hashLen: INT32; name: Chars): INT32;
  VAR slot: INT32;
BEGIN
  slot := HashSlotFor(hashLen, name);
  RETURN (hashTable[slot] MOD 256) - 1
END HashTableGet;

(* --- JsonObject Operations --- *)

PROCEDURE JsonObjectAdd(obj: JsonObject; name: Chars; value: JsonValue): JsonObject;
BEGIN
  HashTableAdd(obj.hashTable, obj.hashLen, name, SOM.VectorSize(obj.names));
  SOM.VectorAppend(obj.names, CreateStringObject(name));
  SOM.VectorAppend(obj.values, value);
  RETURN obj
END JsonObjectAdd;

PROCEDURE JsonObjectGet(obj: JsonObject; name: ARRAY OF CHAR): JsonValue;
  VAR index: INT32; nameChars: Chars; i: INT32; storedName: Chars;
BEGIN
  NEW(nameChars, LEN(name));
  FOR i := 0 TO LEN(name) - 1 DO nameChars[i] := name[i] END;
  index := HashTableGet(obj.hashTable, obj.hashLen, nameChars);
  IF (index # -1) & (index < SOM.VectorSize(obj.names)) THEN
    storedName := SOM.VectorAt(obj.names, index)(StringObject).str;
    IF CharsEqualStr(storedName, name) THEN
      RETURN SOM.VectorAt(obj.values, index)(JsonValue)
    END;
  END;
  HALT(99); RETURN NIL
END JsonObjectGet;

(* --- JsonArray Operations --- *)

PROCEDURE JsonArrayAdd(arr: JsonArray; value: JsonValue): JsonArray;
BEGIN
  SOM.VectorAppend(arr.values, value);
  RETURN arr
END JsonArrayAdd;

PROCEDURE JsonArraySize(arr: JsonArray): INT32;
BEGIN
  RETURN SOM.VectorSize(arr.values)
END JsonArraySize;

(* --- Parser --- *)

PROCEDURE CreateParser(input: Chars): Parser;
  VAR p: Parser;
BEGIN
  NEW(p);
  p.input := input;
  p.len := CharsLen(input);
  p.index := -1;
  p.line := 1;
  p.column := 0;
  p.captureStart := -1;
  p.capturePos := 0;
  p.captureLen := 0;
  p.captureBuf := NIL;
  p.Null := CreateJsonLiteral("null");
  p.True := CreateJsonLiteral("true");
  p.False := CreateJsonLiteral("false");
  p.current := 0X;
  RETURN p
END CreateParser;

PROCEDURE IsWhiteSpace(p: Parser): BOOLEAN;
BEGIN
  RETURN (p.current = " ") OR (p.current = 9X) OR (p.current = 0AX) OR (p.current = 0DX)
END IsWhiteSpace;

PROCEDURE IsDigit(p: Parser): BOOLEAN;
  VAR ch: CHAR;
BEGIN
  ch := p.current;
  RETURN (ch >= "0") & (ch <= "9")
END IsDigit;

PROCEDURE ParserRead(p: Parser);
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

PROCEDURE ReadChar(p: Parser; ch: CHAR): BOOLEAN;
BEGIN
  IF p.current # ch THEN RETURN FALSE END;
  ParserRead(p);
  RETURN TRUE
END ReadChar;

PROCEDURE ReadRequiredChar(p: Parser; ch: CHAR);
BEGIN
  IF ~ReadChar(p, ch) THEN HALT(99) END;
END ReadRequiredChar;

PROCEDURE ReadDigit(p: Parser): BOOLEAN;
BEGIN
  IF ~IsDigit(p) THEN RETURN FALSE END;
  ParserRead(p);
  RETURN TRUE
END ReadDigit;

PROCEDURE SkipWhiteSpace(p: Parser);
BEGIN
  WHILE IsWhiteSpace(p) DO ParserRead(p) END;
END SkipWhiteSpace;

PROCEDURE StartCapture(p: Parser);
BEGIN
  p.captureStart := p.index;
END StartCapture;

PROCEDURE BufAppendChar(p: Parser; ch: CHAR);
  VAR newBuf: Chars; i: INT32;
BEGIN
  IF p.captureBuf = NIL THEN
    p.captureLen := 64;
    NEW(p.captureBuf, p.captureLen);
  ELSIF p.capturePos >= p.captureLen THEN
    NEW(newBuf, p.captureLen * 2);
    FOR i := 0 TO p.capturePos - 1 DO
      newBuf[i] := p.captureBuf[i];
    END;
    p.captureBuf := newBuf;
    p.captureLen := p.captureLen * 2;
  END;
  p.captureBuf[p.capturePos] := ch;
  INC(p.capturePos);
END BufAppendChar;

PROCEDURE PauseCapture(p: Parser);
  VAR End, i: INT32;
BEGIN
  IF p.current = 0X THEN End := p.index ELSE End := p.index - 1 END;
  FOR i := p.captureStart TO End DO
    BufAppendChar(p, p.input[i]);
  END;
  p.captureStart := -1;
END PauseCapture;

PROCEDURE EndCapture(p: Parser): Chars;
  VAR End, i: INT32; captured: Chars;
BEGIN
  IF p.current = 0X THEN End := p.index ELSE End := p.index - 1 END;
  FOR i := p.captureStart TO End DO
    BufAppendChar(p, p.input[i]);
  END;
  NEW(captured, p.capturePos + 1);
  FOR i := 0 TO p.capturePos - 1 DO
    captured[i] := p.captureBuf[i];
  END;
  captured[p.capturePos] := 0X;
  p.capturePos := 0;
  p.captureStart := -1;
  RETURN captured
END EndCapture;

PROCEDURE ReadEscape(p: Parser);
BEGIN
  ParserRead(p);
  IF (p.current = DQUOTE) OR (p.current = "/") OR (p.current = BSLASH) THEN
    BufAppendChar(p, p.current);
  ELSIF p.current = "b" THEN
    BufAppendChar(p, CHR(8));
  ELSIF p.current = "f" THEN
    BufAppendChar(p, CHR(12));
  ELSIF p.current = "n" THEN
    BufAppendChar(p, CHR(10));
  ELSIF p.current = "r" THEN
    BufAppendChar(p, CHR(13));
  ELSIF p.current = "t" THEN
    BufAppendChar(p, CHR(9));
  ELSE
    HALT(99);
  END;
  ParserRead(p);
END ReadEscape;

PROCEDURE ReadStringInternal(p: Parser): Chars;
  VAR s: Chars;
BEGIN
  ParserRead(p);
  StartCapture(p);
  WHILE p.current # DQUOTE DO
    IF p.current = BSLASH THEN
      PauseCapture(p);
      ReadEscape(p);
      StartCapture(p);
    ELSE
      ParserRead(p);
    END;
  END;
  s := EndCapture(p);
  ParserRead(p);
  RETURN s
END ReadStringInternal;

PROCEDURE ReadFraction(p: Parser): BOOLEAN;
BEGIN
  IF ~ReadChar(p, ".") THEN RETURN FALSE END;
  IF ~ReadDigit(p) THEN HALT(99) END;
  WHILE ReadDigit(p) DO END;
  RETURN TRUE
END ReadFraction;

PROCEDURE ReadExponent(p: Parser): BOOLEAN;
BEGIN
  IF ~ReadChar(p, "e") & ~ReadChar(p, "E") THEN RETURN FALSE END;
  IF ~ReadChar(p, "+") THEN
    IF ReadChar(p, "-") THEN END;
  END;
  IF ~ReadDigit(p) THEN HALT(99) END;
  WHILE ReadDigit(p) DO END;
  RETURN TRUE
END ReadExponent;

PROCEDURE ReadNumber(p: Parser): JsonValue;
  VAR firstDigit: CHAR;
BEGIN
  StartCapture(p);
  IF ReadChar(p, "-") THEN END;
  firstDigit := p.current;
  IF ~ReadDigit(p) THEN HALT(99) END;
  IF firstDigit # "0" THEN
    WHILE ReadDigit(p) DO END;
  END;
  IF ReadFraction(p) THEN END;
  IF ReadExponent(p) THEN END;
  RETURN CreateJsonNumber(EndCapture(p))
END ReadNumber;

PROCEDURE ReadName(p: Parser): Chars;
BEGIN
  IF p.current # DQUOTE THEN HALT(99) END;
  RETURN ReadStringInternal(p)
END ReadName;

PROCEDURE ReadString(p: Parser): JsonValue;
BEGIN
  RETURN CreateJsonString(ReadStringInternal(p))
END ReadString;

PROCEDURE ReadNull(p: Parser): JsonValue;
BEGIN
  ParserRead(p);
  ReadRequiredChar(p, "u");
  ReadRequiredChar(p, "l");
  ReadRequiredChar(p, "l");
  RETURN p.Null
END ReadNull;

PROCEDURE ReadTrue(p: Parser): JsonValue;
BEGIN
  ParserRead(p);
  ReadRequiredChar(p, "r");
  ReadRequiredChar(p, "u");
  ReadRequiredChar(p, "e");
  RETURN p.True
END ReadTrue;

PROCEDURE ReadFalse(p: Parser): JsonValue;
BEGIN
  ParserRead(p);
  ReadRequiredChar(p, "a");
  ReadRequiredChar(p, "l");
  ReadRequiredChar(p, "s");
  ReadRequiredChar(p, "e");
  RETURN p.False
END ReadFalse;

PROCEDURE ReadArray(p: Parser): JsonValue;
  VAR arr: JsonArray;
BEGIN
  ParserRead(p);
  arr := CreateJsonArray();
  SkipWhiteSpace(p);
  IF ReadChar(p, "]") THEN RETURN arr END;
  REPEAT
    SkipWhiteSpace(p);
    JsonArrayAdd(arr, readValueFunc(p));
    SkipWhiteSpace(p);
  UNTIL ~ReadChar(p, ",");
  IF ~ReadChar(p, "]") THEN HALT(99) END;
  RETURN arr
END ReadArray;

PROCEDURE ReadObject(p: Parser): JsonValue;
  VAR obj: JsonObject; name: Chars;
BEGIN
  ParserRead(p);
  obj := CreateJsonObject();
  SkipWhiteSpace(p);
  IF ReadChar(p, "}") THEN RETURN obj END;
  REPEAT
    SkipWhiteSpace(p);
    name := ReadName(p);
    SkipWhiteSpace(p);
    IF ~ReadChar(p, ":") THEN HALT(99) END;
    SkipWhiteSpace(p);
    JsonObjectAdd(obj, name, readValueFunc(p));
    SkipWhiteSpace(p);
  UNTIL ~ReadChar(p, ",");
  IF ~ReadChar(p, "}") THEN HALT(99) END;
  RETURN obj
END ReadObject;

PROCEDURE ReadValue(p: Parser): JsonValue;
BEGIN
  CASE p.current OF
    "n": RETURN ReadNull(p)
  | "t": RETURN ReadTrue(p)
  | "f": RETURN ReadFalse(p)
  | "[": RETURN ReadArray(p)
  | "{": RETURN ReadObject(p)
  | "-", "0".."9": RETURN ReadNumber(p)
  ELSE
    IF p.current = DQUOTE THEN RETURN ReadString(p)
    ELSE HALT(99); RETURN NIL
    END
  END
END ReadValue;

PROCEDURE Parse(p: Parser): JsonValue;
  VAR result: JsonValue;
BEGIN
  ParserRead(p);
  SkipWhiteSpace(p);
  result := ReadValue(p);
  SkipWhiteSpace(p);
  IF p.current # 0X THEN HALT(99) END;
  RETURN result
END Parse;

(* --- Benchmark Interface --- *)

PROCEDURE DoBenchmark*(b: Benchmark.Benchmark): SOM.Object;
  VAR p: Parser;
BEGIN
  IF jsonString = NIL THEN jsonString := BuildJsonString() END;
  p := CreateParser(jsonString);
  RETURN Parse(p)
END DoBenchmark;

PROCEDURE VerifyResult*(b: Benchmark.Benchmark; result: SOM.Object): BOOLEAN;
  VAR obj: JsonObject; tmp: JsonValue;
BEGIN
  IF result = NIL THEN RETURN FALSE END;
  IF ~(result IS JsonObject) THEN RETURN FALSE END;
  obj := result(JsonObject);
  tmp := JsonObjectGet(obj, "head");
  IF ~(tmp IS JsonObject) THEN RETURN FALSE END;
  tmp := JsonObjectGet(obj, "operations");
  IF ~(tmp IS JsonArray) THEN RETURN FALSE END;
  RETURN JsonArraySize(tmp(JsonArray)) = 156
END VerifyResult;

PROCEDURE Create*(): Json;
  VAR j: Json;
BEGIN
  NEW(j);
  j.InnerBenchmarkLoop := Benchmark.InnerBenchmarkLoop;
  j.DoBenchmark := DoBenchmark;
  j.VerifyResult := VerifyResult;
  RETURN j
END Create;

BEGIN
  readValueFunc := ReadValue;
  jsonString := NIL;
END Json.
