module lang::rascalcore::compile::Examples::Tst4
import analysis::diff::TextEdits;  

//int chartServer(str s, bool b = false)
//    = chartServer(d(s, b));
//    
//int chartServer(D d) = 0;

//int outer2(int t, int tabSize=4){
//    int rec(int t, int innerKwp = 5) = t + tabSize + innerKwp when t > 10;
//    default int rec(int t) = t;
////    return rec(t);
//}

//int outer4(int t, int tabSize=4){
//    int rec(int t){
//        int rec_inner(int t, int innerKwp = 5) = t + tabSize + innerKwp  when t > 10;
//        default int rec_inner(int t) = t;
//        return rec_inner(t);
//    }
//    return rec(t);
//}

//int outer2(int t, int tabSize=4){
//    int rec(int t, int innerKwp = 5) = t + tabSize + innerKwp when t > 10;
//    default int rec(int t) = t;
//    return rec(t);
//}
//
//test bool outer2_1() = outer2(1) == 1;

//import lang::html::IO;
//import lang::rascal::format::Grammar;
//import util::IDEServices;
//import Content;
//import ValueIO;
//
//Response (Request) valueServer(value v) {
//    Response reply(get(/^\/editor/, parameters=pms)) {
//        if (pms["src"]?) {
//            edit(readTextValueString(#loc, pms["src"]));
//            return response(writeHTMLString(text("done")));
//        }
//
//        return response(writeHTMLString(text("could not edit <pms>")));
//    }
//
//    default Response reply(get(_)) {
//        return response(writeHTMLString(toHTML(v)));
//    }
//
//    return reply;
//}
//
//HTMLElement toHTML(value v) = text("<v>");

//
//// ---- test1 ----
//
//test bool test11() { try return Exp::id(_) := implodeExp("a"); catch ImplodeError(_): return false;}
//
//@IgnoreCompiler{TODO}
//test bool test12() { try return Exp::number(Num::\int("0")) := implodeExp("0"); catch ImplodeError(_): return false;}
//
//test bool test13() { try return Exp::eq(Exp::id(_),Exp::id(_)) := implodeExp("a == b"); catch ImplodeError(_): return false;}
//
//@IgnoreCompiler{TODO}
//test bool test14() { try return Exp::eq(Exp::number(Num::\int("0")), Exp::number(Num::\int("1"))) := implodeExp("0 == 1"); catch ImplodeError(_): return false;}
//
//test bool test15() { try return  Expr::id(_) := implodeExpr("a"); catch ImplodeError(_): return false;}
//
//@IgnoreCompiler{TODO}
//test bool test16() { try return Expr::number(Number::\int("0")) := implodeExpr("0"); catch ImplodeError(_): return false;}
//
//test bool test17() { try return Expr::eq(Expr::id(_),Expr::id(_)) := implodeExpr("a == b"); catch ImplodeError(_): return false;}
//
//@IgnoreCompiler{TODO}
//test bool test18() { try return Expr::eq(Expr::number(Number::\int("0")), Expr::number(Number::\int("1"))) := implodeExpr("0 == 1"); catch ImplodeError(_): return false;}
//
//// ---- test2 ----
//
//test bool test21() { try return Exp::eq(Exp::id("a"),Exp::id("b")) := implodeExpLit1(); catch ImplodeError(_): return false;}
//
//test bool test22() { try return Exp::eq(Exp::id("a"),Exp::number(Num::\int("11"))) := implodeExpLit2(); catch ImplodeError(_): return false;}
//
//test bool test23() { try return Expr::eq(Expr::id("a"),Expr::id("b")) := implodeExprLit1(); catch ImplodeError(_): return false;}
//
//test bool test24() { try return  Expr::eq(Expr::id("a"),Expr::number(Number::\int("11"))) := implodeExprLit2(); catch ImplodeError(_): return false;}

