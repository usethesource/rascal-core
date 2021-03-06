@bootstrapParser
module lang::rascalcore::compile::Rascal2muRascal::RascalPattern
   
import IO;
import ValueIO;
import Location;
import Node;
import Map;
import Set;
import String;
import ParseTree;
import util::Math;

import lang::rascal::\syntax::Rascal;
import lang::rascalcore::compile::muRascal::AST;

import lang::rascalcore::check::AType;
import lang::rascalcore::check::ATypeUtils;
import lang::rascalcore::check::NameUtils;
import lang::rascalcore::compile::util::Names;

import lang::rascalcore::compile::Rascal2muRascal::ModuleInfo;
import lang::rascalcore::compile::Rascal2muRascal::RascalType;
import lang::rascalcore::compile::Rascal2muRascal::TmpAndLabel;
import lang::rascalcore::compile::Rascal2muRascal::TypeUtils;
//import lang::rascalcore::compile::Rascal2muRascal::TypeReifier;

import lang::rascalcore::compile::Rascal2muRascal::RascalExpression;

//import lang::rascalcore::compile::RVM::Interpreter::ParsingTools;

/*
 * Compile the match operator and all possible patterns
 */

/*********************************************************************/
/*                  Match                                            */
/*********************************************************************/

default MuExp translateMatch(Pattern pat, Expression exp, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont) {
    expType = getType(exp);
    expTrans = translate(exp);
    if(isVarOrTmp(expTrans)){
        return translatePat(pat, expType, expTrans, btscopes, trueCont, falseCont);
    } else {
        str fuid = topFunctionScope();
        exp_val = muTmpIValue(nextTmp("exp_val"), fuid, getType(exp));
        res = muValueBlock(abool(), [ muConInit(exp_val, expTrans), 
                                       translatePat(pat, expType, exp_val, btscopes, trueCont, falseCont) 
                                     ]);
        //iprintln(res);
        return res;
    }
}

//MuExp translateMatch((Expression) `<Pattern pat> := <Expression exp>`, str btscope, MuExp trueCont, MuExp falseCont) 
//    = translateMatch(pat, exp, btscope, trueCont, falseCont);
//
//MuExp translateMatch(e: (Expression) `<Pattern pat> !:= <Expression exp>`, str btscope, MuExp trueCont, MuExp falseCont)
//    = translateMatch(pat, exp, btscope, falseCont, trueCont);
//    
//default MuExp translateMatch(Pattern pat, Expression exp, str btscope, MuExp trueCont, MuExp falseCont) =
//    translatePat(pat, getType(exp), translate(exp), btscope, trueCont, falseCont);

/*********************************************************************/
/*                  Get Backtracking Scopes for a Pattern            */
/*********************************************************************/

alias BTSCOPE = tuple[str enter, str resume, str \fail];  // The enter/resume/fail labels of one backtracking scope
alias BTSCOPES = map[loc,BTSCOPE];                        // Map from program fragments to backtracking scopes
alias BTINFO = tuple[BTSCOPE btscope, BTSCOPES btscopes]; // Complete backtracking information

// Getters on backtracking scopes

str getEnter(BTSCOPE btscope) = btscope.enter;
str getResume(BTSCOPE btscope) = btscope.resume;
str getFail(BTSCOPE btscope) = btscope.\fail;

str getEnter(Tree t, BTSCOPES btscopes) = btscopes[getLoc(t)].enter;
str getEnter(loc l, BTSCOPES btscopes)  = btscopes[l].enter;

str getParent(str path, str parent) {
    int i = findLast(path, parent);
    if(i < 0) throw "Cannot find root <parent> in path <path>";
    return path[ .. i + size(parent)];
}
str getEnter(Tree t, str parent, BTSCOPES btscopes) = getParent(btscopes[getLoc(t)].enter, parent);
str getEnter(loc l, str parent, BTSCOPES btscopes)  = getParent(btscopes[l].enter, parent);

str getResume(Tree t, BTSCOPES btscopes) = btscopes[getLoc(t)].resume;
str getResume(loc l, BTSCOPES btscopes)  = btscopes[l].resume;

str getResume(Tree t, str parent, BTSCOPES btscopes) = getParent(btscopes[getLoc(t)].resume, parent);
str getResume(loc l, str parent, BTSCOPES btscopes)  = getParent(btscopes[l].resume, parent);

str getFail(Tree t, BTSCOPES btscopes) = btscopes[getLoc(t)].\fail;
str getFail(loc l, BTSCOPES btscopes)  = btscopes[l].\fail;

str getFail(Tree t, str parent, BTSCOPES btscopes) = getParent(btscopes[getLoc(t)].\fail, parent);
str getFail(loc l, str parent, BTSCOPES btscopes)  = getParent(btscopes[l].\fail, parent);

BTINFO registerBTScope(Tree t, BTSCOPE btscope, BTSCOPES btscopes){
    btscopes[getLoc(t)] = btscope;
    return <btscope, btscopes>;
}

BTSCOPES getBTScopes(Tree t, str enter) = getBTInfo(t, <enter, enter, enter>, ()).btscopes;
BTSCOPES getBTScopes(Tree t, str enter, BTSCOPES btscopes) = getBTInfo(t, <enter, enter, enter>, btscopes).btscopes;

BTINFO getBTInfo(Tree t, str enter, BTSCOPES btscopes) = getBTInfo(t, <enter, enter, enter>, btscopes);

default BTINFO getBTInfo(Tree t, BTSCOPE btscope, BTSCOPES btscopes)
    = registerBTScope(t, btscope, btscopes);

//default BTINFO getBTInfo(Expression e, BTSCOPE btscope, BTSCOPES btscopes) {
//    if(!btscopes[getLoc(e)]?){
//        btscopes[getLoc(e)] = btscope;
//    }
//    return <btscopes[getLoc(e)], btscopes>;
//}

//str getResume(BTSCOPES btscopes){
//    println("btscopes:"); iprintln(btscopes);
//    r2l_scopes = sort(domain(btscopes), beginsAfter);
//    println("r2l_scopes:"); iprintln(r2l_scopes);
//   
//    resume = btscopes[r2l_scopes[0]].resume;
//    for(l <- r2l_scopes){
//        btscope = btscopes[l];
//        println("<l>: <btscope>");
//        resume = btscope.resume;
//        if(btscope.enter !=  btscope.resume){
//            return btscope.resume;
//        }
//    }
//    return resume;
//}

str getResume(BTSCOPES btscopes){
    r2l_scopes = reverse(sort(domain(btscopes)));
    resume = btscopes[r2l_scopes[-1]].resume;
    for(l <- r2l_scopes){
        btscope = btscopes[l];
        resume = btscope.resume;
        if(btscope.enter !=  btscope.resume){
            return btscope.resume;
        }
    }
    return resume;
}

bool haveEntered(str enter, BTSCOPES btscopes){
    return enter in range(btscopes)<0>;
}

/*********************************************************************/
/*                  Patterns                                         */
/*********************************************************************/

// ==== literal pattern =======================================================

default MuExp translatePat(p:(Pattern) `<Literal lit>`, AType subjectType, MuExp subject, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, MuExp restore = muBlock([])) 
    = translateLitPat(lit, subjectType, subject, btscopes, trueCont, falseCont);

MuExp translatePat(Literal lit, AType subjectType, MuExp subject, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, MuExp restore = muBlock([]))
    = translateLitPat(lit, subjectType, subject, btscopes, trueCont, falseCont);

MuExp translateLitPat(Literal lit, AType subjectType, MuExp subject, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont) 
  = muIfelse(muEqual(translate(lit), subject), trueCont, falseCont);

// ==== regexp pattern ========================================================

MuExp translatePat(p:(Pattern) `<RegExpLiteral r>`, AType subjectType, MuExp subject, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, MuExp restore = muBlock([])) 
    = translateRegExpLiteral(r, subjectType, subject, btscopes, trueCont, falseCont);

/*
lexical RegExpLiteral
	= "/" RegExp* "/" RegExpModifier ;

lexical NamedRegExp
	= "\<" Name "\>" 
	| [\\] [/ \< \> \\] 
	| NamedBackslash 
	| ![/ \< \> \\] ;

lexical RegExpModifier
	= [d i m s]* ;

lexical RegExp
	= ![/ \< \> \\] 
	| "\<" Name "\>" 
	| [\\] [/ \< \> \\] 
	| "\<" Name ":" NamedRegExp* "\>" 
	| Backslash 
	// | @category="MetaVariable" [\<]  Expression expression [\>] TODO: find out why this production existed 
	;
lexical NamedBackslash
	= [\\] !>> [\< \> \\] ;
*/

map[str,str] regexpEscapes = (
"(" : "(?:",
")" : ")"
);

MuExp translateRegExpLiteral(re: (RegExpLiteral) `/<RegExp* rexps>/<RegExpModifier modifier>`, AType subjectType, MuExp subject, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont) {
   str fuid = topFunctionScope();
   <buildRegExp,vars> = processRegExpLiteral(re);
   matcher = muTmpMatcher(nextTmp("matcher"), fuid);
   found = muTmpBool(nextTmp("found"), fuid);
   btscope = nextLabel("REGEXP");
   //println("inStringVisit() : <inStringVisit()>");
   code = [ muConInit(matcher, muRegExpCompile(buildRegExp, subject)),
            //*( inStringVisit() ? [ muRegExpSetRegionInVisit(matcher) ]
            //                   : [] ),
            muVarInit(found, muCon(true)),
            muWhileDo("", found,
                      muBlock([ muAssign(found, muRegExpFind(matcher)),
                                muIfelse(found,
                                    muBlock([ *[ muVarInit(vars[i], muRegExpGroup(matcher, i+1)) | i <- index(vars) ],
                                              *( inStringVisit() ? [ muRegExpSetMatchedInVisit(matcher) ]
                                                                 : [] ),
                                               trueCont
                                            ]),
                                    falseCont)
                              ]))
           
          ];
   return muValueBlock(abool(), code);
}

MuExp translateRegExpLiteral(re: (RegExpLiteral) `/<RegExp* rexps>/<RegExpModifier modifier>`, MuExp begin, MuExp end) {
// TODO
   <buildRegExp,varrefs> = processRegExpLiteral(re);
   return muApply(mkCallToLibFun("Library", "MATCH_REGEXP_IN_VISIT"), 
                 [ buildRegExp,
                   muCallMuPrim("make_array", varrefs),
                   begin,
                   end
                 ]); 
}

tuple[MuExp exp, list[MuExp] vars] processRegExpLiteral(e: (RegExpLiteral) `/<RegExp* rexps>/<RegExpModifier modifier>`){
   str fuid = topFunctionScope();
   fragmentCode = [];
   vars = [];
   map[str,int] varnames = ();
   str fragment = "";
   modifierString = "<modifier>";
   for(i <- [0 .. size(modifierString)]){
      fragment += "(?<modifierString[i]>)";
   }
   lrexps = [r | r <- rexps];
   len = size(lrexps); // library!
   i = 0;
   while(i < len){
      r = lrexps[i];
      //println("lregex[<i>]: <r>\nfragment = <fragment>\nfragmentCode = <fragmentCode>");
      if("<r>" == "\\"){
         fragment += "\\" + (i < len  - 1 ? "<lrexps[i + 1]>" : "");
         i += 2;
      } else 
      if(size("<r>") == 1){
         if("<r>" == "(" && i < (len  - 1) && "<lrexps[i + 1]>" == "?"){
           fragment += "(";
         } else {
           fragment += escape("<r>", regexpEscapes);
         }
         i += 1;
      } else {
        if(size(fragment) > 0){
            fragmentCode += muCon(fragment);
            fragment = "";
        }
        switch(r){
          case (RegExp) `\<<Name name>\>`:
        	if(varnames["<name>"]?){
        	   fragment += "\\<varnames["<name>"]>";
        	} else {
        	  fragmentCode += [ muCallPrim3("str_escape_for_regexp", astr(), [getType(name)], [ translate(name) ], r@\loc)];
        	}
          case (RegExp) `\<<Name name>:<NamedRegExp* namedregexps>\>`: {
         		<varref, fragmentCode1> = extractNamedRegExp(r);
         		fragmentCode += fragmentCode1;
         		vars += varref;
         		varnames["<name>"] = size(vars);
         	}
          default:
        	fragmentCode += [muCon("<r>")];
        }
        i += 1;
      }
   }
   
   if(size(fragment) > 0){
      fragmentCode += muCon(fragment);
   }
   if(all(frag <- fragmentCode, muCon(_) := frag)){
      buildRegExp = muCon(intercalate("", [s | muCon(str s) <- fragmentCode]));
      return <buildRegExp, vars>;
   } else {
       swriter = muTmpStrWriter("swriter", fuid);
       buildRegExp = muValueBlock(astr(),
                                  muConInit(swriter, muCallPrim3("open_string_writer", astr(), [], [], e@\loc)) + 
                                  [ muCallPrim3("add_string_writer", astr(), [getType(exp)], [swriter, exp], e@\loc) | exp <- fragmentCode ] +
                                  muCallPrim3("close_string_writer", astr(), [astr()], [swriter], e@\loc));
       return  <buildRegExp, vars>; 
   }  
}

