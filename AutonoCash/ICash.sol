//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ICash {

    function mint(address to, uint amount) external;
    function burn(address from, uint amount) external; 
    function lastWeekAvgTvl() external view returns (uint256);

}