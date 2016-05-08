package ie.ianduffy.scratchpad.binarytree;

import org.junit.Test;

import java.util.List;

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

    @Test
    public void testPreOrder() {
        BinaryTree<Integer> binaryTree = new BinaryTree<>();
        binaryTree.add(7);
        binaryTree.add(1);
        binaryTree.add(0);
        binaryTree.add(3);
        binaryTree.add(2);
        binaryTree.add(5);
        binaryTree.add(4);
        binaryTree.add(6);
        binaryTree.add(9);
        binaryTree.add(8);
        binaryTree.add(10);

        List<Integer> result = binaryTree.preOrder();
        assert result.get(0) == 7;
        assert result.get(1) == 1;
        assert result.get(2) == 0;
        assert result.get(3) == 3;
        assert result.get(4) == 2;
        assert result.get(5) == 5;
        assert result.get(6) == 4;
        assert result.get(7) == 6;
        assert result.get(8) == 9;
        assert result.get(9) == 8;
        assert result.get(10) == 10;
    }

    @Test
    public void testInorder() {
        BinaryTree<Integer> binaryTree = new BinaryTree<>();
        binaryTree.add(7);
        binaryTree.add(1);
        binaryTree.add(0);
        binaryTree.add(3);
        binaryTree.add(2);
        binaryTree.add(5);
        binaryTree.add(4);
        binaryTree.add(6);
        binaryTree.add(9);
        binaryTree.add(8);
        binaryTree.add(10);

        List<Integer> result = binaryTree.inOrder();
        assert result.get(0) == 0;
        assert result.get(1) == 1;
        assert result.get(2) == 2;
        assert result.get(3) == 3;
        assert result.get(4) == 4;
        assert result.get(5) == 5;
        assert result.get(6) == 6;
        assert result.get(7) == 7;
        assert result.get(8) == 8;
        assert result.get(9) == 9;
        assert result.get(10) == 10;
    }


    @Test
    public void testPostOrder() {
        BinaryTree<Integer> binaryTree = new BinaryTree<>();
        binaryTree.add(7);
        binaryTree.add(1);
        binaryTree.add(0);
        binaryTree.add(3);
        binaryTree.add(2);
        binaryTree.add(5);
        binaryTree.add(4);
        binaryTree.add(6);
        binaryTree.add(9);
        binaryTree.add(8);
        binaryTree.add(10);

        List<Integer> result = binaryTree.postOrder();
        assert result.get(0) == 0;
        assert result.get(1) == 2;
        assert result.get(2) == 4;
        assert result.get(3) == 6;
        assert result.get(4) == 5;
        assert result.get(5) == 3;
        assert result.get(6) == 1;
        assert result.get(7) == 8;
        assert result.get(8) == 10;
        assert result.get(9) == 9;
        assert result.get(10) == 7;
    }
}
