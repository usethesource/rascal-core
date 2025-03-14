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
module lang::rascalcore::compile::muRascal2Java::Primitives

//import lang::rascalcore::check::AType;
//import lang::rascalcore::check::ATypeUtils;

extend lang::rascalcore::check::CheckerCommon;

import lang::rascalcore::compile::muRascal2Java::JGenie;
import lang::rascalcore::compile::muRascal::AST;
import lang::rascalcore::compile::muRascal2Java::CodeGen;
import lang::rascalcore::compile::muRascal2Java::Conversions;

import List;
import Node;
import String;

// Rascal primitives

default list[str] transPrimArgs(str prim, AType result, list[AType] details, list[MuExp] exps, JGenie jg){
    return  [details[i]? ? transWithCast(details[i], exps[i], jg) : trans(exps[i], jg) | int i <- index(exps)];
}    

set[str] arithTypes     = {"aint", "areal", "arat", "anum"};
set[str] setTypes       = {"aset", "arel"};
set[str] listTypes      = {"alist", "alrel"};
set[str] setOrListTypes = setTypes + listTypes;

//bool isArithType(AType t) = getName(t) in arithTypes;

bool isSetOnlyType(AType t) = getName(t) == "aset";
bool isRelOnlyType(AType t) = getName(t) == "arel";
bool isSetLikeType(AType t) = getName(t) in setTypes;

bool isListOnlyType(AType t) = getName(t) == "alist";
bool isListRelOnlyType(AType t) = getName(t) == "alrel";
bool isListLikeType(AType t) = getName(t) in listTypes;

bool isSetOrListLikeType(AType t) = getName(t) in setOrListTypes;

//bool isTupleType(AType t) = getName(t) == "atuple";
//bool isMapType(AType t) = getName(t) == "amap";
//bool isNodeType(AType t) = getName(t) == "anode";
//bool isADTType(AType t) = getName(t) == "acons";


// ---- add -------------------------------------------------------------------

JCode transPrim("add", AType r, [AType a, AType b], [str x, str y], JGenie jg)             = "$<getOuter(a)>_add_<getOuter(b)>(<x>,<y>)"  
                                                                                             when isArithAType(a) && isArithAType(b) || 
                                                                                                  isStrAType(a) && isStrAType(b) ||
                                                                                                  isLocAType(a) && isStrAType(b) ||
                                                                                                  isDateTimeAType(a) && isDateTimeAType(b) ||
                                                                                                  isTupleAType(a) && isTupleAType(b) ||
                                                                                                  isListLikeType(a) && isListLikeType(b) ||
                                                                                                  isSetLikeType(a) && isSetLikeType(b) ||
                                                                                                  isMapAType(a) && isMapAType(b);
                                                                                                  
JCode transPrim("add", AType r, [AType a, AType b, AType c], [str x, str y, str z], JGenie jg)          
                                                                                         = "$astr_add_astr(<x>,$astr_add_astr(<y>,<z>))"  when isStrAType(a), isStrAType(b), isStrAType(c);
JCode transPrim("add", AType r, [AType a, AType b], [str x, str y], JGenie jg)           = "$alist_add_elm(<x>,<y>)"      when isListLikeType(a), !isListLikeType(b);
JCode transPrim("add", AType r, [AType a, AType b], [str x, str y], JGenie jg)           = "$elm_add_alist(<x>,<y>)"      when !isListLikeType(a), isListLikeType(b);

JCode transPrim("add", AType r, [AType a, AType b], [str x, str y], JGenie jg)           = "$aset_add_elm(<x>,<y>)"       when isSetLikeType(a), !isSetLikeType(b);
JCode transPrim("add", AType r, [AType a, AType b], [str x, str y], JGenie jg)           = "$elm_add_aset(<x>,<y>)"       when !isSetLikeType(a), isSetLikeType(b);

// ---- add_..._writer -------------------------------------------------------

list[str] transPrimArgs(str prim, AType r, list[AType] atypes, list[MuExp] exps, JGenie jg) = [ trans(exp, jg) | exp <- exps ] 
                                                                                              when prim in {"add_list_writer", "add_set_writer", "add_map_writer", "add_string_writer"};

JCode transPrim("add_list_writer", AType r, list[AType] atypes, [str w, str v], JGenie jg)        = "<w>.append(<v>);\n"; 
JCode transPrim("add_set_writer", AType r, list[AType] atypes, [str w, str v], JGenie jg)         = "<w>.insert(<v>);\n"; 
JCode transPrim("add_map_writer", AType r, list[AType] atypes, [str w, str k, str v], JGenie jg)  = "<w>.insert($VF.tuple(<k>, <v>));\n"; 
JCode transPrim("add_string_writer", AType r, [AType a], [str w, str s], JGenie jg)      = "<w>.write(<s>.getValue());\n" when a == astr();
JCode transPrim("add_string_writer", AType r, [AType a], [str w, str s], JGenie jg)      = "<w>.write(<s>.toString());\n" when a != astr();

// ---- assert_fails ----------------------------------------------------------

JCode transPrim("assert_fails", AType r, [astr()], [str x], JGenie jg)                   = "$assert_fails(<x>)";

// ---- close_..._writer ------------------------------------------------------

list[str] transPrimArgs(str prim, AType r, list[AType] atypes, list[MuExp] exps, JGenie jg) = [ trans(exp, jg) | exp <- exps ] 
                                                                                              when prim in {"close_list_writer", "close_set_writer", "close_map_writer", "close_string_writer"};

JCode transPrim("close_list_writer", AType r, [_], [str w], JGenie jg)                    = "<w>.done()";
JCode transPrim("close_set_writer", AType r, [_], [str w], JGenie jg)                     = "<w>.done()";   
JCode transPrim("close_map_writer", AType r, [_], [str w], JGenie jg)                     = "<w>.done()"; 
JCode transPrim("close_string_writer", AType r, [_], [str w], JGenie jg)                  = "<w>.toString()";  

// ---- compose ---------------------------------------------------------------

JCode transPrim("compose", AType r, [AType a, AType b], [str x, str y], JGenie jg)       = "<x>.asRelation().compose(<y>.asRelation())"
                                                                                           when isSetOrListLikeType(a), isSetOrListLikeType(b);
JCode transPrim("compose", AType r, [AType a, AType b], [str x, str y], JGenie jg)       = "<x>.compose(<y>)"
                                                                                           when isMapAType(a), isMapAType(b);