tuple[MuExp var, list[MuExp] exps] extractNamedRegExp((RegExp) `\<<Name name>:<NamedRegExp* namedregexps>\>`) {
   exps = [];
   str fragment = "(";
   atStart = true;
   for(nr <- namedregexps){
       elm = "<nr>";
       if(atStart && size(trim(elm)) == 0){
       	 continue;
       }
       atStart = false;
       if(size(elm) == 1){
         fragment += escape(elm, regexpEscapes);
       } else if(elm[0] == "\\"){
         fragment += elm[0..];
       } else if((NamedRegExp) `\<<Name name2>\>` := nr){
         //println("Name case: <name2>");
         if(fragment != ""){
            exps += muCon(fragment);
            fragment = "";
         }
         exps += translate(name2);
       }
   }
   exps += muCon(fragment + ")");
   <fuid, pos> = getVariableScope("<name>", name@\loc);
   return <muVar("<name>", fuid, pos, astr()), exps>;
}

// ==== concrete syntax pattern ===============================================

MuExp translateConcrete(e:appl(prod(Symbol::label("parsed",Symbol::lex("Concrete")), [_],_),[Tree concrete]), 
                  MuExp subject, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, MuExp restore = muBlock([]))
  = translateConcrete(concrete, subject, btscopes, trueCont, falseCont, restore=restore); 
  
// this is left when a concrete pattern was not parsed correctly:  
MuExp translatePat(e:appl(prod(Symbol::label("typed",Symbol::lex("Concrete")), [_],_),[Tree concrete]), 
                   AType _, MuExp subject, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, MuExp restore = muBlock([])) 
  = muValueBlock([muThrow(muCon("(compile-time) parse error in concrete syntax", e@\loc))]);   

MuExp translateConcrete(appl(prod(lit(_),_,_), _), MuExp subjectExp, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, MuExp restore = muBlock([])) 
  = trueCont;
  
MuExp translateConcrete(appl(prod(cilit(_),_,_), _), MuExp subjectExp, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, MuExp restore = muBlock([])) 
  = trueCont;   

MuExp translateConcrete(appl(prod(layouts(_),_,_), _), MuExp subjectExp, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, MuExp restore = muBlock([])) 
  = trueCont;   

MuExp translateConcrete(t:appl(prod(Symbol::label("$MetaHole", Symbol _),[Symbol::sort("ConcreteHole")], {\tag("holeType"(Symbol _))}), [ConcreteHole hole]),
                        MuExp subjectExp, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, MuExp restore = muBlock([])) {
   var = mkVar(prettyPrintName(hole.name), hole.name@\loc);
   return muBlock([muVarInit(var, subjectExp), trueCont]);
}

MuExp translateConcrete(t:char(int i),
                        MuExp subject, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, MuExp restore = muBlock([])) 
 = muIfelse(muEqual(muCon(char(i)), subject), trueCont, falseCont);                            
                               
default MuExp translateConcrete(t:appl(Production prod, list[Tree] args),
                               MuExp subject, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, MuExp restore = muBlock([]))  {
   body = trueCont;
   
   for (int i <- reverse(index(args))) {
       // TODO introduce temporaries voor muSubscripts
       body = translateConcrete(args[i], muSubscript(muTreeGetArgs(subject), muCon(i)), btscopes, body, falseCont, restore=restore);
   }                    
                        
   return muIfelse(muEqual(muCon(prod), muTreeGetProduction(subject)), body, falseCont);
}
    
bool isConcreteHole(appl(Production prod, list[Tree] args)) = prod.def == Symbol::label("hole", lex("ConcretePart"));

loc getConcreteHoleVarLoc(h: appl(Production prod, list[Tree] args)) {
	//println("getConcreteHoleVarLoc: <h>");
	if(args[0].args[4].args[0]@\loc?){
		return args[0].args[4].args[0]@\loc;
	}
	if(args[0].args[4]@\loc?){
		println("getConcreteHoleVarLoc: moved up one level to get loc: <h>");
		return args[0].args[4]@\loc;
	}
	println("getConcreteHoleVarLoc: Missing loc:");
	iprintln(h);
	println("hole: <args[0].args[4].args[0]>");
	iprintln(args[0].args[4].args[0]);
	println("<h@\loc?>, <(args[0])@\loc?>,  <(args[0].args[4])@\loc?>, <(args[0].args[4].args[0])@\loc?>");
	throw "getConcreteHoleVarLoc: Missing loc";
}	

MuExp translateParsedConcretePattern(t:appl(Production prod, list[Tree] args), AType symbol){
    throw "Not implemented";
  ////println("translateParsedConcretePattern: <prod>, <symbol>");
  //if(isConcreteHole(t)){
  //   <fuid, pos> = getVariableScope("ConcreteVar",  getConcreteHoleVarLoc(t));
  //   return muApply(mkCallToLibFun("Library","MATCH_TYPED_VAR"), [muTypeCon(symbol), muVarRef("ConcreteVar", fuid, pos)]);
  //}
  ////applCode = muApply(mkCallToLibFun("Library","MATCH_LITERAL"), [muCon("appl")]);
  //prodCode = muApply(mkCallToLibFun("Library","MATCH_LITERAL"), [muCon(prod)]);
  //argsCode = translateConcreteListPattern(args, lex(_) := symbol);
  ////kwParams = muApply(mkCallToLibFun("Library","MATCH_KEYWORD_PARAMS"),  [muCallMuPrim("make_array", []), muCallMuPrim("make_array", [])]);
  //return muApply(mkCallToLibFun("Library", "MATCH_CONCRETE_TREE"), [muCon(prod), argsCode]);
}

MuExp translateParsedConcretePattern(cc: char(int c), AType symbol) {
    throw "Not implemented";
  //return muApply(mkCallToLibFun("Library","MATCH_LITERAL"), [muCon(cc)]);
}

MuExp translateParsedConcretePattern(Pattern pat:(Pattern)`type ( <Pattern s>, <Pattern d> )`, AType symbol) {
    throw "translateParsedConcretePattern type() case"; 
}

// The patterns callOrTree and reifiedType are ambiguous, therefore we need special treatment here.

MuExp translateParsedConcretePattern(amb(set[Tree] alts), AType symbol) {
   throw "translateParsedConcretePattern: ambiguous, <alts>";
}

default MuExp translateParsedConcretePattern(Tree c, AType symbol) {
   //iprintln(c);
   throw "translateParsedConcretePattern: Cannot handle <c> at <c@\loc>";
}

bool isLayoutPat(Tree pat) = appl(prod(layouts(_), _, _), _) := pat;

bool isSeparator(Tree pat, AType sep) = appl(prod(sep, _, _), _) := pat;

tuple[bool, AType] isIterHoleWithSeparator(Tree pat){
  if(t:appl(Production prod, list[Tree] args) := pat && isConcreteHole(t)){
     varloc = getConcreteHoleVarLoc(t);
     <fuid, pos> = getVariableScope("ConcreteVar", varloc);
     holeType = getType(varloc);
     if(isIterWithSeparator(holeType)){
        return <true, getSeparator(holeType)>;
     } 
  }
  return <false, \lit("NONE")>;
}

// TODO: Jurgen; better introduce _ variables instead (would simplify downstream)
// Also this precludes pattern matching _inside_ the separators which is needed
// if you want to analyze them or the comments around the separators.

// Remove separators before and after multivariables in concrete patterns

list[Tree] removeSeparators(list[Tree] pats){
  n = size(pats);
  //println("removeSeparators(<n>): <for(p <- pats){><p><}>");
  if(n <= 0){
  		return pats;
  }
  for(i <- index(pats)){
      pat = pats[i];
      <hasSeps, sep> = isIterHoleWithSeparator(pat);
      if(hasSeps){
         //println("removeSeparators: <i>, <n>, <pat>");
         ilast = i;
         if(i > 2 && isSeparator(pats[i-2], sep)){ 
            ilast = i - 2; 
         }
         ifirst = i + 1;
         if(i + 2 < n && isSeparator(pats[i+2], sep)){
              ifirst = i + 3;
         }
         
         res = pats[ .. ilast] + pat + (ifirst < n ? removeSeparators(pats[ifirst ..]) : []);  
         //println("removeSeparators: ifirst = <ifirst>, return: <for(p <- res){><p><}>");  
         return res;  
      }
  }
  //println("removeSeparators returns: <for(p <- pats){><p><}>");
  return pats;
}

MuExp translateConcreteListPattern(list[Tree] pats, bool isLex){
    throw "Not implemented";
 ////println("translateConcreteListPattern: <for(p <- pats){><p><}>, isLex = <isLex>");
 //pats = removeSeparators(pats);
 ////println("After: <for(p <- pats){><p><}>");
 //lookahead = computeConcreteLookahead(pats);  
 //if(isLex){
 //	return muApply(mkCallToLibFun("Library","MATCH_LIST"), [muCallMuPrim("make_array", 
 //                  [ translatePatAsConcreteListElem(pats[i], lookahead[i], isLex) | i <- index(pats) ])]);
 //}
 //optionalLayoutPat = muApply(mkCallToLibFun("Library","MATCH_OPTIONAL_LAYOUT_IN_LIST"), []);
 //return muApply(mkCallToLibFun("Library","MATCH_LIST"), [muCallMuPrim("make_array", 
 //        [ (i % 2 == 0) ? translatePatAsConcreteListElem(pats[i], lookahead[i], isLex) : optionalLayoutPat | int i <- index(pats) ])]);
}

// Is a symbol an iterator type?

bool isIter(\iter(AType symbol)) = true;
bool isIter(\iter-star(AType symbol)) = true;
bool isIter(\iter-seps(AType symbol, list[AType] separators)) = true;
bool isIter(\iter-star-seps(AType symbol, list[AType] separators)) = true;
default bool isIter(AType s) = false;

// Is a symbol an iterator type with separators?
bool isIterWithSeparator(\iter-seps(AType symbol, list[AType] separators)) = true;
bool isIterWithSeparator(\iter-star-seps(AType symbol, list[AType] separators)) = true;
default bool isIterWithSeparator(AType s) = false;

// What is is the minimal iteration count of a symbol?
int nIter(\iter(AType symbol)) = 1;
int nIter(\iter-star(AType symbol)) = 0;
int nIter(\iter-seps(AType symbol, list[AType] separators)) = 1;
int nIter(\iter-star-seps(AType symbol, list[AType] separators)) = 0;
default int nIter(AType s) { throw "Cannot determine iteration count: <s>"; }

// Get the separator of an iterator type
// TODO: this does not work if the layout is there already...
AType getSeparator(\iter-seps(AType symbol, list[AType] separators)) = separators[0];
AType getSeparator(\iter-star-seps(AType symbol, list[AType] separators)) = separators[0];
default AType getSeparator(AType sym) { throw "Cannot determine separator: <sym>"; }

// What is is the minimal iteration count of a pattern (as Tree)?
int nIter(Tree pat){
  if(t:appl(Production prod, list[Tree] args) := pat && isConcreteHole(t)){
     varloc = getConcreteHoleVarLoc(t);;
     <fuid, pos> = getVariableScope("ConcreteVar", varloc);
     holeType = getType(varloc);
     if(isIterWithSeparator(holeType)){
        return nIter(holeType);
     } 
  }
  return 1;
}

