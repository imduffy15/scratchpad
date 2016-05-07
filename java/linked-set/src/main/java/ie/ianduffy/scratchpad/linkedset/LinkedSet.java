package ie.ianduffy.scratchpad.linkedset;

import lombok.Getter;
import lombok.Setter;

public class LinkedSet<T> {

    private Node<T> head;
    private int size;

    public LinkedSet() {
        this.head = null;
        this.size = 0;
    }

    public boolean contains(T item) {
        if (head == null)
            return false;

        Node<T> headReference = head;

        while (headReference != null) {
            if (headReference.getData().equals(item))
                return true;
            headReference = headReference.getPointer();
        }

        return false;
    }

    public boolean add(T item) {
        if (contains(item)) return false;
        Node<T> nodeToAdd = new Node<>(item);
        if (head == null) head = nodeToAdd;
        else {
            Node<T> reference = head;
            while (reference.getPointer() != null) reference = reference.getPointer();
            reference.setPointer(nodeToAdd);
        }
        size++;
        return true;
    }

    public T get(int index) {
        if (index < 0 || index >= size)
            throw new IndexOutOfBoundsException();
        Node<T> reference = head;
        for (int i = 0; i < index; i++) {
            reference = reference.getPointer();
        }
        return reference.getData();
    }

    public void remove(int index) {
        if (index < 0 || index >= size)
            throw new IndexOutOfBoundsException();
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