// ---- create_... ------------------------------------------------------------

//list[str] transPrimArgs(str prim, AType r, list[AType] atypes, list[MuExp] exps, JGenie jg)                          
//                             newArgs = [];
//    for(arg <- args){
//        if(<true, auxVars, pre, [flatArg]> := flattenArgs(args) && !isEmpty(pre)){
//            newArgs +=  muValueBlock(getType(arg), auxVars + pre + flatArg);
//        } else {
//            newArgs += arg;
//        }
//    }
//    if(newArgs == args){
//        fail;
//    } else {
//        return muPrim(op, result, details, newArgs, src);
//    }                                                         
// TODO reconsider arg [AType a]
JCode transPrim("create_list", AType r, [AType a], list[str] args, JGenie jg)             = "$VF.list(<intercalate(", ", args)>)";
JCode transPrim("create_set", AType r, [AType a], list[str] args, JGenie jg)              = "$VF.set(<intercalate(", ", args)>)";
JCode transPrim("create_map", AType r, [AType a, AType b], list[str] args, JGenie jg)     = "$buildMap(<intercalate(", ", args)>)";
JCode transPrim("create_loc", aloc(), [AType a], [str uri], JGenie jg)                    = "$create_aloc(<uri>)";
JCode transPrim("create_loc_with_offset", aloc(), [aloc(), aint(), aint()], [str l, str off, str len], JGenie jg)
                                                                                          = "$create_aloc_with_offset(<intercalate(", ", [l, castArg(aint(), off), castArg(aint(), len)])>)";
JCode transPrim("create_loc_with_offset_and_begin_end", aloc(), [aloc(),aint(), aint(),_,_], [str l, str off, str len, str bgn, str end], JGenie jg)
                                                                                          = "$create_aloc_with_offset_and_begin_end(<intercalate(", ", [l, castArg(aint(), off), castArg(aint(), len), bgn, end])>)";

JCode transPrim("create_tuple", AType r, list[AType] argTypes, list[str] args, JGenie jg) = "$VF.tuple(<intercalate(", ", args)>)";

list[str] transPrimArgs("create_node", AType r, list[AType] atypes, list[MuExp] exps, JGenie jg) 
                                                                                          = [ trans(exp, jg) | exp <- exps ];
JCode transPrim("create_node", AType r, list[AType] argTypes, [str name, *str args, str kwpMap], JGenie jg)
                                                                                          = "$VF.node(<castArg(astr(), name)>.getValue(), new IValue[] { <intercalate(", ", args)> }, <kwpMap>)";
                                                                                          
list[str] transPrimArgs("create_reifiedType", AType r, list[AType] atypes, list[MuExp] exps, JGenie jg) 
                                                                                          = [ trans(exp, jg) | exp <- exps ];
JCode transPrim("create_reifiedType", AType r, [AType a, AType b], [str sym, str defs], JGenie jg)    
                                                                                          = "$reifiedAType((IConstructor) <sym>, <defs>)";

// ---- divide ----------------------------------------------------------------
 
JCode transPrim("divide", AType r, [AType l, aparameter(_, AType bnd)], [str x, str y], JGenie jg)  
                                                                                         = transPrim("divide", r, [l, bnd], [x, y], jg);
JCode transPrim("divide", AType r, [aparameter(_, AType bnd), AType rgt], [str x, str y], JGenie jg)  
                                                                                         = transPrim("divide", r, [bnd,rgt], [x, y], jg);

JCode transPrim("divide", AType r, [AType a, AType b], [str x, str y], JGenie jg)         = "$<getOuter(a)>_divide_<getOuter(b)>(<x>,<y>)"     when isArithAType(a), isArithAType(b);


// ---- equal -----------------------------------------------------------------

JCode transPrim("equal", abool(), [AType a, AType b], [str x, str y], JGenie jg)         =  "$equal(<x>, <y>)";

// ---- field_project ---------------------------------------------------------

JCode transPrim("field_project", AType r, [AType a], [str x, *str args], JGenie jg)      = "$atuple_field_project((ITuple)<x>, <intercalate(", ", args)>)"
                                                                                           when isTupleAType(a);
JCode transPrim("field_project", AType r, [AType a], [str x, *str args], JGenie jg)      = "$amap_field_project((IMap)<x>, <intercalate(", ", args)>)"
                                                                                           when isMapAType(a);
JCode transPrim("field_project", AType r, [AType a], [str x, *str args], JGenie jg)      = "$arel_field_project((ISet)<x>, <intercalate(", ", args)>)"
                                                                                           when isRelOnlyType(a);
JCode transPrim("field_project", AType r, [AType a], [str x, *str args], JGenie jg)      = "$alrel_field_project((IList)<x>, <intercalate(", ", args)>)"
                                                                                           when isListRelOnlyType(a);

// ---- get_node_name ---------------------------------------------------------
JCode transPrim("get_anode_name", astr(), [anode(_)], [str x], JGenie jg)                = "$anode_get_name((INode)<x>)";

// ---- guarded_field_project -------------------------------------------------

JCode transPrim("guarded_field_project", AType r, [AType a], [str x, *str args], JGenie jg)      = "$guarded_atuple_field_project(<x>, <intercalate(", ", args)>)"
                                                                                                   when isTupleAType(a);
JCode transPrim("guarded_field_project", AType r, [AType a], [str x, *str args], JGenie jg)      = "$guarded_amap_field_project(<x>, <intercalate(", ", args)>)"
                                                                                                    when isMapAType(a);
JCode transPrim("guarded_field_project", AType r, [AType a], [str x, *str args], JGenie jg)      = "$guarded_arel_field_project(<x>, <intercalate(", ", args)>)"
                                                                                                    when isRelOnlyType(a);
JCode transPrim("guarded_field_project", AType r, [AType a], [str x, *str args], JGenie jg)      = "$guarded_alrel_field_project(<x>, <intercalate(", ", args)>)"
                                                                                                    when isListRelOnlyType(a);

// ---- greater ---------------------------------------------------------------