MuExp translatePatAsConcreteListElem(t:appl(Production applProd, list[Tree] args), Lookahead lookahead, bool isLex){
    throw "Not implemented";
  ////println("translatePatAsConcreteListElem:"); iprintln(applProd);
  ////println("lex: <lex(_) := applProd.def>");
  //if(lex(_) := applProd.def){
  //	isLex = true;
  //}
  //  if(isConcreteHole(t)){
  //   varloc = getConcreteHoleVarLoc(t);
  //   <fuid, pos> = getVariableScope("ConcreteVar", varloc);
  //   holeType = getType(varloc);
  //   //println("holeType = <holeType>");
  //  
  //   if(isIter(holeType)){
  //      if(isIterWithSeparator(holeType)){
  //         sep = getSeparator(holeType);
  //         libFun = "MATCH_<isLast(lookahead)>CONCRETE_MULTIVAR_WITH_SEPARATORS_IN_LIST";
  //         //println("libFun = <libFun>");
  //         //println("lookahead = <lookahead>");
  //         if(!isLex){
  //         		holeType = insertLayout(holeType);
  //         }
  //         return muApply(mkCallToLibFun("Library", libFun), [muVarRef("ConcreteListVar", fuid, pos), 
  //         													  muCon(nIter(holeType)), 
  //         													  muCon(1000000), 
  //         													  muCon(lookahead.nElem), 
  //              											  muCon(sep), 
  //              											  muCon(regular(holeType))]);
  //      } else {
  //         libFun = "MATCH_<isLast(lookahead)>CONCRETE_MULTIVAR_IN_LIST";
  //         //println("libFun = <libFun>");
  //         //println("lookahead = <lookahead>");
  //          if(!isLex){
  //         		holeType = insertLayout(holeType);
  //         }
  //         return muApply(mkCallToLibFun("Library", libFun), [muVarRef("ConcreteListVar", fuid, pos), 
  //         													  muCon(nIter(holeType)), 
  //         													  muCon(1000000), 
  //         													  muCon(lookahead.nElem),  
  //         													  muCon(regular(holeType))]);
  //     }
  //   }
  //   return muApply(mkCallToLibFun("Library","MATCH_VAR_IN_LIST"), [muVarRef("ConcreteVar", fuid, pos)]);
  //}
  //return translateApplAsListElem(applProd, args, isLex);
}

MuExp translatePatAsConcreteListElem(cc: char(int c), Lookahead lookahead, bool isLex){
    throw "Not implemented";
  //return muApply(mkCallToLibFun("Library","MATCH_LITERAL_IN_LIST"), [muCon(cc)]);
}

default MuExp translatePatAsConcreteListElem(Tree c, Lookahead lookahead, bool isLex){
    throw "Not implemented";
  //return muApply(mkCallToLibFun("Library","MATCH_PAT_IN_LIST"), [translateParsedConcretePattern(c, getType(c))]);
}

// Translate an appl as element of a concrete list pattern

MuExp translateApplAsListElem(p: prod(lit(str S), _, _), list[Tree] args, bool isLex) {
    throw "Not implemented";
 	//return muApply(mkCallToLibFun("Library","MATCH_LIT_IN_LIST"), [muCon(p)]);
}
 
default MuExp translateApplAsListElem(Production prod, list[Tree] args, bool isLex) {
    throw "Not implemented";
    return muApply(mkCallToLibFun("Library","MATCH_APPL_IN_LIST"), [muCon(prod), translateConcreteListPattern(args, isLex)]);
}

// Is an appl node a concrete multivar?

bool isConcreteMultiVar(t:appl(Production prod, list[Tree] args)){
  if(isConcreteHole(t)){
     varloc = getConcreteHoleVarLoc(t);
     holeType = getType(varloc);
     return isIter(holeType);
  }
  return false;
}

default bool isConcreteMultiVar(Tree t) = false;

// Compute a list of lookaheads for a  list of patterns.
// Recall that a Lookahead is a tuple of the form <number-of-elements-following, number-of-multi-vars-following>

list[Lookahead] computeConcreteLookahead(list[Tree] pats){
    //println("computeConcreteLookahead: <for(p <- pats){><p><}>");
    nElem = 0;
    nMultiVar = 0;
    rprops = for(Tree p <- reverse([p | Tree p <- pats])){
                 append <nElem, nMultiVar>;
                 if(isConcreteMultiVar(p)) {nMultiVar += 1; nElem += nIter(p); } else {nElem += 1;}
             };
    //println("result = <reverse(rprops)>");
    return reverse(rprops);
}
     
// ==== qualified name pattern ===============================================

MuExp translatePat(p:(Pattern) `<QualifiedName name>`, AType subjectType, MuExp subjectExp, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, bool subjectAssigned=false, MuExp restore=muBlock([])){
   if("<name>" == "_"){
      return trueCont;
   }
   //println("qualified name: <name>, <name@\loc>");
   var = mkVar(prettyPrintName(name), name@\loc);
   if(isDefinition(name@\loc) && !subjectAssigned){
    return muBlock([muVarInit(var, subjectExp), trueCont]);
   } else {
    return muIfelse(muIsInitialized(var), muIfelse(muMatch(var, subjectExp), trueCont, falseCont),
                                          muBlock([ muAssign(var, subjectExp), trueCont ]));
   }
} 

// ==== typed name pattern ====================================================
     
MuExp translatePat(p:(Pattern) `<Type tp> <Name name>`, AType subjectType, MuExp subjectExp, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, bool subjectAssigned=false, MuExp restore=muBlock([])){
   trType = translateType(tp);
   if(asubtype(subjectType, trType)){
	   if("<name>" == "_"|| subjectAssigned){
	      return trueCont;
	   }
	   ppname = prettyPrintName(name);
	   <fuid, pos> = getVariableScope(ppname, name@\loc);
	   var = muVar(prettyPrintName(name), fuid, pos, trType[label=ppname]);
	   return var == subjectExp ? trueCont : muBlock([muVarInit(var, subjectExp), trueCont]);
   }
   if("<name>" == "_" || subjectAssigned){
      return muIfelse(muValueIsComparable(subjectExp, trType), trueCont, falseCont);
   }
   ppname = prettyPrintName(name);
   <fuid, pos> = getVariableScope(ppname, name@\loc);
   var = muVar(prettyPrintName(name), fuid, pos, trType[label=ppname]);
   return var == subjectExp ? muIfelse(muValueIsComparable(subjectExp, trType), trueCont, falseCont)
                            : muIfelse(muValueIsComparable(subjectExp, trType), muBlock([muVarInit(var, subjectExp), trueCont]), falseCont);
}  

// ==== reified type pattern ==================================================
//TODO
MuExp translatePat(p:(Pattern) `type ( <Pattern symbol> , <Pattern definitions> )`, AType subjectType, MuExp subjectExp, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, bool subjectAssigned=false, MuExp restore=muBlock([])) {    
    throw "Not implemented";
    //return muApply(mkCallToLibFun("Library","MATCH_REIFIED_TYPE"), [muCon(symbol)]);
}

// ==== call or tree pattern ==================================================

// ---- getBTInfo

str consLabel((Pattern) `<StringLiteral s>`) = "STR";
str consLabel((Pattern) `<QualifiedName s>`) = getUnqualifiedName("<s>");
str consLabel((Pattern) `<Type tp> <Name nm>`) = "<nm>";
default str consLabel(Pattern p) = "GEN";

BTINFO getBTInfo(p:(Pattern) `<Pattern expression> ( <{Pattern ","}* arguments> <KeywordArguments[Pattern] keywordArguments> )`, BTSCOPE btscope, BTSCOPES btscopes) {
    enterCall = "<btscope.enter>_CONS_<consLabel(expression)>";
   
    <btscopeLast, btscopes> = getBTInfo(expression, <enterCall, btscope.resume, btscope.resume>, btscopes);
    for(pat <- arguments){
        <btscopeLast, btscopes> = getBTInfo(pat, btscopeLast, btscopes);
    }
    if(keywordArguments is \default){
        for(kwpat <- keywordArguments.keywordArgumentList){
            <btscopeLast, btscopes> = getBTInfo(kwpat.expression, btscopeLast, btscopes);
        }
    }
    return registerBTScope(p, <enterCall, btscopeLast.resume, btscope.resume>, btscopes);
}

MuExp translatePat(p:(Pattern) `<Pattern expression> ( <{Pattern ","}* arguments> <KeywordArguments[Pattern] keywordArguments> )`, AType subjectType, MuExp subjectExp, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, bool subjectAssigned=false, MuExp restore=muBlock([])) {
   //iprintln(btscopes);
   str fuid = topFunctionScope();
   subject = muTmpIValue(nextTmp("subject"), fuid, subjectType);
   contExp = trueCont;
   
   if((KeywordArguments[Pattern]) `<OptionalComma optionalComma> <{KeywordArgument[Pattern] ","}+ keywordArgumentList>` := keywordArguments){
        for(kwarg <- keywordArgumentList){
            kwname = prettyPrintName(kwarg.name);
            contExp = translatePat(kwarg.expression, getType(kwarg.expression), muGetKwp(subject, subjectType, kwname), btscopes, contExp, falseCont, restore=restore);                 
        }
   }
   
   lpats = [pat | pat <- arguments];   //TODO: should be unnnecessary
   //TODO: bound check
   body = contExp;
   code = muBlock([]);
   for(int i <- reverse(index(lpats))){
       body = translatePat(lpats[i], getType(lpats[i]), muSubscript(subject, muCon(i)), btscopes, body, computeFail(p, lpats, i-1, btscopes, falseCont, restore=restore));
   }
 
   expType = getType(expression);
   subjectInit = /*subjectAssigned ? [] : */muConInit(subject, subjectExp);
   if(expression is qualifiedName){
      qname = "";
      if(expType.label?){
        qname = expType.label;
      } else if(overloadedAType(rel[loc, IdRole, AType] overloads) := expType,
                any(<_, _, tp> <- overloads, tp.label?)){
        for(<_, _, tp> <- overloads){
            if(tp.label?){
                qname = tp.label; break;
            }
        }
      } else {
        throw "Cannot get name in call pattern: <expType>";
      }
      fun_name = getUnqualifiedName(prettyPrintName(qname));
      code = muBlock([subjectInit, muIfelse(muHasNameAndArity(subjectType, expType, muCon(fun_name), size(lpats), subject), body, falseCont)]);
   } else if(expression is literal){ // StringConstant
      fun_name = prettyPrintName("<expression>"[1..-1]);
      code = muBlock([subjectInit, muIfelse(muHasNameAndArity(subjectType, expType, muCon(fun_name), size(lpats), subject), body, falseCont)]);
    } else {
     fun_name_subject = muTmpIValue(nextTmp("fun_name_subject"), fuid, expType);
     code = muBlock([subjectInit,
                     muIfelse(muValueIsComparable(subject, anode([])),
                              muBlock([ muConInit(fun_name_subject, muCallPrim3("get_anode_name", astr(), [anode([])], [subject], getLoc(expression))),
                                        translatePat(expression, expType, fun_name_subject, btscopes, 
                                                     muIfelse(muHasNameAndArity(subjectType, expType, fun_name_subject, size(lpats), subject), body, falseCont),  
                                                     falseCont,
                                                     subjectAssigned=false,
                                                     restore=restore)
                                  ]),
                               falseCont)
                    ]);         
   }
   code = muEnter(getEnter(p, btscopes), code);
   return code;
}

 MuExp translatePatKWArguments((KeywordArguments[Pattern]) ``, AType subjectType, MuExp subjectExp, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, bool subjectAssigned=false, MuExp restore=muBlock([]))
    = trueCont;
 
 MuExp translatePatKWArguments((KeywordArguments[Pattern]) ``, AType subjectType, MuExp subjectExp, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, bool subjectAssigned=false, MuExp restore=muBlock([])){
    code = trueCont;
    for(kwarg <- keywordArgumentList){
        kwtype = getType(kwarg.expression);
        kwfield = "<kwarg.name>";
        code = muIfelse(muHasKwp(subjectExp, kwfield),
                        muIfelse(muEqual(muGetKwp(subjectExp, kwtype, kwfield), translate(kwarg.expression)), code, falseCont),
                        falseCont);
   }
   return code;
 }

