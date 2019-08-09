package org.rascalmpl.core.library.lang.rascalcore.compile.runtime.utils;

import org.rascalmpl.core.library.lang.rascalcore.compile.runtime.ATypeFactory;
import org.rascalmpl.core.library.lang.rascalcore.compile.runtime.InternalCompilerError;
import org.rascalmpl.core.library.lang.rascalcore.compile.runtime.ToplevelType;
import org.rascalmpl.interpreter.types.DefaultRascalTypeVisitor;

import io.usethesource.vallang.IConstructor;
import io.usethesource.vallang.IListWriter;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.type.DefaultTypeVisitor;
import io.usethesource.vallang.type.Type;

public class Type2ATypeReifier extends ATypeFactory {
	
	protected static IString empty = $VF.string("");
	
	public static IConstructor reify2atype(final Type t, IString label){
		return t.accept(new DefaultTypeVisitor<IConstructor, RuntimeException>(null) {
			@Override
			public IConstructor visitVoid(Type type) throws RuntimeException {
				return label.length() == 0 ? avoid() : avoid(label);
			}
			@Override
			public IConstructor visitBool(Type type) throws RuntimeException {
				return label.length() == 0 ? abool() : abool(label);
			}
			@Override
			public IConstructor visitInteger(Type type) throws RuntimeException {
				return label.length() == 0 ? aint() : aint(label);
			}
			@Override
			public IConstructor visitReal(Type type) throws RuntimeException {
				return label.length() == 0 ? areal() : areal(label);
			}
			
			@Override
			public IConstructor visitRational(Type type) throws RuntimeException {
				return label.length() == 0 ? arat() : arat(label);
			}
			@Override
			public IConstructor visitNumber(Type type) throws RuntimeException {
				return label.length() == 0 ? anum() : anum(label);
			}
			@Override
			public IConstructor visitString(Type type) throws RuntimeException {
				return label.length() == 0 ? astr() : astr(label);
			}
			@Override
			public IConstructor visitSourceLocation(Type type) throws RuntimeException {
				return label.length() == 0 ? aloc() : aloc(label);
			}
			@Override
			public IConstructor visitDateTime(Type type) throws RuntimeException {
				return label.length() == 0 ? adatetime() : adatetime(label);
			}
			@Override
			public IConstructor visitList(Type type) throws RuntimeException {
				IConstructor elmType = reify2atype(type.getElementType(), empty);
				return label.length() == 0 ? alist(elmType) : alist(elmType, label);
			}
			
			// bag
			
			@Override
			public IConstructor visitSet(Type type) throws RuntimeException {
				IConstructor elmType = reify2atype(type.getElementType(), empty);
				return label.length() == 0 ? aset(elmType) : aset(elmType, label);
			}
			
			@Override
			public IConstructor visitTuple(Type type) throws RuntimeException {
				Type fieldTypes = type.getFieldTypes();
				String[] fieldNames = type.getFieldNames();
				int arity = type.getArity();
				IConstructor fieldATypes[] = new IConstructor[arity];
				for(int i = 0; i <arity; i++) {
					fieldATypes[i] = reify2atype(fieldTypes.getFieldType(i), fieldNames == null ? empty : $VF.string(fieldNames[i]));
				}
				return label.length() == 0 ? atuple(fieldATypes) : atuple(fieldATypes, label);
			}
			
			@Override
			public IConstructor visitMap(Type type) throws RuntimeException {
				String keyLabel = type.getKeyLabel();
				IConstructor keyType = reify2atype(type.getKeyType(), keyLabel.isEmpty() ? empty : $VF.string(keyLabel));
				
				String valLabel = type.getValueLabel();
				IConstructor valType = reify2atype(type.getValueType(), valLabel.isEmpty() ? empty : $VF.string(valLabel));
				return label.length() == 0 ? amap(keyType, valType) : amap(keyType, valType, label);
			}
			
			@Override
			public IConstructor visitParameter(Type type) throws RuntimeException {
				String pname = type.getName();
				IConstructor boundType = reify2atype(type.getBound(), empty);
				return aparameter($VF.string(pname), boundType);
			}
			
			@Override
			public IConstructor visitNode(Type type) throws RuntimeException {
				return label.length() == 0 ? anode() : anode(label); 
			}
			
			@Override
			public IConstructor visitAbstractData(Type type) throws RuntimeException {
				String adtName = t.getName();
				Type parameters = t.getTypeParameters();
				int arity = parameters.getArity();
				IListWriter w = $VF.listWriter();
				for(int i = 0; i <arity; i++) {
					w.append(reify2atype(parameters.getFieldType(i), empty));
				}
				return label.length() == 0 ? aadt($VF.string(adtName), w.done(), dataSyntax)
						                   : aadt($VF.string(adtName), w.done(), dataSyntax, label);
			}
			
			@Override
			public IConstructor visitConstructor(Type type) throws RuntimeException {
				String consName = t.getName();
				Type adt = t.getAbstractDataType();
				Type fields = type.getFieldTypes();
				int arity = fields.getArity();
				IListWriter w = $VF.listWriter();
				for(int i = 0; i <arity; i++) {
					w.append(reify2atype(fields.getFieldType(i), empty));
				}
				return acons(reify2atype(adt, empty), w.done(), $VF.listWriter().done(), $VF.string(consName));
			}
			
			@Override
			public IConstructor visitValue(Type type) throws RuntimeException {
				return avalue();
			}
			
			@Override
			public IConstructor visitAlias(Type type) throws RuntimeException {
				throw new InternalCompilerError("Alias not implemented: " + type);
			}
			
			@Override
			public IConstructor visitExternal(Type type) throws RuntimeException {
				throw new InternalCompilerError("External not implemented: " + type);
			}
		});
	}
	
	public static void main(String [] args) {
		IValue one = $VF.integer(1);
		IValue two = $VF.integer(2);
		System.err.println(reify2atype(one.getType(), empty));
		System.err.println(reify2atype(one.getType(), $VF.string("intLabel")));
		
		System.err.println(reify2atype($VF.set(one).getType(), empty));
		System.err.println(reify2atype($VF.set(one).getType(), $VF.string("set Label")));
		
		System.err.println(reify2atype($VF.tuple(one,two).getType(), empty));
		
		System.err.println(reify2atype($TF.tupleType($TF.integerType(), "abc"), empty));
		
		System.err.println(reify2atype($VF.list($VF.tuple(one,two)).getType(), empty));
		
		Type D = $TF.abstractDataType($TS, "D");
		Type D_d = $TF.constructor($TS, D, "d");
		
		System.err.println(reify2atype(D, empty));
		System.err.println(reify2atype(D_d, empty));
		
	}
	
	
}