//import IO;
//
//lexical Id = [a-z]+ \ "type";
//
//layout Whitespace = [\ \t\n]*;
//
//start syntax Program = Stat+;
//
//syntax Stat
//    = "type" Id ";"
//    | Type Id ";"
//    | Exp ";"
//    ;
//
//syntax Type
//    = Id
//    | Id "*"
//    ;
//
//syntax Exp
//    = Id
//    | left Exp "*" Exp
//    ;
//
//start[Program] program(str input) {
//  // we always start with an empty symbol table
//  set[str] symbolTable = {};
//
//  // here we collect type declarations
//  Stat declareType(s:(Stat) `type <Id id>;`) {
//    println("declared <id>");
//    symbolTable += {"<id>"};
//    return s;
//  }
//
//  // here we remove type names used as expressions
//  Exp filterExp(e:(Exp) `<Id id>`) {
//    if ("<id>" in symbolTable) {
//        println("filtering <id> because it was declared as a type.");
//        filter;
//    }
//    else {
//        return e;
//    }
//  }
//
//  return parse(#start[Program], input, |demo:///|, filters={declareType, filterExp}, hasSideEffects=true);
//}
//
//value main(){
//    example = "type a; a * a;";
//    return program(example);
//}

//import ParseTree;
//
//@synopsis{Pretty prints parse trees using ASCII art lines for edges.}
//str prettyTree(Tree t, bool src=false, bool characters=true, bool \layout=false, bool literals=\layout) {
//  str nodeLabel(appl(prod(label(str l, Symbol nt), _, _), _)) = "<type(nt,())> = <l>: ";
//  //str nodeLabel(appl(prod(Symbol nt, as, _), _))              = "<type(nt,())> = <for (a <- as) {><type(a,())> <}>";
//  //str nodeLabel(appl(regular(Symbol nt), _))                  = "<type(nt,())>";
//  //str nodeLabel(char(32))                                     = "⎵";
//  //str nodeLabel(char(10))                                     = "\\r";
//  //str nodeLabel(char(13))                                     = "\\n"; 
//  //str nodeLabel(char(9))                                      = "\\t";
//  //str nodeLabel(amb(_) )                                      = "❖";
//  //str nodeLabel(loc src)                                      = "<src>";
//  default str nodeLabel(Tree v)                               = "<v>";
//
//  //lrel[str,value] edges(Tree t:appl(_,  list[Tree] args)) = [<"src", t@\loc> | src, t@\loc?] + [<"", k> | Tree k <- args, include(k)];
//  //lrel[str,value] edges(amb(set[Tree] alts))              = [<"", a> | Tree a <- alts];
//  //lrel[str,value] edges(loc _)                            = [];
//  //default lrel[str,value] edges(Tree _)                   = [];
//  //  
//  return ppvalue(t, nodeLabel/*, edges*/);
//}
//
//@synopsis{Pretty prints nodes and ADTs using ASCII art for the edges.}
//str prettyNode(node n, bool keywords=true) {
//  //str nodeLabel(list[value] _)       = "[…]";
//  //str nodeLabel(set[value] _)        = "{…}";
//  //str nodeLabel(map[value, value] _) = "(…)";
//  //str nodeLabel(value t)             = "\<…\>" when typeOf(t) is \tuple;
//  //str nodeLabel(node k)              = getName(k);
//  default str nodeLabel(value v)     = "<v>";
//  
//  //lrel[str,value] edges(list[value] l)       = [<"", x> | value x <- l];
//  //lrel[str,value] edges(value t)             = [<"", x> | value x <- carrier([t])] when typeOf(t) is \tuple;
//  //lrel[str,value] edges(set[value] s)        = [<"", x> | value x <- s];
//  //lrel[str,value] edges(map[str, value] m)   = [<"<x>", m[x]> | value x <- m];  
//  //lrel[str,value] edges(map[num, value] m)   = [<"<x>", m[x]> | value x <- m];  
//  //lrel[str,value] edges(map[loc, value] m)   = [<"<x>", m[x]> | value x <- m];  
//  //lrel[str,value] edges(map[node, value] m)  = [<"key", x>, <"value", m[x]> | value x <- m];  
//  //lrel[str,value] edges(node k)              = [<"", kid> | value kid <- getChildren(k)] + [<l, m[l]> | keywords, map[str,value] m := getKeywordParameters(k), str l <- m];
//  //default lrel[str,value] edges(value _)     = [];
//    
//  return ppvalue(n, nodeLabel/*, edges*/);
//}
//
//private str ppvalue(value e, str(value) nodeLabel/*, lrel[str,value](value) edges*/) 
//  = ""; //" <nodeLabel(e)>
//    //'<ppvalue_(e, nodeLabel, edges)>";
//
////private str ppvalue_(value e, str(value) nodeLabel, lrel[str,value](value) edges, str indent = "") {
////  lrel[str, value] kids = edges(e);
////  int i = 0;
////
////  str indented(str last, str other, bool doSpace) 
////    = "<indent> <if (i == size(kids) - 1) {><last><} else {><other><}><if (doSpace) {> <}>";
////    
////  return "<for (<str l, value sub> <- kids) {><indented("└─", "├─", l == "")><if (l != "") {>─<l>─→<}><nodeLabel(sub)>
////         '<ppvalue_(sub, nodeLabel, edges, indent = indented(" ", "│", true))><i +=1; }>";
////}

