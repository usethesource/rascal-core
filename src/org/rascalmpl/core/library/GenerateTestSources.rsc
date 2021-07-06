module GenerateTestSources

import IO;
import String;
import Set;
import util::Reflective;
import lang::rascalcore::compile::Compile;
import util::FileSystem;
import util::Monitor;
import util::Benchmark;

PathConfig manualTestConfig= pathConfig(bin=|project://rascal-core/generated/compiled_rascal|);

void main(list[str] args) = generateTestSources(manualTestConfig);

void generateTestSources(PathConfig pcfg) {
   testConfig = pathConfig(
     bin=pcfg.bin,
     srcs=[
       |std:///|
     ]);
   map[str,int] durations = ();
     
   println("PathConfig for generating test sources:\n");
   iprintln(testConfig);

   println(readFile(|lib://rascal/META-INF/MANIFEST.MF|));

   libraryModules = ["Boolean", 
                     "DateTime", 
                     "Exception", 
                     /*"Grammar",*/ 
                     "IO", 
                     "List", 
                     "ListRelation", 
                     "Location", 
                     "Map", 
                     "Message", 
                     "Node", 
                     "ParseTree", 
                     "Prelude", 
                     "Relation", 
                     "Set", "String", 
                     /*"Traversal",*/
                     "Type", 
                     "ValueIO",
                     "analysis::graphs::Graph", 
                     "util::FileSystem", 
                     "util::Reflective",
                     "util::UUID",
                     "analysis::m3::AST", 
                     "analysis::m3::Core", 
                     "analysis::m3::FlowGraph", 
                     "analysis::m3::Registry",
                     "analysis::m3::TypeSymbol"];  
   
   for (m <- libraryModules) {
     safeCompile(m, testConfig, (int d) { durations[m] = d; });
   }
     
   testFolder = |std:///lang/rascal/tests|;
   
   testModules = [ replaceAll(file[extension=""].path[1..], "/", "::") 
                 | loc file <- find(testFolder, "rsc"),     // all Rascal source files
                 /\/concrete\// !:= file.path ];            // excluding all concrete tests (not yet implemented in compiler)
   
   //testModules = [ "lang::rascal::tests::basic::Equality"];
   
   for (m <- testModules) {
      safeCompile(m, testConfig, (int d) { durations[m] = d; });
   }
   
   //iprintln(sort({ <m, durations[m] / 1000000000> | m <- durations}, bool (<_,int i>, <_, int j>) { return i < j; }));
}

void testCompile(str \module) {
  int duration = 0;
  safeCompile(\module, manualTestConfig, (int d) { duration = d; return; });
  println("compile of <\module> lasted <duration / (1000*1000*1000.0)> seconds");
}

void safeCompile(str \module, PathConfig pcfg, void (int duration) measure) {
   try {
     measure(cpuTime(() {    
       compile(\module, pcfg);
     }));
   }
   catch value exception: {
     println("Something unexpected went wrong during test source generation for <\module>:
             '    <exception>");  
   }
}