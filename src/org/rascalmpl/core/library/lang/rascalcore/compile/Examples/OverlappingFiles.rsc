module lang::rascalcore::compile::Examples::OverlappingFiles

import IO;
import util::FileSystem;
import Relation;
import String;
import Set;

str asBaseFileName(loc l){
    path = l.path;
    n = findLast(path, "/");
    return n >= 0 ? path[n+1 ..] : path;
}

rel[str, str] getFiles(loc dir){
    dirPath = dir.path;
    ndirPath = size(dirPath);
    return { <asBaseFileName(f), f.path[ndirPath..]> | loc f <- find(dir, bool (loc l) { return !isDirectory(l); }) };
}

void main(){
    rascalDir = |file:///Users/paulklint/git/rascal/src/|;
    rascalCoreDir =  |file:///Users/paulklint/git/rascal-core/src/|;
    typepalDir =  |file:///Users/paulklint/git/typepal/src|;

    srcDir = rascalCoreDir;
    rascalFiles =  getFiles(rascalDir);
    srcFiles =  getFiles(srcDir);
   
    identical = range(rascalFiles) & range(srcFiles);
    println("<size(identical)> identical files:");
    iprintln(identical);

    // These files have the same name but cannot clash when merged
    approved = {"AST.rsc", "TestGrammars.rsc", "Characters.rsc", "CharactersTests.rsc", "Names.rsc", "Keywords.rsc",
    "Layout.rsc", "LayoutTests.rsc", "LiteralsTests.rsc", "Symbols.rsc", "Literals.rsc",
    "Attributes.rsc", "Tests.rsc", "ModuleInfo.rsc", "Names.java"};
    sameName = domain(rascalFiles) & domain(srcFiles) - approved;

    println("<size(sameName)> files with same name:");
    for(c <- sameName){
        println("<c>:<for(f <- rascalFiles[c]+srcFiles[c]){>
                '   <f><}>");

   }
}