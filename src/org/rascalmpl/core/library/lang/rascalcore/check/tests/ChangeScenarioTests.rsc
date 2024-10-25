@synopsis{Tests for common change scenarios}
module lang::rascalcore::check::tests::ChangeScenarioTests

import lang::rascalcore::check::tests::StaticTestingUtils;

test bool fixMissingImport(){
    clearMemory();
    assert missingModuleInModule("module B import A;");
    writeModule("module A");
    return checkModuleOK("module C import B;");
}

test bool fixMissingExtend(){
    clearMemory();
    assert missingModuleInModule("module B extend A;");
    writeModule("module A");
    return checkModuleOK("module C extend B;");
}

test bool fixErrorInImport(){
    clearMemory();
    assert checkModuleOK("module A public bool b = false;");
    moduleB = "module B import A; int n = b + 1;";
    assert unexpectedTypeInModule(moduleB);
    assert checkModuleOK("module A public int b = 0;"); // change b to type int
    return checkModuleOK(moduleB);
}

test bool fixErrorInExtend(){
    clearMemory();
    assert checkModuleOK("module A bool b = false;");
    moduleB = "module B extend A; int n = b + 1;";
    assert unexpectedTypeInModule(moduleB);
    assert checkModuleOK("module A int b = 0;"); // change b to type int
    return checkModuleOK(moduleB);
}

test bool introduceErrorInImport(){
    clearMemory();
    assert checkModuleOK("module A public int b = 0;");
    moduleB = "module B import A; int n = b + 1;";
    assert checkModuleOK(moduleB);
    assert checkModuleOK("module A public bool b = false;");
    return unexpectedTypeInModule(moduleB);
}

test bool introduceErrorInExtend(){
    clearMemory();
    assert checkModuleOK("module A int b = 0;");
    moduleB = "module B extend A; int n = b + 1;";
    assert checkModuleOK(moduleB);
    assert checkModuleOK("module A bool b = false;");
    return unexpectedTypeInModule(moduleB);
}

test bool removeImportedModuleAndRestoreIt1(){
    clearMemory();
    assert checkModuleOK("module A");
    moduleB = "module B import A;";
    assert checkModuleOK(moduleB);
    removeModule("A");
    assert missingModuleInModule(moduleB);
    assert checkModuleOK("module A");
    return checkModuleOK(moduleB);
}

test bool removeImportedModuleAndRestoreIt2(){
    clearMemory();
    moduleA = "module A int twice(int n) = n * n;";
    assert checkModuleOK(moduleA);
    moduleB = "module B import A; int quad(int n) = twice(twice(n));";
    assert checkModuleOK(moduleB);
    removeModule("A");
    assert missingModuleInModule(moduleB);
    assert checkModuleOK(moduleA);
    return checkModuleOK(moduleB);
}

test bool removeExtendedModuleAndRestoreIt1(){
    clearMemory();
    moduleA = "module A";
    assert checkModuleOK(moduleA);
    moduleB = "module B extend A;";
    assert checkModuleOK(moduleB);
    removeModule("A");
    assert missingModuleInModule(moduleB);
    assert checkModuleOK(moduleA);
    return checkModuleOK(moduleB);
}

test bool removeExtendedModuleAndRestoreIt2(){
    clearMemory();
    moduleA = "module A int twice(int n) = n * n;";
    assert checkModuleOK(moduleA);
    moduleB = "module B extend A; int quad(int n) = twice(twice(n));";
    assert checkModuleOK(moduleB);
    removeModule("A");
    assert missingModuleInModule(moduleB);
    assert checkModuleOK(moduleA);
    return checkModuleOK(moduleB);
}

test bool removeOverloadAndRestoreIt(){
    clearMemory();
    moduleA1 = "module A
                int dup(int n) = n + n;
                str dup(str s) = s + s;";
    moduleA2 = "module A
                int dup(int n) = n + n;";
    assert checkModuleOK(moduleA1);
    moduleB = "module B import A;  str f(str s) = dup(s);";
    assert checkModuleOK(moduleB);
    removeModule("A");
    assert missingModuleInModule(moduleB);

    assert checkModuleOK(moduleA2);
    assert argumentMismatchInModule(moduleB);
    assert checkModuleOK(moduleA1);
    return checkModuleOK(moduleB);
}

test bool removeConstructorAndRestoreIt(){
    clearMemory();
    moduleA1 = "module A
                data D = d(int n) | d(str s);";
    moduleA2 = "module A
                data D = d(int n);";
    assert checkModuleOK(moduleA1);
    moduleB = "module B import A;  D f(str s) = d(s);";
    assert checkModuleOK(moduleB);
    removeModule("A");
    assert missingModuleInModule(moduleB);

    assert checkModuleOK(moduleA2);
    assert argumentMismatchInModule(moduleB);
    assert checkModuleOK(moduleA1);
    return checkModuleOK(moduleB);
}

// ---- incremental type checking ---------------------------------------------
// Legend:
//      X ==> Y: replace X by Y
//      *X     : check starts at X
//      X!     : X is (re)checked
// Scenarios:
//     I        II      III     IV      V       VI
//
//     *A1!     A1  ==> A2!     A2  ==> A3!     A3
//              |       |       |       |       |
//             *B1!     B1      B1      B1 ==>  B2!
//                              |       |       |
//                             *C1!    *C1     *C1