//test bool everyTypeCanBeReifiedWithoutExceptions(&T u) = _ := typeOf(u);
//
//test bool allConstructorsAreDefined() 
//  = (0 | it + 1 | /cons(_,_,_,_) := #P.definitions) == 7;
//
//test bool allConstructorsForAnAlternativeDefineTheSameSort() 
//  = !(/choice(def, /cons(label(_,def),_,_,_)) !:= #P.definitions);
//  
//test bool typeParameterReificationIsStatic1(&F _) = #&F.symbol == \parameter("F",\value());
//test bool typeParameterReificationIsStatic2(list[&F] _) = #list[&F].symbol == \list(\parameter("F",\value()));
//
//@ignore{issue #1007}
//test bool typeParameterReificationIsStatic3(&T <: list[&F] f) = #&T.symbol == \parameter("T", \list(\parameter("F",\value())));
//
//test bool dynamicTypesAreAlwaysGeneric(value v) = !(type[value] _ !:= type(typeOf(v),()));
//
//// New tests which can be enabled after succesful bootstrap
//data P(int size = 0);
//
//@ignore{Does not work after changed TypeReifier in compiler}
//test bool allConstructorsHaveTheCommonKwParam()
//  =  all(/choice(def, /cons(_,_,kws,_)) := #P.definitions, label("size", \int()) in kws);
//   
//@ignoreCompiler{Does not work after changed TypeReifier in compiler}  
//test bool axiomHasItsKwParam()
//  =  /cons(label("axiom",_),_,kws,_) := #P.definitions && label("mine", \adt("P",[])) in kws;  
//
//@ignore{Does not work after changed TypeReifier in compiler}  
//test bool axiomsKwParamIsExclusive()
//  =  all(/cons(label(!"axiom",_),_,kws,_) := #P.definitions, label("mine", \adt("P",[])) notin kws);
//  
  
  


//import List;
//test bool listCount1(list[int] L){
//   int cnt(list[int] L){
//    int count = 0;
//    while ([int _, *int _] := L) { 
//           count = count + 1;
//           L = tail(L);
//    }
//    return count;
//  }
//  return cnt(L) == size(L);
//}
//
//value main()= listCount1([-8,1121836232,-5,0,1692910390]);


//test bool testSimple1() 
//    = int i <- [1,4] && int j <- [2,1] && int k := i + j && k >= 5;
//
//value main() = testSimple1();

//int f(list[int] ds){
//    if([int xxx]:= ds, xxx > 0){
//        return 1;
//    } else {
//        return 2;
//    }
//}
//value main() = /*testSimple1() && */f([1]) == 1;
