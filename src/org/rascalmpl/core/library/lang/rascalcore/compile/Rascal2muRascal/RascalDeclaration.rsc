@license{
Copyright (c) 2018-2025, NWO-I CWI, Swat.engineering and Paul Klint
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.
}
@bootstrapParser
module lang::rascalcore::compile::Rascal2muRascal::RascalDeclaration

import IO;
import Map;
import List;
import ListRelation;
import Location;
import Node;
import Set;
import String;
import lang::rascal::\syntax::Rascal;
import ParseTree;

import lang::rascalcore::compile::CompileTimeError;

import lang::rascalcore::compile::muRascal::AST;

import lang::rascalcore::check::AType;
import lang::rascalcore::check::ATypeUtils;
import lang::rascalcore::check::BacktrackFree;
import lang::rascalcore::check::NameUtils;
import lang::rascalcore::compile::util::Names;
import lang::rascalcore::check::SyntaxGetters;

import lang::rascalcore::compile::Rascal2muRascal::ModuleInfo;
import lang::rascalcore::compile::Rascal2muRascal::RascalType;
import lang::rascalcore::compile::Rascal2muRascal::TypeUtils;
import lang::rascalcore::compile::Rascal2muRascal::TmpAndLabel;

import lang::rascalcore::compile::Rascal2muRascal::RascalExpression;
import lang::rascalcore::compile::Rascal2muRascal::RascalPattern;
import lang::rascalcore::compile::Rascal2muRascal::RascalStatement;

import lang::rascalcore::compile::muRascal2Java::Conversions;   // TODO:undesired dependency




/********************************************************************/
/*                  Translate declarations in a module              */
/********************************************************************/
	
public void translateToplevel((Toplevel) `<Declaration decl>`) {
    translateDecl(decl);
}

// -- variable declaration ------------------------------------------

void translateDecl(d: (Declaration) `<Tags tags> <Visibility visibility> <Type tp> <{Variable ","}+ variables> ;`) {
	str module_name = asUnqualifiedName(getRascalModuleName());
    enterFunctionScope("<module_name>_init");
   	for(var <- variables){
   	    unescapedVarName = unescapeName("<var.name>");
   		addVariableToModule(muModuleVar(getType(tp), unescapedVarName));
   		if(var is initialized) {
   		   init_code =  translate(var.initial);
   		   asg = muAssign( muVar(unescapedVarName, getRascalModuleNameUnderscores(), -1, filterOverloads(getType(tp), {variableId()}), variableId()), init_code);
   		   addVariableInitializationToModule(asg);
   		}
   	}
   	leaveFunctionScope();
}   	

// -- miscellaneous declarations that can be skipped since they are handled during type checking ------------------

void translateDecl(d: (Declaration) `<Tags tags> <Visibility visibility> anno <Type annoType> <Type onType>@<Name name> ;`) { /*skip: translation has nothing to do here */ }
void translateDecl(d: (Declaration) `<Tags tags> <Visibility visibility> alias <UserType user> = <Type base> ;`)   { /* skip: translation has nothing to do here */ }
void translateDecl(d: (Declaration) `<Tags tags> <Visibility visibility> tag <Kind kind> <Name name> on <{Type ","}+ types> ;`)  { throw("tag"); }

void translateDecl(d : (Declaration) `<Tags tags> <Visibility visibility> data <UserType user> <CommonKeywordParameters commonKeywordParameters> ;`) { /* skip: translation has nothing to do here */ }


void translateDecl(d: (Declaration) `<Tags tags> <Visibility visibility> data <UserType user> <CommonKeywordParameters commonKeywordParameters> = <{Variant "|"}+ variants> ;`) {
    /* all getters are generated by generateAllFieldGetters */
 }
 
private MuExp promoteVarsToFieldReferences(MuExp exp, AType consType, MuExp consVar, str definingModule)
    = visit(exp){
        case muVar(str fieldName, _, -1, AType tp, IdRole idRole) => muGetField(tp, consType, consVar, fieldName)
        case muVarKwp(str fieldName, _, AType tp) => muGetKwField(tp, consType, consVar, fieldName, definingModule)
     };
    
public void translateDecl(d: (Declaration) `<FunctionDeclaration functionDeclaration>`) {
    translateFunctionDeclaration(functionDeclaration);
}


