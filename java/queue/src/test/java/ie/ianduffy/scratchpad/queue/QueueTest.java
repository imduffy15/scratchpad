package ie.ianduffy.scratchpad.queue;

import org.junit.Test;

public class QueueTest {

	@Test
    public void canEnqAndDeqFromAQueue() {
        Queue<Integer> queue = new Queue<>(3);

        queue.enq(10);
        queue.enq(20);
        queue.enq(30);

        boolean thrown = false;
        try {
            queue.enq(40);
        } catch (IndexOutOfBoundsException e) {
            thrown = true;
        }

        assert thrown;

        assert queue.deq() == 10;
        queue.enq(10);
        assert queue.deq() == 20;
        assert queue.deq() == 30;
        assert queue.deq() == 10;
    }
}