JCode transPrim("greater", abool(), [abool(), abool()], [str x, str y], JGenie jg)      = "$abool_lessequal_abool(<x>,<y>).not()"; 
JCode transPrim("greater", AType r, [AType a, AType b], [str x, str y], JGenie jg)      = "$<getOuter(a)>_lessequal_<getOuter(b)>(<x>,<y>).not()"     when isArithAType(a), isArithAType(b);
JCode transPrim("greater", abool(), [astr(), astr()], [str x, str y], JGenie jg)        = "$astr_lessequal_astr(<x>,<y>).not()"; 
JCode transPrim("greater", abool(), [adatetime(), adatetime()], [str x, str y], JGenie jg)         
                                                                                        = "$adatetime_lessequal_adatetime(<x>,<y>).not()"; 
JCode transPrim("greater", abool(), [aloc(), aloc()], [str x, str y], JGenie jg)        = "$aloc_lessequal_aloc(<x>,<y>).not()"; 
JCode transPrim("greater", abool(), [AType a, AType b], [str x, str y], JGenie jg)      = "$atuple_lessequal_atuple(<x>,<y>).not()"      when isTupleAType(a), isTupleAType(b);
JCode transPrim("greater", abool(), [AType a, AType b], [str x, str y], JGenie jg)      = "$anode_lessequal_anode(<x>,<y>).not()"        when isNodeAType(a), isNodeAType(b);
JCode transPrim("greater", abool(), [AType a, AType b], [str x, str y], JGenie jg)      = "$alist_lessequal_alist(<x>,<y>).not()"        when isListLikeType(a), isListLikeType(b);
JCode transPrim("greater", abool(), [AType a, AType b], [str x, str y], JGenie jg)      = "$aset_lessequal_aset(<x>,<y>).not()"          when isSetLikeType(a), isSetLikeType(b);
JCode transPrim("greater", abool(), [AType a, AType b], [str x, str y], JGenie jg)      = "$amap_lessequal_amap(<x>,<y>).not()"          when isMapAType(a), isMapAType(b);
JCode transPrim("greater", abool(), [AType a, AType b], [str x, str y], JGenie jg)      = "$lessequal(<x>,<y>).not()"                    when isValueAType(a), isValueAType(b);


// ---- greaterequal ----------------------------------------------------------

JCode transPrim("greaterequal", abool(), [abool(), abool()], [str x, str y], JGenie jg)  = "$abool_less_abool(<x>,<y>).not()"; 
//JCode transPrim("greaterequal", abool(), [AType a, AType b], [str x, str y], JGenie jg)  = "$alist_less_alist(<x>,<y>).not()"            when isListLikeType(a), isListLikeType(b); 
JCode transPrim("greaterequal", AType r, [AType a, AType b], [str x, str y], JGenie jg)  = "$<getOuter(a)>_less_<getOuter(b)>(<x>,<y>).not()"     when isArithAType(a), isArithAType(b);
JCode transPrim("greaterequal", abool(), [astr(), astr()], [str x, str y], JGenie jg)    = "$astr_less_astr(<x>,<y>).not()"; 
JCode transPrim("greaterequal", abool(), [adatetime(), adatetime()], [str x, str y], JGenie jg)         
                                                                                         = "$adatetime_less_adatetime(<x>,<y>).not()"; 
JCode transPrim("greaterequal", abool(), [aloc(), aloc()], [str x, str y], JGenie jg)    = "$aloc_less_aloc(<x>,<y>).not()"; 
JCode transPrim("greaterequal", abool(), [AType a, AType b], [str x, str y], JGenie jg)  = "$atuple_less_atuple(<x>,<y>).not()"          when isTupleAType(a), isTupleAType(b); 
JCode transPrim("greaterequal", abool(), [AType a, AType b], [str x, str y], JGenie jg)  = "$anode_less_anode(<x>,<y>).not()"            when isNodeAType(a), isNodeAType(b); 
JCode transPrim("greaterequal", abool(), [AType a, AType b], [str x, str y], JGenie jg)  = "$alist_less_alist(<x>,<y>).not()"            when isListLikeType(a), isListLikeType(b); 
JCode transPrim("greaterequal", abool(), [AType a, AType b], [str x, str y], JGenie jg)  = "$aset_less_aset(<x>,<y>).not()"              when isSetLikeType(a), isSetLikeType(b); 
JCode transPrim("greaterequal", abool(), [AType a, AType b], [str x, str y], JGenie jg)  = "$amap_less_amap(<x>,<y>).not()"              when isMapAType(a), isMapAType(b);  
JCode transPrim("greaterequal", abool(), [AType a, AType b], [str x, str y], JGenie jg)  = "$less(<x>,<y>).not()"                        when isValueAType(a), isValueAType(b);  

// has
// has_field
// ---- in --------------------------------------------------------------------

JCode transPrim("in", abool(), [AType a, AType b],  [str x, str y], JGenie jg)           = "$VF.bool(<y>.contains(<x>))"                when isSetOrListLikeType(b);
JCode transPrim("in", abool(), [AType a, AType b],  [str x, str y], JGenie jg)           = "$VF.bool(<y>.containsKey(<x>))"             when isMapAType(b);

// ---- intersect -------------------------------------------------------------

JCode transPrim("intersect", AType r, [AType a, AType b], [ str x, str y], JGenie jg)    = "<x>.intersect(<y>)"                         when isListLikeType(a), isListLikeType(b);
JCode transPrim("intersect", AType r, [AType a, AType b], [ str x, str y], JGenie jg)    = "<x>.intersect(<y>)"                         when isSetLikeType(a), isSetLikeType(b);
JCode transPrim("intersect", AType r, [AType a, AType b], [ str x, str y], JGenie jg)    = "<x>.common(<y>)"                            when isMapAType(a), isMapAType(b);

// ---- is --------------------------------------------------------------------

JCode transPrim("is", abool(), [AType a], [str x, str y], JGenie jg)                     = "$is(<x>,<y>)";

// ---- guarded_subscript -----------------------------------------------------

list[str] transPrimArgs("guarded_subscript", AType r, [AType a, aint()], [MuExp x, MuExp y], JGenie jg)  
                                                                                                = [ transWithCast(a,x,jg), trans2NativeInt(y,jg) ] 
                                                                                                  when isListOnlyType(a) || (a == astr()) || isTupleAType(a) || 
                                                                                                       isNodeAType(a) || isADTAType(a); 
                                                                                       
