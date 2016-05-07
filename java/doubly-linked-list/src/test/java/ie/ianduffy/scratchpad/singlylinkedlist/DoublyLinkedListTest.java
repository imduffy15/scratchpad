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
    public void testRemovingFirstElementFromALinkedList() {
        DoublyLinkedList<Integer> list = new DoublyLinkedList<>();

        list.add(10);
        list.add(20);

        assert list.get(0) == 10;
        assert list.get(1) == 20;
        assert list.size() == 2;

        list.remove(0);
        assert list.size() == 1;
        assert list.get(0) == 20;
    }
}
