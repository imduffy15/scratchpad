package ie.ianduffy.scratchpad.hashset;

import org.junit.Test;

public class HashSetTest {

    @Test
    public void canPushToAndPopFromTheStack() {
        Stack<Integer> stack = new Stack<>();

        stack.push(10);
        stack.push(20);
        stack.push(30);
        stack.push(40);

        assert stack.pop() == 40;
        assert stack.pop() == 30;
        assert stack.pop() == 20;
        assert stack.pop() == 10;
    }
}
