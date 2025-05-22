//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./GovGuard.sol";
import "./ICash.sol";

interface ISale {
    function getCashAmount(
        uint tokenAmount
    ) external view returns (uint cashAmount);
}

contract TokenDistributor is GovGuard {

    address public immutable cash;
    address public immutable token;
    address public immutable sale;

    address public immutable distributor;

    uint public constant MIN_RELEASE_PERIOD = 1 weeks;
    uint public lastReleaseTs;

    constructor(
        address cash_,
        address token_,
        address sale_,
        address distributor_,
        address gov_,
        address guard_
    ) GovGuard(gov_, guard_) {
        cash = cash_;
        token = token_;
        sale = sale_;
        distributor = distributor_;
    }

    function maxReleaseAmount() public view returns(uint) {
        return ICash(cash).lastWeekAvgTvl() * 1e18 / ISale(sale).getCashAmount(1e18) / 50;
    }

    function release(uint amount) external onlyGuard {
        require(lastReleaseTs + MIN_RELEASE_PERIOD <= block.timestamp, "release time error");
        require(amount <= maxReleaseAmount(), "release amount error");
        IERC20(token).transfer(distributor, amount);
        lastReleaseTs = block.timestamp;
    }



}