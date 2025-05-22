//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IVault {

    function accept(address token) external view returns (bool);
    function tvl() external view returns (uint256);

}