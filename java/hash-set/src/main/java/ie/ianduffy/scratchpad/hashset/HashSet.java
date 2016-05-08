package ie.ianduffy.scratchpad.hashset;

import ie.ianduffy.scratchpad.linkedset.LinkedSet;

public class HashSet<T> {

	private LinkedSet<T>[] hashTable;

	HashSet(int size) {
        hashTable = (LinkedSet<T>[]) (new LinkedSet[size]);
        for (int i = 0; i < size; i++) {
            hashTable[i] = new LinkedSet<>();
        }
    }
	private int hashCode(T item) {
		return Math.abs(item.hashCode() % hashTable.length);
	}

	public void add(T item) {
		hashTable[hashCode(item)].add(item);
	}

	public boolean contains(T item) {
		return hashTable[hashCode(item)].contains(item);
	}

	public int size() {
		int size = 0;
		for (int i = 0; i < hashTable.length; i++) {
			size = size + hashTable[i].size();
		}
		return size;
	}

}
