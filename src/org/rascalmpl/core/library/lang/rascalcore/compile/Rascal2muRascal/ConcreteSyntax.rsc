module lang::rascalcore::compile::Rascal2muRascal::ConcreteSyntax

import lang::rascalcore::compile::Rascal2muRascal::TypeUtils;

import lang::rascalcore::check::ATypeUtils;
import lang::rascalcore::check::AType;

import ParseTree;
import Message;
import String;
import IO;

// WARNING: this module is sensitive to bootstrapping dependencies and implicit contracts:
// 
// * The functionality of parseConcreteFragments depends on the shape of the Rascal grammar,
// yet this grammar is not imported here. We use the Tree meta notation from ParseTree.rs to detect production
// rules of the Rascal grammar;
// * This module must not use concrete syntax itself to avoid complex bootstrapping issues;

tuple[Tree, TModel] parseConcreteFragments(Tree M, TModel tm, AGrammar gr) {
   // here we translate internal type-checker symbols to the original Productions and Symbol 
   // to be used by the parser generator and the Rascal run-time:
   map[Symbol, Production] rules = adefinitions2definitions(gr.rules);
   
   @doc{parse fragment or store parse error in the TModel}
   Tree parseFragment(t:appl(prod(label("typed",lex("Concrete")), _, _),[_,_,Tree varsym,_,_,_,_, parts,_])) {
      try {
         sym = atype2symbol(getType(varsym@\loc));
         return appl(prod(label("parsed",Symbol::lex("Concrete")), [sym], {}), [
                   doParseFragment(sym, parts.args, rules)
                ])[@\loc=t@\loc];
      }
      catch ParseError(loc l) : {
        tm.messages += error("parse error in concrete syntax fragment `<for (p <- parts){><p><}>`", l);
        return orig; 
      }
   }

   M = visit(M) {
     case Tree t:appl(p:prod(label("concrete",sort(/Expression|Pattern/)), _, _),[Tree concrete])
          => appl(p, [parseFragment(concrete)])[@\loc=t@\loc]
   }
   
   return <M, tm>;
}


Tree doParseFragment(Symbol sym, list[Tree] parts, map[Symbol, Production] rules) {
   int index = 0;
   map[int, Tree] holes = ();
   
   // TODO: record shifts in source locations to relocate the locs of the resulting parse tree later
   str cleanPart(appl(prod(label("text",lex("ConcretePart")), _, _),[Tree stuff])) = "<stuff>";
   str cleanPart(appl(prod(label("lt",lex("ConcretePart")), _, _),_)) = "\<";
   str cleanPart(appl(prod(label("gt",lex("ConcretePart")), _, _),_)) = "\>";
   str cleanPart(appl(prod(label("bq",lex("ConcretePart")), _, _),_)) = "`";
   str cleanPart(appl(prod(label("bs",lex("ConcretePart")), _, _),_)) = "\\";
   str cleanPart(appl(prod(label("newline",lex("ConcretePart")), _, _),_)) = "\n";
   str cleanPart(appl(prod(label("hole",lex("ConcretePart")), _, _),[Tree hole])) {
      index += 1;
      holes[index] = hole;
      
      // here we weave in a unique and indexed sub-string for which a special rule
      // was added by the parser generator: 
      return "\u0000<atype2symbol(getType(hole.args[2]@\loc))>:<index>\u0000";
   }
   
   // first replace holes by indexed sub-strings
   str input = "<for (p <- parts) {><cleanPart(p)><}>";

   // now parse the input to get a Tree (or a ParseError is thrown)
   Tree tree = parse(type(sym, rules), input, |todo:///|);
   
   // TODO: source annotations in the tree should be updated/shifted according to
   // the things cleanPart did to the input..
   
   // replace the indexed woven sub-strings back with the original holes (wrapped in an easily labeled appl ($MetaHole) for
   // use by the code generator)
   // TODO: move the source annotations on the tree according to shifts recorded earlier
   tree = visit (tree) {
     case Tree v:appl(prod(Symbol::label("$MetaHole", Symbol varType), _, {\tag("holeType"(Symbol ht))}), [char(0),_,_,Tree i,char(0)]) => 
          appl(prod(label("$MetaHole", varType),[Symbol::sort("ConcreteHole")], {\tag("holeType"(ht))}), 
               [holes[toInt("<i>")]])[@\loc=v@\loc]
   }
   
   return tree;
}