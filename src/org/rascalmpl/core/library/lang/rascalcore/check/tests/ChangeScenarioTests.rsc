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

bool removeImportedModuleAndRestoreIt1(){
    clearMemory();
    assert checkModuleOK("module A");
    moduleB = "module B import A;";
    assert checkModuleOK(moduleB);
    removeModule("A");
    assert missingModuleInModule(moduleB);
    assert checkModuleOK("module A");
    return checkModuleOK(moduleB);
}

bool removeImportedModuleAndRestoreIt2(){
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

bool removeExtendedModuleAndRestoreIt1(){
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

bool removeExtendedModuleAndRestoreIt2(){
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