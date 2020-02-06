module lang::rascalcore::package::Packager

import util::FileSystem;
import IO;
import String;
import ValueIO;

public void package(list[loc] srcs, loc bin, loc target) {
  packageSourceFiles(srcs, bin);  
  rewriteTypeFiles(srcs, bin, target);
}

void packageSourceFiles(list[loc] srcs, loc bin) {
  for (folder <- srcs, file <- find(folder, "rsc")) {
    copyFile(file, bin + relativize(file, folder));
  }
}

void rewriteTypeFiles(list[loc] srcs, loc bin, loc target) {
  for (file <- find(bin, "tpl")) {
     model = readBinaryValueFile(file);
     model = rewriteTypeModel(model, paths(srcs), target);
     writeBinaryValueFile(file, model);
  }
}

// map all files to their relative path within their respective source folder 
map[loc, str] paths(list[loc] srcs) 
  = (l:relativize(src, l) | src <- srcs, /file(loc l) <- crawl(src));

// we do not insist on a specific type here for forward/backward compatibility's sake
value rewriteTypeModel(value model, map[loc,str] paths, loc target) 
  = visit(model) {
      case loc l => target + paths[l]
  };

// compute a relative path of a file for a given base folder, if the file is indeed nested inside the given folder
str relativize(loc folder, loc file) = relativize(folder.path, file.path) 
  when folder.scheme == file.scheme,
       folder.authority == file.authority;
        
str relativize(str folder, str file:/^<folder>/) = file[size(folder)..];
