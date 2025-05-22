//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract GovGuard {
    address public gov;
    address public guard;

    modifier onlyGov() {
        require(msg.sender == gov, "not gov");
        _;
    }

    modifier onlyGuard() {
        require(msg.sender == guard || tx.origin == guard, "not guard");
        _;
    }

    constructor(address gov_, address guard_) {
        gov = gov_;
        guard = guard_;
    }

    function setGuard(address guard_) external onlyGov {
        guard = guard_;
    }

    function setGov(address newGov_) external onlyGov {
        gov = newGov_;
    }
}
