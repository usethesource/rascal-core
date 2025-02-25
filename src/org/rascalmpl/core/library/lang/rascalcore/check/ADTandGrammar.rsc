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
module lang::rascalcore::check::ADTandGrammar

/*
    Based on the facts in a given TModel, the functions in this module compute and store ADTs in the store using the key key_ADTs
    as well as a grammar using the key key_grammar. While doing so it also performs some consistency checks.
*/

extend lang::rascalcore::check::CheckerCommon;

import lang::rascalcore::agrammar::definition::Layout;
import lang::rascalcore::agrammar::definition::Keywords;

import lang::rascal::\syntax::Rascal;

import IO;
import Node;
import Set;
import ListRelation;
import Location;
import Relation;
import Message;
import Map;
import util::Reflective;

void addADTsAndCommonKeywordFields(Solver s){
    addADTs(s);
    addCommonKeywordFields(s);
}

bool commonTypeParameter(list[AType] params1, list[AType] params2){
    n1 = size(params1);
    n2 = size(params2);
    if(n1 == 0 || n2 == 0) return false;
    return n1 == n2 && all(i <- [0..n1], params1[i] == params2[i] || isTypeParameter(params1[i]) && isTypeParameter(params2[i]));
}

list[AType] removeLabels(list[AType] params) = [ unset(p, "alabel") | p <- params ];

void addADTs(Solver s){
    facts = s.getFacts();
    defines = s.getAllDefines();
    definedADTs = { unset(t, "alabel") | def <- defines, /AType t:aadt(str _, list[AType] _, _) := def };
    usedADTs = { unset(t, "alabel") | loc k <- facts, /AType t:aadt(str _, list[AType] parameters, _) := facts[k], !isEmpty(parameters), any(p <- parameters, !isTypeParameter(p)) };
    ADTs = { a[parameters=removeLabels(a.parameters)] | a <- definedADTs + usedADTs };

    // remove versions with type parameter on same position.

    //solve(ADTs){
    //    if(any(AType a1 <- ADTs, AType a2 <- ADTs, a1 != a2, a1.adtName == a2.adtName, commonTypeParameter(a1.parameters, a2.parameters))){
    //        ADTs -= a2;
    //    }
    //}
    s.push(key_ADTs, ADTs);
}

