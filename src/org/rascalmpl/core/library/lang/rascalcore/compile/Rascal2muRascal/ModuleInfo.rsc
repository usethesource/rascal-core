module lang::rascalcore::compile::Rascal2muRascal::ModuleInfo

import List;
import lang::rascalcore::compile::muRascal::AST;
import lang::rascalcore::compile::Rascal2muRascal::TmpAndLabel;
import Grammar;
import lang::rascalcore::check::RascalConfig;
import String;

 // Global state maintained when translating a Rascal module

private str module_name;							//  name of current module
private map[str,str] module_tags;                   // tags of current module;
private list[str] imported_modules = [];			// modules imported by current module
private list[str] extended_modules = [];			// modules extended by current module
private list[MuFunction] functions_in_module = [];	// functions declared in current module
private list[MuModuleVar] variables_in_module = [];	// variables declared in current module
private list[MuExp] variable_initializations = [];	// initialized variables declared in current module

private bool optimizingVisit = false;
private bool enablingAsserts = true;

// Access functions

public bool optimizeVisit() = optimizingVisit;

public bool assertsEnabled() = enablingAsserts;

public void setModuleName(str name){
	module_name = name;
}

public str getRascalModuleName() = module_name;

public str getRascalModuleNameUnderscores() = replaceAll(module_name, "::", "_");

public void setModuleTags(map[str,str] mtags){
    module_tags = mtags;
}

map[str,str] getModuleTags(){
    return module_tags;
}

public void addImportToModule(str moduleName){
	imported_modules += moduleName;
}

public list[str] getImportsInModule(){
	return imported_modules;
}

public void addExtendToModule(str moduleName){
	extended_modules += moduleName;
}

public list[str] getExtendsInModule(){
	return extended_modules;
}

public list[MuFunction] getFunctionsInModule() {
  	//println("getFunctionsInModule:");for(fun <- functions_in_module){ println("\t<fun.uniqueName>, <fun.scopeIn>"); }
	return functions_in_module;
}

public void addFunctionToModule(MuFunction fun) {
   functions_in_module += [fun];
}

public void addFunctionsToModule(list[MuFunction] funs) {
   if(size(funs) > 0){
   		//println("addFunctionsToModule [<size(funs)>]: <for(fun <- funs){><fun.qname>, \"<fun.scopeIn>\" <}>");
   
   		functions_in_module += funs;
   
   		//for(f <- functions_in_module){ println("\t<f.qname>, \"<f.scopeIn>\""); }
   }
}

public void setFunctionsInModule(list[MuFunction] funs) {
   //println("setFunctionsInModule: <for(f <- funs){><f.qname>, \"<f.scopeIn>\" <}>");
   
   functions_in_module = funs;
   
   //for(f <- functions_in_module){	println("\t<f.qname>, \"<f.scopeIn>\""); }
}

public void addVariableToModule(MuModuleVar muVar){
	variables_in_module += [muVar];
}

public list[MuModuleVar] getVariablesInModule(){
	return variables_in_module;
}


public void addVariableInitializationToModule(MuExp exp){
	variable_initializations += [exp];
}

public list[MuExp] getVariableInitializationsInModule(){
//println("getVariableInitializationsInModule:");
//iprintln(variable_initializations);
	return variable_initializations;
}

// Reset global state

void resetModuleInfo(RascalCompilerConfig compilerConfig) {

    optimizingVisit = compilerConfig.optimizeVisit;
    enablingAsserts = compilerConfig.enableAsserts;
 	module_name = "** undefined **";
 	module_tags = ("***":"+++");
    imported_modules = [];
    extended_modules = [];
	functions_in_module = [];
	variables_in_module = [];
	variable_initializations = [];
	resetTmpAndLabel();
}
