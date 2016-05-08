package ie.ianduffy.scratchpad.binarytree;

import org.junit.Test;

public class BinaryTreeTest {

	@Test
    public void testAddingToABinaryTree() {
        BinaryTree<Integer> binaryTree = new BinaryTree<>();

        assert binaryTree.add(10) == true;
        assert binaryTree.add(10) == false;
        assert binaryTree.add(1) == true;
        assert binaryTree.add(5) == true;

        assert binaryTree.size() == 3;
    }
	@Test
    public void testHeightCalculationOfABinaryTree() {
        BinaryTree<Integer> binaryTree = new BinaryTree<>();

        assert binaryTree.add(10) == true;
        assert binaryTree.add(1) == true;
        assert binaryTree.add(12) == true;

        assert binaryTree.height() == 2;
    }
	@Test
    public void testElementContainedWithinBinaryTree() {
        BinaryTree<Integer> binaryTree = new BinaryTree<>();

        assert binaryTree.add(10) == true;
        assert binaryTree.add(1) == true;
        assert binaryTree.add(12) == true;

        assert binaryTree.contains(10) == true;
        assert binaryTree.contains(1) == true;
        assert binaryTree.contains(12) == true;
        assert binaryTree.contains(100) == false;
    }
	@Test
    public void testGettingTheMinimumElementWithinABinaryTree() {
        BinaryTree<Integer> binaryTree = new BinaryTree<>();

        assert binaryTree.add(10) == true;
        assert binaryTree.add(1) == true;
        assert binaryTree.add(5) == true;
        assert binaryTree.add(2) == true;
        assert binaryTree.add(-1) == true;
        assert binaryTree.add(12) == true;

        assert binaryTree.min() == -1;

    }
	@Test
    public void testGettingTheMaximumElementWithinABinaryTree() {
        BinaryTree<Integer> binaryTree = new BinaryTree<>();

        assert binaryTree.add(10) == true;
        assert binaryTree.add(1) == true;
        assert binaryTree.add(5) == true;
        assert binaryTree.add(2) == true;
        assert binaryTree.add(-1) == true;
        assert binaryTree.add(100) == true;
        assert binaryTree.add(12) == true;

        assert binaryTree.max() == 100;

    }
}
