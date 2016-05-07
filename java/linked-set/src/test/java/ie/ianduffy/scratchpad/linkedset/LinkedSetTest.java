package ie.ianduffy.scratchpad.linkedset;

import org.junit.Test;

public class LinkedSetTest {

    @Test
    public void testAddingToALinkedList() {
        LinkedSet<Integer> list = new LinkedSet<>();

        assert list.add(10) == true;
        assert list.add(20) == true;
        assert list.add(10) == false;

        assert list.get(0) == 10;
        assert list.get(1) == 20;
        assert list.size() == 2;

    }

    @Test
    public void testRemovingSingleElementFromALinkedList() {
        LinkedSet<Integer> list = new LinkedSet<>();

        assert list.add(10) == true;
        assert list.add(10) == false;

        assert list.get(0) == 10;
        assert list.size() == 1;

        list.remove(0);
        assert list.size() == 0;
    }

    @Test
    public void testRemovingElementsFromALinkedList() {
        LinkedSet<Integer> list = new LinkedSet<>();

        assert list.add(10) == true;
        assert list.add(20) == true;
        assert list.add(30) == true;
        assert list.add(10) == false;

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