// ==== set pattern ===========================================================

BTINFO getBTInfoSet(p:(Pattern) `<QualifiedName name>`, BTSCOPE btscope, BTSCOPES btscopes){
    enter1 = btscope.enter + nameSuffix("VAR", name);
    resume1 = enter1;
    fail1 = btscope.resume;
    return registerBTScope(p, <enter1, resume1, fail1>, btscopes);
}  
  
BTINFO getBTInfoSet(p:(Pattern) `<Type tp> <Name name>`, BTSCOPE btscope, BTSCOPES btscopes) {
    enter1 = btscope.enter + nameSuffix("VAR", name);
    resume1 = enter1;
    fail1 = btscope.resume;
    return registerBTScope(p, <enter1, resume1, fail1>, btscopes);
}

BTINFO getBTInfoSet(p:(Pattern) `<QualifiedName name>*`, BTSCOPE btscope, BTSCOPES btscopes) {
    enter1 = btscope.enter + nameSuffix("MVAR", name);
    resume1 = enter1;
    fail1 = btscope.resume;
    return registerBTScope(p, <enter1, resume1, fail1>, btscopes);
}

BTINFO getBTInfoSet(p:(Pattern) `*<Name name>`, BTSCOPE btscope, BTSCOPES btscopes) {
    enter1 = btscope.enter + nameSuffix("MVAR", name);
    resume1 = enter1;
    fail1 = btscope.resume;
    return registerBTScope(p, <enter1, resume1, fail1>, btscopes);
}

BTINFO getBTInfoSet(p:(Pattern) `*<Type tp> <Name name>`, BTSCOPE btscope, BTSCOPES btscopes) {
    enter1 = btscope.enter + nameSuffix("MVAR", name);
    resume1 = enter1;
    fail1 = btscope.resume;
    return registerBTScope(p, <enter1, resume1, fail1>, btscopes);
}

BTINFO getBTInfoSet(p:(Pattern) `<Pattern expression> ( <{Pattern ","}* arguments> <KeywordArguments[Pattern] keywordArguments> )`, BTSCOPE btscope, BTSCOPES btscopes){ 
    //return getBTInfo(p, btscope, btscopes);
    enter1 = btscope.enter;
    return getBTInfo(p, <enter1, enter1+"_CONS_<consLabel(expression)>", enter1>, btscopes);
}

BTINFO getBTInfoSet(p:(Pattern) `[<{Pattern ","}* pats>]`, BTSCOPE btscope, BTSCOPES btscopes)
    = getBTInfo(p, btscope, btscopes);
    
BTINFO getBTInfoSet(p:(Pattern) `{<{Pattern ","}* pats>}`, BTSCOPE btscope, BTSCOPES btscopes)
    = getBTInfo(p, btscope, btscopes);
    
BTINFO getBTInfoSet(p:(Pattern) `\<<{Pattern ","}* pats>\>`, BTSCOPE btscope, BTSCOPES btscopes)
    = getBTInfo(p, btscope, btscopes);

default BTINFO getBTInfoSet(Pattern p, BTSCOPE btscope, BTSCOPES btscopes) {
    enter1 = btscope.enter + "_DFLT";
    resume1 = enter1;
    fail1 = btscope.resume;
    return registerBTScope(p, <enter1, resume1, resume1>, btscopes);
}

// ---- getBTInfo
    
BTINFO getBTInfo(p:(Pattern) `{<{Pattern ","}* pats>}`,  BTSCOPE btscope, BTSCOPES btscopes){
    <fixedLiterals, toBeMatchedPats, fixedVars, fixedMultiVars, leftMostVar> = analyzeSetPattern(p);
   
    enterSet = "<btscope.enter>_SET";
    BTSCOPE btscopeLast = <enterSet, btscope.resume, btscope.resume>;
    for(pat <- toBeMatchedPats){
        <btscopeLast, btscopes> = getBTInfoSet(pat, btscopeLast, btscopes);
    }
    return registerBTScope(p, <enterSet, btscopeLast.resume, btscope.resume>, btscopes);
}

// ---- translate set pattern

MuExp translatePat(p:(Pattern) `{<{Pattern ","}* pats>}`, AType subjectType, MuExp subjectExp, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, bool subjectAssigned=false, MuExp restore=muBlock([])) 
    = translateSetPat(p, subjectType, subjectExp, btscopes, trueCont, falseCont, subjectAssigned=subjectAssigned, restore=restore);

// Translate patterns as element of a set pattern

str isLast(bool b) = b ? "LAST_" : "";

MuExp translatePatAsSetElem(p:(Pattern) `<QualifiedName name>`, bool last, AType elmType, MuExp subject, MuExp prevSubject, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, MuExp restore=muBlock([])) {
    return translateVarAsSetElem(mkVar(p), isDefinition(p), p@\loc, last, elmType, subject, prevSubject, btscopes, trueCont, falseCont, restore=restore);
}

MuExp translatePatAsSetElem(p:(Pattern) `<Type tp> <Name name>`, bool last, AType elmType, MuExp subject, MuExp prevSubject, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, MuExp restore=muBlock([])) {
    return translateVarAsSetElem(mkVar(p), isDefinition(p), p@\loc, last, elmType, subject, prevSubject, btscopes, trueCont, falseCont, restore=restore);
}

MuExp translateVarAsSetElem(MuExp var, bool isDefinition, loc patloc, bool last, AType elmType, MuExp subject, MuExp prevSubject, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, MuExp restore=muBlock([])) {
   fuid = topFunctionScope();
   elem = muTmpIValue(nextTmp("elem"), fuid, elmType);
   varPresent = var.name != "_";
   needsCheck = !asubtype(elmType, var.atype);
   
   if(!varPresent){
        var.name = var.name + nextTmp();
   }
   
   my_btscope = btscopes[patloc];
   code = muBlock([]);
  
   if(!varPresent && !needsCheck){
       code = muForAll(my_btscope.enter, elem, aset(elmType), prevSubject,
                       muBlock([ muConInit(subject, muCallPrim3("delete", aset(elmType), [aset(elmType), elmType], [prevSubject, elem], patloc)),
                                 trueCont
                               ]));     
   } else {
	   trueBlock = muBlock([ muConInit(subject, muCallPrim3("delete", aset(elmType), [aset(elmType), elmType], [prevSubject, var], patloc)),
                             trueCont
                           ]);
	   if(isDefinition){
	       needInit = isUsed(var, trueCont) || !last;
	       body = muBlock([ *(needInit  ? [muVarInit(var, elem)] : []),
                            trueBlock
                          ]);
	       if(needsCheck){
    	      body = muIf(muValueIsSubType(elem, var.atype), body);
    	   }     
    	   code = muForAll(my_btscope.enter, elem, aset(elmType), prevSubject, body);                           
	   } else {
	       code = muForAll(my_btscope.enter, elem, aset(elmType), prevSubject,
	                       muIfelse(muIsInitialized(var), muIf(muEqual(elem, var), trueBlock),
	                                                      muBlock([ muAssign(var, elem), trueBlock ])));
	   }
   }
   
   //if(needsCheck){
   //     code = muIfelse(muValueIsComparable(prevSubject, aset(var.atype)), code, muFail(getFail(patloc, btscopes)));
  // }
   
   return muIfelse(//last ? muEqualNativeInt(muSize(prevSubject, aset(elmType)), muCon(1)) 
                            muGreaterEqNativeInt(muSize(prevSubject, aset(elmType)), muCon(1)), 
                   muBlock([ code, falseCont ])
                   , falseCont
                   );
} 

MuExp translatePatAsSetElem(p:(Pattern) `_*`, bool last, AType elmType, MuExp subject, MuExp prevSubject, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont){
    return translateMultiVarAsSetElem(mkVar(p), false, p@\loc, last, elmType, subject, prevSubject, btscopes, trueCont, falseCont);
}

MuExp translatePatAsSetElem(p:(Pattern) `*_`, bool last, AType elmType, MuExp subject, MuExp prevSubject, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont){
    return translateMultiVarAsSetElem(mkVar(p), false, p@\loc, last, elmType, subject, prevSubject, btscopes, trueCont, falseCont);
}

MuExp translatePatAsSetElem(p:(Pattern) `<QualifiedName name>*`, bool last, AType elmType, MuExp subject, MuExp prevSubject, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont) {
    return translateMultiVarAsSetElem(mkVar(p), isDefinition(name@\loc), p@\loc, last, elmType, subject, prevSubject, btscopes, trueCont, falseCont);  
}

MuExp translatePatAsSetElem(p:(Pattern) `*<Name name>`, bool last, AType elmType, MuExp subject, MuExp prevSubject, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont) {
    return translateMultiVarAsSetElem(mkVar(p), isDefinition(name@\loc), p@\loc, last, elmType, subject, prevSubject, btscopes, trueCont, falseCont); 
 }

MuExp translatePatAsSetElem(p:(Pattern) `*<Type tp>  _`, bool last, AType elmType, MuExp subject, MuExp prevSubject, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont) {
   return translateMultiVarAsSetElem(mkVar(p), false, p@\loc, last, elmType, subject, prevSubject, btscopes, trueCont, falseCont);
}

MuExp translatePatAsSetElem(p:(Pattern) `*<Type tp> <Name name>`, bool last, AType elmType, MuExp subject, MuExp prevSubject, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont) {
   return translateMultiVarAsSetElem(mkVar(p), true, p@\loc, last, elmType, subject, prevSubject, btscopes, trueCont, falseCont);
}

MuExp translateMultiVarAsSetElem(MuExp var, bool isDefinition, loc patsrc, bool last, AType elmType, MuExp subject, MuExp prevSubject, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont) {
   fuid = topFunctionScope();
   elem = muTmpIValue(nextTmp("elem"), fuid, aset(var.atype));
  
   my_btscope = btscopes[patsrc];
   code = muBlock([]);

   varPresent = var.name != "_"; 
   needsCheck = !asubtype(aset(elmType), var.atype);
   
   if(!varPresent){
        var.name = var.name + nextTmp();
   }
  
   if(!varPresent && !needsCheck){
        code = muBlock([ muForAll(my_btscope.enter, elem, aset(elmType), muCallPrim3("subsets", aset(elmType), [aset(elmType)], [prevSubject], patsrc),
                                  muBlock([ muConInit(subject, muCallPrim3("subtract", aset(elmType), [aset(elmType), aset(elmType)], [prevSubject, elem], patsrc)),
                                            trueCont
                                          ])),
                         falseCont
                       ]);
    } else {
        if(isDefinition || !varPresent){
            asgSubject =  muBlock([ muConInit(subject, muCallPrim3("subtract", aset(elmType), [aset(elmType), aset(elmType)], [prevSubject, elem], patsrc)),
                                    trueCont
                                  ]);
           
            if(needsCheck){
                asgSubject =  muIf(muValueIsSubType(var, var.atype), asgSubject);
           }
            code = muBlock([ muForAll(my_btscope.enter, elem, aset(elmType), muCallPrim3("subsets", aset(elmType), [aset(elmType)], [prevSubject], patsrc),
                                      muBlock([ muVarInit(var, elem),
                                                asgSubject
                                              ])),
                             falseCont
                           ]);
        } else {
            trueBlock = muBlock([ muConInit(subject, muCallPrim3("subtract", aset(elmType), [aset(elmType), aset(elmType)], [prevSubject, elem], patsrc)),
                                  trueCont
                                 ]);
            initialized = muTmpBool("initialized", fuid);   
                 
            asgVar = muBlock([ muAssign(var, elem), trueBlock]);
            if(needsCheck){
                asgVar =  muIf(muValueIsSubType(var, var.atype), asgVar);
            }
            code = muBlock([ muConInit(initialized, muIsInitialized(var)),
                             muForAll(my_btscope.enter, elem, aset(elmType), muCallPrim3("subsets", aset(elmType), [aset(elmType)], [prevSubject], patsrc),
                                      muBlock([ muIfelse(initialized, muIf(muEqual(elem, var),  trueBlock),
                                                                           asgVar)
                                              ])),
                             falseCont
                           ]);
        }
    }
    
    //if(needsCheck){
    //    code = muIfelse(muValueIsComparable(prevSubject, aset(elmType)), 
    //                    code
    //                    , falseCont//, muFail(getFail(my_btscope))
    //                );
    //} 
        
   return code;
}