JCode transPrim("guarded_subscript", AType r, [astr(), aint()], [str x, str y], JGenie jg)      = "$guarded_astr_subscript_int(<x>,<y>)";
JCode transPrim("guarded_subscript", AType r, [AType a, aint()], [str x, str y], JGenie jg)     = "$guarded_atuple_subscript_int(<x>,<y>)" when isTupleAType(a);
JCode transPrim("guarded_subscript", AType r, [AType a, aint()], [str x, str y], JGenie jg)     = "$guarded_anode_subscript_int(<x>,<y>)" when isNodeAType(a);
JCode transPrim("guarded_subscript", AType r, [AType a, aint()], [str x, str y], JGenie jg)     = "$guarded_aadt_subscript_int(<x>,<y>)" when isADTAType(a);
JCode transPrim("guarded_subscript", AType r, [AType a, AType b], [ str x, str y], JGenie jg)   
                                                                                                = "$guarded_list_subscript(<x>,<y>)" when isListOnlyType(a);
JCode transPrim("guarded_subscript", AType r, [AType a, AType b], [str x, str y], JGenie jg)    = "$guarded_map_subscript(<x>,<y>)" when isMapAType(a);

JCode transPrim("guarded_subscript", AType r, [AType a, *AType types], [str x, *str args], JGenie jg) {
    if(arel(atypeList(list[AType] elemTypes)) := a){
        n = size(elemTypes);
        if(n == 2 && !jg.isWildCard(args[0])){
            return isSetLikeType(types[0])  ? "$guarded_arel2_subscript1_aset(<x>,<args[0]>))"
                                            : "$guarded_arel_subscript1_noset(<x>,<args[0]>)" ;
        } else if(size(args) == 1 && !jg.isWildCard(args[0]) && !isSetLikeType(types[0])){
            return "$guarded_arel_subscript1_noset(<x>,<args[0]>)";
        }
        return "$guarded_arel_subscript(<x>,<makeIndex(args)>,<makeIndexDescr(types, args, jg)>)";    
    } else if(alrel(atypeList(list[AType] elemTypes)) := a){
        n = size(elemTypes);
        if(n == 2 && !jg.isWildCard(args[0])){
            return isSetLikeType(types[0])  ? "$guarded_alrel2_subscript1_aset(<x>,<args[0]>))"
                                            : "$guarded_alrel_subscript1_noset(<x>,<args[0]>)" ;
        } else if(size(args) == 1 && !jg.isWildCard(args[0]) && !isSetLikeType(types[0])){
            return "$guarded_alrel_subscript1_noset(<x>,<args[0]>)";
        }
        return "$guarded_alrel_subscript(<x>,<makeIndex(args)>,<makeIndexDescr(types, args, jg)>)";    
    } else
        fail;
}   
                                                                                       
// ---- join ------------------------------------------------------------------

JCode transPrim("join", AType r, [AType a, AType b], [str x, str y], JGenie jg)          = "$alist_product_alist(<x>,<y>)" when isListOnlyType(a), isListOnlyType(b);
JCode transPrim("join", AType r, [AType a, AType b], [str x, str y], JGenie jg)          = "$alist_join_alrel(<x>,<y>)" when isListOnlyType(a), isListRelOnlyType(b);
JCode transPrim("join", AType r, [AType a, AType b], [str x, str y], JGenie jg)          = "$alrel_join_alrel(<x>,<y>)" when isListRelOnlyType(a), isListRelOnlyType(b);
JCode transPrim("join", AType r, [AType a, AType b], [str x, str y], JGenie jg)          = "$alrel_join_alist(<x>,<y>)" when isListRelOnlyType(a), isListOnlyType(b);

JCode transPrim("join", AType r, [AType a, AType b], [str x, str y], JGenie jg)          = "$aset_product_aset(<x>,<y>)" when isSetOnlyType(a), isSetOnlyType(b);
JCode transPrim("join", AType r, [AType a, AType b], [str x, str y], JGenie jg)          = "$aset_join_arel(<x>,<y>)" when isSetOnlyType(a), isRelOnlyType(b);
JCode transPrim("join", AType r, [AType a, AType b], [str x, str y], JGenie jg)          = "$arel_join_arel(<x>,<y>)" when isRelOnlyType(a), isRelOnlyType(b);
JCode transPrim("join", AType r, [AType a, AType b], [str x, str y], JGenie jg)          = "$arel_join_aset(<x>,<y>)" when isRelOnlyType(a), isSetOnlyType(b);

// ----less -------------------------------------------------------------------

JCode transPrim("less", abool(), [abool(), abool()], [str x, str y], JGenie jg)          = "$abool_less_abool(<x>,<y>)"; 
JCode transPrim("less", AType r, [AType a, AType b], [str x, str y], JGenie jg)          = "$<getOuter(a)>_less_<getOuter(b)>(<x>,<y>)"     when isArithAType(a), isArithAType(b);
JCode transPrim("less", abool(), [astr(), astr()], [str x, str y], JGenie jg)            = "$astr_less_astr(<x>,<y>)";  
JCode transPrim("less", abool(), [adatetime(), adatetime()], [str x, str y], JGenie jg)  = "$adatetime_less_adatetime(<x>,<y>)"; 
JCode transPrim("less", abool(), [aloc(), aloc()], [str x, str y], JGenie jg)            = "$aloc_less_aloc(<x>,<y>)"; 
JCode transPrim("less", abool(), [AType a, AType b], [str x, str y], JGenie jg)          = "$atuple_less_atuple(<x>,<y>)"  when isTupleAType(a), isTupleAType(b); 
JCode transPrim("less", abool(), [AType a, AType b], [str x, str y], JGenie jg)          = "$anode_less_anode(<x>,<y>)" when isNodeAType(a), isNodeAType(b); 
JCode transPrim("less", abool(), [AType a, AType b], [str x, str y], JGenie jg)          = "$alist_less_alist(<x>,<y>)"  when isListLikeType(a), isListLikeType(b);    
JCode transPrim("less", abool(), [AType a, AType b], [str x, str y], JGenie jg)          = "$aset_less_aset(<x>,<y>)" when isSetLikeType(a), isSetLikeType(b);  
JCode transPrim("less", abool(), [AType a, AType b], [str x, str y], JGenie jg)          = "$amap_less_amap(<x>,<y>)" when isMapAType(a), isMapAType(b); 
JCode transPrim("less", abool(), [AType a, AType b], [str x, str y], JGenie jg)          = "$less(<x>,<y>)" when isValueAType(a), isValueAType(b); 

