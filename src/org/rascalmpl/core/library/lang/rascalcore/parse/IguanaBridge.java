package org.rascalmpl.core.library.lang.rascalcore.parse;

import org.iguana.grammar.Grammar;
import org.iguana.grammar.GrammarGraph;
import org.iguana.grammar.GrammarGraphBuilder;
import org.iguana.iggy.GrammarBuilder;
import org.iguana.parser.IguanaParser;
import org.iguana.util.Configuration;

import io.usethesource.vallang.IConstructor;
import io.usethesource.vallang.IMap;
import io.usethesource.vallang.ISourceLocation;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.IValueFactory;

public class IguanaBridge {
	private IValueFactory vf;

	public IguanaBridge(IValueFactory vf) {
		this.vf = vf;
	}
	
	
	public IConstructor parse(IValue grammar, ISourceLocation src) {
		Grammar.Builder builder = Grammar.builder();

		IMap definitions = (IMap) ((IConstructor) grammar).get("definitions");
		IConstructor start = (IConstructor) ((IConstructor) grammar).get("symbol");
		
		for (IValue def : definitions) {
			define(builder, def);
		}
		
		Configuration.Builder configBuilder = new Configuration.Builder();
		
		IguanaParser parser = new IguanaParser(builder.build());
		
		parser.getParserTree()
		return null;
	}


	private void define(Grammar.Builder builder, IValue def) {
		// TODO Auto-generated method stub
		
	}
}