MuExp translatePatAsSetElem(p:(Pattern) `+<Pattern argument>`, bool last, AType elmType, MuExp subject, MuExp prevSubject, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont) {
  throw "splicePlus pattern <p>";
}   

default MuExp translatePatAsSetElem(Pattern p, bool last, AType elmType, MuExp subject, MuExp prevSubject, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont) {

//TODO: take last element into account
  try {
        pcon = muCon(translatePatternAsConstant(p));
        return muIfelse(muCallPrim3("in", abool(), [elmType, aset(elmType)], [pcon, prevSubject], p@\loc),
                        muBlock([ muConInit(subject, muCallPrim3("delete", aset(elmType), [aset(elmType), elmType], [prevSubject, pcon], p@\loc)),
                                  trueCont ]),
                        falseCont);                            
  } catch: {
        str fuid = topFunctionScope();
        elem = muTmpIValue(nextTmp("elem"), fuid, elmType);
        my_btscope = btscopes[getLoc(p)];
        // TODO length check?
        forAll_scope = my_btscope.enter+ "_DFLT_SET_ELM";
        code = muForAll(forAll_scope, elem, aset(elmType), prevSubject,
                        translatePat(p, elmType, elem, btscopes, 
                            muBlock([ muConInit(subject, muCallPrim3("delete", aset(elmType), [aset(elmType), elmType], [prevSubject, elem], p@\loc)),
                                      trueCont ]),            
                            muFail(forAll_scope)
                            ));
        return code;
  }
}

/*
 * Get the name of a pattern at position k, when no name, return "_<k>".
 */
private str getName(Pattern pat, int k){
  if(pat is splice){
     arg = pat.argument;
     return arg is qualifiedName ? prettyPrintName(arg.qualifiedName) : prettyPrintName(arg.name);
  } else if(pat is multiVariable){
    return prettyPrintName(pat.qualifiedName); 
  } else if(pat is qualifiedName){
    return prettyPrintName(pat.qualifiedName);  
  } else if(pat is typedVariable){
    return prettyPrintName(pat.name);
  } else {
    return "_<k>";
  } 
}

private bool isDefinition(Pattern pat){
  if(pat is splice){
     return isDefinition(pat.argument);
  } else if(pat is multiVariable){
    return "<pat.qualifiedName>" == "_" || isDefinition(pat.qualifiedName@\loc); 
  } else if(pat is qualifiedName){
    return "<pat>" == "_" || isDefinition(pat.qualifiedName@\loc);  
  } else if(pat is typedVariable){
    return true;
  } else 
    return false;
}

private bool isDefinedOutsidePat(loc def, Pattern container){
    try {
        defined = getDefinition(def); 
        return !isContainedIn(defined, container@\loc);
    } catch: {
         return false;
    }
}

private bool allVarsDefinedOutsidePat(Pattern pat, Pattern container){
  if(pat is splice){
     return allVarsDefinedOutsidePat(pat.argument, container);
  } else if(pat is multiVariable){
        if("<pat.qualifiedName>" == "_") return false;
        return isDefinedOutsidePat(pat.qualifiedName@\loc, container);
  } else if(pat is qualifiedName){
        if("<pat>" == "_") return false;
        return isDefinedOutsidePat(pat.qualifiedName@\loc, container);  
  } else if(pat is typedVariable){
    return false;
  } else {
    bool found = true;
    visit(pat){
        case (Pattern) `<QualifiedName qualifiedName>`:  found = found && isDefinedOutsidePat(qualifiedName@\loc, container);
        case (Pattern) `<QualifiedName qualifiedName>*`: found = found && isDefinedOutsidePat(qualifiedName@\loc, container);
    }
    return found;
    }
}

private MuExp mkVar(Pattern pat){
   if(pat is splice){
     tp = getType(pat);
     return mkVar(pat.argument);
  } else if(pat is multiVariable){
        if("<pat.qualifiedName>" == "_"){
            return muVar("_", topFunctionScope(), -1, avalue());
        } else {
            return mkVar("<pat.qualifiedName>", pat.qualifiedName@\loc);
        }
  } else if(pat is qualifiedName){
        if("<pat>" == "_"){
             return muVar("_", topFunctionScope(), -1, avalue());
        } else {
            return mkVar("<pat>", pat@\loc);
        }
  } else if(pat is typedVariable){
        if("<pat.name>" == "_"){
             return muVar("_", topFunctionScope(), -1, getType(pat.name));
         } else {
            return mkVar("<pat.name>", pat.name@\loc);
         }
  } else 
    throw "mkVar: <pat>";
}

tuple[list[MuExp] literals, list[Pattern] toBeMatched, list[Pattern] vars, list[Pattern] multiVars, int leftMostVar] analyzeSetPattern(p:(Pattern) `{<{Pattern ","}* pats>}`){
   list[Pattern] lpats = [pat | pat <- pats]; // TODO: unnnecessary

   /* collect literals and already defined vars/multivars; also remove patterns with duplicate names */
   fixedLiterals = [];                  // constant elements in the set pattern
   list[Pattern] toBeMatchedPats = [];  // the list of patterns that will ultimately be matched
   fixedVars = [];                      // var pattern elements with already (previosuly) defined value
   fixedMultiVars = [];                 // multi-var pattern elements with already (previosuly) defined value
   int leftMostVar = -1;                // index of leftmost multi-variable
   
    outer: for(int i <- index(lpats)){
              pat = lpats[i];
              str name = getName(pat, i);
              if(name != "_"){
                  for(int j <- [0 .. i]){
                      if(getName(lpats[j], j) == name){
                         continue outer;
                      }
                  }
              }
              if(pat is literal){
                fixedLiterals += isConstant(pat.literal) ? muCon(getLiteralValue(pat.literal)) : translate(pat.literal);
              } else if(pat is splice || pat is multiVariable){
                if(allVarsDefinedOutsidePat(pat, p)){
                    fixedMultiVars += pat;
                } else {
                    if(leftMostVar == -1) leftMostVar = size(toBeMatchedPats);
                    toBeMatchedPats += pat;
                }
              } else if(pat is qualifiedName){
                if(allVarsDefinedOutsidePat(pat, p)){
                    fixedVars += pat;
               } else {
                    if(leftMostVar == -1) leftMostVar = size(toBeMatchedPats);
                    toBeMatchedPats += pat;               
                }
              } else if(pat is typedVariable){
                    if(leftMostVar == -1) leftMostVar = size(toBeMatchedPats);
                    toBeMatchedPats += pat;
              } else { 
                try {
                    fixedLiterals += muCon(translatePatternAsConstant(pat));
                } catch: {
                    toBeMatchedPats += pat;
                }
              }
           } 
   return <fixedLiterals, toBeMatchedPats, fixedVars, fixedMultiVars, leftMostVar>;
}

/*
 * Translate a set pattern: 
 * - since this is a set, for patterns with the same name, duplicates are removed.
 * - all literal patterns are separated
 * - all other patterns are compiled in order
 * - if the last pattern is a multi-variable it is treated specially.
 * Note: there is an unused optimization here: if the last multi-var in the pattern is followed by other patterns
 * AND these patterns do not refer to that variable, then the multi-var can be moved to the end of the pattern.
*/

MuExp translateSetPat(p:(Pattern) `{<{Pattern ","}* pats>}`, AType subjectType, MuExp subjectExp, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, bool subjectAssigned=false) {
    //iprintln(btscopes);
    try {
        constantPat = translatePatternAsConstant(p);
        return muIfExp(muEqual(subjectExp, muCon(constantPat)), trueCont, falseCont);
    } catch e: /* not a constant pattern */;
    
   elmType = (aset(tp) := subjectType && tp != avoid()) ? tp : avalue();
   typecheckNeeded = !asubtype(getType(p), subjectType);
   my_btscope = btscopes[getLoc(p)];
   btscope = my_btscope.enter;
   
   fixedLiterals = [];                  // constant elements in the set pattern
   list[Pattern] toBeMatchedPats = [];  // the list of patterns that will ultimately be matched
   list[Pattern] fixedVars = [];        // var pattern elements with already (previosuly) defined value
   list[Pattern] fixedMultiVars = [];   // multi-var pattern elements with already (previosuly) defined value
   int leftMostVar = -1;                // index of leftmost multi-variable
   
   <fixedLiterals, toBeMatchedPats, fixedVars, fixedMultiVars, leftMostVar> = analyzeSetPattern(p);
   rightMostPat = size(toBeMatchedPats) - 1;
   
   str fuid = topFunctionScope();
   subject = muTmpIValue(nextTmp("subject"), fuid, subjectType); // <<< type?
   fixed = muTmpIValue(nextTmp("fixed"), fuid, subjectType);     // <<<
   subjects = [ muTmpIValue(nextTmp("subject"), fuid, subjectType) | int i <- reverse(index(toBeMatchedPats)) ];
   
   //for(int i <- index(toBeMatchedPats)){
   //     println("<i>: <toBeMatchedPats[i]> =\> <subjects[i]>");
   //}
   
   MuExp fixedParts = muCon({con | muCon(value con) <- fixedLiterals });
    
   for(vp <- fixedVars){
       fixedParts = muCallPrim3("add", aset(elmType), [aset(elmType), elmType], [fixedParts, mkVar(vp)], p@\loc);
   }
   for(vp <- fixedMultiVars){
       fixedParts = muCallPrim3("add", aset(elmType), [aset(elmType), aset(elmType)], [fixedParts, mkVar(vp)], p@\loc);
   }
   subject_minus_fixed = muCallPrim3("subtract", aset(elmType), [aset(elmType), aset(elmType)], [subject, fixed], p@\loc);
   
   MuExp setPatTrueCont =
        isEmpty(subjects) ? ( ( isEmpty(fixedLiterals) && isEmpty(fixedVars) && isEmpty(fixedMultiVars) )
                            ? muIfExp(muEqualNativeInt(muSize(subject, aset(avalue())), muCon(0)), trueCont,  muFail(getFail(my_btscope)))
                            : muIfExp(muEqualNativeInt(muSize(subject_minus_fixed, aset(avalue())), muCon(0)), trueCont, muFail(getFail(my_btscope)))
                            )
                          : muIfExp(muEqualNativeInt(muSize(subjects[-1], aset(avalue())), muCon(0)), trueCont,  muFail(getResume(my_btscope)))
                          ;
   //iprintln(setPatTrueCont);
   for(int i <- reverse(index(toBeMatchedPats))){
      pat = toBeMatchedPats[i];
      isRightMostPat = (i == rightMostPat);
      currentSubject = subjects[i];
      previousSubject = (i == 0) ? subject : subjects[i-1];
      resumePrevious = (i == 0) ? falseCont : muFail(getResume(toBeMatchedPats[i-1], btscopes));
      setPatTrueCont = translatePatAsSetElem(pat, isRightMostPat, elmType, currentSubject, previousSubject, btscopes, setPatTrueCont, resumePrevious);
   }
   
   block = muBlock([]);
   if(isEmpty(fixedLiterals) && isEmpty(fixedVars) && isEmpty(fixedMultiVars)){
        block = setPatTrueCont;
   } else {
        block = muBlock([ muConInit(fixed, fixedParts),
                          muIfelse(muCallPrim3("subset", aset(elmType), [aset(elmType), aset(elmType)], [fixed, subject], p@\loc),
                                   muBlock([ *(leftMostVar <= 0 ? [muAssign(subject, subject_minus_fixed)] : [muConInit(subjects[leftMostVar-1], subject)]),
                                             setPatTrueCont]),
                                   muFail(getFail(my_btscope)))
                        ]);
   }
   //iprintln(block);
   code = muBlock([ muVarInit(subject, subjectExp),
                    *( typecheckNeeded ? [muIfelse( muValueIsSubType(subject, subjectType),
                                                    block
                                                    , falseCont
                                                    )
                                         ]
                                       : [ block ])
                   ,  *( noSequentialExit(block) ? [] : [falseCont] )
                       ]);
    //code = muEnter(getEnter(p, btscopes)+"_outer", code);
    return code;
}

