package ie.ianduffy.scratchpad.queue;

public class Queue<T> {

    private int size = 0;
    private int head = 0;
    private int tail = 0;

    private T[] queue;

    public Queue(int size) {
        queue = (T[]) (new Object[size]);
        ;
    }

    private boolean isEmpty() {
        return size == 0;
    }

    public void enq(T item) {
        if (size == queue.length)
            throw new IndexOutOfBoundsException();
        size++;
        queue[tail] = item;
        tail = (1 + tail) % queue.length;
    }

    public T deq() {
        if (isEmpty())
            return null;
        T data = queue[head];
        head = (1 + head) % queue.length;
        size--;
        return data;
    }
}
