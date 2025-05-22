//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./ICash.sol";

contract TokenFund is ERC20 {
    uint256 public constant MIN_RELEASE_DELAY = 60 days;
    uint256 public constant RELEASE_PERIOD = 30 days;
    uint256 public constant RELEASE_RATIO = 1e18 / 50;
    uint256 public constant MIN_RELEASE_CASH_TVL = 10_000_000 ether;

    address public immutable cash;
    address public immutable token;

    uint256 public START_RELEASE_TIME = type(uint256).max;

    mapping(address => uint256) public claimed;

    constructor(
        address cash_,
        address token_,
        uint amount_,
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) {
        cash = cash_;
        token = token_;
        _mint(msg.sender, amount_);
    }

    function setStartTime() external {
        require(
            START_RELEASE_TIME == type(uint256).max &&
                ICash(cash).lastWeekAvgTvl() >= MIN_RELEASE_CASH_TVL,
            "set starttime error"
        );
        START_RELEASE_TIME = block.timestamp + MIN_RELEASE_DELAY;
    }

    function claimable(address user) public view returns (uint256) {
        uint curTs = block.timestamp;
        if (curTs < START_RELEASE_TIME || balanceOf(user) == 0) {
            return 0;
        }
        uint retR = (RELEASE_RATIO * (curTs - START_RELEASE_TIME)) /
            RELEASE_PERIOD;
        if (retR > 1e18) {
            retR = 1e18;
        }
        uint ret = (retR * balanceOf(user)) / 1e18 - claimed[user];
        return ret;
    }

    function pureBalanceOf(address user) external view returns (uint256) {
        return balanceOf(user) - claimed[user];
    }

    function claim(uint256 amount) external {
        require(claimable(msg.sender) >= amount, "claim error");
        IERC20(token).transfer(msg.sender, amount);
        claimed[msg.sender] += amount;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        uint claimedBal = claimed[from];
        if (claimedBal > 0) {
            uint claimedAmount = (claimedBal * amount) / balanceOf(from);
            claimed[from] -= claimedAmount;
            claimed[to] += claimedAmount;
        }
    }
}
