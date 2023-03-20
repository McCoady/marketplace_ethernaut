// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "solmate/tokens/ERC1155.sol";

contract TestERC1155 is ERC1155 {
    
    constructor(address _to) {
        mintTokens(_to);
    }

    function mintTokens(address _to) public {
        _mint(_to, 0,1,"");
    }


    function uri(uint256 id) public override view returns(string memory _uri) {
        return "www.test.com/";
    }
}