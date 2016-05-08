package ie.ianduffy.scratchpad.stack;

import java.util.ArrayList;
import java.util.List;

public class Stack<T> {

	private int size = 0;
	private List<T> list = new ArrayList();

	public Stack() {

	}

	public Boolean isEmpty() {
		return size == 0;
	}

	public void push(T item) {
		list.add(item);
		size++;
	}

	public T pop() {
		if (isEmpty())
			return null;
		size--;
		return list.get(size);
	}
}
