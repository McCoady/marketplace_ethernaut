// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "solmate/tokens/ERC721.sol";

contract TestERC721 is ERC721 {
    uint256 totalSupply;
    
    constructor(address _to) ERC721("Test NFT", "TEST") {
        mintTokens(_to);
    }

    function mintTokens(address _to) public {
        uint256 _tokenId = totalSupply;
        _mint(_to, _tokenId);
        ++totalSupply;
    }

    function tokenURI(uint256 id) public override view returns(string memory uri) {
        return "www.test.com/";
    }
}