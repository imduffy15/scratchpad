package ie.ianduffy.scratchpad.doublylinkedlist;

import lombok.Getter;
import lombok.Setter;

public class DoublyLinkedList<T> {

	private Node<T> head;
	private Node<T> tail;

	private int size;

	public DoublyLinkedList() {

	}

	public void add(T item) {
        Node<T> nodeToAdd = new Node<>(item, tail);
        if (head == null) {
            head = nodeToAdd;
        } else {
            tail.setNext(nodeToAdd);
        }
        tail = nodeToAdd;
        size++;
    }
	public T get(int index) {
		if (index < 0 || index > size)
			throw new IndexOutOfBoundsException();

		Node<T> headReference = head;
		for (int i = 0; i < index; i++) {
			headReference = headReference.getNext();
		}

		return headReference.getData();
	}

	public void remove(int index) {
		if (index < 0 || index > size)
			throw new IndexOutOfBoundsException();

		Node<T> headReference = head;
		for (int i = 0; i < index; i++) {
			headReference = headReference.getNext();
		}

		if (headReference == head) {
			head = head.getNext();
		} else {
			headReference.getPrevious().setNext(headReference.getNext());
		}

		size--;
	}

	public int size() {
		return size;
	}

	private class Node<T> {
		@Getter
		private T data;

		@Getter
		@Setter
		private Node<T> next = null;

		@Getter
		private Node<T> previous = null;

		public Node(T data, Node<T> previous) {
			this.data = data;
			this.previous = previous;
		}
	}
}