// ==== tuple pattern =========================================================

// ---- getBTInfo

BTINFO getBTInfo(p:(Pattern) `\<<{Pattern ","}* pats>\>`, BTSCOPE btscope, BTSCOPES btscopes) {
    enterTuple = "<btscope.enter>_TUPLE";
    BTSCOPE btscopeLast =  <enterTuple, /*btscope.resume,*/ enterTuple, btscope.resume>; //<enterTuple, btscope.resume, btscope.resume>;
    for(pat <- pats){
        <btscopeLast, btscopes> = getBTInfo(pat, btscopeLast, btscopes);
    }
    return registerBTScope(p, <enterTuple, btscopeLast.resume, btscope.resume>, btscopes);
}

// ---- translate tuple pattern

MuExp translatePat(p:(Pattern) `\<<{Pattern ","}* pats>\>`, AType subjectType, MuExp subjectExp, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, MuExp restore=muBlock([])) {
    try {
        constantPat = translatePatternAsConstant(p);
        return muIfExp(muEqual(subjectExp, muCon(constantPat)), trueCont, falseCont);
    } catch e: /* not a constant pattern */;
    
    lpats = [pat | pat <- pats];   //TODO: should be unnnecessary
    elmTypes = [getType(pat) | pat <- lpats];
    patType = atuple(atypeList(elmTypes));
    
    str fuid = topFunctionScope();
    subject = muTmpIValue(nextTmp("tuple_subject"), fuid, subjectType);
  
    //iprintln(btscopes);
    
    body = trueCont;
    for(int i <- reverse(index(lpats))){
        body = translatePat(lpats[i], elmTypes[i], muSubscript(subject, muCon(i)), btscopes, body, computeFail(p, lpats, i-1, btscopes, falseCont));
    }
    body = muEnter(getEnter(p, btscopes), body);
    code = [ muConInit(subject, subjectExp), muIfelse(muHasTypeAndArity(patType, size(lpats), subject), body, falseCont)];
    return muBlock(code);
}

// ==== list pattern ==========================================================

//  List pattern [L0, L1, ..., Ln]
//                                                 +-----------+
//            +----------------------------------->| falseCont |
//            |                                    +-----------+
//            |
//        +--F--+----------------------------------------------+
//        |     |                                              |
//  ----->| L0  R <------+                                     |
//        |     |        |                                     |
//        |-----+        |                                     |
//        |  |        +--F--+-------------------------------+  |
//        |  |        |     |                               |  |
//        |  +------->| L1  R <------+                      |  |
//        |           |     |        |                      |  |
//        |           +-----+        |                      |  |
//        |           |  |           |                      |  |
//        |           |  |    ...    |                      |  |
//        |           |  |        +--F--+----------------+  |  |
//        |           |  |        |     |                |  |  |
//        |           |  +------->| Ln  R <------+       |  |  |
//        |           |           |     |        |       |  |  |
//        |           |           +-----+        |       |  |  |
//        |           |           |  |           |       |  |  |
//        |           |           |  |     +-----F----+  |  |  |
//        |           |           |  +---->| trueCont |  |  |  |
//        |           |           |        +----------+  |  |  |
//        |           |           +----------------------+  |  |
//        |           |                                     |  |
//        |           +-------------------------------------+  |
//        |                                                    |
//        +----------------------------------------------------+    

// ---- getBTInfo 

BTINFO getBTInfo(p:(Pattern) `[<{Pattern ","}* pats>]`,  BTSCOPE btscope, BTSCOPES btscopes){
    enterList = "<btscope.enter>_LIST";
    BTSCOPE btscopeLast = <enterList, btscope.resume, btscope.resume>;
    for(pat <- pats){
        <btscopeLast, btscopes> = getBTInfoList(pat, btscopeLast, btscopes);
    }
    return registerBTScope(p, <enterList, btscopeLast.resume, btscope.resume>, btscopes);
}

str nameSuffix(str s, Name name){
    sname = "<name>";
    return sname == "_" ? "_<s><nextTmp(sname)>" : "_<s>_<unescapeAndStandardize(sname)>";
}

str nameSuffix(str s, QualifiedName name){
    sname = "<name>";
    return sname == "_" ? "_<s><nextTmp(sname)>" : "_<s>_<unescapeAndStandardize(sname)>";
}

BTINFO getBTInfoList(p:(Pattern) `<QualifiedName name>`, BTSCOPE btscope, BTSCOPES btscopes){
    btscope.enter += nameSuffix("VAR", name);
    return registerBTScope(p, btscope, btscopes);
}    
BTINFO getBTInfoList(p:(Pattern) `<Type tp> <Name name>`, BTSCOPE btscope, BTSCOPES btscopes) {
    btscope.enter += nameSuffix("VAR", name);
    return registerBTScope(p, btscope, btscopes);
}
    
BTINFO getBTInfoList(p:(Pattern) `<Literal lit>`, BTSCOPE btscope, BTSCOPES btscopes)
    = registerBTScope(p, btscope, btscopes);

BTINFO getBTInfoList(p:(Pattern) `<QualifiedName name>*`, BTSCOPE btscope, BTSCOPES btscopes) {
    enter1 = btscope.enter + nameSuffix("MVAR", name);
    resume1 = enter1;
    fail1 = btscope.resume;
    return registerBTScope(p, <enter1, resume1, fail1>, btscopes);
}

BTINFO getBTInfoList(p:(Pattern) `*<Name name>`, BTSCOPE btscope, BTSCOPES btscopes) {
    enter1 = btscope.enter + nameSuffix("MVAR", name);
    resume1 = enter1;
    fail1 = btscope.resume;
    return registerBTScope(p, <enter1, resume1, fail1>, btscopes);
}

BTINFO getBTInfoList(p:(Pattern) `*<Type tp> <Name name>`, BTSCOPE btscope, BTSCOPES btscopes) {
    enter1 = btscope.enter + nameSuffix("MVAR", name);
    resume1 = enter1;
    fail1 = btscope.resume;
    return registerBTScope(p, <enter1, resume1, fail1>, btscopes);
}

default BTINFO getBTInfoList(Pattern p, BTSCOPE btscope, BTSCOPES btscopes) = getBTInfo(p, btscope, btscopes);  

// ---- translate list pattern

MuExp computeFail(Pattern p, list[Pattern] lpats, int i, btscopes, MuExp falseCont){
    //iprintln(btscopes);
    if(i < 0) return falseCont;
    resume_elm = getResume(lpats[i], btscopes);
    fail_p = getFail(p, btscopes);
    return resume_elm == fail_p ? falseCont : muFail(resume_elm);
}

MuExp translatePat(p:(Pattern) `[<{Pattern ","}* pats>]`, AType subjectType, MuExp subjectExp, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, bool subjectAssigned=false, MuExp restore=muBlock([])) {
   // iprintln(btscopes);
    lookahead = computeLookahead(p);  
    lpats = [pat | pat <- pats];   //TODO: should be unnnecessary
    npats = size(lpats);
    elmType = avalue();
    if(alist(tp) := subjectType && tp != avoid()){
    	elmType = tp;
    }
    try {
        constantPat = translatePatternAsConstant(p);
        return muIfExp(muEqual(subjectExp, muCon(constantPat)), trueCont, falseCont);
    } catch e: /* not a constant pattern */;
    
    str fuid = topFunctionScope();
    subj = nextTmp("subject");
    subject = muTmpIValue(subj, fuid, alist(elmType));
    cursor = muTmpInt(subj + "_cursor", fuid);
    sublen = muTmpInt(subj + "_len", fuid);
    typecheckNeeded = asubtype(getType(p), subjectType);
  
    //iprintln(trueCont);
    trueCont = muIfelse(muEqualNativeInt(cursor, sublen), trueCont, muFail(getResume(lpats[-1], btscopes)));
    for(i <- reverse(index(lpats))){
        trueCont = translatePatAsListElem(lpats[i], lookahead[i], subjectType, subject, sublen, cursor, i, btscopes, 
                                                    trueCont, 
                                                    computeFail(p, lpats, i-1, btscopes, falseCont),
                                                    restore=restore);
    }
    
    body = trueCont;
    
    i_am_multivar = !isEmpty(lookahead) && isMultiVar(lpats[0]);
    size_test = isEmpty(lookahead) ? muEqualNativeInt(sublen, muCon(0))
                                   : (lookahead[0].nMultiVar == 0 && !i_am_multivar) ? muEqualNativeInt(sublen, muCon(lookahead[0].nElem + 1))                                                   
                                                                                     : muGreaterEqNativeInt(sublen, muCon(lookahead[0].nElem + (i_am_multivar ? 0 : 1)));      
    block = muBlock([ muConInit(sublen, muSize(subject, alist(elmType))),
                      muIfelse(size_test, 
                               body,
                               falseCont
                              )
                    ]);
    //iprintln(block);
    code = muBlock([ *(subjectAssigned ? [muVarInit(subject, subjectExp)] : [muConInit(subject, subjectExp)]),   
                     muVarInit(cursor, muCon(0)), 
                     *(typecheckNeeded ? [muIfelse( muValueIsSubType(subject, subjectType),
                                                    block
                                                    , falseCont
                                                    )]                                                  
                                       : [ block ])
                     ]);
    //code = muEnter(getEnter(p, btscopes), code); // <<
    //iprintln(code);
    return code;
}

bool isMultiVar(p:(Pattern) `<QualifiedName name>*`) = true;
bool isMultiVar(p:(Pattern) `*<Type tp> <Name name>`) = true;
bool isMultiVar(p:(Pattern) `*<Name name>`) = true;
default bool isMultiVar(Pattern p) = false;

bool isAnonymousMultiVar(p:(Pattern) `_*`) = true;
bool isAnonymousMultiVar(p:(Pattern) `*<Type tp> _`) = true;
bool isAnonymousMultiVar(p:(Pattern) `*_`) = true;
default bool isAnonymousMultiVar(Pattern p) = false;

bool isAnonymousVar(p:(Pattern) `_`) = true;
bool isAnonymousVar(p:(Pattern) `<Type tp> _`) = true;
default bool isAnonymousVar(Pattern p) = false;

int nIter(p:(Pattern) `<QualifiedName name>*`) = 0;
int nIter(p:(Pattern) `*<Type tp> <Name name>`) = 0;
int nIter(p:(Pattern) `*<Name name>`) = 0;
default int nIter(Pattern p) { throw "Cannot determine iteration count: <p>"; }

// Lookahead information for a specific position in a list pattern
// nElem = the number of pattern elements following this position that are not multivars
// nMultiVar = the number of multivars following this position

alias Lookahead = tuple[int nElem, int nMultiVar];

list[Lookahead] computeLookahead((Pattern) `[<{Pattern ","}* pats>]`){
    nElem = 0;
    nMultiVar = 0;
    rprops = for(Pattern p <- reverse([p | Pattern p <- pats])){
                 append <nElem, nMultiVar>;
                 if(isMultiVar(p)) nMultiVar += 1; else nElem += 1;
             };
    return reverse(rprops);
}

str isLast(Lookahead lookahead) = lookahead.nMultiVar == 0 ? "LAST_" : "";

