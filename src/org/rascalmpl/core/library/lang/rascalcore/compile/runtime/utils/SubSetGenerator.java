package org.rascalmpl.core.library.lang.rascalcore.compile.runtime.utils;

import java.util.Iterator;

import org.rascalmpl.values.ValueFactoryFactory;

import io.usethesource.vallang.ISet;
import io.usethesource.vallang.ISetWriter;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.IValueFactory;

public class SubSetGenerator implements Iterable<ISet> {
	private ISet subject;
	
	public SubSetGenerator(ISet s){
		subject = s;
	}

	@Override
	public Iterator<ISet> iterator() {
		return new SubSetIterator(subject);
	}
}

class SubSetIterator implements Iterator<ISet> {
	private final static IValueFactory $VF = ValueFactoryFactory.getValueFactory();
	private long n;
	private final int len;
	private final long max;	// TODO: this only works for subsets upto 64 elements
	private final IValue[] setElems;
	
	SubSetIterator(ISet s){
		len = s.size();
		n = 0;
		max = (1L << len);
		setElems = new IValue[len];
		int i = 0;
		for(IValue elm : s){
			setElems[i++] = elm;
		}
	}

	@Override
	public boolean hasNext() {
		return n < max;
	}

	@Override
	public ISet next() {
		ISetWriter w = $VF.setWriter();
		for (int j = 0; j < len; j++) {
			// (1L<<j) is a number with jth bit 1 
			// so when we 'and' them with the 
			// subset number we get which numbers 
			// are present in the subset and which 
			// are not 
			if ((n & (1L << j)) > 0) 
				w.insert(setElems[j]);
		}
		n++;
		return w.done();
	}

}