// adt

// ---- lessequal -------------------------------------------------------------

JCode transPrim("lessequal", abool(), [abool(), abool()], [str x, str y], JGenie jg)     = "$abool_lessequal_abool(<x>,<y>)"; 
JCode transPrim("lessequal", AType r, [AType a, AType b], [str x, str y], JGenie jg)     = "$<getOuter(a)>_lessequal_<getOuter(b)>(<x>,<y>)"     when isArithAType(a), isArithAType(b);
JCode transPrim("lessequal", abool(), [astr(), astr()], [str x, str y], JGenie jg)       = "$astr_lessequal_astr(<x>,<y>)";  
JCode transPrim("lessequal", abool(), [adatetime(), adatetime()], [str x, str y], JGenie jg)  
                                                                                         = "$adatetime_lessequal_adatetime(<x>,<y>)"; 
JCode transPrim("lessequal", abool(), [aloc(), aloc()], [str x, str y], JGenie jg)       = "$aloc_lessequal_aloc(<x>,<y>)"; 
JCode transPrim("lessequal", abool(), [AType a, AType b], [str x, str y], JGenie jg)     = "$atuple_lessequal_atuple(<x>,<y>)" when isTupleAType(a), isTupleAType(b); 
JCode transPrim("lessequal", abool(), [AType a, AType b], [str x, str y], JGenie jg)     = "$anode_lessequal_anode(<x>,<y>)"  when isNodeAType(a), isNodeAType(b); 
JCode transPrim("lessequal", abool(), [AType a, AType b], [str x, str y], JGenie jg)     = "$alist_lessequal_alist(<x>,<y>)"  when isListLikeType(a), isListLikeType(b);     
JCode transPrim("lessequal", abool(), [AType a, AType b], [str x, str y], JGenie jg)     = "$aset_lessequal_aset(<x>,<y>)" when isSetLikeType(a), isSetLikeType(b); 
JCode transPrim("lessequal", abool(), [AType a, AType b], [str x, str y], JGenie jg)     = "$amap_lessequal_amap(<x>,<y>)"  when isMapAType(a), isMapAType(b);   
JCode transPrim("lessequal", abool(), [AType a, AType b], [str x, str y], JGenie jg)     = "$lessequal(<x>,<y>)" when isValueAType(a), isValueAType(b);

// ---- modulo ----------------------------------------------------------------
JCode transPrim("mod", aint(), [aint(), aint()], [str x, str y], JGenie jg)              = "<x>.mod(<y>)";

// ---- negative --------------------------------------------------------------

JCode transPrim("negative", AType r, [AType a], [str x], JGenie jg)                      = "<x>.negate()"            when isArithAType(r);

// nonterminal-get-arg

JCode transPrim("nonterminal-get-arg", AType r, [AType a, aint()], [str s, str idx], JGenie jg)
                                                                                        = "$nonterminal_get_arg(((ITree)<s>), <idx>.intValue())";
//non_negative

// ---- not -------------------------------------------------------------------

list[str] transPrimArgs("not", abool(), [abool()], [MuExp x], JGenie jg)                 = [producesNativeBool(x) ? "$VF.bool(<trans(x, jg)>)" : trans(x, jg) ];
           
JCode transPrim("not", abool(), [abool()], [str x], JGenie jg)                           = "(<castArg(abool(),x)>).not()";

// ---- notequal --------------------------------------------------------------

JCode transPrim("notequal", abool(), [AType a, AType b], [str x, str y], JGenie jg)      = "$equal(<x>,<y>).not()";

// ---- notin -----------------------------------------------------------------

JCode transPrim("notin", abool(), [AType a, AType b],  [str x, str y], JGenie jg)        = "$VF.bool(!(<y>).contains(<x>))"       when isSetOrListLikeType(b);
JCode transPrim("notin", abool(), [AType a, AType b],  [str x, str y], JGenie jg)        = "$VF.bool(!(<y>).containsKey(<x>))"    when isMapAType(b);
                                                                                                            
// ---- open_..._writer -------------------------------------------------------

JCode transPrim("open_list_writer", AType r, [], [], JGenie jg)                          = "$VF.listWriter()";
JCode transPrim("open_set_writer", AType r, [], [], JGenie jg)                           = "$VF.setWriter();\n";   
JCode transPrim("open_map_writer", AType r, [], [], JGenie jg)                           = "$VF.mapWriter()";  
JCode transPrim("open_string_writer", AType r, [], [], JGenie jg)                        = "new StringWriter()";

// ---- parse -----------------------------------------------------------------

JCode transPrim("parse", AType r, [avalue(), astr(), aloc()], [str x, str y, str z], JGenie jg) = castArg(r, "$parse(<x>, <y>, <z>)");

// ---- product ---------------------------------------------------------------

JCode transPrim("product", AType r, [AType a, AType b], [str x, str y], JGenie jg)       = "$<getOuter(a)>_product_<getOuter(b)>(<x>,<y>)"     when isArithAType(a), isArithAType(b);
JCode transPrim("product", AType r, [AType a, AType b], [str x, str y], JGenie jg)       = "$alist_product_alist(<x>,<y>)"   when isListLikeType(a), isListLikeType(b);
JCode transPrim("product", AType r, [AType a, AType b], [str x, str y], JGenie jg)       = "$aset_product_aset(<x>,<y>)"     when isSetLikeType(a), isSetLikeType(b);

// project
// ---- remainder -------------------------------------------------------------

JCode transPrim("remainder", AType r, [aint(), aint()], [str x, str y], JGenie jg)       = "<x>.remainder(<y>)";

// ---- slice -----------------------------------------------------------------

list[str] transSliceArgs(MuExp first, MuExp second, MuExp end, JGenie jg) =  [ first == muNoValue() ? "null" : trans2NativeInt(first,jg),
                                                                               second == muNoValue() ? "null" : trans2NativeInt(second,jg), 
                                                                               end == muNoValue() ? "null" : trans2NativeInt(end,jg) ];

list[str] transPrimArgs("slice", AType r, [AType a], [MuExp x, MuExp first, MuExp second, MuExp end], JGenie jg) = [ trans(x,jg), *transSliceArgs(first, second, end, jg)];
                                                                                   