test bool nobreakingChange1(){
    clearMemory();
    moduleA1 = "module A";
    moduleA2 = "module A
                    public int n = 3;";
    moduleA3 = "module A
                    public int n = 3;
                    data D = d1();";

    assert checkedInModule(moduleA1, ["A"]);    // I

    moduleB1 = "module B
                    import A;";
    moduleB2 = "module B
                    import A;
                    public int m = n + 1;";
    assert checkedInModule(moduleB1, ["B"]);    // II

    writeModule(moduleA2);
    assert checkedInModule(moduleB1, ["A"]);    // III

    moduleC1 = "module C
                    import B;
                    int f() = 2;";
    assert checkedInModule(moduleC1, ["C"]);    // IV

    writeModule(moduleA3);

    assert checkedInModule(moduleC1, ["A"]);    // V

    writeModule(moduleB2);
    return checkedInModule(moduleC1, ["B"]);    // VI
}
//      I                   II
//
//      A1!------+          A1--------+
//      |        |          |         |
//      B1!--+   |    ==>   B2!--+    |
//      |    |   |          |    |    |
//      C1!  +---D1!        C1   +----D1
//      |        |          |         |
//      +--*E!---+          +---*E----+

test bool nobreakingChange2(){
    clearMemory();
    moduleA1 = "module A";
    moduleB1 = "module B import A;";
    moduleC1 = "module C import B;";
    moduleD1 = "module D import A; import B;";
    moduleE1 = "module E import C; import D;";

    moduleB2 = "module B import A; int n = 0;";

    writeModule(moduleA1);
    writeModule(moduleB1);
    writeModule(moduleC1);
    writeModule(moduleD1);
    writeModule(moduleE1);

    assert checkedInModule(moduleE1, ["A", "B", "C", "D", "E"]);    // I

    writeModule(moduleB2);
    return checkedInModule(moduleC1, ["B"]);                        // II
}

//      I                   II
//
//      A1!------+          A1--------+
//      |        |          |         |
//      B1!--+   |    ==>   B2!--+    |
//      |    |   |          |    |    |
//      C1!  +---D1!        C1!  +----D1
//      |        |          |         |
//      +--*E!---+          +---*E----+

test bool noBreakingChange3(){
    clearMemory();
    moduleA1 = "module A";
    moduleB1 = "module B import A; int b() = 1;";
    moduleC1 = "module C import B; int c() = b();";
    moduleD1 = "module D import A; import B;";
    moduleE1 = "module E import C; import D;";

    moduleB2 = "module B import A; int b(int n) = n;";

    writeModule(moduleA1);
    writeModule(moduleB1);
    writeModule(moduleC1);
    writeModule(moduleD1);
    writeModule(moduleE1);

    assert checkedInModule(moduleE1, ["A", "B", "C", "D", "E"]);    // I

    writeModule(moduleB2);
    return checkedInModule(moduleC1, ["B", "C"]);                   // II
}


//      I       II             III       IV
//
//      A1!     A1-----+  ==>  A2!       A2-------+
//      |       |      |       |         |        |
//      B1!     B1    *D1!     B1        B1       D1!
//      |       |              |         |        |
//     *C1!     C1            *C1   ==> *C2! -----+
//
test bool noBreakingChange4(){
    clearMemory();
    moduleA1 = "module A";
    moduleA2 = "module A int a() = 0;";
    moduleB1 = "module B import A; int b() = 1;";
    moduleC1 = "module C import B; int c() = b();";
    moduleC2 = "module C import B; import D; int c() = b();";
    moduleD1 = "module D import A;";

    writeModule(moduleA1);
    writeModule(moduleB1);
    writeModule(moduleC1);

    assert checkedInModule(moduleC1, ["A", "B", "C"]);  // I

    writeModule(moduleD1);
    assert checkedInModule(moduleD1, ["D"]);            // II

    writeModule(moduleA2);
    assert checkedInModule(moduleC1, ["A"]);            // III

     writeModule(moduleC2);
     return checkedInModule(moduleC2, ["C", "D"]);      // IV
}

test bool noBreakingChange5(){
    moduleException1 = "module Exception";
    moduleException2 = "module Exception
                            int n = 0;";
    moduleMath = "module Math import Exception; import List; ";
    moduleList = "module List import Map; import Exception; ";
    moduleMap = "module Map";
    moduleSet1 = "module Set import List; import Exception; import Math;";
    moduleSet2 = "module Set import List; import Exception; import Math;
                        int m = 0;";
    moduleTop = "module Top  import List; import Set; ";

    writeModule(moduleException1);
    writeModule(moduleMath);
    writeModule(moduleList);
    writeModule(moduleMap);
    writeModule(moduleSet1);
    writeModule(moduleTop);

    assert checkedInModule(moduleTop, ["Exception", "Math", "List", "Map", "Set", "Top"]);

    writeModule(moduleException2);
    assert checkedInModule(moduleTop, ["Exception"]);

    writeModule(moduleSet2);
    return checkedInModule(moduleTop, ["Set"]);
}