public void generateAllFieldGetters(loc module_scope){
    map[AType, set[AType]] constructors = getConstructorsMap();
    map[AType, list[Keyword]] common_keyword_fields = getCommonKeywordFieldsMap();
    
    for(adtType <- getADTs(), !isSyntaxType(adtType)){
        generateGettersForAdt(adtType, module_scope, constructors[adtType] ? {}, common_keyword_fields[adtType] ? []);
    }
}

private void generateGettersForAdt(AType adtType, loc module_scope, set[AType] constructors, list[Keyword] common_keyword_fields){

    adtName = getUniqueADTName(adtType); 
  
    /*
     * Create getters for constructor specific keyword fields.
     */
    
    lrel[str, AType, AType] kwfield2cons = [];
    
    set[str] generated_getters = {};
    
    set[str] generated_common_getters = {};
       
    for(consType <- constructors){
       /*
        * Create constructor=specific getters for each keyword field
        */
       consName = consType.alabel;
       
       for(kw <- consType.kwFields, kw has defaultExp, isContainedIn(kw.defaultExp@\loc, module_scope)){
            kwType = kw.fieldType;
            defaultExp = kw.defaultExp;
            str kwFieldName = kwType.alabel;
            kwfield2cons += <kwFieldName, kwType, consType>;
            //str fuid = getGetterNameForKwpField(consType, kwFieldName);
            str getterName = unescapeAndStandardize("$getkw_<adtName>_<consName>_<kwFieldName>");
         
            if(getterName notin generated_getters){
                generated_getters += getterName;
                
                getterType = afunc(kwType, [consType], []);
                consVar = muVar(consName, getterName, 0, consType, constructorId());
                
                defExpCode = promoteVarsToFieldReferences(translate(defaultExp), consType, consVar, kw.definingModule);
                body = muReturn1(kwType, muIfElse(muIsKwpConstructorDefined(consVar, kwFieldName), muGetKwFieldFromConstructor(kwType, consVar, kwFieldName), defExpCode));
                addFunctionToModule(muFunction(getterName, getterName, getterType, [consVar], [], [], "", false, true, false, {}, {}, {}, getModuleScope(), [], (), body)); 
            } else {
                println("In generated_getters: <getterName>");
                
            }              
       }
    }
    
     /*
      * Create generic getters for all keyword fields
      */
    
    for(str kwFieldName <- domain(kwfield2cons)){
        conses = kwfield2cons[kwFieldName];
        //str fuid = getGetterNameForKwpField(adtType, kwFieldName);
        str getterName = unescapeAndStandardize("$getkw_<adtName>_<kwFieldName>");
            
        returnType = lubList(conses<0>);
        getterType = afunc(returnType, [adtType], []);
        adtVar = muVar(adtName, getterName, 0, adtType, dataId());
        failCode = muFailReturn(returnType);
        for(Keyword kw <- common_keyword_fields, kw has defaultExp, isContainedIn(kw.defaultExp@\loc, module_scope)){
            kwType = kw.fieldType;
            str commonKwFieldName = unescape(kwType.alabel);
            if(commonKwFieldName == kwFieldName){
               generated_common_getters += commonKwFieldName;
               defExprCode = promoteVarsToFieldReferences(translate(kw.defaultExp), adtType, adtVar, kw.definingModule);
               failCode = muIfElse(muIsKwpConstructorDefined(adtVar, kwFieldName), muReturn1( returnType, muGetKwFieldFromConstructor(kwType, adtVar, kwFieldName)), muReturn1(returnType, defExprCode));
            }
        }
        body = muBlock([ muIf(muHasNameAndArity(adtType, consType, muCon(asUnqualifiedName(consType.alabel)), size(consType.fields), adtVar),
                              muReturn1(kwType, muGetKwField(kwType, consType, adtVar, kwFieldName, findDefiningModule(getLoc(consType.kwFields[0].defaultExp)))))
                       | <kwType, consType> <- conses, isContainedIn(getLoc(consType.kwFields[0].defaultExp), module_scope)
                       ]
                       + failCode
                      );
        addFunctionToModule(muFunction(getterName, getterName, getterType, [adtVar], [], [], "", false, true, false, {}, {}, {}, getModuleScope(), [], (), body));               
    }
    
        /*
     * Create getters for common keyword fields of this data type
     */
    seen = {};
    for(Keyword kw <- common_keyword_fields, kw has defaultExp, kw.fieldType notin seen, isContainedIn(kw.defaultExp@\loc, module_scope)){
        kwType = kw.fieldType;
        defaultExp = kw.defaultExp;
        seen += kwType;
        str kwFieldName = unescape(kwType.alabel);
        if(kwFieldName in generated_common_getters) continue;
        generated_common_getters += kwFieldName;
        if(asubtype(adtType, treeType)){
            if(kwFieldName == "loc") kwFieldName = "src"; // TODO: remove when .src is gone
        }
        //str fuid = getGetterNameForKwpField(adtType, kwFieldName);
        str getterName = unescapeAndStandardize("$getkw_<adtName>_<kwFieldName>");
        if(getterName == "$getkw_Tree_message"){ // TODO: remove when annotations are gone
                continue;
        }
       
        getterType = afunc(kwType, [adtType], []);
        adtVar = muVar(getterName, getterName, 0, adtType, variableId());
        
        defExprCode = promoteVarsToFieldReferences(translate(defaultExp), adtType, adtVar, kw.definingModule);
        body = muReturn1(kwType, muIfElse(muIsKwpConstructorDefined(adtVar, kwFieldName), muGetKwFieldFromConstructor(kwType, adtVar, kwFieldName), defExprCode));
        addFunctionToModule(muFunction(getterName, getterName, getterType, [adtVar], [], [], "", false, true, false, {}, {}, {}, getModuleScope(), [], (), body));               
    }
  
    
    /*
     * Ordinary fields are directly accessed via information in the constructor type
     */
 }

