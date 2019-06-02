module lang::rascalcore::parse::Parser

import ParseTree;

@javaClass{org.rascalmpl.core.library.lang.rascalcore.parse.IguanaBridge}
java &T <: Tree parse(&T <: Tree grammar, loc input);