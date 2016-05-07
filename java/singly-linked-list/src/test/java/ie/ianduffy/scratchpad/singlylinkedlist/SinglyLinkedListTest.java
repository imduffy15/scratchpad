package ie.ianduffy.scratchpad.singlylinkedlist;

import org.junit.Test;

public class SinglyLinkedListTest {


    @Test
    public void testAddingToALinkedList() {
        SinglyLinkedList<Integer> list = new SinglyLinkedList<>();

        list.add(10);
        list.add(20);

        assert list.get(0) == 10;
        assert list.get(1) == 20;
        assert list.size() == 2;

    }

    @Test
    public void testRemovingSingleElementFromALinkedList() {
        SinglyLinkedList<Integer> list = new SinglyLinkedList<>();

        list.add(10);

        assert list.get(0) == 10;
        assert list.size() == 1;

        list.remove(0);
        assert list.size() == 0;
    }

    @Test
    public void testRemovingElementsFromALinkedList() {
        SinglyLinkedList<Integer> list = new SinglyLinkedList<>();

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