// -- function declaration ------------------------------------------

private set[TypeVar] getTypeVarsinFunction(FunctionDeclaration fd){
    res = {};
    top-down-break visit(fd){
        case (Expression) `<Type _> <Parameters _> { <Statement+ _> }`:
                /* ignore type vars in closures. This is not water tight since a type parameter of the surrounding
                  function may be used in the body of this closure */;
        case TypeVar tv: res += tv;
    }
    return res;
}

public void translateFunctionDeclaration(FunctionDeclaration fd){
  //println("r2mu: Compiling \uE007[<fd.signature.name>](<fd.src>)");
  inScope = topFunctionScope();
  funsrc = fd.src;
  useTypeParams = getTypeVarsinFunction(fd);
  enterFunctionDeclaration(funsrc, !isEmpty(useTypeParams));

  try {
      ttags =  translateTags(fd.tags);
      tmods = translateModifiers(fd.signature.modifiers);
      if(ignoreTest(ttags)){
          // The type checker does not generate type information for ignored functions
           addFunctionToModule(muFunction("$ignored_<prettyPrintName(fd.signature.name)>_<fd.src.offset>", 
                                         prettyPrintName(fd.signature.name), 
                                         afunc(abool(),[],[]),
                                         [],
                                         [],
                                         [],
                                         inScope, 
                                         false, 
                                         true,
                                         false,
                                         {},
                                         {},
                                         {},
                                         fd.src, 
                                         tmods, 
                                         ttags,
                                         muReturn1(abool(), muCon(false))));
          	return;
      }
      fname = prettyPrintName(fd.signature.name);
      ftype = getFunctionType(funsrc);
      resultType = ftype.ret;
      bool isVarArgs = ftype.varArgs;
      nformals = size(ftype.formals);
      fuid = convert2fuid(funsrc);
    
      enterFunctionScope(fuid);
      
      //// Keyword parameters
      lrel[str name, AType atype, MuExp defaultExp]  kwps = translateKeywordParameters(fd.signature.parameters);
      
      my_btscopes = getBTScopesParams([ft | ft <- fd.signature.parameters.formals.formals], fname);
      mubody = muBlock([]);
      if(ttags["javaClass"]?){
         params = [ muVar(ftype.formals[i].alabel, fuid, i, ftype.formals[i], formalId()) | i <- [ 0 .. nformals] ];
         mubody = muReturn1(resultType, muCallJava("<fd.signature.name>", ttags["javaClass"], ftype, params, fuid));
      } else if(fd is \default){ // function declaration with statements
                body_code = [ translate(stat, my_btscopes) | stat <- fd.body.statements ];
                if(isVoidAType(ftype.ret)) body_code += muReturn0();
                mubody = muBlock(body_code);
                //if(!exitViaReturn(mubody)){
                //    muBody = muReturn1(ftype.ret, mubody);
                //}
       } else if(fd is \expression || fd is \conditional){
            mubody = translateReturn(ftype.ret, fd.expression);
       }

      enterSignatureSection();
     
      isPub = !fd.visibility is \private;
      isMemo = ttags["memo"]?; 
      conditions = (fd is \conditional) ? [exp | exp <- fd.conditions] : [];
      <formalVars, tbody> = translateFunction(fname, fd.signature.parameters.formals.formals, ftype, mubody, isMemo, conditions);
      
      
      
      if(!isEmpty(useTypeParams) && /muTypeParameterMap(_) !:= tbody){
        typeVarsInParams = getFunctionTypeParameters(ftype);
        tbody = muBlock([muTypeParameterMap(typeVarsInParams), tbody]);
      }
      
      leaveSignatureSection();
      externals = getExternalRefs(tbody, fuid, formalVars);
      extendedFormalVars = getExtendedFunctionFormals(fd.src, fuid);
      localRefs = getLocalRefs(tbody);
       
      addFunctionToModule(muFunction(prettyPrintName(fd.signature.name), 
                                     fuid, 
      								 ftype,
      								 formalVars,
      								 extendedFormalVars,
      								 kwps,
      								 inScope,
      								 isVarArgs, 
      								 isPub,
      								 isMemo,
      								 externals,
      								 localRefs,
      								 getKeywordParameterRefs(tbody, fuid),
      								 fd.src, 
      								 tmods, 
      								 ttags,
      								 tbody));
      
      leaveFunctionScope();
      leaveFunctionDeclaration();
  } catch e: CompileTimeError(_): {
      throw e;  
  } catch Ambiguity(loc src, str _, str _): {
      throw CompileTimeError(error("Ambiguous code", src));
  }
  //catch e: {
  //      throw "EXCEPTION in translateFunctionDeclaration, compiling <fd.signature.name>: <e>";
  //}
}

