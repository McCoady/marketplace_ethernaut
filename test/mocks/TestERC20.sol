// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "solmate/tokens/ERC20.sol";

contract TestERC20 is ERC20 {
    
    constructor(address _to) ERC20("Test NFT", "TEST", 18) {
        mintTokens(_to);
    }

    function mintTokens(address _to) public {
        _mint(_to, 10 ether);
    }
}