MuExp translatePatAsListElem(p:(Pattern) `<QualifiedName name>`, Lookahead lookahead, AType subjectType, MuExp subject, MuExp sublen, MuExp cursor, int posInPat, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, MuExp restore=muBlock([])) {
    if("<name>" == "_"){
       return muIfelse(muLessNativeInt(cursor, sublen),
                       muBlock([ muIncNativeInt(cursor, muCon(1)), 
                                 trueCont
                               ]),
                       falseCont);
    }
    var = mkVar(prettyPrintName(name), name@\loc);
    if(isDefinition(name@\loc)){
        return muIfelse(muLessNativeInt(cursor, sublen),
                        muBlock([ muVarInit(var, muSubscript(subject, cursor)),
                                  muIncNativeInt(cursor, muCon(1)), 
                                  trueCont
                                ]),
                       falseCont);
                  
    } else {
        return muIfelse(muLessNativeInt(cursor, sublen),
                        muIfelse(muIsInitialized(var), 
                                 muIfelse(muEqual(var, muSubscript(subject, cursor)),
                                          muBlock([ muIncNativeInt(cursor, muCon(1)), 
                                                    trueCont
                                                  ]),
                                          falseCont),
                                 muBlock([ muAssign(var, muSubscript(subject, cursor)), 
                                           muIncNativeInt(cursor, muCon(1)), 
                                           trueCont
                                         ])),
                        falseCont);
    }
} 

MuExp translatePatAsListElem(p:(Pattern) `<Type tp> <Name name>`, Lookahead lookahead, AType subjectType, MuExp subject, MuExp sublen, MuExp cursor, int posInPat, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, MuExp restore=muBlock([])) {
   trType = translateType(tp);
   lengthCheck = muLessNativeInt(cursor, sublen);
   check = lengthCheck;
   if(!asubtype(subjectType, alist(trType))){
        check = muAndNativeBool(lengthCheck, muValueIsComparable(muSubscript(subject, cursor), trType));
   }
   if("<name>" == "_"){
      return muIfelse(check, muBlock([ muIncNativeInt(cursor, muCon(1)), trueCont ]),
                             falseCont);
   } else {
       var = mkVar(prettyPrintName(name), name@\loc);
       var.atype = getType(tp);
       
       return muIfelse(check, muBlock([ muVarInit(var, muSubscript(subject, cursor)), muIncNativeInt(cursor, muCon(1)), trueCont ]),
                              falseCont);
   }
 } 

MuExp translatePatAsListElem(p:(Pattern) `<Literal lit>`, Lookahead lookahead, AType subjectType, MuExp subject, MuExp sublen, MuExp cursor, int posInPat, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, MuExp restore=muBlock([])) {
    if(lit is regExp) fail;
 
    return muIfelse(muAndNativeBool(muLessNativeInt(cursor, sublen), muEqual(translate(lit), muSubscript(subject, cursor))), 
                    muBlock([ muIncNativeInt(cursor, muCon(1)), 
                              trueCont
                            ]),
                    falseCont);
}

// Multi variables

bool isUsed(MuExp var, MuExp exp){
    return true; // TODO
    //nm = var.name;
    //return /nm := exp; // In some cases, the type in the var can still be a type var, so only look for the var name;
}

MuExp translatePatAsListElem(p:(Pattern) `<QualifiedName name>*`, Lookahead lookahead, AType subjectType, MuExp subject, MuExp sublen, MuExp cursor, int posInPat, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, MuExp restore=muBlock([])) {
    return translateMultiVarAsListElem(mkVar(p), isDefinition(name@\loc), lookahead, subjectType, subject, sublen, cursor, posInPat, getEnter(p, btscopes), trueCont, falseCont, restore=restore);
}

MuExp translatePatAsListElem(p:(Pattern) `*<Name name>`, Lookahead lookahead, AType subjectType, MuExp subject, MuExp sublen, MuExp cursor, int posInPat, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, MuExp restore=muBlock([])) {
    return translateMultiVarAsListElem(mkVar(p), isDefinition(name@\loc), lookahead, subjectType, subject, sublen, cursor, posInPat, getEnter(p, btscopes), trueCont, falseCont, restore=restore);
} 

MuExp translatePatAsListElem(p:(Pattern) `*<Type tp> <Name name>`, Lookahead lookahead, AType subjectType, MuExp subject, MuExp sublen, MuExp cursor, int posInPat, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, MuExp restore=muBlock([])) {
    return translateMultiVarAsListElem(mkVar(p), isDefinition(name@\loc), lookahead, subjectType, subject, sublen, cursor, posInPat, getEnter(p, btscopes), trueCont, falseCont, restore=restore);
}

MuExp translatePatAsListElem(p:(Pattern) `+<Pattern argument>`, Lookahead lookahead, AType subjectType, MuExp subject, MuExp sublen, MuExp cursor, int posInPat, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, MuExp restore=muBlock([])) {
    throw "splicePlus pattern";
} 

// TODO: optimize last multivar in list pattern

MuExp translateMultiVarAsListElem(MuExp var, bool isDefinition, Lookahead lookahead, AType subjectType, MuExp subject, MuExp sublen, MuExp cursor, int posInPat, str enter, MuExp trueCont, MuExp falseCont, MuExp restore=muBlock([])) {
    fuid =  topFunctionScope();
    v = nextTmp("<unescapeAndStandardize(var.name)>_<abs(var.pos)>");
    startcursor = muTmpInt(v + "_start", fuid);
    savedcursor = muTmpInt(cursor.name + "_saved", fuid);
    len = muTmpInt(v + "_len", fuid);
    prevlen = muTmpInt(v + "_prevlen", fuid);
    //var.atype = alist(avalue()); // = muVar(prettyPrintName("<name>"), fuid, pos, alist(avalue()));
    varPresent = var.name != "_";
    needsCheck = !asubtype(subjectType, var.atype);
    
    code = muBlock([]);
    if(lookahead.nMultiVar == 0 && !(varPresent && isUsed(var, trueCont) || needsCheck)){
        code = muBlock([ muConInit(startcursor, cursor), 
                         muConInit(len, muSubNativeInt(muSubNativeInt(sublen, startcursor), muCon(lookahead.nElem))),         
                         muAssign(cursor, muAddNativeInt(startcursor, len)),
                         muEnter(enter, trueCont),
                         falseCont
                       ]);
                       
    } else {
        if(isDefinition || !varPresent){
           if(needsCheck && !varPresent){
                var.name = var.name + nextTmp();
           }
           asgCursor = muBlock([ muAssign(cursor, muAddNativeInt(startcursor, len)), trueCont ]);
           if(needsCheck){
                asgCursor =  muIf(muValueIsSubType(var, var.atype), asgCursor);
           }
           code = muBlock([ muConInit(startcursor, cursor),
                            
                            muForRangeInt(enter, len, 0, 1, muSubNativeInt(sublen, startcursor), 
                                          muBlock([ *restore,
                                                    *( (varPresent && isUsed(var, trueCont) || (needsCheck && !varPresent)) ? [muConInit(var, muSubList(subject, startcursor, len))] : [] ),
                                                    asgCursor
                                                  ])),
                            falseCont
                          ]);
        } else {
           code = muBlock([ muConInit(startcursor, cursor),
                            muConInit(len, muSubNativeInt(muSubNativeInt(sublen, startcursor), muCon(lookahead.nElem))),   
                            muConInit(prevlen, muSize(var, subjectType)),
                            muIfelse(muGreaterEqNativeInt(len, prevlen), 
                                 muIfelse(muIsInitialized(var),
                                          muIf(muEqual(var, muSubList(subject, startcursor, prevlen)),
                                               muBlock([ muAssign(cursor, muAddNativeInt(startcursor, prevlen)),
                                                         trueCont
                                                       ])),
                                          muBlock([ muAssign(var, muSubList(subject, startcursor, prevlen)),
                                                    muAssign(cursor, muAddNativeInt(startcursor, prevlen)),
                                                    trueCont
                                                  ]))
                                 , falseCont // <<<<
                                 )
                             , falseCont    // <<<<     
                          ]);
        }
   }
    if(needsCheck){
        code = muIf(muValueIsComparable(subject, var.atype), code);
    }
    return muEnter(enter, code); 
}

default MuExp translatePatAsListElem(Pattern p, Lookahead lookahead, AType subjectType, MuExp subject, MuExp sublen, MuExp cursor, int posInPat, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, MuExp restore=muBlock([])) {
    try {
        pcon = muCon(translatePatternAsConstant(p));
        return muIfelse(muAndNativeBool(muLessNativeInt(cursor, sublen), muEqual(muSubscript(subject, cursor), pcon)),         
                        muBlock([ muAssign(cursor, muAddNativeInt(cursor, muCon(1))),
                                  trueCont ])
                        , falseCont // <<<<
                        );                            
    } catch: {
        if(p is descendant){
            // Make sure to undo cursor updates
            // -2 is ok since p matches at least 1 element (it cannot be a multivar)
            first = true;
            trueCont = top-down-break visit(trueCont) { 
                case muForAll( _, _, _, muDescendantMatchIterator(_, _), _): {if(first) { first = false; fail;}} // skip nested descandants
                case muBlock([muIncNativeInt(_, muCon(-2)), muFail(_)]): {;}    // prevent cascading insertion of decrement
                case mf: muFail(_) => muBlock([muIncNativeInt(cursor, muCon(-2)), mf]) 
            };
        }
        
        
  
        return translatePat(p, getListElementType(subjectType), muSubscript(subject, cursor), btscopes, 
                               muValueBlock(avalue(), [ muIncNativeInt(cursor, muCon(1)), trueCont]), 
                               falseCont, restore=muBlock([restore,muAssign(cursor, muCon(posInPat))])
                           );
   }
}

// -- variable becomes pattern ---------------------------------------

BTINFO getBTInfo(p:(Pattern) `<Name name> : <Pattern pattern>`,  BTSCOPE btscope, BTSCOPES btscopes) {
    <btscope1, btscopes1> = getBTInfo(pattern, btscope, btscopes);
    return registerBTScope(p, btscope1, btscopes1);
}

MuExp translatePat(p:(Pattern) `<Name name> : <Pattern pattern>`, AType subjectType, MuExp subjectExp, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, bool subjectAssigned=false, MuExp restore=muBlock([])) {
    if(subjectAssigned){
         return translatePat(pattern, subjectType, subjectExp, btscopes, trueCont, falseCont, subjectAssigned=false, restore=restore);
    } else {
        var = mkVar(prettyPrintName(name), name@\loc);
        asg = isDefinition(name@\loc) ? muVarInit(var, subjectExp) : muAssign(var, subjectExp);
        return translatePat(pattern, subjectType, subjectExp, btscopes, muValueBlock(avalue(), [ asg, trueCont ]), falseCont, subjectAssigned=subjectAssigned, restore=restore);
    }
}

// -- as type pattern ------------------------------------------------

BTINFO getBTInfo(p:(Pattern) `[ <Type tp> ] <Pattern argument>`,  BTSCOPE btscope, BTSCOPES btscopes) {
    <btscope1, btscopes1> = getBTInfo(argument, btscope, btscopes);
    return registerBTScope(p, btscope1, btscopes1);
}

MuExp translatePat(p:(Pattern) `[ <Type tp> ] <Pattern argument>`, AType subjectType, MuExp subjectExp, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, bool subjectAssigned=false, MuExp restore=muBlock([])) =
    muIfelse(muValueIsSubType(subjectExp, translateType(tp)), 
             translatePat(argument, subjectType, subjectExp, btscopes, trueCont, falseCont, subjectAssigned=subjectAssigned, restore=restore),
             falseCont);

// -- descendant pattern ---------------------------------------------

BTINFO getBTInfo(p:(Pattern) `/ <Pattern pattern>`,  BTSCOPE btscope, BTSCOPES btscopes) {
    enter_desc = "<btscope.enter>_DESC";
    <pat_btscope, btscopes1> = getBTInfo(pattern, <enter_desc, enter_desc, enter_desc>, btscopes);
    return registerBTScope(p, <enter_desc, enter_desc, btscope.resume>, btscopes1);
}

MuExp captureExits(MuExp exp, list[str] entered, str succeedLab, str failLab){
    return visit(exp){
        case muEnter(str enter1, MuExp exp1) => muEnter(enter1, captureExits(exp1, enter1 + entered, succeedLab, failLab))
        case muSucceed(enter1) => muSucceed(succeedLab) when enter1 notin entered
        case muFail(enter1) => muFail(failLab) when enter1 notin entered
    }
}

