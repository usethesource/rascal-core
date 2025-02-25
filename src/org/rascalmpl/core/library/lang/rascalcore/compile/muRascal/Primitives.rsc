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
module lang::rascalcore::compile::muRascal::Primitives

extend lang::rascalcore::check::ATypeBase;
extend lang::rascalcore::compile::muRascal::AST;

import List;
import Node;

data MuExp; 
   
/*
 *  Constant folding rules for muPrim
 *  See: lang::rascalcore::compile::Rascal2muRascal::RascalConstantCall for constant folding of selected calls
 */
 
bool allConstant(list[MuExp] args) { b = isEmpty(args) || all(a <- args, muCon(_) := a); return b; }

// Integer addition

MuExp muPrim("add", aint(), [aint(), aint()], [muCon(int n1), muCon(int n2)], loc src) = muCon(n1 + n2);

MuExp muPrim("add", aint(), [aint(), aint()], [muPrim("add", aint(), [aint(), aint()], [MuExp e, muCon(int n1)], loc src1), muCon(int n2)], loc src2) =
      muPrim("add", aint(), [aint(), aint()], [e, muCon(n1 + n2)], src2);

MuExp muPrim("add", aint(), [aint(), aint()], [muCon(int n1), muPrim("add", aint(), [aint(), aint()], [muCon(int n2), MuExp e], loc src1)], loc src2)  =
      muPrim("add", aint(), [aint(), aint()], [muCon(n1 + n2), e], src2);

// Integer subtraction
 
MuExp muPrim("subtract", aint(), [aint(), aint()], [muCon(int n1), muCon(int n2)], loc src) = muCon(n1 - n2);

MuExp muPrim("subtract", aint(), [aint(), aint()], [muPrim("subtract", aint(), [aint(), aint()], [MuExp e, muCon(int n1)], loc src1), muCon(int n2)], loc src2) =
      muPrim("subtract", aint(), [aint(), aint()], [e, muCon(n1 - n2)], src2);

MuExp muPrim("subtract", aint(), [aint(), aint()], [muCon(int n1), muPrim("subtract", aint(), [aint(), aint()], [muCon(int n2), MuExp e], loc src1)], loc src2)  =
      muPrim("subtract", aint(), [aint(), aint()], [muCon(n1 - n2), e], src2);      

// Unary minus 
MuExp muPrim("negative", aint(), [aint()], [muCon(int n)], loc src2)  = muCon(-n);
MuExp muPrim("negative", areal(), [areal()], [muCon(real r)], loc src2)  = muCon(-r);
MuExp muPrim("negative", arat(), [arat()], [muCon(rat r)], loc src2)  = muCon(-r);

// Integer multiplication

MuExp muPrim("product", aint(), [aint(), aint()], [muCon(int n1), muCon(int n2)], loc src) = muCon(n1 * n2);

MuExp muPrim("product", aint(), [aint(), aint()], [muPrim("product", aint(), [aint(), aint()], [MuExp e, muCon(int n1)], loc src1), muCon(int n2)], loc src2) =
      muPrim("product", aint(), [aint(), aint()], [e, muCon(n1 * n2)], src2);

MuExp muPrim("product", aint(), [aint(), aint()], [muCon(int n1), muPrim("product", aint(), [aint(), aint()], [muCon(int n2), MuExp e], loc src1)], loc src2)  =
      muPrim("product", aint(), [aint(), aint()], [muCon(n1 * n2), e], src2);

// String concatenation

MuExp muPrim("add", astr(), [astr(), astr()], [muCon(str s1), muCon(str s2)], loc src) = muCon(s1 + s2);

MuExp muPrim("add", astr(), [astr(), astr()], [muPrim("add", astr(), [astr(), astr()], [MuExp e, muCon(str s1)], loc src1), muCon(str s2)], loc src2) =
      muPrim("add", astr(), [astr(), astr()], [e, muCon(s1 + s2)], src2);