JCode transPrim("slice", AType r, [astr()], [str x, str first, str second, str end], JGenie jg)   = "$astr_slice(<castArg(astr(), x)>, <first>, <second>, <end>)";
JCode transPrim("slice", AType r, [AType a], [str x, str first, str second, str end], JGenie jg)  = "$alist_slice(<castArg(a, x)>, <first>, <second>, <end>)" when isListLikeType(a);
JCode transPrim("slice", AType r, [AType a], [str x, str first, str second, str end], JGenie jg)  = "$anode_slice(<castArg(a, x)>, <first>, <second>, <end>)" when isNodeAType(a);
JCode transPrim("slice", AType r, [\iter(aadt(_,[], lexicalSyntax()))], [str x, str first, str second, str end], JGenie jg)  
                                                                                         = "$lexical_slice(<x>,<first>, <second>, <end>)";
JCode transPrim("slice", AType r, [\iter(aadt(_,[], contextFreeSyntax()))], [str x,  str first, str second, str end], JGenie jg)  
                                                                                         = "$concrete_slice(<x>,<first>, <second>, <end>)";

JCode transPrim("slice", AType r, [\iter-seps(aadt(_,[], lexicalSyntax()), list[AType] separators)], [str x, str first, str second, str end], JGenie jg)  
                                                                                         = "$lexical_slice_seps(<x>,<first>, <second>, <end>)";
JCode transPrim("slice", AType r, [\iter-seps(aadt(_,[], contextFreeSyntax()), list[AType] separators)], [str x, str first, str second, str end], JGenie jg)  
                                                                                         = "$concrete_slice_seps(<x>,<first>, <second>, <end>)";
                                                                                                                                                                                                                                                                           
JCode transPrim("slice", AType r, [\iter-star(aadt(_,[], lexicalSyntax()))], [str x, str first, str second, str end], JGenie jg)  
                                                                                         = "$lexical_slice(<x>, <first>, <second>, <end>)";

JCode transPrim("slice", AType r, [\iter-star(aadt(_,[], contextFreeSyntax()))], [str x, str first, str second, str end], JGenie jg)  
                                                                                         = "$concrete_slice(<x>, <first>, <second>, <end>)";
                                                                                         
JCode transPrim("slice", AType r, [\iter-star-seps(aadt(_,[], lexicalSyntax()), list[AType] separators)], [str x, str first, str second, str end], JGenie jg)  
                                                                                         = "$lexical_slice_seps(<x>,<first>, <second>, <end>)";
JCode transPrim("slice", AType r, [\iter-star-seps(aadt(_,[], contextFreeSyntax()), list[AType] separators)], [str x, str first, str second, str end], JGenie jg)  
                                                                                         = "$concrete_slice_seps(<x>,<first>, <second>, <end>)";

// ---- list slice operations -------------------------------------------------

// str_slice_replace
list[str] transPrimArgs("astr_slice_replace", AType r, [AType a], [MuExp x, MuExp first, MuExp second, MuExp end, MuExp repl], JGenie jg)
                                                                                                 = [ trans(x,jg), *transSliceArgs(first, second, end, jg), trans(repl, jg)];
 
JCode transPrim("astr_slice_replace", AType r, [AType a], [str x, str first, str second, str end, str repl], JGenie jg) = "$astr_slice_replace(<x>, <first>, <second>, <end>, <repl>)";

// anode_slice_replace
list[str] transPrimArgs("anode_slice_replace", AType r, [AType a], [MuExp x, MuExp first, MuExp second, MuExp end, MuExp repl], JGenie jg)
                                                                                                 = [ trans(x,jg), *transSliceArgs(first, second, end, jg), trans(repl, jg)];
 
JCode transPrim("anode_slice_replace", AType r, [AType a], [str x, str first, str second, str end, str repl], JGenie jg) = "$anode_slice_replace(<x>, <first>, <second>, <end>, <repl>)";


// list_slice_replace
list[str] transPrimArgs("alist_slice_replace", AType r, [AType a], [MuExp x, MuExp first, MuExp second, MuExp end, MuExp repl], JGenie jg)
                                                                                                 = [ trans(x,jg), *transSliceArgs(first, second, end, jg), trans(repl, jg)];
 
JCode transPrim("alist_slice_replace", AType r, [AType a], [str x, str first, str second, str end, str repl], JGenie jg) = "$alist_slice_replace(<x>, <first>, <second>, <end>, <repl>)";


//// list_slice_replace
//list[str] transPrimArgs("alist_slice_replace", AType r, [AType a], [MuExp x, MuExp first, MuExp second, MuExp end, MuExp repl], JGenie jg)
//                                                                                                 = [ trans(x,jg), *transSliceArgs(first, second, end, jg), trans(repl, jg)];
 
//JCode transPrim("alist_slice_replace", AType r, [AType a], [str x, str first, str second, str end, str repl], JGenie jg) = "$alist_slice_replace(<x>, <first>, <second>, <end>, <repl>)";

// list_slice_add
list[str] transPrimArgs("alist_slice_add", AType r, [AType a], [MuExp x, MuExp first, MuExp second, MuExp end, MuExp repl], JGenie jg)
                                                                                                 = [ trans(x,jg), *transSliceArgs(first, second, end, jg), trans(repl, jg)];
 
JCode transPrim("alist_slice_add", AType r, [AType a], [str x, str first, str second, str end, str repl], JGenie jg) = "$alist_slice_add(<x>, <first>, <second>, <end>, <repl>)";

// list_slice_subtract
list[str] transPrimArgs("alist_slice_subtract", AType r, [AType a], [MuExp x, MuExp first, MuExp second, MuExp end, MuExp repl], JGenie jg)
                                                                                                 = [ trans(x,jg), *transSliceArgs(first, second, end, jg), trans(repl, jg)];
 
JCode transPrim("alist_slice_subtract", AType r, [AType a], [str x, str first, str second, str end, str repl], JGenie jg) = "$alist_slice_subtract(<x>, <first>, <second>, <end>, <repl>)";

// list_slice_product
list[str] transPrimArgs("alist_slice_product", AType r, [AType a], [MuExp x, MuExp first, MuExp second, MuExp end, MuExp repl], JGenie jg)
                                                                                                 = [ trans(x,jg), *transSliceArgs(first, second, end, jg), trans(repl, jg)];
 
JCode transPrim("alist_slice_product", AType r, [AType a], [str x, str first, str second, str end, str repl], JGenie jg) = "$alist_slice_product(<x>, <first>, <second>, <end>, <repl>)";

