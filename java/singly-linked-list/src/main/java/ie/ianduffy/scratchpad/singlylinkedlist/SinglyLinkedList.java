package ie.ianduffy.scratchpad.singlylinkedlist;

import lombok.Getter;
import lombok.Setter;

public class SinglyLinkedList<T> {

    private Node<T> head;
    private int size;

    public SinglyLinkedList() {
        this.head = null;
        this.size = 0;
    }

    public void add(T item) {
        Node<T> nodeToAdd = new Node<>(item);
        if (head == null) head = nodeToAdd;
        else {
            Node<T> reference = head;
            while (reference.getPointer() != null) reference = reference.getPointer();
            reference.setPointer(nodeToAdd);
        }
        size++;
    }

    public T get(int index) {
        if (index < 0 || index >= size) throw new IndexOutOfBoundsException();
        Node<T> reference = head;
        for (int i = 0; i < index; i++) {
            reference = reference.getPointer();
        }
        return reference.getData();
    }

    public void remove(int index) {
        if (index < 0 || index >= size) throw new IndexOutOfBoundsException();
        Node<T> reference = head;
        Node<T> nodeBeforeNodeToBeDeleted = head;
        for (int i = 0; i < index; i++) {
            nodeBeforeNodeToBeDeleted = reference;
            reference = reference.getPointer();
        }

        if (reference == head) {
            head = head.getPointer();
        } else {
            nodeBeforeNodeToBeDeleted.setPointer(reference.getPointer());
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
        private Node<T> pointer;

        public Node(T data) {
            this.data = data;
        }
    }
}