private str getParameterName(list[Pattern] patterns, int i) = getParameterName(patterns[i], i);

private str getParameterName((Pattern) `<QualifiedName qname>`, int i) = "<qname>";
private str getParameterName((Pattern) `<QualifiedName qname> *`, int i) = "<qname>";
private str getParameterName((Pattern) `<Type tp> <Name name>`, int i) = "<name>";
private str getParameterName((Pattern) `<Name name> : <Pattern pattern>`, int i) = "<name>";
private str getParameterName((Pattern) `<Type tp> <Name name> : <Pattern pattern>`, int i) = "<name>";
private default str getParameterName(Pattern p, int i) = "$<i>";

private list[str] getParameterNames({Pattern ","}* formals){
     abs_formals = [f | f <- formals];
     return[ getParameterName(abs_formals, i) | i <- index(abs_formals) ];
}

private Tree getParameterNameAsTree(list[Pattern] patterns, int i) = getParameterNameAsTree(patterns[i], i);

private Tree getParameterNameAsTree((Pattern) `<QualifiedName qname>`, int i) = qname;
private Tree getParameterNameAsTree((Pattern) `<QualifiedName qname> *`, int i) = qname;
private Tree getParameterNameAsTree((Pattern) `<Type tp> <Name name>`, int i) = name;
private Tree getParameterNameAsTree((Pattern) `<Name name> : <Pattern pattern>`, int i) = name;
private Tree getParameterNameAsTree((Pattern) `<Type tp> <Name name> : <Pattern pattern>`, int i) = name;

private bool hasParameterName(list[Pattern] patterns, int i) = hasParameterName(patterns[i], i);

private bool hasParameterName((Pattern) `<QualifiedName qname>`, int i) = !isWildCard("<qname>");
private bool hasParameterName((Pattern) `<QualifiedName qname> *`, int i) = !isWildCard("<qname>");
private bool hasParameterName((Pattern) `<Type tp> <Name name>`, int i) = !isWildCard("<name>");
private bool hasParameterName((Pattern) `<Name name> : <Pattern pattern>`, int i) = !isWildCard("<name>");
private bool hasParameterName((Pattern) `<Type tp> <Name name> : <Pattern pattern>`, int i) = !isWildCard("<name>");
private default bool hasParameterName(Pattern p, int i) = false;

/*
 * Get all variables that are assigned inside a visit but are not locally introduced in that visit
 */
private set[MuExp] getVarsUsedInVisit(list[MuCase] cases, MuExp def){
    exps = [c.exp | c <- cases] + def;
    return { v1 | exp <- exps, /v:muVar(str _name, str _scope, int _, AType t, IdRole idRole) := exp, /muVarInit(v, _) !:= exp, t1 := unsetRec(t, "alabel"), v1 := v[atype=t1]};
}

