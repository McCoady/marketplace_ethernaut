// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MarketplaceProxy is UUPSUpgradeable, OwnableUpgradeable {


function _authorizeUpgrade(address) internal override onlyOwner {}
}