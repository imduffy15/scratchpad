package ie.ianduffy.scratchpad.doublylinkedlist;

import org.junit.Test;

public class DoublyLinkedListTest {


    @Test
    public void testAddingToALinkedList() {
        DoublyLinkedList<Integer> list = new DoublyLinkedList<>();

        list.add(10);
        list.add(20);

        assert list.get(0) == 10;
        assert list.get(1) == 20;
        assert list.size() == 2;

    }

    @Test
    public void testRemovingSingleElementFromALinkedList() {
        DoublyLinkedList<Integer> list = new DoublyLinkedList<>();

        list.add(10);

        assert list.get(0) == 10;
        assert list.size() == 1;

        list.remove(0);
        assert list.size() == 0;
    }

    @Test
    public void testRemovingElementsFromALinkedList() {
        DoublyLinkedList<Integer> list = new DoublyLinkedList<>();

        list.add(10);
        list.add(20);
        list.add(30);

        assert list.get(0) == 10;
        assert list.get(1) == 20;
        assert list.get(2) == 30;
        assert list.size() == 3;

        list.remove(1);
        list.remove(0);
        assert list.size() == 1;
        assert list.get(0) == 30;
    }
}