MuExp translatePat(p:(Pattern) `/ <Pattern pattern>`,  AType subjectType, MuExp subjectExp, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, MuExp restore=muBlock([])){
	desc_btscope = btscopes[getLoc(p)];
	concreteMatch = concreteTraversalAllowed(pattern, subjectType);

	reachable_syms = { avalue() };
	reachable_prods = {};
    if(optimizing()){
	   tc = getTypesAndConstructors(pattern);
       <reachable_syms, reachable_prods>  = getReachableTypes(subjectType, tc.constructors, tc.types, concreteMatch);
    }
    descriptor = descendantDescriptor(concreteMatch, reachable_syms, reachable_prods, getReifiedDefinitions());
    fuid = topFunctionScope();
    elmType = ( avoid() | alub(it, sym) | sym <- reachable_syms );
    elem = muTmpIValue(nextTmp("elem"), fuid, elmType);
    patType = getType(pattern);
 
    capturedTrueCont = captureExits(trueCont, [], desc_btscope.resume, desc_btscope.resume);
    body = translatePat(pattern, avalue(), elem, btscopes, capturedTrueCont, muFail(desc_btscope.resume), restore=restore);

    if(!isValueType(patType)){
        body =  muIfelse(muValueIsComparable(elem, patType), body,  muFail(desc_btscope.resume));
    }
    
    code = muBlock([ muForAll( desc_btscope.enter, elem, aset(elmType), muDescendantMatchIterator(subjectExp, descriptor),
                               body
                             ),
                     falseCont
                   ]);             
    return code;
}

// Strip start if present

AType stripStart(\start(AType s)) = s;
default AType stripStart(AType s) = s;

// Is  a pattern a concretePattern?
// Note that a callOrTree pattern always requires a visit of the production to inspect labeled fields and is etherefore
// NOT a concrete pattern

bool isConcretePattern(Pattern p) {
    tp = getType(p);
    return isNonTerminalType(tp) && !(p is callOrTree); // && Symbol::sort(_) := tp;
}  
	
bool isConcreteType(AType subjectType) =
	(  isNonTerminalType(subjectType)
	|| asubtype(subjectType, aadt("Tree", [], dataSyntax())) && subjectType != aadt("Tree", [], dataSyntax())
	);
	
bool concreteTraversalAllowed(Pattern pattern, AType subjectType) =
    isConcreteType(subjectType) && isConcretePattern(pattern);
	
// get the types and constructor names from a pattern

tuple[set[AType] types, set[str] constructors] getTypesAndConstructors(p:(Pattern) `<QualifiedName qualifiedName>`) =
	<{getType(p)}, {}>;
	
tuple[set[AType] types, set[str] constructors] getTypesAndConstructors(p:(Pattern) `<Type tp> <Name name>`) =
	<{getType(p)}, {}>;	
	
tuple[set[AType] types, set[str] constructors] getTypesAndConstructors(p:(Pattern) `<Name name> : <Pattern pattern>`) =
	getTypesAndConstructors(pattern);	

tuple[set[AType] types, set[str] constructors]  getTypesAndConstructors(p:(Pattern) `<Type tp> <Name name> : <Pattern pattern>`) =
	getTypesAndConstructors(pattern);
		
tuple[set[AType] types, set[str] constructors] getTypesAndConstructors(p:(Pattern) `<Pattern expression> ( <{Pattern ","}* arguments> <KeywordArguments[Pattern] keywordArguments> )`) =
	(expression is qualifiedName) ? <{}, {prettyPrintName("<expression>")}> : <{getType(p)}, {}>;

tuple[set[AType] types, set[str] constructors] getTypesAndConstructors(Pattern p) = <{getType(p)}, {}>;

// -- anti pattern ---------------------------------------------------
    
BTINFO getBTInfo(p:(Pattern) `! <Pattern pattern>`,  BTSCOPE btscope, BTSCOPES btscopes) {
    enterAnti = "<btscope.enter>_ANTI";
    <pat_btscope, btscopes1> = getBTInfo(pattern, <enterAnti, enterAnti, enterAnti>, btscopes);
    return registerBTScope(p, <enterAnti, pat_btscope.\fail, btscope.resume>, btscopes1);
    
    //<btscope1, btscopes1> = getBTInfo(pattern, btscope, btscopes);
    //return registerBTScope(p, btscope1, btscopes1);
}

MuExp translatePat(p:(Pattern) `! <Pattern pattern>`, AType subjectType, MuExp subjectExp, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, bool subjectAssigned=false, MuExp restore=muBlock([])){
    //iprintln(btscopes);
    my_btscope = btscopes[getLoc(p)];
    code = muEnter(my_btscope.enter, translatePat(pattern, subjectType, subjectExp, btscopes, falseCont, trueCont, restore=restore));
    //iprintln(code);
    //if(!noSequentialExit(code)){
    //    code = muBlock([code, trueCont]);
    //    iprintln(code);
    //}
    
    return code;
    //return muEnter(my_btscope.enter, translatePat(pattern, subjectType, subjectExp, btscopes, muFail(my_btscope.resume), muSucceed(my_btscope.\fail)));
    
    //return muCallPrim3("not", abool(), [abool()], [translatePat(pattern, subjectType, subjectExp, btscopes, trueCont, falseCont, subjectAssigned=subjectAssigned)], p@\loc);
    //return  translatePat(pattern, subjectType, subjectExp, btscopes, muFail(getEnter(pattern, btscopes)), muSucceed(getEnter(pattern, btscopes)), subjectAssigned=subjectAssigned);
    //my_btscope = btscopes[getLoc(p)];
    
    //code = muEnter(my_btscope.enter, translatePat(pattern, subjectType, subjectExp, btscopes, muSucceed(my_btscope.enter), muFail(my_btscope.\fail)));
    //iprintln(code);
    //code = negate(code, [my_btscope.\fail]);
    //iprintln(code);
    //return code;
}
// -- typed variable becomes pattern ---------------------------------

BTINFO getBTInfo(p:(Pattern) `<Type tp> <Name name> : <Pattern pattern>`, BTSCOPE btscope, BTSCOPES btscopes) {
        <btscope1, btscopes1> = getBTInfo(pattern, btscope, btscopes);
        return registerBTScope(p, btscope1, btscopes1);
}

MuExp translatePat(p:(Pattern) `<Type tp> <Name name> : <Pattern pattern>`, AType subjectType, MuExp subjectExp, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, bool subjectAssigned=false, MuExp restore=muBlock([])) {
    trType = translateType(tp);
  
    if("<name>" == "_"){
         trPat = translatePat(pattern, subjectType, subjectExp, btscopes, trueCont, falseCont, subjectAssigned=subjectAssigned, restore=restore);
         // TODO JURGEN: this static subtype test is not correct, the static subjecttype may be \value, but still this code should check
         // whether or not the value is accidentally the right trType!
         return asubtype(subjectType, trType) ? trPat : muIfelse(muValueIsSubType(subjectExp, trType), trPat, falseCont);
    }
    str fuid = ""; int pos=0;           // TODO: this keeps type checker happy, why?
    <fuid, pos> = getVariableScope(prettyPrintName(name), name@\loc);
    ppname = prettyPrintName(name);
    var = muVar(ppname, fuid, pos, trType[label=ppname]);
    trueCont2 = trueCont;
    if(subjectExp != var){
        trueCont2 =  muValueBlock(avalue(), [ /*subjectAssigned ? muAssign(var, subjectExp) :*/ muVarInit(var, subjectExp), trueCont ]);
    } 
    trPat = translatePat(pattern, subjectType, subjectExp, btscopes, trueCont2, falseCont, subjectAssigned=subjectAssigned, restore=restore);
    return asubtype(subjectType, trType) ? trPat :  muIfelse(muValueIsSubType(subjectExp, trType), trPat, falseCont);
}

MuExp translatePat(p:(Pattern) `<Concrete con>`, AType subjectType, MuExp subjectExp, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, bool subjectAssigned=false, MuExp restore=muBlock([])) {
  return translateConcrete(con, subjectExp, btscopes, trueCont, falseCont, restore=restore);
} 

// -- default rule for pattern ---------------------------------------

default BTINFO getBTInfo(Pattern p, BTSCOPE btscope, BTSCOPES btscopes)
    = registerBTScope(p, btscope, btscopes);

default MuExp translatePat(Pattern p, AType subjectType,  MuExp subjectExp, BTSCOPES btscopes, MuExp trueCont, MuExp falseCont, bool subjectAssigned=false, MuExp restore=muBlock([])) { 
    return muValueBlock([muThrow(muCon("could not translate pattern <p>: <p@\loc>"))]); 
}


/*****************************************************************************/
/*                      Constant Patterns                                    */
/* - try to translate a pattern to a constant (and throw an exception when   */
/*   this is impossible                                                      */
/*****************************************************************************/

value getLiteralValue((Literal) `<Literal s>`) =  readTextValueString("<s>") when isConstant(s);

bool isConstant(StringLiteral l) = l is nonInterpolated;
bool isConstant(LocationLiteral l) = l.protocolPart is nonInterpolated && l.pathPart is nonInterpolated;
bool isConstant(RegExpLiteral l)  = false;
default bool isConstant(Literal l) = true;
 
value translatePatternAsConstant(p:(Pattern) `<Literal lit>`) = getLiteralValue(lit) when isConstant(lit);

value translatePatternAsConstant(p:(Pattern) `<Pattern expression> ( <{Pattern ","}* arguments> <KeywordArguments[Pattern] keywordArguments> )`) {
  if(!isEmpty("<keywordArguments>")) throw "Not a constant pattern: <p>";
  if(isADTType(getType(p))) throw "ADT pattern not considered constant: <p>";
  return makeNode("<expression>", [ translatePatternAsConstant(pat) | Pattern pat <- arguments ]);
}

value translatePatternAsConstant(p:(Pattern) `{<{Pattern ","}* pats>}`) {
    res = { translatePatternAsConstant(pat) | Pattern pat <- pats };
    return res;
}

value translatePatternAsConstant(p:(Pattern) `[<{Pattern ","}* pats>]`) = [ translatePatternAsConstant(pat) | Pattern pat <- pats ];

value translatePatternAsConstant(p:(Pattern) `\<<{Pattern ","}* pats>\>`) {
  lpats = [ pat | pat <- pats]; // TODO
  return ( <translatePatternAsConstant(lpats[0])> | it + <translatePatternAsConstant(lpats[i])> | i <- [1 .. size(lpats)] );
}

default value translatePatternAsConstant(Pattern p){
  throw "Not a constant pattern: <p>";
}

/*********************************************************************/
/*                  BacktrackFree for Patterns                       */
/*********************************************************************/

// TODO: Make this more precise and complete

bool backtrackFree(p:(Pattern) `[<{Pattern ","}* pats>]`) = false; // p == (Pattern) `[]` || all(pat <- pats, backtrackFree(pat));
bool backtrackFree(p:(Pattern) `{<{Pattern ","}* pats>}`) = false; //p == (Pattern) `{}` || all(pat <- pats, backtrackFree(pat));
bool backtrackFree(p:(Pattern) `\<<{Pattern ","}* pats>\>`) = false; // all(pat <- pats, backtrackFree(pat));
bool backtrackFree(p:(Pattern) `<Name name> : <Pattern pattern>`) = backtrackFree(pattern);
bool backtrackFree(p:(Pattern) `[ <Type tp> ] <Pattern pattern>`) = backtrackFree(pattern);

bool backtrackFree(p:(Pattern) `<Pattern expression> ( <{Pattern ","}* arguments> <KeywordArguments[Pattern] keywordArguments> )`)
    = backtrackFree(expression) && (isEmpty(argumentList) || all(arg <- argumentList, backtrackFree(arg)))
                                && (isEmpty(keywordArgumentList) || all(kwa <- keywordArgumentList, backtrackFree(kwa.expression)))
    when argumentList := [arg | arg <- arguments], 
         keywordArgumentList := (((KeywordArguments[Pattern]) `<OptionalComma optionalComma> <{KeywordArgument[Pattern] ","}+ kwaList>` := keywordArguments)
                                ? [kwa | kwa <- kwaList]
                                : []);
bool backtrackFree((Pattern) `/ <Pattern pattern>`) = false;
bool backtrackFree((Pattern) `<RegExpLiteral r>`) = false;
default bool backtrackFree(Pattern p) = !isMultiVar(p);
