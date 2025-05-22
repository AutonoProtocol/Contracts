//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TokenSale {
    uint public constant START_PRICE = 2e16;
    uint public constant END_PRICE = 1e18;
    uint public constant MAX_SALE_AMOUNT = 100_000_000 ether;

    address public immutable cash;
    address public immutable token;
    address public immutable treasury;

    uint public saleAmount;

    constructor(address cash_, address token_, address treasury_) {
        cash = cash_;
        token = token_;
        treasury = treasury_;
    }

    function buyToken(uint tokenAmount) external {
        require(tokenAmount >= 1e18 && tokenAmount <= 1_000_000 ether, "error");
        uint cashAmount = getCashAmount(tokenAmount);
        IERC20(cash).transferFrom(msg.sender, treasury, cashAmount);
        saleAmount += tokenAmount;
        IERC20(token).transfer(msg.sender, tokenAmount);
    }

    function getCashAmount(
        uint tokenAmount
    ) public view returns (uint cashAmount) {
        uint price = START_PRICE +
            ((END_PRICE - START_PRICE) * (saleAmount + tokenAmount / 2)) /
            MAX_SALE_AMOUNT;
        if (price > 1e18) {
            price = 1e18;
        }
        cashAmount = (tokenAmount * price) / 1e18;
    }
}