// list_slice_divide
list[str] transPrimArgs("alist_slice_divide", AType r, [AType a], [MuExp x, MuExp first, MuExp second, MuExp end, MuExp repl], JGenie jg)
                                                                                                 = [ trans(x,jg), *transSliceArgs(first, second, end, jg), trans(repl, jg)];
 
JCode transPrim("alist_slice_divide", AType r, [AType a], [str x, str first, str second, str end, str repl], JGenie jg) = "$alist_slice_divide(<x>, <first>, <second>, <end>, <repl>)";

// list_slice_intersect
list[str] transPrimArgs("alist_slice_intersect", AType r, [AType a], [MuExp x, MuExp first, MuExp second, MuExp end, MuExp repl], JGenie jg)
                                                                                                 = [ trans(x,jg), *transSliceArgs(first, second, end, jg), trans(repl, jg)];
 
JCode transPrim("alist_slice_intersect", AType r, [AType a], [str x, str first, str second, str end, str repl], JGenie jg) = "$alist_slice_intersect(<x>, <first>, <second>, <end>, <repl>)";

// ---- splice ----------------------------------------------------------------
list[str] transPrimArgs("splice_list", AType r, [AType a, AType b], [MuExp x, MuExp y], JGenie jg) = [trans(x, jg), trans(y, jg)];
JCode transPrim("splice_list", AType r, [AType a, AType b],  [str w, str v], JGenie jg)    = "$listwriter_splice(<w>,<v>);\n";

list[str] transPrimArgs("splice_set", AType r, [AType a, AType b], [MuExp x, MuExp y], JGenie jg) = [trans(x, jg), trans(y, jg)];
JCode transPrim("splice_set", AType r, [AType a, AType b],  [str w, str v], JGenie jg)     = "$setwriter_splice(<w>,<v>);\n";
// TODO: concrete cases
    
// str_escape_for_regexp
JCode transPrim("str_escape_for_regexp", astr(), [AType a], [str x], JGenie jg)             = "$str_escape_for_regexp(<a == astr() ? "<x>" : "<x>.toString()">)";

// ---- subscript -------------------------------------------------------------
    
list[str] transPrimArgs("subscript", AType r, [AType a, aint()], [MuExp x, MuExp y], JGenie jg)  
                                                                                = [ transWithCast(a,x,jg), trans2NativeInt(y,jg) ] 
                                                                                  when isListOnlyType(a) || isStrAType(a) || isTupleAType(a) || 
                                                                                       isNodeAType(a) || isADTAType(a) || isSyntaxType(a) || isValueAType(a);
//list[str] transPrimArgs("subscript", AType r, [AType a, aint()], [MuExp x, MuExp y], JGenie jg) 
//                                                                                = [ transWithCast(a,x,jg), trans2NativeInt(y,jg) ] 
//                                                                                  when isSyntaxType(a);



JCode transPrim("subscript", AType r, [\iter(aadt(_,[], lexicalSyntax())), aint()], [str x, str y], JGenie jg)  
                                                                                         = "$lexical_subscript(<x>,<y>)";
JCode transPrim("subscript", AType r, [\iter(\achar-class(_)), aint()], [str x, str y], JGenie jg)  
                                                                                         = "$lexical_subscript(<x>,<y>)";
                                                                                         
JCode transPrim("subscript", AType r, [\iter(aadt(_,[], contextFreeSyntax())), aint()], [str x, str y], JGenie jg)  
                                                                                         = "$concrete_subscript(<x>,<y>)";

JCode transPrim("subscript", AType r, [\iter-seps(aadt(_,[], lexicalSyntax()), list[AType] separators), aint()], [str x, str y], JGenie jg)  
                                                                                         = "$lexical_subscript_seps(<x>,<y>)";
JCode transPrim("subscript", AType r, [\iter-seps(\achar-class(_), list[AType] separators), aint()], [str x, str y], JGenie jg)  
                                                                                         = "$lexical_subscript_seps(<x>,<y>)";

JCode transPrim("subscript", AType r, [\iter-seps(aadt(_,[], contextFreeSyntax()), list[AType] separators), aint()], [str x, str y], JGenie jg)  
                                                                                         = "$concrete_subscript_seps(<x>,<y>)";
                                                                                                                                                                                                                                                                           
JCode transPrim("subscript", AType r, [\iter-star(aadt(_,[], lexicalSyntax())), aint()], [str x, str y], JGenie jg)  
                                                                                         = "$lexical_subscript(<x>,<y>)";
JCode transPrim("subscript", AType r, [\iter-star(\achar-class(_)), aint()], [str x, str y], JGenie jg)  
                                                                                         = "$lexical_subscript(<x>,<y>)";

JCode transPrim("subscript", AType r, [\iter-star(aadt(_,[], contextFreeSyntax())), aint()], [str x, str y], JGenie jg)  
                                                                                         = "$concrete_subscript(<x>,<y>)";
                                                                                         
JCode transPrim("subscript", AType r, [\iter-star-seps(aadt(_,[], lexicalSyntax()), list[AType] separators), aint()], [str x, str y], JGenie jg)  
                                                                                         = "$lexical_subscript_seps(<x>,<y>)";
JCode transPrim("subscript", AType r, [\iter-star-seps(\achar-class(_), list[AType] separators), aint()], [str x, str y], JGenie jg)  
                                                                                         = "$lexical_subscript_seps(<x>,<y>)";

JCode transPrim("subscript", AType r, [\iter-star-seps(aadt(_,[], contextFreeSyntax()), list[AType] separators), aint()], [str x, str y], JGenie jg)  
                                                                                         = "$concrete_subscript_seps(<x>,<y>)";


JCode transPrim("subscript", AType r, [AType a, aint()], [str x, str y], JGenie jg)      = "$subscript_int(<x>,<y>)" when isValueAType(a) || isNonTerminalAType(a) ;
JCode transPrim("subscript", AType r, [astr(), aint()], [str x, str y], JGenie jg)       = "$astr_subscript_int(<x>,<y>)";
JCode transPrim("subscript", AType r, [AType a, aint()], [str x, str y], JGenie jg)      = "$atuple_subscript_int(<x>,<y>)" when isTupleAType(a);

