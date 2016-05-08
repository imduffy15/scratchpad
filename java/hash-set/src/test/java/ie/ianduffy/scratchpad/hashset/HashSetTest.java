package ie.ianduffy.scratchpad.hashset;

import org.junit.Test;

public class HashSetTest {

	@Test
    public void canAddToAHashSet() {
        HashSet<Integer> hashSet = new HashSet<>(2);

        for (int i = 0; i < 999; i++) {
            hashSet.add((int) (Math.random() * 100));
        }

        assert hashSet.size() == 100;
    }
	@Test
    public void canCheckIfAHashSetContainsElementX() {
        HashSet<Integer> hashSet = new HashSet<>(2);

        hashSet.add(10);

        assert hashSet.contains(10) == true;
        assert hashSet.contains(1) == false;
    }
}
