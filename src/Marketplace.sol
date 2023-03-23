// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "openzeppelin-contracts/utils/cryptography/SignatureChecker.sol";
import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "openzeppelin-contracts/utils/introspection/IERC165.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/token/ERC1155/IERC1155.sol";

struct Item {
    address collection;
    uint256 tokenId;
    uint256 price;
    uint256 expiry;
    address signer;
    address paymentToken;
}

contract Marketplace is Initializable, OwnableUpgradeable {
    error WrongPrice();
    error Expired();
    error InvalidSignature();
    error EtherSendFail();
    error ERC20NotWhitelisted();
    error UsedSignature();
    error ZeroAddress();

    mapping(address => bool) public whitelistedERC20;
    mapping(bytes => bool) public usedSig;

    function initialize(address _owner) public initializer {
        if (_owner == address(0)) revert ZeroAddress();
        __Ownable_init();
        transferOwnership(_owner);
    }

    function purchaseWithEth(
        Item calldata _item,
        bytes calldata signature
    ) external payable {
        if (msg.value != _item.price) revert WrongPrice();
        if (block.timestamp > _item.expiry) revert Expired();
        if (usedSig[signature]) revert UsedSignature();

        bool validSig = checkSignature(_item, signature);
        if (!validSig) revert InvalidSignature();

        (bool sent, ) = _item.signer.call{value: msg.value}("");
        if (!sent) revert EtherSendFail();

        usedSig[signature] = true;
        if (IERC165(_item.collection).supportsInterface(0xd9b67a26)) {
            IERC1155(_item.collection).safeTransferFrom(
                _item.signer,
                msg.sender,
                _item.tokenId,
                1,
                ""
            );
        } else if (IERC165(_item.collection).supportsInterface(0x80ac58cd)) {
            IERC721(_item.collection).safeTransferFrom(
                _item.signer,
                msg.sender,
                _item.tokenId
            );
        }
    }

    function acceptBid(Item calldata _item, bytes calldata signature) external {
        if (block.timestamp > _item.expiry) revert Expired();
        if (usedSig[signature]) revert UsedSignature();
        bool validSig = checkSignature(_item, signature);
        if (!validSig) revert InvalidSignature();
        if (!whitelistedERC20[_item.paymentToken]) revert ERC20NotWhitelisted();

        usedSig[signature] = true;
        if (IERC165(_item.collection).supportsInterface(0xd9b67a26)) {
            IERC1155(_item.collection).safeTransferFrom(
                msg.sender,
                _item.signer,
                _item.tokenId,
                1,
                ""
            );
        } else if (IERC165(_item.collection).supportsInterface(0x80ac58cd)) {
            IERC721(_item.collection).safeTransferFrom(
                msg.sender,
                _item.signer,
                _item.tokenId
            );
        }
        IERC20(_item.paymentToken).transferFrom(
            _item.signer,
            msg.sender,
            _item.price
        );

        // check signature valid
        // transfer funds to seller (end bid validity?)
        // transfer token to owner
    }

    function whitelistERC20(address _tokenAddress) external onlyOwner {
        whitelistedERC20[_tokenAddress] = true;
    }

    function removeWhitelistERC20(address _tokenAddress) external onlyOwner {
        whitelistedERC20[_tokenAddress] = false;
    }

    function checkSignature(
        Item calldata _item,
        bytes calldata signature
    ) internal view returns (bool) {
        // signature is a hash of collection address, tokenId, price, expiry, address of person who created the bid/offer, the payment token (0 if $ETH), chainId,address of this contract
        bytes32 sigHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                _item.collection,
                _item.tokenId,
                _item.price,
                _item.expiry,
                _item.signer,
                _item.paymentToken,
                block.chainid,
                address(this)
            )
        );

        return
            SignatureChecker.isValidSignatureNow(
                _item.signer,
                sigHash,
                signature
            );
    }
}
