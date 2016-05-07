package ie.ianduffy.scratchpad.binarytree;

import lombok.Getter;
import lombok.Setter;

public class BinaryTree<T extends Comparable> {

    private Node<T> root = null;
    private int size = 0;

    public BinaryTree() {

    }

    public boolean add(T item) {
        int originalSize = size;
        root = add(root, item);
        return (size > originalSize);
    }

    public T min() {
        if (root == null)
            return null;
        Node<T> reference = root;
        while (reference.getLeft() != null) {
            reference = reference.getLeft();
        }
        return reference.getData();
    }

    public T max() {
        if (root == null)
            return null;
        Node<T> reference = root;
        while (reference.getRight() != null) {
            reference = reference.getRight();
        }
        return reference.getData();
    }

    private Node<T> add(Node<T> root, T item) {
        if (root == null) {
            size++;
            return new Node<T>(item, null, null);
        } else if (root.getData().compareTo(item) > 0) {
            root.setLeft(add(root.getLeft(), item));
            return root;
        } else if (root.getData().compareTo(item) < 0) {
            root.setRight(add(root.getRight(), item));
            return root;
        }
        return root;
    }

    public int height() {
        return height(root);
    }

    private int height(Node<T> root) {
        if (root == null)
            return 0;
        return 1 + Math.max(height(root.getLeft()), height(root.getRight()));
    }

    public boolean contains(T item) {
        return contains(root, item);
    }

    private boolean contains(Node<T> root, T item) {
        if (root == null) {
            return false;
        } else if (root.getData().compareTo(item) > 0) {
            return contains(root.getLeft(), item);
        } else if (root.getData().compareTo(item) < 0) {
            return contains(root.getRight(), item);
        } else {
            return true;
        }
    }

    public int size() {
        return size;
    }

    private class Node<T> {
        @Getter
        private T data;

        @Getter
        @Setter
        private Node<T> left;

        @Getter
        @Setter
        private Node<T> right;

        public Node(T data, Node<T> left, Node<T> right) {
            this.data = data;
            this.left = left;
            this.right = right;
        }
    }
}
