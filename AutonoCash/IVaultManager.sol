//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IVaultManager {

    function redeemByVault(address user, uint amount) external;

}