void addCommonKeywordFields(Solver s){
    set[Define] definitions = s.getAllDefines();
    lrel[AType adtType, Keyword defaultType] commonKeywordFields = [];
    //lrel[AType adtType, AType defaultType] commonKeywordFields = [];
    //lrel[AType, KeywordFormal] commonKeywordFields = [];

    // Collect common keywords and check double declarations

    //rel[AType,str,AType] commonKeywordFieldNames = {};
    //rel[AType,str,KeywordFormal] commonKeywordFieldNames = {};

    for(Define def <- definitions, def.idRole == dataId()){
        try {
            adtType = s.getType(def);
            //commonKeywordNames = commonKeywordFieldNames[adtType]<0>;
            for(kwf <- def.defInfo.commonKeywordFields){
                fieldName = "<kwf.name>";
                fieldType = s.getType(kwf);
                fieldType.alabel = fieldName;
                moduleName = getRascalModuleName(kwf.expression@\loc, s.getConfig().typepalPathConfig);
                commonKeywordFields += <adtType, kwField(fieldType, fieldName, moduleName, kwf.expression)>;
                //commonKeywordFieldNames += <adtType, fieldName, fieldType>;
                // TODO: reconsider this
                //if(fieldName in commonKeywordNames){
                //    msgs = [ Message::error("Double declaration of common keyword Field `<fieldName>` for data type `<adtType.adtName>`", getLoc(kwf2))
                //           | kwf2 <- commonKeywordFieldNames[adtType]<1>, "<kwf2.name>" == fieldName
                //           ];
                //    s.addMessages(msgs);
                //}
            }
        } catch TypeUnavailable():
            ;//s.addMessages([ Message::error("Unavailable type in declaration of `<def.id>`", def.defined) ]);
      }
    //println("commonKeywordFields");
    //for(<tp, dflt> <- commonKeywordFields) println("<tp>, <dflt>");
    s.push(key_common_keyword_fields, commonKeywordFields);

    // Warn for overlapping declarations of common keyword fields and ordinary fields

    map[AType, map[str, AType]] adt_common_keyword_fields_name_and_kwf = ( adtType : ( kwf.fieldName : kwf.fieldType | kwf <- commonKeywordFields[adtType] ? []) | adtType <- toSet(commonKeywordFields<0>) );

    //map[AType, map[str, KeywordFormal]] adt_common_keyword_fields_name_and_kwf = ( adtType : ( "<kwf.name>" : kwf | kwf <- commonKeywordFields[adtType] ? []) | adtType <- domain(commonKeywordFields) );
    //
    for(Define def <- definitions, def.idRole == constructorId()){
        try {
            consType = s.getType(def);
            set[str] commonFieldNames = domain(adt_common_keyword_fields_name_and_kwf[consType.adt] ? ());
            for(fld <- consType.fields){
               if(fld.alabel in commonFieldNames){
                    kwf = adt_common_keyword_fields_name_and_kwf[consType.adt][fld.alabel];
                    msgs = [ Message::warning("Common keyword field `<fld.alabel>` of data type `<consType.adt.adtName>` overlaps with field of constructor `<consType.alabel>`", |unknown:///|),
                             Message::warning ("Field `<fld.alabel>` of constructor `<consType.alabel>` overlaps with common keyword field of data type `<consType.adt.adtName>`", def.defined)
                           ];
                    s.addMessages(msgs);
                }
            }
        } catch TypeUnavailable():
            ;//s.addMessages([ Message::error("Unavailable type in declaration of `<def.id>`", def.defined) ]);

    }

    lrel[AType,AType,Define] adt_constructors = [];
    for(Define def <- definitions, def.idRole == constructorId()){
        try {
            consType = s.getType(def);
            if(consType.alabel == "type") continue; // TODO: where is the duplicate?
            conses_so_far = adt_constructors[consType.adt];
            //for(<AType c, Define cdef> <- conses_so_far, c.alabel == consType.alabel, cdef.defined != def.defined, comparable(c.fields, consType.fields)){
            //    msgs = [ Message::error("Duplicate/comparable constructor `<consType.alabel>` of data type `<consType.adt.adtName>`", def.defined),
            //             Message::error("Duplicate/comparable constructor `<consType.alabel>` of data type `<consType.adt.adtName>`", cdef.defined)
            //           ];
            //    s.addMessages(msgs);
            //}
            adt_constructors += <consType.adt, consType, def>;
        } catch TypeUnavailable():
            ;//s.addMessages([ Message::error("Unavailable type in declaration of `<def.id>`", def.defined) ]);

    }
}

list[&T <: node ] unsetRec(list[&T <: node] args) = [unsetRec(a) | a <- args];

bool isManualLayout(AProduction p) = (p has attributes && atag("manual"()) in p.attributes);

tuple[TModel, ModuleStatus] addGrammar(str qualifiedModuleName, set[str] imports, set[str] extends, map[str,TModel] transient_tms, ModuleStatus ms){
    try {
        rel[AType,AProduction] definedProductions = {};
        allStarts = {};
        for(m <- {qualifiedModuleName, *imports, *extends}){
            TModel tm1;
            if(transient_tms[m]?){
                tm1 = transient_tms[m];
            } else {
                <found, tm1, ms> = getTModelForModule(m, ms);
                if(!found) {
                    msg = error("Cannot add grammar, tmodel for <m> not found", ms.moduleLocs[qualifiedModuleName] ? |unknown:///|);
                    ms.messages[qualifiedModuleName] ? {} += { msg };
                    tm1 = tmodel(modelName=qualifiedModuleName, messages=[msg]);
                    return <tm1, ms>;
                }
            }
            facts = tm1.facts;
            prodLocs1 = { k | loc k <- facts, aprod(_) := facts[k] };

            // filter out productions contained in priority/associativity declarations
            prodLocs2 = { k | k <- prodLocs1, !any(l <- prodLocs1, k != l, isStrictlyContainedIn(k, l)) };

            definedProductions += {<p.def, p> | loc k <- prodLocs2, aprod(p) := facts[k] };

            allStarts += { t | loc k <- facts, \start(t) := facts[k] };
        }
        allStarts = uncloseTypeParams(allStarts);
        rel[AType,AProduction] allProductions = uncloseTypeParams(definedProductions);

        allProductions = visit(allProductions){
            case p:prod(\start(a:aadt(_,_,_)),defs) => p[def=a]
            case \start(a:aadt(_,_,_)) => a
        }

        set[AType] allLayouts = {};
        set[AType] allManualLayouts = {};
        map[AType,AProduction] syntaxDefinitions = ();

        for(AType adtType <- domain(allProductions)){
            if(\start(adtType2) := adtType){
                adtType = adtType2;
            }
            productions = allProductions[adtType];
            syntaxDefinitions[adtType] = achoice(adtType, productions);
            //println("syntaxDefinitions, for <adtType> add <achoice(adtType, productions)>");

            if(adtType.syntaxRole == layoutSyntax()){
                if(any(p <- productions, isManualLayout(p))){
                   allManualLayouts += adtType;
                } else {
                    allLayouts = {*allLayouts, adtType};
                }
            }
        }

        // Check keyword rules

        tm = checkKeywords(allProductions, transient_tms[qualifiedModuleName]);

        // Check layout

        if(size(allLayouts) > 1) { // Warn for  multiple layout definitions
            allLayoutNames = {ladt.adtName | AType ladt <- allLayouts};
            for(AType ladt <- allLayouts){
                otherLayoutNames = {"`<lname>`" | str lname <- (allLayoutNames - ladt.adtName)};
                for(p <- syntaxDefinitions[ladt].alternatives){
                    tm.messages += [warning(interpolate("Multiple layout definitions: layout %q can interfere with layout %v", AType(Tree t) { return tm.facts[getLoc(t)]; }, [ladt.adtName, otherLayoutNames]),
                                            p.src)];
                }
            }
        }

        definedLayout = aadt("$default$", [], layoutSyntax());
        if(isEmpty(allLayouts) || !isEmpty(allStarts)){
            syntaxDefinitions += (AType::layouts("$default$"): achoice(AType::layouts("$default$"), {prod(AType::layouts("$default$"), [])}));
        }
        
        if(size(allLayouts) >= 1){
            definedLayout = getOneFrom(allLayouts);
        }

        // Add start symbols

        for(AType adtType <- allStarts){
            syntaxDefinitions[\start(adtType)] = achoice(\start(adtType), { prod(\start(adtType), [definedLayout, adtType[alabel="top"], definedLayout]) });
        }

        // Add auxiliary rules for instantiated syntactic ADTs outside the grammar rules
        facts = tm.facts;
        allADTs = uncloseTypeParams({ unset(adt, "alabel") | loc k <- facts, /AType adt:aadt(str _, list[AType] _, _) := facts[k] });
        //println("ADTandGrammar, allADTs:"); iprintln(allADTs);

        instantiated_in_grammar =
            { unset(adt, "alabel")
            | /adt:aadt(str _, list[AType] parameters, SyntaxRole _) := syntaxDefinitions,
              !isEmpty(parameters),
              all(p <- parameters, !isTypeParameter(p))
            };
        //println("ADTandGrammar, instantiated_in_grammar:"); iprintln(instantiated_in_grammar);

        instantiated =
            { unset(adt, "alabel")
            | AType adt <- allADTs,
              !isEmpty(adt.parameters),
              all(p <- adt.parameters, !isTypeParameter(p))
            };
        //println("ADTandGrammar, instantiated:"); iprintln(instantiated);
        instantiated_outside = instantiated - instantiated_in_grammar;
        //println("ADTandGrammar, instantiated_outside:"); iprintln(instantiated_outside);
        parameterized_uninstantiated_ADTs =
            { unset(adt, "alabel")[parameters = uncloseTypeParams(params)]
            | adt <- allADTs,
              adt.syntaxRole != dataSyntax(),
              params := getADTTypeParameters(adt),
              !isEmpty(params),
              all(p <- params, isTypeParameter(p))
            };
        //println("ADTandGrammar, parameterized_uninstantiated_ADTs:"); iprintln(parameterized_uninstantiated_ADTs);

        AType uninstantiate(AType t){
            iparams = getADTTypeParameters(t);
            for(uadt <- parameterized_uninstantiated_ADTs){
                uadtParams = getADTTypeParameters(uadt);
                if(t.adtName == uadt.adtName && size(iparams) == size(uadtParams)){
                    return uadt;
                }
            }
            return t;
        }

        if(!isEmpty(instantiated_outside)){
            for(adt <- instantiated_outside, adt.syntaxRole != dataSyntax()){
                iparams = getADTTypeParameters(adt);
                uadt = uninstantiate(adt);
                auxNT = aadt("$<adt.adtName><for(p <- iparams){>_<p.adtName><}>", [], adt.syntaxRole);
                rule = achoice(auxNT, {prod(auxNT, [adt]) });
                syntaxDefinitions += (auxNT : rule);
            }
        }

        // Construct the grammar

        g = grammar(allStarts, syntaxDefinitions);
        g = layouts(g, definedLayout, allManualLayouts);
        //println("ADTandGrammar:"); iprintln(g, lineLimit=10000);
        //g = expandKeywords(g);
        g.rules += (AType::aempty():achoice(AType::aempty(), {prod(AType::aempty(),[])}));
        tm = tmlayouts(tm, definedLayout, allManualLayouts);
        //println("ADTandGrammar:"); iprintln(g, lineLimit=10000);
        tm.store[key_grammar] = [g];
        return <tm, ms>;
    } catch TypeUnavailable(): {
        // protect against undefined entities in the grammar that have not yet been reported.
        return <tmodel(), ms>;
    }
}

@doc{intersperses layout symbols in all non-lexical productions}
public TModel tmlayouts(TModel t, AType l, set[AType] others) {

  res = top-down-break visit (t) {
    case AType atype => regulars(atype , l, others)
  }
  return res;
}

// A keyword production may only contain:
// - literals or ciliterals
// - other nonterminals that satisfy this rule.

bool isValidKeywordProd(AType sym, set[AType] allLiteral){
    if(  alit(_) := sym
      || acilit(_) := sym
      || aprod(prod(aadt(_,[],_),[alit(_)])) := sym
      || aprod(prod(aadt(_,[],_),[acilit(_)])) := sym
      ){
        return true;
    }
    if(aprod(prod(a:aadt(_,[],_),_)) := sym && a in allLiteral){
       return true;
    }
    return false;
}

TModel checkKeywords(rel[AType, AProduction] allProductions, TModel tm){
    allLiteral = {};
    solve(allLiteral){
        forADT:
        for(AType adtType <- domain(allProductions), adtType notin allLiteral){
            for(prod(AType _, list[AType] asymbols) <- allProductions[adtType]){
                for(sym <- asymbols){
                    if(!isValidKeywordProd(sym, allLiteral)){
                       continue forADT;
                    }
                }
                allLiteral += adtType;
            }
        }
    }
    for(AType adtType <- domain(allProductions), ((\start(t) := adtType) ? t.syntaxRole : adtType.syntaxRole) == keywordSyntax()){
        for(p:prod(AType _, list[AType] asymbols) <- allProductions[adtType]){
            if(size(asymbols) != 1){
                tm.messages += [warning(size(asymbols) == 0 ? "One symbol needed in keyword declaration, found none" : "Keyword declaration should consist of one symbol", p.src)];
            }
            for(sym <- asymbols){
                if(alit(_) := sym || acilit(_) := sym) continue;
                if(!isADTAType(sym) || isADTAType(sym) && sym notin allLiteral){
                    tm.messages += [warning(interpolate("Only literals allowed in keyword declaration, found %t", AType(Tree t) { return tm.facts[getLoc(t)]; }, [sym]), p.src) ];
                }
            }
        }
    }
    return tm;
}