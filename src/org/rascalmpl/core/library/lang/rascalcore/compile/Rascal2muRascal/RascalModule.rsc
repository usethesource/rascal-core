@bootstrapParser
module lang::rascalcore::compile::Rascal2muRascal::RascalModule

import IO;
import Map;
import String;
import Set;
import List;
import Relation;
import util::Reflective;
//import util::ValueUI;

import ParseTree;
import lang::rascalcore::compile::CompileTimeError;

import lang::rascal::\syntax::Rascal;
import lang::rascalcore::compile::muRascal::AST;
//import lang::rascalcore::compile::muRascal2RVM::Relocate;

extend lang::rascalcore::check::Checker;

import lang::rascalcore::compile::Rascal2muRascal::ModuleInfo;
import lang::rascalcore::compile::Rascal2muRascal::TmpAndLabel;
import lang::rascalcore::compile::Rascal2muRascal::RascalType;
import lang::rascalcore::compile::Rascal2muRascal::TypeUtils;
import lang::rascalcore::compile::Rascal2muRascal::TypeReifier;

import lang::rascalcore::compile::Rascal2muRascal::RascalDeclaration;
import lang::rascalcore::compile::Rascal2muRascal::RascalExpression;

/*
 * Translate a Rascal module to muRascal.
 * The essential function is:
 * - r2mu		translate Rascal module to muRascal
 */

/********************************************************************/
/*                  Translate one module                            */
/********************************************************************/

@doc{Compile a parsed Rascal source module to muRascal}
MuModule r2mu(lang::rascal::\syntax::Rascal::Module M, TModel tmodel, PathConfig pcfg, loc reloc=|noreloc:///|, bool verbose = true, bool optimize = true, bool enableAsserts=false){
   try {
      resetModuleInfo(optimize, enableAsserts);
      module_name = "<M.header.name>";
      setModuleName(module_name);
      mtags = translateTags(M.header.tags);
      setModuleTags(mtags);
      if(ignoreTest(mtags)){
            return errorMuModule(getModuleName(), {info("Ignore tag suppressed compilation", M@\loc)}, M@\loc);
      }
     
      if(verbose) println("r2mu: entering ... <module_name>, enableAsserts: <enableAsserts>");
   	  
   	  // Extract scoping information available from the configuration returned by the type checker  
   	  extractScopes(tmodel); 
   	  
   	  // Extract all declarations for the benefit of the type reifier
      //extractDeclarationInfo(tmodel);
  
   	  map[str,AType] types = ();
   	  //	( uid2str[uid] : \type | 
   	  //	  int uid <- config.store, 
   	  //	  ( AbstractValue::constructor(RName name, Symbol \type, KeywordParamMap keywordParams, int containedIn, _, loc at) := config.store[uid]
   	  //	  || AbstractValue::production(RName name, Symbol \type, int containedIn, _, Production p, loc at) := config.store[uid] 
   	  //	  ),
   	  //	  //bprintln(config.store[uid]), bprintln(config.store[containedIn].at.path), bprintln(at.path),
   	  //	  !isEmpty(getSimpleName(name)),
   	  //	  containedIn == 0, 
   	  //	  ( config.store[containedIn].at.path == at.path // needed due to the handling of 'extend' by the type checker
   	  //	  || at.path  == "/ConsoleInput.rsc"             // TODO: hack to get the RascalShell working, since config.store[0].at.path
   	  //	                                                 // "/experiments/Compiler/Compile.rc"???
   	  //	  )
   	  //	);
   	 
   	  translateModule(M);
   	 
   	  modName = replaceAll("<M.header.name>","\\","");
                      
   	  return /*relocMuModule(*/
   	            muModule(modName,
   	  				  getModuleTags(),
   	                  toSet(tmodel.messages), 
   	  				  getImportsInModule(),
   	  				  getExtendsInModule(), 
   	  				  getADTs(), 
   	  				  getConstructors(),
   	  				  getFunctionsInModule(), 
   	  				  getVariablesInModule(), 
   	  				  getVariableInitializationsInModule(), 
   	  				  getModuleVarInitLocals(modName), 
   	  				  getOverloadedFunctions(), 
   	  				  getGrammar(),
   	  				  {}, //{<prettyPrintName(rn1), prettyPrintName(rn2)> | <rn1, rn2> <- config.importGraph},
   	  				  M@\loc) /*,   
   	  				  reloc,
   	  				  pcfg.srcs)*/;

   }
   catch ParseError(loc l): {
        if (verbose) println("Parse error in concrete syntax <l>; returning error module");
        return errorMuModule(getModuleName(), {error("Parse error in concrete syntax fragment", l)}, M@\loc);
   }
   catch CompileTimeError(Message m): {
        return errorMuModule(getModuleName(), {m}, M@\loc);
   }
   //catch value e: {
   //     return errorMuModule(getModuleName(), {error("Unexpected compiler exception <e>", M@\loc)}, M@\loc);
   //}
   finally {
   	   resetModuleInfo(optimize, enableAsserts);
   	   resetScopeExtraction();
   }
   throw "r2mu: cannot come here!";
}

TModel relocConfig(TModel tmodel, loc reloc, list[loc] srcs){
        return visit(tmodel) { case loc l => relocLoc(l, reloc, srcs) };
}

void translateModule((Module) `<Header header> <Body body>`) {
    for(imp <- header.imports) importModule(imp);
	for( tl <- body.toplevels) translate(tl);
}

/********************************************************************/
/*                  Translate imports in a module                   */
/********************************************************************/

private void importModule((Import) `import <QualifiedName qname> ;`){
    addImportToModule("<qname>"); //TODO
    // addImportToModule(prettyPrintName(convertName(qname)));
}

private void importModule((Import) `extend <QualifiedName qname> ;`){
	moduleName = "<qname>";    //TODO
	//moduleName = prettyPrintName(convertName(qname));
	addImportToModule(moduleName);
	addExtendToModule(moduleName);
}

private void importModule((Import) `<SyntaxDefinition syntaxdef>`){ /* nothing to do */ }

private default void importModule(Import imp){
    throw "Unimplemented import: <imp>";
}