/*
 * Get all assigned variables in all visits that need to be treated as reference variables
 */
public set[MuExp] getLocalRefs(MuExp exp)
    = { *getVarsUsedInVisit(cases, defaultExp) | /muVisit(str _, MuExp _, list[MuCase] cases, MuExp defaultExp, VisitDescriptor _) := exp };

/*
 * Get all variables that have been introduced outside the given function scope
 */
public set[MuExp] getExternalRefs(MuExp exp, str fuid, list[MuExp] formals){
   formalNames = {f.name | f <- formals};
   res = { v1 | /v:muVar(str name2, str fuid2, int _, AType t, IdRole idRole) := exp, name2 notin formalNames, fuid2 != fuid, fuid2 != "", t1 := unsetRec(t, "alabel"), v1 := v[atype=t1]};
   //println("getExternalRefs, <fuid>, <formals>: <res>");
   return res;
}
/*
 * Get all keyword variables that have introduced outside the given function scope
 */
public set[MuExp] getKeywordParameterRefs(MuExp exp, str fuid){
    //println("getKeywordParameterRefs(<exp>, <fuid>)");
    res = { unsetRec(v, "alabel") | /v:muVarKwp(str _, str fuid2, AType _) := exp, fuid2 != fuid };
    //println("getKeywordParameterRefs =\> <res>");
    return res;
}
    
/********************************************************************/
/*                  Translate keyword parameters                    */
/********************************************************************/

public lrel[str name, AType atype, MuExp defaultExp] translateKeywordParameters(Parameters parameters) {
  KeywordFormals kwfs = parameters.keywordFormals;
  kwmap = [];
  if(kwfs is \default && {KeywordFormal ","}+ keywordFormalList := parameters.keywordFormals.keywordFormalList){
      keywordParamsMap = getKeywords(parameters);
      kwmap = [ <"<kwf.name>", keywordParamsMap["<kwf.name>"], translate(kwf.expression)> | KeywordFormal kwf <- keywordFormalList ];
  }
  return kwmap;
}

/********************************************************************/
/*                  Translate function body                         */
/********************************************************************/

private MuExp returnFromFunction(MuExp body, AType ftype, list[MuExp] formalVars, bool isMemo, bool addReturn=false) {
  res = body;
  if(ftype.ret == avoid()){ 
    if(isMemo){
         res = visit(res){
            case muReturn0() => muMemoReturn0(ftype, formalVars)
         }
         res = muBlock([res,  muMemoReturn0(ftype, formalVars)]);
      }
     return res;
  } else {
      res = addReturn ? muReturn1(ftype.ret, body) : body;
      
      if(isMemo){
         res = visit(res){
            case muReturn1(_, e) => muMemoReturn1(ftype, formalVars, e)
         }
      }
      
      parameters = { unset(par, "alabel") | /par:aparameter(name, bound) := ftype };
     
      if(!isEmpty(parameters) && /muReturn1(_,_) := res){
        str fuid = topFunctionScope();
        result = muTmpIValue(nextTmp("result"), fuid, ftype.ret);
        res = visit(res){
            case muReturn1(_, e) => muBlock([ muConInit(result, e),
                                              muIfElse(muValueIsNonVoidSubtypeOf(result, ftype.ret),
                                                       muReturn1(ftype.ret, result),
                                                       muFailReturn(ftype.ret))
                                            ])
        };
     }
      
      return res;   
  }
}
         
private MuExp functionBody(MuExp body, AType ftype, list[MuExp] formalVars, bool isMemo){
    if(isMemo){
        str fuid = topFunctionScope();
        result = muTmpIValue(nextTmp("result"), fuid, avalue());
        return muCheckMemo(ftype, formalVars, body);
    } else {
        return body;
    }
}