JCode transPrim("subscript", AType r, [AType a, aint()], [str x, str y], JGenie jg)      = "$aadt_subscript_int(<x>,<y>)" when isADTAType(a);

JCode transPrim("subscript", AType r, [AType a, aint()], [str x, str y], JGenie jg)      = "$anode_subscript_int(<x>,<y>)" when isNodeAType(a);

JCode transPrim("subscript", AType r, [AType a, AType b], [str x, str y], JGenie jg)     = "$alist_subscript_int(<x>,<y>)" when isListOnlyType(a);
JCode transPrim("subscript", AType r, [AType a, AType b], [str x, str y], JGenie jg)     = "$amap_subscript(<x>,<y>)" when isMapAType(a);

default JCode transPrim("subscript", AType r, [AType a, *AType types], [str x, *str args], JGenie jg) {
    if(arel(atypeList(list[AType] elemTypes)) := a){
        n = size(elemTypes);
        if(n == 2 && !jg.isWildCard(args[0])){
            return isSetLikeType(types[0])  ? "$arel2_subscript1_aset(<x>,<args[0]>)"
                                            : "$arel_subscript1_noset(<x>,<args[0]>)" ;
        } else if(size(args) == 1 && !jg.isWildCard(args[0]) && !isSetLikeType(types[0])){
            return "$arel_subscript1_noset(<x>,<args[0]>)";
        }
        return "$arel_subscript(<x>,<makeIndex(args)>,<makeIndexDescr(types, args, jg)>)";    
    } else if(alrel(atypeList(list[AType] elemTypes)) := a){
        n = size(elemTypes);
        if(n == 2 && !jg.isWildCard(args[0])){
            return isSetLikeType(types[0])  ? "$alrel2_subscript1_aset(<x>,<args[0]>)"
                                            : "$alrel_subscript1_noset(<x>,<args[0]>)" ;
        } else if(size(args) == 1 && !jg.isWildCard(args[0]) && !isSetLikeType(types[0])){
            return "$alrel_subscript1_noset(<x>,<args[0]>)";
        }
        return "$alrel_subscript(<x>,<makeIndex(args)>,<makeIndexDescr(types, args, jg)>)";  
    } else if(isOverloadedAType(a)){
        return "$subscript_int(<x>,<args[0]>)";
    } else {
        fail;
    }
}      

JCode makeIndex(list[str] idx)
    = "new IValue[]{<intercalate(", ", idx)>}";

//  return a subscript descriptor: an array with integers for each index: 0: noset, 1: set, 2: wildcard
JCode makeIndexDescr(list[AType] types, list[str] idx, JGenie jg)
    = "new int[]{<intercalate(", ", [jg.isWildCard(idx[i]) ? 2 : isSetLikeType(types[i]) ? 1 : 0 | i <- index(idx)])>}";
    
// TODO: concrete cases
 
// ---- subtract --------------------------------------------------------------

JCode transPrim("subtract", AType r, [AType a, AType b], [str x, str y], JGenie jg)      = "((<atype2javatype(r)>) <x>.subtract(<y>))" when isArithAType(a), isArithAType(b);
JCode transPrim("subtract", AType r, [AType a, AType b], [str x, str y], JGenie jg)      = "<x>.subtract(<y>)"      when isSetOrListLikeType(a), isSetOrListLikeType(b), !equivalent(getElementType(a), b);
JCode transPrim("subtract", AType r, [AType a, AType b], [str x, str y], JGenie jg)      = "<x>.delete(<y>)"        when isSetOrListLikeType(a), !isSetOrListLikeType(b);
JCode transPrim("subtract", AType r, [AType a, AType b], [str x, str y], JGenie jg)      = "<x>.remove(<y>)"        when isMapAType(a), isMapAType(b);

// ---- delete ----------------------------------------------------------------
JCode transPrim("delete", AType r, [AType a, AType b], [str x, str y], JGenie jg)        = "<x>.delete(<y>)";

// ---- subset ----------------------------------------------------------------

JCode transPrim("subset", AType r, [AType a, AType b], [str x, str y], JGenie jg)        = "<x>.isSubsetOf(<y>)"        when isSetOrListLikeType(a), isSetOrListLikeType(b);

// ---- subsets ---------------------------------------------------------------

JCode transPrim("subsets", AType r, [AType a], [str x], JGenie jg)                       = "new SubSetGenerator(<x>)" when isSetLikeType(a);

// ---- transitive_closure ----------------------------------------------------

JCode transPrim("transitive_closure", AType r, [AType a], [str x], JGenie jg)            = "<x>.asRelation().closure()";

// ---- transitive_reflexive_closure ------------------------------------------

JCode transPrim("transitive_reflexive_closure", AType r, [AType a], [str x], JGenie jg)  = "<x>.asRelation().closureStar()";


// ---- toIString --------------------------------------------------------------

JCode transPrim("toIString", astr(), [AType a], [str x], JGenie jg) = "$toIString(<x>)";

//JCode transPrim("typeOf", AType r, [AType a], [str x], JGenie jg)                       = "$typeOf(<x>)";

// ---- update ----------------------------------------------------------------

list[str] transPrimArgs("update", AType r, [AType a], [MuExp x, MuExp y, MuExp z], JGenie jg)  
                                                                                         = [ trans(x,jg), trans2NativeInt(y,jg), trans(z, jg) ] 
                                                                                           when isListLikeType(a) || (a == astr()) || isTupleAType(a) || isNodeAType(a) || isLocAType(a);
list[str] transPrimArgs("update", AType r, [AType a], [MuExp x, MuExp y, MuExp z], JGenie jg)  
                                                                                         = [ trans(x,jg), trans2NativeStr(y,jg), trans(z, jg) ]
                                                                                           when isADTAType(a);
                                                                                
JCode transPrim("update", AType r, [AType a], [str x, str y, str z], JGenie jg)         = "$alist_update(<y>,<z>,<castArg(a,x)>)"    /* order */
                                                                                          when isListLikeType(a);
JCode transPrim("update", AType r, [AType a], [str x, str y, str z], JGenie jg)         = "$amap_update(<y>,<z>, <castArg(a,x)>)"    /* order */
                                                                                          when isMapAType(a);
JCode transPrim("update", AType r, [AType a], [str x, str y, str z], JGenie jg)         = "$atuple_update(<y>,<z>,<castArg(a,x)>)"  /* order */
                                                                                          when isTupleAType(a);