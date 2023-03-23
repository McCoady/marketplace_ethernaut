// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "../src/Marketplace.sol";
import "./mocks/TestERC20.sol";
import "./mocks/TestERC721.sol";
import "./mocks/TestERC1155.sol";

contract ContractTest is Test, ERC721TokenReceiver, ERC1155TokenReceiver {
    Marketplace mrkt;
    TestERC20 whitelistedToken20;
    TestERC20 notWhitelistedToken20;
    TestERC721 token721;
    TestERC1155 token1155;

    address testUserOne = vm.addr(1);
    address testUserTwo = vm.addr(2);

    function setUp() public {
        mrkt = new Marketplace();
        mrkt.initialize(address(this));
        console.logAddress(mrkt.owner());
        whitelistedToken20 = new TestERC20(testUserTwo);
        whitelistedToken20 = new TestERC20(testUserTwo);
        token721 = new TestERC721(testUserOne);
        token1155 = new TestERC1155(testUserOne);
    }

    function testTokenBalances() public {
        uint256 erc20Balance = whitelistedToken20.balanceOf(testUserTwo);
        assertEq(erc20Balance, 10 ether);

        assertEq(token721.ownerOf(0), testUserOne);
        assertEq(token1155.balanceOf(testUserOne, 0), 1);
    }

    function testWhitelistERC20() public {
        mrkt.whitelistERC20(address(whitelistedToken20));
        assert(mrkt.whitelistedERC20(address(whitelistedToken20)));
    }

    function testRemoveWhitelistERC20() public {
        mrkt.whitelistERC20(address(whitelistedToken20));
        assert(mrkt.whitelistedERC20(address(whitelistedToken20)));
        mrkt.removeWhitelistERC20(address(whitelistedToken20));
        assert(!mrkt.whitelistedERC20(address(whitelistedToken20)));
    }

    function testSignedMessage() public {
        Item memory _testItem = Item(
            address(0),
            0,
            1 ether,
            block.timestamp + 1000,
            address(this),
            address(0)
        );
        bytes32 signature = getEthSignedMessage(_testItem);
        console.logBytes32(signature);
    }

    function testPurchaseWithEth() public {
        setAllowanceERC721(testUserOne);
        uint256 testUserOneBalance = testUserOne.balance;

        Item memory _testItem = Item(
            address(token721),
            0,
            1 ether,
            block.timestamp + 1000,
            testUserOne,
            address(0)
        );

        bytes32 hashedMsg = getEthSignedMessage(_testItem);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, hashedMsg);
        bytes memory signature = abi.encodePacked(r, s, v);
        mrkt.purchaseWithEth{value: 1 ether}(_testItem, signature);

        // assert logic
        assertEq(testUserOneBalance + 1 ether, testUserOne.balance);
        assertEq(token721.ownerOf(0), address(this));
    }

    function testCannotPurchaseExpiredOffer() public {
        setAllowanceERC721(testUserOne);
        uint256 testUserOneBalance = testUserOne.balance;

        Item memory _testItem = Item(
            address(token721),
            0,
            1 ether,
            block.timestamp + 1000,
            testUserOne,
            address(0)
        );

        bytes32 hashedMsg = getEthSignedMessage(_testItem);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, hashedMsg);
        bytes memory signature = abi.encodePacked(r, s, v);
        vm.warp(1002);
        vm.expectRevert(Marketplace.Expired.selector);
        mrkt.purchaseWithEth{value: 1 ether}(_testItem, signature);
    }

    function testCannotPurchaseWithUsedSignature() public {
        setAllowanceERC721(testUserOne);
        uint256 testUserOneBalance = testUserOne.balance;

        Item memory _testItem = Item(
            address(token721),
            0,
            1 ether,
            block.timestamp + 1000,
            testUserOne,
            address(0)
        );

        bytes32 hashedMsg = getEthSignedMessage(_testItem);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, hashedMsg);
        bytes memory signature = abi.encodePacked(r, s, v);
        mrkt.purchaseWithEth{value: 1 ether}(_testItem, signature);

        // assert logic
        assertEq(testUserOneBalance + 1 ether, testUserOne.balance);
        assertEq(token721.ownerOf(0), address(this));

        token721.transferFrom(address(this), testUserOne, 0);
        assertEq(token721.ownerOf(0), testUserOne);

        vm.expectRevert(Marketplace.UsedSignature.selector);
        mrkt.purchaseWithEth{value: 1 ether}(_testItem, signature);
    }

    function testCannotPurchaseUnlistedToken() public {
        setAllowanceERC721(testUserOne);
        token721.mintTokens(testUserOne);
        assertEq(token721.ownerOf(1), testUserOne);


        Item memory _testItem = Item(
            address(token721),
            0,
            1 ether,
            block.timestamp + 1000,
            testUserOne,
            address(0)
        );

        Item memory _testWrongItem = Item(
            address(token721),
            1,
            1 ether,
            block.timestamp + 1000,
            testUserOne,
            address(0)
        );

        bytes32 hashedMsg = getEthSignedMessage(_testItem);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, hashedMsg);
        bytes memory signature = abi.encodePacked(r, s, v);
        vm.expectRevert(Marketplace.InvalidSignature.selector);
        mrkt.purchaseWithEth{value: 1 ether}(_testWrongItem, signature);
    }

    function testCannotPurchaseWrongPrice() public {
        setAllowanceERC721(testUserOne);
        uint256 testUserOneBalance = testUserOne.balance;

        Item memory _testItem = Item(
            address(token721),
            0,
            1 ether,
            block.timestamp + 1000,
            testUserOne,
            address(0)
        );

        bytes32 hashedMsg = getEthSignedMessage(_testItem);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, hashedMsg);
        bytes memory signature = abi.encodePacked(r, s, v);
        vm.expectRevert(Marketplace.WrongPrice.selector);
        mrkt.purchaseWithEth{value: 0.1 ether}(_testItem, signature);
    }

    function testAcceptBid() public {
        uint256 testUserTwoBalance = whitelistedToken20.balanceOf(testUserTwo);

        // set marketplace allowance for testUserTwo
        setAllowanceERC20(testUserTwo);
        // set marketplace allowance of ERC721 token for testUserOne
        setAllowanceERC721(testUserOne);

        //create bid from test address
        Item memory _testItem = Item(
            address(token721),
            0,
            1 ether,
            block.timestamp + 1000,
            testUserTwo,
            address(whitelistedToken20)
        );

        bytes memory signature = buildSignature(_testItem, 2);
        startHoax(testUserOne);
        mrkt.acceptBid(_testItem, signature);

        assertEq(
            testUserTwoBalance - 1 ether,
            whitelistedToken20.balanceOf(testUserTwo)
        );
        assertEq(1 ether, whitelistedToken20.balanceOf(testUserOne));
        assertEq(token721.ownerOf(0), testUserTwo);
    }

    function testCannotAcceptExpiredBid() public {
        // set marketplace allowance for testUserTwo
        setAllowanceERC20(testUserTwo);
        // set marketplace allowance of ERC721 token for testUserOne
        setAllowanceERC721(testUserOne);

        //create bid from test address
        Item memory _testItem = Item(
            address(token721),
            0,
            1 ether,
            block.timestamp + 1000,
            testUserTwo,
            address(whitelistedToken20)
        );

        bytes memory signature = buildSignature(_testItem, 2);
        startHoax(testUserOne);
        vm.warp(1002);
        vm.expectRevert(Marketplace.Expired.selector);
        mrkt.acceptBid(_testItem, signature);
    }

    function testCannotAcceptBidWrongPrice() public {
        // set marketplace allowance for testUserTwo
        setAllowanceERC20(testUserTwo);
        // set marketplace allowance of ERC721 token for testUserOne
        setAllowanceERC721(testUserOne);

        //create bid from test address
        Item memory _testItem = Item(
            address(token721),
            0,
            1 ether,
            block.timestamp + 1000,
            testUserTwo,
            address(whitelistedToken20)
        );

        Item memory _fakeItem = Item(
            address(token721),
            0,
            10 ether,
            block.timestamp + 1000,
            testUserTwo,
            address(whitelistedToken20)
        );

        bytes memory signature = buildSignature(_fakeItem, 2);
        startHoax(testUserOne);
        vm.expectRevert(Marketplace.InvalidSignature.selector);
        mrkt.acceptBid(_testItem, signature);
    }

    function testCannotAcceptBidWithNonWhitelistedERC20() public {
        uint256 testUserTwoBalance = whitelistedToken20.balanceOf(testUserTwo);

        // set marketplace allowance for testUserTwo
        setAllowanceERC20(testUserTwo);
        // set marketplace allowance of ERC721 token for testUserOne
        setAllowanceERC721(testUserOne);

        //create bid from test address
        Item memory _testItem = Item(
            address(token721),
            0,
            1 ether,
            block.timestamp + 1000,
            testUserTwo,
            address(notWhitelistedToken20)
        );

        bytes memory signature = buildSignature(_testItem, 2);
        startHoax(testUserOne);
        vm.expectRevert(Marketplace.ERC20NotWhitelisted.selector);
        mrkt.acceptBid(_testItem, signature);
    }

    function testPurchaseERC1155WithEth() public {
        setAllowanceERC1155(testUserOne);
        uint256 testUserOneBalance = testUserOne.balance;

        Item memory _testItem = Item(
            address(token1155),
            0,
            1 ether,
            block.timestamp + 1000,
            testUserOne,
            address(0)
        );

        bytes32 hashedMsg = getEthSignedMessage(_testItem);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, hashedMsg);
        bytes memory signature = abi.encodePacked(r, s, v);
        mrkt.purchaseWithEth{value: 1 ether}(_testItem, signature);

        // assert logic
        assertEq(testUserOneBalance + 1 ether, testUserOne.balance);
        assertEq(token1155.balanceOf(address(this), 0), 1);
        assertEq(token1155.balanceOf(testUserOne, 0), 0);
    }

    function testAcceptBidERC1155() public {
        uint256 testUserTwoBalance = whitelistedToken20.balanceOf(testUserTwo);

        // set marketplace allowance for testUserTwo
        setAllowanceERC20(testUserTwo);
        // set marketplace allowance of ERC721 token for testUserOne
        setAllowanceERC1155(testUserOne);

        //create bid from test address
        Item memory _testItem = Item(
            address(token1155),
            0,
            1 ether,
            block.timestamp + 1000,
            testUserTwo,
            address(whitelistedToken20)
        );

        bytes memory signature = buildSignature(_testItem, 2);
        startHoax(testUserOne);
        mrkt.acceptBid(_testItem, signature);

        assertEq(
            testUserTwoBalance - 1 ether,
            whitelistedToken20.balanceOf(testUserTwo)
        );
        assertEq(1 ether, whitelistedToken20.balanceOf(testUserOne));
        assertEq(token1155.balanceOf(testUserTwo, 0), 1);
        assertEq(token1155.balanceOf(testUserOne, 0), 0);
    }

    function testCannotPurchaseAfterTokenTransferred() public {
        setAllowanceERC721(testUserOne);

        Item memory _testItem = Item(
            address(token721),
            0,
            1 ether,
            block.timestamp + 1000,
            testUserOne,
            address(0)
        );

        bytes32 hashedMsg = getEthSignedMessage(_testItem);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, hashedMsg);
        bytes memory signature = abi.encodePacked(r, s, v);
        startHoax(testUserOne);
        token721.transferFrom(testUserOne, testUserTwo, 0);
        vm.stopPrank();
        setAllowanceERC721(testUserTwo);
        vm.expectRevert(bytes("WRONG_FROM"));
        mrkt.purchaseWithEth{value: 1 ether}(_testItem, signature);
    }

    function testCanAcceptBidAfterTransfer() public {
        uint256 testUserTwoBalance = whitelistedToken20.balanceOf(testUserTwo);

        // set marketplace allowance for testUserTwo
        setAllowanceERC20(testUserTwo);
        // set marketplace allowance of ERC721 token for testUserOne
        setAllowanceERC721(testUserOne);

        //create bid from test address
        Item memory _testItem = Item(
            address(token721),
            0,
            1 ether,
            block.timestamp + 1000,
            testUserTwo,
            address(whitelistedToken20)
        );

        bytes memory signature = buildSignature(_testItem, 2);
        startHoax(testUserOne);
        token721.transferFrom(testUserOne, address(this), 0);
        vm.stopPrank();
        setAllowanceERC721(address(this));
        mrkt.acceptBid(_testItem, signature);

        assertEq(
            testUserTwoBalance - 1 ether,
            whitelistedToken20.balanceOf(testUserTwo)
        );
        assertEq(1 ether, whitelistedToken20.balanceOf(address(this)));
        assertEq(token721.ownerOf(0), testUserTwo);
    }

    // Helper functions

    function getEthSignedMessage(
        Item memory _item
    ) public returns (bytes32 sigHash) {
        sigHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                _item.collection,
                _item.tokenId,
                _item.price,
                _item.expiry,
                _item.signer,
                _item.paymentToken,
                block.chainid,
                address(mrkt)
            )
        );
    }

    function setAllowanceERC721(address _addr) public {
        // approve ERC721 token for transfer as testUserOne
        startHoax(_addr);
        token721.approve(address(mrkt), 0);
        vm.stopPrank();
    }

    function setAllowanceERC1155(address _addr) public {
        // approve ERC721 token for transfer as testUserOne
        startHoax(_addr);
        token1155.setApprovalForAll(address(mrkt), true);
        vm.stopPrank();
    }

    function setAllowanceERC20(address _addr) public {
        // whitelist testERC20
        mrkt.whitelistERC20(address(whitelistedToken20));
        // approve ERC20 token for transfer as testUserTwo
        startHoax(_addr);
        whitelistedToken20.approve(address(mrkt), 1 ether);
        vm.stopPrank();
    }

    function buildSignature(
        Item memory _item,
        uint256 signer
    ) public returns (bytes memory signature) {
        bytes32 hashedMsg = getEthSignedMessage(_item);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signer, hashedMsg);
        signature = abi.encodePacked(r, s, v);
    }
}
