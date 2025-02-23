module  lang::rascalcore::compile::Examples::B
  
import lang::rascalcore::compile::Examples::A;
        
void main() {
    X = X + 1; // <-- typecheck errors
}