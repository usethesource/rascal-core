@bootstrapParser
module lang::rascalcore::check::NameUtils

import lang::rascal::\syntax::Rascal;

import List;
import String;

public str prettyPrintName(QualifiedName qn){
    if ((QualifiedName)`<{Name "::"}+ nl>` := qn) { 
        nameParts = [ prettyPrintName(n) | n <- nl ];
        return intercalate("::", nameParts);
       //return replaceAll("<qn>", "\\", "");
    }
    throw "Unexpected syntax for qualified name: <qn>";
}

public str prettyPrintName(Name nm){ 
    return prettyPrintName("<nm>");
}

public str prettyPrintName(str nm){
    return replaceFirst(nm, "\\", "");
}

public str prettyPrintBaseName(QualifiedName qn){
    if ((QualifiedName)`<{Name "::"}+ nl>` := qn) { 
        nameParts = [ n | n <- nl ];
        return prettyPrintName(nameParts[-1]);
        //return replaceFirst("<nameParts[-1]>", "\\", "");
    }
    throw "Unexpected syntax for qualified name: <qn>";
}

public str prettyPrintBaseName(Name nm){ 
    return prettyPrintName(nm);
   // return replaceFirst("<nm>", "\\", "");
}

public tuple[str qualifier, str base] splitQualifiedName(QualifiedName qn){
    if ((QualifiedName)`<{Name "::"}+ nl>` := qn) { 
        //nameParts = [ replaceFirst("<n>", "\\", "") | n <- nl ];
        nameParts = [ prettyPrintName(n) | n <- nl ];
        return size(nameParts) > 1 ? <intercalate("::", nameParts[0 .. -1]), nameParts[-1]> : <"", nameParts[0]>;
    }
    throw "Unexpected syntax for qualified name: <qn>";
}