public tuple[list[MuExp] formalVars, MuExp funBody] translateFunction(str fname, {Pattern ","}* formals, AType ftype, MuExp body, bool isMemo, list[Expression] when_conditions, bool addReturn=false){
     // Create a loop label to deal with potential backtracking induced by the formal parameter patterns  
     
     list[Pattern] formalsList = [f | f <- formals];
     str fuid = topFunctionScope();
     my_btscopes = getBTScopesParams(formalsList, fname);
     parameters = { unset(par, "alabel") | /par:aparameter(name, bound) := ftype };
     
     ndummies = size(dummyFormalsInReturnType(ftype));
     
     formalVars = for(i <- index(formalsList)){
        pname = getParameterName(formalsList, i);
        ndummies += size(dummyFormalsInType(getType(formalsList[i])));
        if(hasParameterName(formalsList, i) && !isUse(formalsList[i]@\loc)){
            pos = getPositionInScope(pname, getParameterNameAsTree(formalsList, i)@\loc);
            //println("<pname>: pos = <pos>, ndummies = <ndummies>, pos - ndummies = <pos - ndummies>");
            //if(pos - ndummies > 0) pos -= ndummies;
            append muVar(pname, fuid, pos, unsetRec(getType(formalsList[i]), "alabel"), formalId());
        } else {
            append muVar(pname, fuid, -i, unsetRec(getType(formalsList[i]), "alabel"), formalId());
        }
     }           
                  
     leaveSignatureSection();
     when_body = returnFromFunction(body, ftype, formalVars, isMemo, addReturn=addReturn);
     //iprintln(when_body);
     if(!isEmpty(when_conditions)){
        addReturn = true;
        my_btscopes = getBTScopesAnd(when_conditions, fname, my_btscopes); 
        //iprintln(my_btscopes);
        when_body = translateAndConds(my_btscopes, when_conditions, when_body, muFailReturn(ftype));
     }
     //iprintln(when_body);
     enterSignatureSection();
     params_when_body = ( when_body
                        | isEmpty(parameters) ? translatePat(formalsList[i], getType(formalsList[i]), formalVars[i], my_btscopes, it, muFailReturn(ftype), subjectAssigned=hasParameterName(formalsList, i) )
                                              : translatePatInSignatureWithTypeParameters(formalsList[i], getType(formalsList[i]), formalVars[i], my_btscopes, it, muFailReturn(ftype), subjectAssigned=hasParameterName(formalsList, i) )
                        | i <- reverse(index(formalsList)));
                        
     funCode = functionBody(isVoidAType(ftype.ret) || !addReturn ? params_when_body : muReturn1(ftype.ret, params_when_body), ftype, formalVars, isMemo);
     funCode = visit(funCode) { case muFail(fname) => muFailReturn(ftype) };
     funCode = removeDeadCode(funCode);
     
     alwaysReturns = ftype.returnsViaAllPath || isVoidAType(getResult(ftype));
     formalsBTFree = isEmpty(formalsList) || all(f <- formalsList, backtrackFree(f));
     if(!formalsBTFree || (formalsBTFree && !alwaysReturns)){
        funCode = muBlock([muExists(fname, funCode), muFailReturn(ftype)]);
     }
     //iprintln(funCode);
     funCode = removeDeadCode(funCode);
     
      if(!isEmpty(parameters) && /muTypeParameterMap(_) !:= funCode){    
         funCode = muBlock([ muTypeParameterMap(parameters), funCode ]);
      }
     //iprintln(funCode);
     return <formalVars, funCode>;
}

/********************************************************************/
/*                  Translate tags in a function declaration        */
/********************************************************************/

public map[str,str] translateTags(Tags tags){
   m = ();
   for(tg <- tags.tags){
     str name = "<tg.name>";
     if(name == "license")
       continue;
     if(tg is \default){
        cont = "<tg.contents>"[1 .. -1];
        m[name] = cont; //name == "javaClass" ? resolveLibOverriding(cont) : cont;
     } else if (tg is empty)
        m[name] = "";
     else
        m[name] = "<tg.expression>";
   }
   return m;
}

public bool ignoreCompiler(map[str,str] tagsMap)
    = !isEmpty(domain(tagsMap) &  {"ignore", "Ignore", "ignoreCompiler", "IgnoreCompiler"});

//private bool ignoreCompilerTest(map[str, str] tags) = !isEmpty(domain(tags) & {"ignoreCompiler", "IgnoreCompiler"});

public bool ignoreTest(map[str, str] tags) = !isEmpty(domain(tags) & {"ignore", "Ignore", "ignoreCompiler", "IgnoreCompiler"});

/********************************************************************/
/*       Translate the modifiers in a function declaration          */
/********************************************************************/

private list[str] translateModifiers(FunctionModifiers modifiers){
   lst = [];
   for(m <- modifiers.modifiers){
     if(m is \java) 
       lst += "java";
     else if(m is \test)
       lst += "test";
     else
       lst += "default";
   }
   return lst;
} 