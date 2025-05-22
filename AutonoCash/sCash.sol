//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

contract StakedCash is ERC4626 {
    constructor(IERC20 _asset) ERC20("Staked USDA", "sUSDA") ERC4626(_asset) {}
}