MuExp muPrim("add", astr(), [astr(), astr()], [muCon(str s1), muPrim("add", astr(), [astr(), astr()], [muCon(str s2), MuExp e], loc src1)], loc src2)  =
      muPrim("add", astr(), [astr(), astr()], [muCon(s1 + s2), e], src2);

// Create composite datatypes

MuExp muPrim("create_list", AType r, [AType elm], list[MuExp] args, loc src) = muCon([a | muCon(a) <- args]) 
      when allConstant(args);

MuExp muPrim("create_set", AType r, [AType e], list[MuExp] args, loc src) = muCon({a | muCon(a) <- args}) 
      when allConstant(args);
    
MuExp muPrim("create_map", AType r, [AType k, AType v], list[MuExp] args, loc src) {
      if(allConstant(args)){
            try {
                  return muCon((args[i].c : args[i+1].c | int i <- [0, 2 .. size(args)]));
            } catch _:;
      }
      fail;
}
           
MuExp muPrim("create_tuple", atuple(atypeList([*AType _])), [*AType _], [muCon(v1)], loc src) = muCon(<v1>);
MuExp muPrim("create_tuple", atuple(atypeList([*AType _])), [*AType _], [muCon(v1), muCon(v2)], loc src) = muCon(<v1, v2>);
MuExp muPrim("create_tuple", atuple(atypeList([*AType _])), [*AType _], [muCon(v1), muCon(v2), muCon(v3)], loc src) = muCon(<v1, v2, v3>);
MuExp muPrim("create_tuple", atuple(atypeList([*AType _])), [*AType _], [muCon(v1), muCon(v2), muCon(v3), muCon(v4)], loc src) = muCon(<v1, v2, v3, v4>);
MuExp muPrim("create_tuple", atuple(atypeList([*AType _])), [*AType _], [muCon(v1), muCon(v2), muCon(v3), muCon(v4), muCon(v5)], loc src) = muCon(<v1, v2, v3, v4, v5>);
MuExp muPrim("create_tuple", atuple(atypeList([*AType _])), [*AType _], [muCon(v1), muCon(v2), muCon(v3), muCon(v4), muCon(v5), muCon(v6)], loc src) = muCon(<v1, v2, v3, v4, v5, v6>);
MuExp muPrim("create_tuple", atuple(atypeList([*AType _])), [*AType _], [muCon(v1), muCon(v2), muCon(v3), muCon(v4), muCon(v5), muCon(v6), muCon(v7) ], loc src) = muCon(<v1, v2, v3, v4, v5, v6, v7>);
MuExp muPrim("create_tuple", atuple(atypeList([*AType _])), [*AType _], [muCon(v1), muCon(v2), muCon(v3), muCon(v4), muCon(v5), muCon(v6), muCon(v7), muCon(v8) ], loc src) = muCon(<v1, v2, v3, v4, v5, v6, v7, v8>);
MuExp muPrim("create_tuple", atuple(atypeList([*AType _])), [*AType _], [muCon(v1), muCon(v2), muCon(v3), muCon(v4), muCon(v5), muCon(v6), muCon(v7), muCon(v8), muCon(v9) ], loc src) = muCon(<v1, v2, v3, v4, v5, v6, v7, v8, v9>);
MuExp muPrim("create_tuple", atuple(atypeList([*AType _])), [*AType _], [muCon(v1), muCon(v2), muCon(v3), muCon(v4), muCon(v5), muCon(v6), muCon(v7), muCon(v8), muCon(v9),  muCon(v10) ], loc src) = muCon(<v1, v2, v3, v4, v5, v6, v7, v8, v9, v10>);

MuExp muPrim("create_node", AType r, [*AType _], [muCon(str name), *MuExp args, muKwpActuals(lrel[str kwpName, MuExp exp] kwpActuals)], loc src) 
    = isEmpty(kwpActuals) ? muCon(makeNode(name, [a | muCon(a) <- args])) 
                          : muCon(makeNode(name, [a | muCon(a) <- args], keywordParameters = (kwpName: exp | <kwpName, muCon(exp)> <- kwpActuals)))  
      when allConstant(args), allConstant(kwpActuals<1>);